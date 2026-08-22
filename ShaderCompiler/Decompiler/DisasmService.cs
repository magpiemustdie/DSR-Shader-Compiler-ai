using System;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace ShaderCompiler.Decompiler
{
    /// <summary>
    /// Orchestrates the full decompile pipeline:
    ///   .fpo/.vpo → DXBC asm (via fxc /dumpbin)
    ///              → HLSL skeleton (HlslGenerator, metadata from DxbcParser)
    ///              → compilable HLSL (AsmToHlsl translator)
    /// </summary>
    public class DisasmService
    {
        private readonly string _fxcPath;

        public DisasmService(string fxcPath)
        {
            if (string.IsNullOrWhiteSpace(fxcPath))
                throw new ArgumentException("fxc.exe path is not set.");
            if (!File.Exists(fxcPath))
                throw new FileNotFoundException($"fxc.exe not found: {fxcPath}");
            _fxcPath = fxcPath;
        }

        // ----------------------------------------------------------------
        // Step 1: .fpo/.vpo → DXBC asm text
        // fxc /dumpbin outputs disassembly to stdout
        // ----------------------------------------------------------------
        public async Task<string> DisassembleAsync(string fpoPath)
        {
            var psi = new ProcessStartInfo(_fxcPath, $"/dumpbin \"{fpoPath}\"")
            {
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
                UseShellExecute        = false,
                CreateNoWindow         = true
            };

            using var proc = Process.Start(psi)!;
            var stdoutTask = proc.StandardOutput.ReadToEndAsync();
            var stderrTask = proc.StandardError.ReadToEndAsync();
            await Task.WhenAll(stdoutTask, stderrTask, proc.WaitForExitAsync());

            string stdout = await stdoutTask;
            string stderr = await stderrTask;

            // fxc /dumpbin writes asm to stdout
            if (!string.IsNullOrWhiteSpace(stdout))
                return stdout;

            return $"; fxc disassembly failed (exit {proc.ExitCode})\n; {stderr}";
        }

        // ----------------------------------------------------------------
        // Step 2a: .fpo → HLSL skeleton (metadata + asm in comments)
        // ----------------------------------------------------------------
        public async Task<string> ToHlslSkeletonAsync(string fpoPath)
        {
            byte[] data = await File.ReadAllBytesAsync(fpoPath);
            string asm  = await DisassembleAsync(fpoPath);

            var parser = new DxbcParser();
            parser.Parse(data);

            return HlslGenerator.Generate(parser, asm);
        }

        // ----------------------------------------------------------------
        // Step 2b: asm text → compilable HLSL (full translation)
        // Auto-detects DX9 (ps_3_0) vs DX11 (ps_5_0)
        // ----------------------------------------------------------------
        public static string TranslateAsm(string asmText)
        {
            // Detect DX9 by presence of ps_3_0 / vs_3_0 / ps_2_0
            if (Regex.IsMatch(asmText, @"\b(ps|vs)_[23]_\d\b"))
            {
                var t9 = new Dx9AsmToHlsl();
                return t9.Translate(asmText);
            }
            var t = new AsmToHlsl();
            return t.Translate(asmText);
        }

        // ----------------------------------------------------------------
        // Step 2c: .fpo → compilable HLSL (skeleton + translated body)
        // ----------------------------------------------------------------
        public async Task<string> ToTranslatedHlslAsync(string fpoPath)
        {
            string asm = await DisassembleAsync(fpoPath);
            return TranslateAsm(asm);
        }

        // ----------------------------------------------------------------
        // Step 3: compilable HLSL → .fpo (compile back)
        // ----------------------------------------------------------------
        public async Task<(bool success, string output)> CompileAsync(
            string hlslPath, string outPath, string profile = "ps_5_0", string entry = "main",
            string[]? defines = null)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
            string defArgs = defines != null
                ? string.Join(" ", System.Linq.Enumerable.Select(defines, d => $"/D{d}"))
                : "";
            // Compile without debug info to match original shader size
            // Original shaders don't have /Zi debug information
            string args = $"\"{hlslPath}\" /Fo\"{outPath}\" /T {profile} /E {entry} /nologo {defArgs}";

            var psi = new ProcessStartInfo(_fxcPath, args)
            {
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
                UseShellExecute        = false,
                CreateNoWindow         = true
            };

            using var proc = Process.Start(psi)!;
            var stdoutTask = proc.StandardOutput.ReadToEndAsync();
            var stderrTask = proc.StandardError.ReadToEndAsync();
            await Task.WhenAll(stdoutTask, stderrTask, proc.WaitForExitAsync());

            string combined = (await stdoutTask) + (await stderrTask);
            return (proc.ExitCode == 0, combined);
        }

        // ----------------------------------------------------------------
        // Batch: folder of .fpo/.vpo/.cpo → asm + optional translated HLSL
        // ----------------------------------------------------------------
        public async Task BatchDecompileAsync(string inputDir, string outputDir,
            bool translateToHlsl, Action<string> log, Action<int, int> progress)
        {
            var exts = new[] { "*.fpo", "*.vpo", "*.cpo" };
            var allFiles = new System.Collections.Generic.List<string>();
            foreach (var ext in exts)
                allFiles.AddRange(Directory.GetFiles(inputDir, ext));

            Directory.CreateDirectory(outputDir);
            int done = 0, total = allFiles.Count;

            foreach (var f in allFiles)
            {
                string name = Path.GetFileName(f);
                try
                {
                    string asm    = await DisassembleAsync(f);
                    string asmOut = Path.Combine(outputDir, name + ".asm");
                    await File.WriteAllTextAsync(asmOut, asm);

                    if (translateToHlsl)
                    {
                        string hlsl    = TranslateAsm(asm);
                        string hlslOut = Path.Combine(outputDir, name + ".translated.hlsl");
                        await File.WriteAllTextAsync(hlslOut, hlsl);
                        log($"  {name} → .asm + .translated.hlsl");
                    }
                    else
                    {
                        log($"  {name} → .asm");
                    }
                }
                catch (Exception ex)
                {
                    log($"  SKIP {name}: {ex.Message}");
                }

                progress(++done, total);
            }
        }
    }
}
