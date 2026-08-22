using Microsoft.Win32;
using ShaderCompiler.Decompiler;
using SoulsFormats;
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using WinForms = System.Windows.Forms;

namespace ShaderCompiler
{
    public partial class MainWindow : Window
    {
        private CancellationTokenSource? _cts;

        public MainWindow()
        {
            InitializeComponent();
            LoadSettings();
        }

        // ----------------------------------------------------------------
        // Settings
        // ----------------------------------------------------------------
        private string SettingsPath => Path.Combine(AppContext.BaseDirectory, "settings.txt");

        private void LoadSettings()
        {
            if (!File.Exists(SettingsPath)) return;
            foreach (var line in File.ReadAllLines(SettingsPath))
            {
                var p = line.Split('=', 2);
                if (p.Length != 2) continue;
                switch (p[0])
                {
                    case "DSR":          TxtDSR.Text          = p[1]; break;
                    case "Original":     TxtOriginal.Text     = p[1]; break; // legacy
                    case "PTDE":         TxtPTDE.Text         = p[1]; break; // legacy
                    case "FXC":          TxtFXC.Text          = p[1]; break;
                    case "FXC81":        TxtFXC81.Text        = p[1]; break;
                    case "Source":       TxtSource.Text       = p[1]; break;
                    case "DSRShaders":   /* deprecated — DSR\shader\ is used automatically */ break;
                    case "PTDEShaders":  TxtPTDEShaders.Text  = p[1]; break;
                    case "SwitchShaders":TxtSwitchShaders.Text= p[1]; break;
                }
            }
            // Migrate legacy PTDE field
            if (string.IsNullOrWhiteSpace(TxtPTDEShaders.Text) && !string.IsNullOrWhiteSpace(TxtPTDE.Text))
                TxtPTDEShaders.Text = TxtPTDE.Text;
            // Auto-detect fxc_new if not set
            if (string.IsNullOrWhiteSpace(TxtFXC.Text))
            {
                string exeDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)!;
                string autoNew = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", "tools", "fxc_new", "fxc.exe"));
                if (File.Exists(autoNew)) TxtFXC.Text = autoNew;
            }
            // Migrate old tools\fxc.exe → tools\fxc_new\fxc.exe
            else if (TxtFXC.Text.EndsWith(@"\tools\fxc.exe", StringComparison.OrdinalIgnoreCase) ||
                     TxtFXC.Text.EndsWith("/tools/fxc.exe", StringComparison.OrdinalIgnoreCase))
            {
                string migrated = Path.Combine(Path.GetDirectoryName(TxtFXC.Text)!, "..", "fxc_new", "fxc.exe");
                migrated = Path.GetFullPath(migrated);
                if (File.Exists(migrated)) TxtFXC.Text = migrated;
            }
            // Auto-detect fxc_81 if not set
            if (string.IsNullOrWhiteSpace(TxtFXC81.Text))
            {
                string exeDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)!;
                string auto81 = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", "tools", "fxc_81", "fxc.exe"));
                if (File.Exists(auto81)) TxtFXC81.Text = auto81;
            }
        }

        private void SaveSettings() =>
            File.WriteAllLines(SettingsPath, new[]
            {
                $"DSR={TxtDSR.Text}",
                $"Original={TxtOriginal.Text}",
                $"FXC={TxtFXC.Text}",
                $"FXC81={TxtFXC81.Text}",
                $"Source={TxtSource.Text}",
                $"PTDEShaders={TxtPTDEShaders.Text}",
                $"SwitchShaders={TxtSwitchShaders.Text}",
            });

        // ----------------------------------------------------------------
        // Settings browse
        // ----------------------------------------------------------------
        private void BrowseDSR_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog
            {
                Description = "Select Dark Souls Remastered game folder (contains DarkSoulsRemastered.exe)",
                SelectedPath = TxtDSR.Text
            };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK)
                TxtDSR.Text = dlg.SelectedPath;
        }

        private void BrowseOriginal_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog
            {
                Description  = "Select folder with original (vanilla) .shaderbnd.dcx files",
                SelectedPath = TxtOriginal.Text
            };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK)
                TxtOriginal.Text = dlg.SelectedPath;
        }

        private void BrowsePTDE_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog
            {
                Description  = "Select PTDE shader folder (contains FRPG_Flver_fpo.shaderbnd etc.)",
                SelectedPath = TxtPTDE.Text
            };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK)
                TxtPTDE.Text = dlg.SelectedPath;
        }

        private void BrowseFXC_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog { Filter = "fxc.exe|fxc.exe|All files|*.*", Title = "Select fxc.exe" };
            if (dlg.ShowDialog() == true) TxtFXC.Text = dlg.FileName;
        }

        private void BrowseFXC81_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog
            {
                Filter = "fxc.exe|fxc.exe|All files|*.*",
                Title  = "Select fxc.exe from Windows 8.1 SDK (version 6.3.9600.16384)",
                InitialDirectory = string.IsNullOrWhiteSpace(TxtFXC81.Text)
                    ? @"C:\Program Files (x86)\Windows Kits\8.1\bin\x64"
                    : Path.GetDirectoryName(TxtFXC81.Text)
            };
            if (dlg.ShowDialog() == true) TxtFXC81.Text = dlg.FileName;
        }

        private void BrowseSource_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog
            {
                Description = "Select shader source folder — must contain FRPG_FlverPBL, FRPG_Filter, FRPG_Menu subfolders",
                SelectedPath = TxtSource.Text
            };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK)
                TxtSource.Text = dlg.SelectedPath;
        }

        // ── New platform shader folder browsers ──
        private void BrowseDSRShaders_Click(object sender, RoutedEventArgs e)
        {
            // DSR shaders = DSR\shader\ — just open the folder browser at that path
            var dlg = new WinForms.FolderBrowserDialog
            {
                Description  = "Select DSR shader folder (contains .shaderbnd.dcx files)",
                SelectedPath = Path.Combine(TxtDSR.Text, "shader")
            };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK)
                TxtDSR.Text = Path.GetDirectoryName(dlg.SelectedPath) ?? dlg.SelectedPath;
        }

        private void BrowsePTDEShaders_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog
            {
                Description  = "Select PTDE shader folder (contains .shaderbnd files)",
                SelectedPath = TxtPTDEShaders.Text
            };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK)
                TxtPTDEShaders.Text = dlg.SelectedPath;
        }

        private void BrowseSwitchShaders_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog
            {
                Description  = "Select DSR Switch shader folder (contains .fpo binary files)",
                SelectedPath = TxtSwitchShaders.Text
            };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK)
                TxtSwitchShaders.Text = dlg.SelectedPath;
        }

        // ----------------------------------------------------------------
        // Filter checkbox sync: "Filter (all)" ↔ sub-checkboxes
        // ----------------------------------------------------------------
        // ----------------------------------------------------------------
        // Build
        // ----------------------------------------------------------------
        private async void Build_Click(object sender, RoutedEventArgs e)
        {
            if (BtnBuild.Content.ToString() == "Cancel") { _cts?.Cancel(); return; }

            SaveSettings();
            TxtLog.Clear();
            Progress.Value = 0;
            TxtStatus.Text = "";
            BtnBuild.Content = "Cancel";
            _cts = new CancellationTokenSource();

            string buildFxc = (ChkUseFxc81ForBuild.IsChecked == true && File.Exists(TxtFXC81.Text))
                ? TxtFXC81.Text : TxtFXC.Text;

            var builder = new ShaderBuilder(
                dsr:         TxtDSR.Text,
                fxc:         buildFxc,
                source:      TxtSource.Text,
                force:       ChkForce.IsChecked == true,
                token:       _cts.Token,
                originalDir: TxtOriginal.Text);

            builder.OnLog      += msg => Dispatcher.Invoke(() => { TxtLog.AppendText(msg + "\n"); TxtLog.ScrollToEnd(); });
            builder.OnProgress += (done, total) => Dispatcher.Invoke(() =>
            {
                Progress.Value = total > 0 ? done * 100.0 / total : 0;
                TxtStatus.Text = $"{done}/{total}";
            });

            LogBuild($"FXC: {buildFxc}");
            builder.ShowArchives();

            // Read checkbox states on UI thread
            bool buildFlverFpo = ChkFlver.IsChecked    == true;
            bool buildFlverVpo = ChkFlverVS.IsChecked  == true;
            bool buildFilter   = ChkFilter.IsChecked   == true;
            bool buildMenu     = ChkMenu.IsChecked      == true;
            bool buildSfxPBL   = ChkSfxPBL.IsChecked   == true;
            bool buildDeferred = ChkDeferred.IsChecked  == true;
            bool buildDbgFont  = ChkDbgFont.IsChecked   == true;
            bool packAfter     = ChkPackAfterBuild.IsChecked == true;

            try
            {
                await Task.Run(() =>
                {
                    if (buildFlverFpo) { builder.BuildFlverPBL(); builder.BuildSnow(); }
                    if (buildFlverVpo) { builder.BuildFlverPBLVS(); builder.BuildSnowVS(); }
                    if (buildFilter)   builder.BuildFilter();
                    if (buildMenu)     builder.BuildMenu();
                    if (buildSfxPBL)   builder.BuildSfxPBL();
                    if (buildDeferred) builder.BuildDeferred();
                    if (buildDbgFont)  builder.BuildDbgFont();
                });

                if (packAfter && builder.Errors == 0)
                {
                    LogBuild("\nPacking bundles...");
                    await Task.Run(() => builder.BuildArchivesFromStructure());
                }
            }
            catch (OperationCanceledException) { LogBuild("Build cancelled."); }
            catch (Exception ex)               { LogBuild($"Error: {ex.Message}"); }
            finally
            {
                BtnBuild.Content = "Build";
                Progress.Value = 100;
                LogBuild($"\nDone. Built: {builder.Built}  Skipped: {builder.Skipped}  Errors: {builder.Errors}");
            }
        }

        // ----------------------------------------------------------------
        // Build All — compile all 7 archives from source + pack
        // ----------------------------------------------------------------
        private async void BuildAll_Click(object sender, RoutedEventArgs e)
        {
            if (BtnBuildAll.Content.ToString() == "Cancel") { _cts?.Cancel(); return; }

            SaveSettings();
            TxtLog.Clear();
            Progress.Value = 0;
            TxtStatus.Text = "";
            BtnBuildAll.Content = "Cancel";
            BtnBuild.IsEnabled  = false;
            _cts = new CancellationTokenSource();

            // Always use fxc_81 for clean build (matches original DSR compiler)
            string buildFxc = File.Exists(TxtFXC81.Text) ? TxtFXC81.Text : TxtFXC.Text;

            var builder = new ShaderBuilder(
                dsr:         TxtDSR.Text,
                fxc:         buildFxc,
                source:      TxtSource.Text,
                force:       true,   // always force rebuild — this is a clean build
                token:       _cts.Token,
                originalDir: "");    // no originals needed

            builder.OnLog      += msg => Dispatcher.Invoke(() => { TxtLog.AppendText(msg + "\n"); TxtLog.ScrollToEnd(); });
            builder.OnProgress += (done, total) => Dispatcher.Invoke(() =>
            {
                Progress.Value = total > 0 ? done * 100.0 / total : 0;
                TxtStatus.Text = $"{done}/{total}";
            });

            LogBuild($"=== BUILD ALL (clean) ===");
            LogBuild($"FXC: {buildFxc}");
            LogBuild($"DSR: {TxtDSR.Text}");
            LogBuild($"Source: {TxtSource.Text}");
            LogBuild("");

            var sw = System.Diagnostics.Stopwatch.StartNew();

            try
            {
                // Step 1 — compile everything
                await Task.Run(() => builder.BuildAll(), _cts.Token);

                LogBuild($"\nCompile: {builder.Built} built, {builder.Skipped} skipped, {builder.Errors} errors ({sw.Elapsed.TotalSeconds:0}s)");

                if (builder.Errors > 0)
                {
                    LogBuild($"\n[ABORT] {builder.Errors} compile errors — not packing.");
                    return;
                }

                // Step 2 — pack all 7 archives (no unpack of originals needed)
                LogBuild("\n--- Packing archives ---");
                await Task.Run(() => builder.BuildArchivesFromStructure(), _cts.Token);

                sw.Stop();
                LogBuild($"\n=== Done in {sw.Elapsed.TotalSeconds:0}s ===");
            }
            catch (OperationCanceledException) { LogBuild("Build All cancelled."); }
            catch (Exception ex)               { LogBuild($"Error: {ex.Message}"); }
            finally
            {
                BtnBuildAll.Content = "Build All";
                BtnBuild.IsEnabled  = true;
                Progress.Value = 100;
            }
        }

        // ----------------------------------------------------------------
        // Pack a single bundle after build
        // ----------------------------------------------------------------
        private void PackBundle(string bundleFileName, string dsrPath, ShaderBuilder builder)
        {
            string shaderDir = Path.Combine(dsrPath, "shader");
            string bundlePath = Path.Combine(shaderDir, bundleFileName);

            if (!File.Exists(bundlePath))
            {
                LogBuild($"  Pack skipped — not found: {bundleFileName}");
                return;
            }

            // Build a lookup of only the files compiled in this run
            var builtLookup = builder.BuiltFiles
                .ToLookup(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase);

            if (!builtLookup.Any())
            {
                LogBuild($"  Pack skipped — no files built for {bundleFileName}");
                return;
            }

            try
            {
                byte[] origBytes;
                DCX.CompressionInfo compression;
                if (bundlePath.EndsWith(".dcx", StringComparison.OrdinalIgnoreCase))
                    origBytes = DCX.Decompress(bundlePath, out compression);
                else
                {
                    origBytes   = File.ReadAllBytes(bundlePath);
                    compression = new DCX.DcpDfltCompressionInfo();
                }

                var origBnd = BND3.Read(origBytes);

                int replaced = 0;
                foreach (var file in origBnd.Files)
                {
                    string fname = Path.GetFileName(file.Name);
                    // Only replace slots whose file was actually compiled in this run
                    if (!builtLookup[fname].Any()) continue;

                    file.Bytes = File.ReadAllBytes(builtLookup[fname].First());
                    replaced++;
                }

                byte[] outBytes = DCX.Compress(origBnd.Write(), compression);
                File.WriteAllBytes(bundlePath, outBytes);
                LogBuild($"  Packed {replaced}/{origBnd.Files.Count} → {bundleFileName}");
            }
            catch (Exception ex)
            {
                LogBuild($"  Pack FAILED ({bundleFileName}): {ex.Message}");
            }
        }

        private void LogBuild(string msg) =>
            Dispatcher.Invoke(() => { TxtLog.AppendText(msg + "\n"); TxtLog.ScrollToEnd(); });

        // ----------------------------------------------------------------
        // Bundle tab — Unpack
        // ----------------------------------------------------------------
        private void BrowseUnpackSrc_Click(object sender, RoutedEventArgs e)
        {
            string shaderDir = Path.Combine(TxtDSR.Text, "shader");
            var dlg = new OpenFileDialog
            {
                Filter      = "Shader bundle|*.shaderbnd.dcx;*.shaderbnd|All files|*.*",
                Title       = "Select .shaderbnd.dcx to unpack",
                InitialDirectory = Directory.Exists(shaderDir) ? shaderDir : null
            };
            if (dlg.ShowDialog() == true) TxtUnpackSrc.Text = dlg.FileName;
        }

        private void Unpack_Click(object sender, RoutedEventArgs e)
        {
            string path = TxtUnpackSrc.Text;
            if (string.IsNullOrWhiteSpace(path))
            {
                System.Windows.MessageBox.Show("Select a .shaderbnd.dcx file first.", "Unpack");
                return;
            }
            if (!File.Exists(path))
            {
                System.Windows.MessageBox.Show($"File not found:\n{path}", "Unpack");
                return;
            }

            try
            {
                string name   = Path.GetFileName(path);
                // Match Build output folder naming: dots → dashes
                // FRPG_FlverPBL_fpo_DX11.shaderbnd.dcx → FRPG_FlverPBL_fpo_DX11-shaderbnd-dcx
                string stem   = name.Replace(".shaderbnd.dcx", "-shaderbnd-dcx")
                                    .Replace(".shaderbnd", "-shaderbnd");
                string outDir = Path.Combine(Path.GetDirectoryName(path)!, stem);

                Directory.CreateDirectory(outDir);

                // Create .bak before first unpack so original is always preserved
                string bakPath = path + ".bak";
                if (!File.Exists(bakPath))
                {
                    File.Copy(path, bakPath);
                    LogBundle($"Backup created: {Path.GetFileName(bakPath)}");
                }

                byte[] bndBytes = path.EndsWith(".dcx", StringComparison.OrdinalIgnoreCase)
                    ? DCX.Decompress(path)
                    : File.ReadAllBytes(path);

                var bnd = BND3.Read(bndBytes);
                int written = 0, skipped = 0;
                foreach (var file in bnd.Files)
                {
                    // Flat layout: just filename, no subfolders
                    string dest = Path.Combine(outDir, Path.GetFileName(file.Name));
                    // Don't overwrite files that already exist (e.g. compiled by us)
                    if (File.Exists(dest))
                    {
                        skipped++;
                        continue;
                    }
                    File.WriteAllBytes(dest, file.Bytes);
                    written++;
                }

                string msg = $"Unpacked {written} files, skipped {skipped} existing → {outDir}";
                LogBundle(msg);

                // Auto-fill Pack fields
                TxtPackSrcDir.Text = outDir;
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"Unpack failed:\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        // ----------------------------------------------------------------
        // Bundle tab — Pack
        // ----------------------------------------------------------------
        private void BrowsePackSrcDir_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog
            {
                Description  = "Select folder containing compiled .fpo / .vpo files",
                SelectedPath = TxtPackSrcDir.Text
            };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK)
                TxtPackSrcDir.Text = dlg.SelectedPath;
        }

        private void BrowsePackTemplate_Click(object sender, RoutedEventArgs e)
        {
            string shaderDir = Path.Combine(TxtDSR.Text, "shader");
            var dlg = new OpenFileDialog
            {
                Filter      = "Shader bundle|*.shaderbnd.dcx;*.shaderbnd|All files|*.*",
                Title       = "Select original .shaderbnd.dcx as template (will be overwritten)",
                InitialDirectory = Directory.Exists(shaderDir) ? shaderDir : null
            };
            if (dlg.ShowDialog() == true) TxtPackTemplate.Text = dlg.FileName;
        }

        private void Pack_Click(object sender, RoutedEventArgs e)
        {
            string srcDir   = TxtPackSrcDir.Text;
            string origPath = TxtPackTemplate.Text;

            if (!Directory.Exists(srcDir))
            {
                System.Windows.MessageBox.Show("Select a folder with .fpo files first.", "Pack");
                return;
            }
            if (!File.Exists(origPath))
            {
                System.Windows.MessageBox.Show("Select a template .shaderbnd.dcx first.", "Pack");
                return;
            }

            try
            {
                byte[] origBytes;
                DCX.CompressionInfo compression;
                if (origPath.EndsWith(".dcx", StringComparison.OrdinalIgnoreCase))
                    origBytes = DCX.Decompress(origPath, out compression);
                else
                {
                    origBytes   = File.ReadAllBytes(origPath);
                    compression = new DCX.DcpDfltCompressionInfo();
                }

                var origBnd = BND3.Read(origBytes);

                // Build lookup: filename → full path on disk (flat folder, no duplicates expected)
                var fpoLookup = Directory.GetFiles(srcDir, "*.fpo", SearchOption.AllDirectories)
                    .Concat(Directory.GetFiles(srcDir, "*.vpo", SearchOption.AllDirectories))
                    .Concat(Directory.GetFiles(srcDir, "*.cpo", SearchOption.AllDirectories))
                    .ToLookup(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase);

                int replaced = 0;
                foreach (var file in origBnd.Files)
                {
                    string fname = Path.GetFileName(file.Name);
                    // Normalize internal path to find the matching file on disk
                    string internalRel = BndPathToRelative(file.Name);
                    string diskPath = Path.Combine(srcDir, internalRel);

                    if (File.Exists(diskPath))
                    {
                        // Exact path match — use the file at the correct internal path
                        file.Bytes = File.ReadAllBytes(diskPath);
                        replaced++;
                    }
                    else if (fpoLookup[fname].Any())
                    {
                        // Fallback: match by filename only (e.g. flat bundles like FlverPBL)
                        file.Bytes = File.ReadAllBytes(fpoLookup[fname].First());
                        replaced++;
                    }
                }

                byte[] outBytes = DCX.Compress(origBnd.Write(), compression);
                File.WriteAllBytes(origPath, outBytes);

                LogBundle($"Packed {replaced}/{origBnd.Files.Count} files → {Path.GetFileName(origPath)}");
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"Pack failed:\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        // ----------------------------------------------------------------
        // Bundle tab — Quick access buttons
        // Sets TxtUnpackSrc to the selected bundle from DSR\shader\
        // ----------------------------------------------------------------
        private void QuickBundle_Click(object sender, RoutedEventArgs e)
        {
            if (sender is not System.Windows.Controls.Button btn) return;
            string bundleName = btn.Tag?.ToString() ?? "";
            string shaderDir  = Path.Combine(TxtDSR.Text, "shader");
            string fullPath   = Path.Combine(shaderDir, bundleName);

            if (!File.Exists(fullPath))
            {
                LogBundle($"Not found: {fullPath}");
                return;
            }

            TxtUnpackSrc.Text = fullPath;
            TxtPackTemplate.Text = fullPath;
            LogBundle($"Selected: {fullPath}");
        }

        private void LogBundle(string msg) =>
            Dispatcher.Invoke(() => { TxtBundleLog.AppendText(msg + "\n"); TxtBundleLog.ScrollToEnd(); });

        // ----------------------------------------------------------------
        // Switch: Use original / Use modded
        // ----------------------------------------------------------------

        // Known bundles that have a compiled counterpart (unpacked folder in DSR\shader\)
        private static readonly string[] _switchableBundles = new[]
        {
            "FRPG_FlverPBL_fpo_DX11.shaderbnd.dcx",
            "FRPG_FlverPBL_vpo_DX11.shaderbnd.dcx",
            "FRPG_Filter_DX11.shaderbnd.dcx",
            "FRPG_Menu_DX11.shaderbnd.dcx",
            "FRPG_SfxPBL_DX11.shaderbnd.dcx",
        };

        private void UseOriginal_Click(object sender, RoutedEventArgs e)
        {
            if (sender is not System.Windows.Controls.Button btn) return;
            SwitchToOriginal(btn.Tag?.ToString() ?? "");
        }

        private void UseModded_Click(object sender, RoutedEventArgs e)
        {
            if (sender is not System.Windows.Controls.Button btn) return;
            SwitchToModded(btn.Tag?.ToString() ?? "");
        }

        private void AllOriginal_Click(object sender, RoutedEventArgs e)
        {
            foreach (var bundle in _switchableBundles)
                SwitchToOriginal(bundle);
        }

        private void AllModded_Click(object sender, RoutedEventArgs e)
        {
            foreach (var bundle in _switchableBundles)
                SwitchToModded(bundle);
        }

        // Copy original bundle from TxtOriginal → DSR\shader\
        private void SwitchToOriginal(string bundleFileName)
        {
            if (string.IsNullOrWhiteSpace(bundleFileName)) return;

            string origDir = TxtOriginal.Text;
            if (string.IsNullOrWhiteSpace(origDir) || !Directory.Exists(origDir))
            {
                LogSwitch($"  Original folder not set or not found. Set it in Settings.");
                return;
            }

            string srcPath  = Path.Combine(origDir, bundleFileName);
            string destPath = Path.Combine(TxtDSR.Text, "shader", bundleFileName);

            if (!File.Exists(srcPath))
            {
                LogSwitch($"  Not found in original folder: {bundleFileName}");
                return;
            }
            if (!Directory.Exists(Path.GetDirectoryName(destPath)!))
            {
                LogSwitch($"  DSR shader folder not found: {Path.GetDirectoryName(destPath)}");
                return;
            }

            File.Copy(srcPath, destPath, overwrite: true);
            LogSwitch($"  ◀ Original → {bundleFileName}");
        }

        // Pack compiled shaders from unpacked folder → DSR\shader\
        private void SwitchToModded(string bundleFileName)
        {
            if (string.IsNullOrWhiteSpace(bundleFileName)) return;

            string shaderDir  = Path.Combine(TxtDSR.Text, "shader");
            string bundlePath = Path.Combine(shaderDir, bundleFileName);

            if (!File.Exists(bundlePath))
            {
                LogSwitch($"  Bundle not found in DSR\\shader\\: {bundleFileName}");
                return;
            }

            string stem   = bundleFileName.Replace(".shaderbnd.dcx", "-shaderbnd-dcx")
                                          .Replace(".shaderbnd", "-shaderbnd");
            string srcDir = Path.Combine(shaderDir, stem);

            if (!Directory.Exists(srcDir))
            {
                LogSwitch($"  Unpacked folder not found: {stem}  (run Unpack first)");
                return;
            }

            try
            {
                byte[] origBytes;
                DCX.CompressionInfo compression;
                if (bundlePath.EndsWith(".dcx", StringComparison.OrdinalIgnoreCase))
                    origBytes = DCX.Decompress(bundlePath, out compression);
                else
                {
                    origBytes   = File.ReadAllBytes(bundlePath);
                    compression = new DCX.DcpDfltCompressionInfo();
                }

                var bnd = BND3.Read(origBytes);

                // Build lookup: filename → path (flat folder, no duplicates expected)
                var newFiles = Directory.GetFiles(srcDir, "*.fpo", SearchOption.AllDirectories)
                    .Concat(Directory.GetFiles(srcDir, "*.vpo", SearchOption.AllDirectories))
                    .Concat(Directory.GetFiles(srcDir, "*.cpo", SearchOption.AllDirectories))
                    .ToLookup(f => Path.GetFileName(f), StringComparer.OrdinalIgnoreCase);

                int replaced = 0;
                foreach (var file in bnd.Files)
                {
                    string fname = Path.GetFileName(file.Name);
                    string internalRel = BndPathToRelative(file.Name);
                    string diskPath = Path.Combine(srcDir, internalRel);

                    if (File.Exists(diskPath))
                    {
                        file.Bytes = File.ReadAllBytes(diskPath);
                        replaced++;
                    }
                    else if (newFiles[fname].Any())
                    {
                        file.Bytes = File.ReadAllBytes(newFiles[fname].First());
                        replaced++;
                    }
                }

                File.WriteAllBytes(bundlePath, DCX.Compress(bnd.Write(), compression));
                LogSwitch($"  ▶ Modded ({replaced} files) → {bundleFileName}");
            }
            catch (Exception ex)
            {
                LogSwitch($"  Switch to modded FAILED ({bundleFileName}): {ex.Message}");
            }
        }

        // Normalize a BND3 internal path (may be absolute like "N:\FRPG\Source\...")
        // to a relative path suitable for Path.Combine with an output directory.
        private static string BndPathToRelative(string bndName)
        {
            string name = bndName.Replace('/', '\\');
            // Strip drive letter (e.g. "N:\")
            if (name.Length >= 2 && name[1] == ':')
                name = name.Substring(2);
            return name.TrimStart('\\');
        }

        private void LogSwitch(string msg) =>
            Dispatcher.Invoke(() => { TxtSwitchLog.AppendText(msg + "\n"); TxtSwitchLog.ScrollToEnd(); });

        // ----------------------------------------------------------------
        // Decompile PTDE .shaderbnd (DX9, no DCX) → .asm files
        // ----------------------------------------------------------------
        private async void DecompilePtdeBundle_Click(object sender, RoutedEventArgs e)
        {
            if (!File.Exists(TxtFXC.Text))
            {
                System.Windows.MessageBox.Show("fxc.exe not found.", "PTDE Decompile");
                return;
            }

            var dlg = new OpenFileDialog
            {
                Filter      = "Shader bundle|*.shaderbnd|All files|*.*",
                Title       = "Select PTDE .shaderbnd file",
                InitialDirectory = @"D:\Dark Souls Prepare To Die Edition\DATA\shader"
            };
            if (dlg.ShowDialog() != true) return;

            string bundlePath = dlg.FileName;
            string exeDir     = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)!;
            string outBase    = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", "reference", "ptde_decompiled"));
            Directory.CreateDirectory(outBase);

            LogBundle($"PTDE: {bundlePath}");
            LogBundle($"Output: {outBase}");

            await Task.Run(async () =>
            {
                // Read BND3 (no DCX)
                byte[] data = File.ReadAllBytes(bundlePath);
                if (data[0] != 'B' || data[1] != 'N' || data[2] != 'D' || data[3] != '3')
                {
                    LogBundle("ERROR: Not a BND3 file");
                    return;
                }

                int fileCount = BitConverter.ToInt32(data, 0x10);
                LogBundle($"Files in bundle: {fileCount}");

                int done = 0;
                for (int i = 0; i < fileCount; i++)
                {
                    int b        = 0x20 + i * 0x18;
                    int dataSize = BitConverter.ToInt32(data, b + 4);
                    int dataOff  = BitConverter.ToInt32(data, b + 8);
                    int nameOff  = BitConverter.ToInt32(data, b + 16);

                    // Read name
                    string name = "";
                    if (nameOff > 0 && nameOff < data.Length)
                    {
                        int end = nameOff;
                        while (end < data.Length && data[end] != 0) end++;
                        name = System.Text.Encoding.ASCII.GetString(data, nameOff, end - nameOff);
                    }
                    if (string.IsNullOrEmpty(name)) name = $"shader_{i}.fpo";
                    string fname = Path.GetFileName(name);

                    if (dataOff <= 0 || dataSize <= 0 || dataOff + dataSize > data.Length) continue;

                    // Write .fpo to temp
                    string tmpFpo = Path.Combine(Path.GetTempPath(), fname);
                    File.WriteAllBytes(tmpFpo, data[dataOff..(dataOff + dataSize)]);

                    // Disassemble with fxc /dumpbin
                    string asmOut = Path.Combine(outBase, fname + ".asm");
                    try
                    {
                        var psi = new System.Diagnostics.ProcessStartInfo(TxtFXC.Text, $"/dumpbin \"{tmpFpo}\"")
                        {
                            RedirectStandardOutput = true,
                            RedirectStandardError  = true,
                            UseShellExecute        = false,
                            CreateNoWindow         = true
                        };
                        using var proc = System.Diagnostics.Process.Start(psi)!;
                        string asm = await proc.StandardOutput.ReadToEndAsync();
                        await proc.WaitForExitAsync();

                        if (!string.IsNullOrWhiteSpace(asm))
                            await File.WriteAllTextAsync(asmOut, asm);
                    }
                    catch { }
                    finally { if (File.Exists(tmpFpo)) File.Delete(tmpFpo); }

                    done++;
                    if (done % 100 == 0 || done == fileCount)
                    {
                        int pct = fileCount > 0 ? done * 100 / fileCount : 0;
                        LogBundle($"  [{pct,3}%] {done}/{fileCount}  {fname}");
                        Dispatcher.Invoke(() => { Progress.Value = pct; TxtStatus.Text = $"{done}/{fileCount}"; });
                    }
                }

                LogBundle($"\nDone: {done} shaders → {outBase}");
                Dispatcher.Invoke(() => { Progress.Value = 100; TxtStatus.Text = "Done"; });
            });
        }

        // Restore .shaderbnd.dcx from .bak
        private void RestoreFromBak_Click(object sender, RoutedEventArgs e)        {
            if (sender is not System.Windows.Controls.Button btn) return;
            string bundleName = btn.Tag?.ToString() ?? "";
            string shaderDir  = Path.Combine(TxtDSR.Text, "shader");
            string dcxPath    = Path.Combine(shaderDir, bundleName);
            string bakPath    = dcxPath + ".bak";

            if (!File.Exists(bakPath))
            {
                LogBundle($"No .bak found: {bakPath}");
                return;
            }

            var result = System.Windows.MessageBox.Show(
                $"Restore original bundle from backup?\n\n{bakPath}\n→ {dcxPath}\n\nThis will overwrite the current .dcx.",
                "Restore from .bak", MessageBoxButton.YesNo, MessageBoxImage.Warning);

            if (result != MessageBoxResult.Yes) return;

            File.Copy(bakPath, dcxPath, overwrite: true);
            LogBundle($"Restored: {Path.GetFileName(dcxPath)} from .bak");
        }

        // ----------------------------------------------------------------
        // Decompile tab
        // ----------------------------------------------------------------
        private void BrowseDecompIn_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog { Description = "Select folder with .fpo/.vpo files" };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK) TxtDecompIn.Text = dlg.SelectedPath;
        }

        private void BrowseDecompOut_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new WinForms.FolderBrowserDialog { Description = "Select output folder" };
            if (dlg.ShowDialog() == WinForms.DialogResult.OK) TxtDecompOut.Text = dlg.SelectedPath;
        }

        private void BrowseCompileIn_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog { Filter = "HLSL|*.hlsl;*.fx;*.fxh|All|*.*", Title = "Select HLSL file" };
            if (dlg.ShowDialog() != true) return;
            TxtCompileIn.Text = dlg.FileName;
            if (string.IsNullOrWhiteSpace(TxtCompileOut.Text))
            {
                bool isVs = (CmbProfile.SelectedItem as System.Windows.Controls.ComboBoxItem)?.Content?.ToString()?.StartsWith("vs") == true;
                TxtCompileOut.Text = Path.ChangeExtension(dlg.FileName, isVs ? ".vpo" : ".fpo");
            }
        }

        private void BrowseCompileOut_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new SaveFileDialog
            {
                Filter     = "Shader|*.fpo;*.vpo|All|*.*",
                DefaultExt = ".fpo",
                FileName   = Path.GetFileNameWithoutExtension(TxtCompileIn.Text) + ".fpo"
            };
            if (dlg.ShowDialog() == true) TxtCompileOut.Text = dlg.FileName;
        }

        private async void CompileHlsl_Click(object sender, RoutedEventArgs e)
        {
            string hlslPath = TxtCompileIn.Text;
            string outPath  = TxtCompileOut.Text;
            string profile  = (CmbProfile.SelectedItem as System.Windows.Controls.ComboBoxItem)?.Content?.ToString() ?? "ps_5_0";
            string entry    = string.IsNullOrWhiteSpace(TxtEntry.Text) ? "main" : TxtEntry.Text.Trim();

            if (!File.Exists(hlslPath))          { System.Windows.MessageBox.Show("HLSL file not found.");  return; }
            if (string.IsNullOrWhiteSpace(outPath)) { System.Windows.MessageBox.Show("Set output path.");   return; }
            if (!File.Exists(TxtFXC.Text))       { System.Windows.MessageBox.Show("fxc.exe not found.");    return; }

            TxtCompileStatus.Text       = "Compiling…";
            TxtCompileStatus.Foreground = System.Windows.Media.Brushes.Gray;

            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
                var psi = new ProcessStartInfo(TxtFXC.Text,
                    $"\"{hlslPath}\" /Fo\"{outPath}\" /T {profile} /E {entry} /nologo /D_WIN32=1 /D_DX11=1")
                {
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    UseShellExecute        = false,
                    CreateNoWindow         = true
                };
                using var proc = Process.Start(psi)!;
                string stdout = await proc.StandardOutput.ReadToEndAsync();
                string stderr = await proc.StandardError.ReadToEndAsync();
                await proc.WaitForExitAsync();

                if (proc.ExitCode == 0)
                {
                    TxtCompileStatus.Text       = $"OK → {Path.GetFileName(outPath)}";
                    TxtCompileStatus.Foreground  = System.Windows.Media.Brushes.LimeGreen;
                    TxtDecompLog.AppendText($"Compiled: {outPath}\n");
                }
                else
                {
                    TxtCompileStatus.Text       = "FAILED";
                    TxtCompileStatus.Foreground  = System.Windows.Media.Brushes.Red;
                    foreach (var line in (stdout + stderr).Split('\n'))
                        if (line.Contains("error") || line.Contains("warning"))
                            TxtDecompLog.AppendText($"  {line.Trim()}\n");
                    TxtDecompLog.ScrollToEnd();
                }
            }
            catch (Exception ex)
            {
                TxtCompileStatus.Text = "Error";
                System.Windows.MessageBox.Show($"Compile error:\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private async void DisasmSingle_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog { Filter = "Shader|*.fpo;*.vpo;*.cpo|All|*.*", Title = "Select shader" };
            if (dlg.ShowDialog() != true) return;
            try
            {
                var svc = new DisasmService(TxtFXC.Text);
                string asm = await svc.DisassembleAsync(dlg.FileName);
                string out_ = dlg.FileName + ".asm";
                File.WriteAllText(out_, asm);
                TxtDecompLog.AppendText($"Written: {out_}\n");
            }
            catch (Exception ex) { System.Windows.MessageBox.Show(ex.Message); }
        }

        private async void DecompileSingle_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog { Filter = "Shader|*.fpo;*.vpo;*.cpo|All|*.*", Title = "Select shader" };
            if (dlg.ShowDialog() != true) return;
            try
            {
                var svc = new DisasmService(TxtFXC.Text);
                string hlsl = await svc.ToHlslSkeletonAsync(dlg.FileName);
                string out_ = dlg.FileName + ".hlsl";
                File.WriteAllText(out_, hlsl);
                TxtDecompLog.AppendText($"Written: {out_}\n");
            }
            catch (Exception ex) { System.Windows.MessageBox.Show(ex.Message); }
        }

        private void TranslateAsm_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog { Filter = "ASM|*.asm|All|*.*", Title = "Select .asm file" };
            if (dlg.ShowDialog() != true) return;
            string hlsl = DisasmService.TranslateAsm(File.ReadAllText(dlg.FileName));
            string out_ = Path.ChangeExtension(dlg.FileName, ".translated.hlsl");
            File.WriteAllText(out_, hlsl);
            TxtDecompLog.AppendText($"Written: {out_}\n");
        }

        private async void BatchDecomp_Click(object sender, RoutedEventArgs e)
        {
            string inDir  = TxtDecompIn.Text;
            string outDir = string.IsNullOrWhiteSpace(TxtDecompOut.Text)
                ? Path.Combine(inDir, "decompiled") : TxtDecompOut.Text;

            if (!Directory.Exists(inDir)) { System.Windows.MessageBox.Show("Input folder not found."); return; }

            TxtDecompLog.Clear();
            Progress.Value = 0;
            BtnBatchDecomp.IsEnabled = false;

            // Count files first so user sees what's happening
            var exts = new[] { "*.fpo", "*.vpo", "*.cpo" };
            var allFiles = exts.SelectMany(e => Directory.GetFiles(inDir, e)).ToList();
            if (allFiles.Count == 0)
            {
                TxtDecompLog.AppendText($"No .fpo/.vpo/.cpo files found in:\n{inDir}\n\n");
                TxtDecompLog.AppendText("Tip: select a folder with unpacked shaders, e.g.:\n");
                TxtDecompLog.AppendText($"  DSR\\shader\\FRPG_FlverPBL_fpo_DX11-shaderbnd-dcx\\\n");
                TxtDecompLog.AppendText("Or use Bundle tab → 'Decompile all bundles' to unpack+decompile automatically.");
                BtnBatchDecomp.IsEnabled = true;
                return;
            }

            TxtDecompLog.AppendText($"Found {allFiles.Count} shaders in {inDir}\n");
            TxtDecompLog.AppendText($"Output: {outDir}\n\n");

            DisasmService svc;
            try { svc = new DisasmService(TxtFXC.Text); }
            catch (Exception ex) { System.Windows.MessageBox.Show(ex.Message); BtnBatchDecomp.IsEnabled = true; return; }

            try
            {
                await svc.BatchDecompileAsync(inDir, outDir, ChkTranslate.IsChecked == true,
                    msg  => Dispatcher.Invoke(() => { TxtDecompLog.AppendText(msg + "\n"); TxtDecompLog.ScrollToEnd(); }),
                    (d, t) => Dispatcher.Invoke(() => { Progress.Value = t > 0 ? d * 100.0 / t : 0; TxtStatus.Text = $"{d}/{t}"; }));
                TxtDecompLog.AppendText($"\nDone. Output: {outDir}");
            }
            catch (Exception ex) { TxtDecompLog.AppendText($"Error: {ex.Message}\n"); }
            finally { BtnBatchDecomp.IsEnabled = true; Progress.Value = 100; }
        }

        // ----------------------------------------------------------------
        // Decompile all DX11 bundles → reference/decompiled/
        // ----------------------------------------------------------------
        private async void DecompileAllBundles_Click(object sender, RoutedEventArgs e)
        {
            // DSR shaders = DSR\shader\
            string shaderDir = Path.Combine(TxtDSR.Text, "shader");

            if (!Directory.Exists(shaderDir))
            {
                System.Windows.MessageBox.Show("Set 'DSR game folder' in Settings (or DSR game folder).", "Decompile all");
                return;
            }
            if (!File.Exists(TxtFXC.Text))
            {
                System.Windows.MessageBox.Show("fxc.exe not found.", "Decompile all");
                return;
            }

            string exeDir  = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)!;
            string outBase = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", "reference", "DSR_Windows"));

            // Fallback: ask user if path doesn't look right
            if (!Directory.Exists(Path.GetDirectoryName(outBase)!))
            {
                var dlg = new WinForms.FolderBrowserDialog
                {
                    Description  = "Select output folder for decompiled shaders",
                    SelectedPath = exeDir
                };
                if (dlg.ShowDialog() != WinForms.DialogResult.OK) return;
                outBase = Path.Combine(dlg.SelectedPath, "decompiled");
            }

            var bundles = Directory.GetFiles(shaderDir, "*.shaderbnd.dcx")
                .Concat(Directory.GetFiles(shaderDir, "*.shaderbnd"))
                .Where(f => !f.EndsWith(".bak", StringComparison.OrdinalIgnoreCase))
                .OrderBy(f => f)
                .ToArray();

            LogBundle($"Found {bundles.Length} bundles in {shaderDir}");
            Directory.CreateDirectory(outBase);

            DisasmService svc;
            try { svc = new DisasmService(TxtFXC.Text); }
            catch (Exception ex) { System.Windows.MessageBox.Show(ex.Message); return; }

            int totalBundles = 0, totalFiles = 0, totalErrors = 0;

            await Task.Run(async () =>
            {
                foreach (var bundlePath in bundles)
                {
                    string bundleName = Path.GetFileName(bundlePath);
                    if (!File.Exists(bundlePath))
                    {
                        LogBundle($"SKIP (not found): {bundleName}");
                        continue;
                    }

                    // Unpack bundle
                    string stem   = bundleName.Replace(".shaderbnd.dcx", "").Replace(".shaderbnd", "");
                    string outDir = Path.Combine(outBase, stem);
                    Directory.CreateDirectory(outDir);

                    LogBundle($"\n--- {bundleName} ---");

                    try
                    {
                        byte[] raw = bundlePath.EndsWith(".dcx", StringComparison.OrdinalIgnoreCase)
                            ? DCX.Decompress(bundlePath)
                            : File.ReadAllBytes(bundlePath);

                        var bnd = BND3.Read(raw);
                        int unpacked = 0;
                        foreach (var file in bnd.Files)
                        {
                            string fname = Path.GetFileName(file.Name);
                            File.WriteAllBytes(Path.Combine(outDir, fname), file.Bytes);
                            unpacked++;
                        }
                        LogBundle($"  Unpacked {unpacked} files");
                        totalBundles++;

                        // Decompile all .fpo/.vpo — log every 50 files
                        int filesDone = 0;
                        var allShaders = Directory.GetFiles(outDir, "*.fpo")
                            .Concat(Directory.GetFiles(outDir, "*.vpo"))
                            .Concat(Directory.GetFiles(outDir, "*.cpo"))
                            .ToList();
                        int total = allShaders.Count;
                        LogBundle($"  Translating {total} shaders...");

                        foreach (var shaderFile in allShaders)
                        {
                            try
                            {
                                string asm  = await svc.DisassembleAsync(shaderFile);
                                string hlsl = DisasmService.TranslateAsm(asm);
                                await File.WriteAllTextAsync(shaderFile + ".asm", asm);
                                await File.WriteAllTextAsync(shaderFile + ".translated.hlsl", hlsl);
                            }
                            catch { /* skip broken shaders */ }

                            filesDone++;
                            if (filesDone % 50 == 0 || filesDone == total)
                            {
                                int pct = total > 0 ? filesDone * 100 / total : 0;
                                LogBundle($"  [{pct,3}%] {filesDone}/{total}  {Path.GetFileName(shaderFile)}");
                                Dispatcher.Invoke(() =>
                                {
                                    Progress.Value = pct;
                                    TxtStatus.Text = $"{stem}: {filesDone}/{total}";
                                });
                            }
                        }

                        totalFiles += filesDone;
                    }
                    catch (Exception ex)
                    {
                        LogBundle($"  ERROR: {ex.Message}");
                        totalErrors++;
                    }
                }

                LogBundle($"\n=== Done: {totalBundles} bundles, {totalFiles} shaders translated, {totalErrors} errors ===");
                LogBundle($"Output: {outBase}");
                Dispatcher.Invoke(() => { Progress.Value = 100; TxtStatus.Text = "Done"; });
            });
        }

        // ----------------------------------------------------------------
        // Decompile all PTDE .shaderbnd bundles → reference/ptde_decompiled/
        // Each bundle: extract .fpo → fxc /dumpbin → .asm → Dx9AsmToHlsl → .translated.hlsl
        // ----------------------------------------------------------------
        private async void DecompileAllPtdeBundles_Click(object sender, RoutedEventArgs e)
        {
            // Use new PTDEShaders field, fall back to legacy TxtPTDE
            string ptdeDir = !string.IsNullOrWhiteSpace(TxtPTDEShaders.Text)
                ? TxtPTDEShaders.Text : TxtPTDE.Text;
            if (string.IsNullOrWhiteSpace(ptdeDir) || !Directory.Exists(ptdeDir))
            {
                System.Windows.MessageBox.Show("Set 'PTDE shaders folder' in Settings first.", "Decompile PTDE");
                return;
            }
            string fxcPath = TxtFXC.Text;
            if (!File.Exists(fxcPath))
            {
                System.Windows.MessageBox.Show("fxc.exe not found.", "Decompile PTDE");
                return;
            }

            string exeDir  = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)!;
            string outBase = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", "reference", "PTDE_Windows"));
            Directory.CreateDirectory(outBase);

            LogBundle($"PTDE shader dir: {ptdeDir}");
            LogBundle($"Output: {outBase}");

            var bundles = Directory.GetFiles(ptdeDir, "*.shaderbnd");
            if (bundles.Length == 0)
            {
                LogBundle("No .shaderbnd files found.");
                return;
            }
            LogBundle($"Found {bundles.Length} bundles");

            await Task.Run(async () =>
            {
                int totalBundles = 0, totalFiles = 0, totalErrors = 0;

                foreach (var bundlePath in bundles.OrderBy(x => x))
                {
                    string bundleName = Path.GetFileNameWithoutExtension(bundlePath);
                    string outDir     = Path.Combine(outBase, bundleName);
                    Directory.CreateDirectory(outDir);

                    LogBundle($"\n--- {Path.GetFileName(bundlePath)} ---");

                    byte[] data;
                    try { data = File.ReadAllBytes(bundlePath); }
                    catch (Exception ex) { LogBundle($"  READ ERROR: {ex.Message}"); continue; }

                    // Validate BND3 magic
                    if (data.Length < 4 || data[0] != 'B' || data[1] != 'N' || data[2] != 'D' || data[3] != '3')
                    {
                        LogBundle($"  SKIP: not a BND3 (magic={data[0]:X2}{data[1]:X2}{data[2]:X2}{data[3]:X2})");
                        continue;
                    }

                    // Parse BND3 header
                    int fileCount = BitConverter.ToInt32(data, 0x10);
                    LogBundle($"  {fileCount} shaders");

                    int filesDone = 0, filesErr = 0;
                    for (int i = 0; i < fileCount; i++)
                    {
                        int b        = 0x20 + i * 0x18;
                        if (b + 0x18 > data.Length) break;
                        int dataSize = BitConverter.ToInt32(data, b + 4);
                        int dataOff  = BitConverter.ToInt32(data, b + 8);
                        int nameOff  = BitConverter.ToInt32(data, b + 16);

                        string fname = $"shader_{i}.fpo";
                        if (nameOff > 0 && nameOff < data.Length)
                        {
                            int end = nameOff;
                            while (end < data.Length && data[end] != 0) end++;
                            string raw = System.Text.Encoding.ASCII.GetString(data, nameOff, end - nameOff);
                            if (!string.IsNullOrEmpty(raw)) fname = Path.GetFileName(raw);
                        }

                        if (dataOff <= 0 || dataSize <= 0 || dataOff + dataSize > data.Length)
                        {
                            LogBundle($"  SKIP [{i}] {fname}: bad offset/size (off={dataOff} size={dataSize})");
                            continue;
                        }

                        string tmpFpo  = Path.Combine(Path.GetTempPath(), fname);
                        string asmOut  = Path.Combine(outDir, fname + ".asm");
                        string hlslOut = Path.Combine(outDir, fname + ".translated.hlsl");

                        try
                        {
                            File.WriteAllBytes(tmpFpo, data[dataOff..(dataOff + dataSize)]);

                            // Disassemble
                            var psi = new System.Diagnostics.ProcessStartInfo(fxcPath, $"/dumpbin \"{tmpFpo}\"")
                            {
                                RedirectStandardOutput = true,
                                RedirectStandardError  = true,
                                UseShellExecute        = false,
                                CreateNoWindow         = true
                            };
                            using var proc = System.Diagnostics.Process.Start(psi)!;
                            string asm    = await proc.StandardOutput.ReadToEndAsync();
                            string stderr = await proc.StandardError.ReadToEndAsync();
                            await proc.WaitForExitAsync();

                            if (string.IsNullOrWhiteSpace(asm))
                            {
                                LogBundle($"  FAIL [{i}] {fname}: fxc returned empty (stderr: {stderr.Trim()})");
                                filesErr++;
                                continue;
                            }

                            await File.WriteAllTextAsync(asmOut, asm);

                            // Translate DX9 asm → HLSL
                            string hlsl = DisasmService.TranslateAsm(asm);
                            await File.WriteAllTextAsync(hlslOut, hlsl);

                            filesDone++;
                        }
                        catch (Exception ex)
                        {
                            LogBundle($"  FAIL [{i}] {fname}: {ex.Message}");
                            filesErr++;
                        }
                        finally { try { File.Delete(tmpFpo); } catch { } }

                        if ((filesDone + filesErr) % 50 == 0 || i == fileCount - 1)
                        {
                            int pct = fileCount > 0 ? (i + 1) * 100 / fileCount : 0;
                            LogBundle($"  [{pct,3}%] {i + 1}/{fileCount}  {fname}");
                            Dispatcher.Invoke(() =>
                            {
                                Progress.Value = pct;
                                TxtStatus.Text = $"{bundleName}: {i + 1}/{fileCount}";
                            });
                        }
                    }

                    LogBundle($"  OK: {filesDone} translated, {filesErr} errors → {outDir}");
                    totalBundles++;
                    totalFiles  += filesDone;
                    totalErrors += filesErr;
                }

                LogBundle($"\n=== Done: {totalBundles} bundles, {totalFiles} shaders, {totalErrors} errors ===");
                LogBundle($"Output: {outBase}");
                Dispatcher.Invoke(() => { Progress.Value = 100; TxtStatus.Text = "Done"; });
            });
        }

        // ================================================================
        // MTD extractor — dumps material definitions to mtd/ folder
        // ================================================================
        private async void ExtractMtd_Click(object sender, RoutedEventArgs e)
        {
            string dsrPath = TxtDSR.Text;
            if (string.IsNullOrWhiteSpace(dsrPath) || !Directory.Exists(dsrPath))
            {
                System.Windows.MessageBox.Show("Set 'DSR game folder' in Settings first.", "Extract MTD");
                return;
            }

            string mtdDir = Path.Combine(dsrPath, "mtd");
            if (!Directory.Exists(mtdDir))
            {
                System.Windows.MessageBox.Show($"MTD folder not found:\n{mtdDir}", "Extract MTD");
                return;
            }

            // Output to project root / mtd/
            string exeDir    = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)!;
            string projectRoot = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", ".."));
            string outDir    = Path.Combine(projectRoot, "mtd");
            Directory.CreateDirectory(outDir);

            LogBundle($"Extracting MTD from {mtdDir} → {outDir}");

            await Task.Run(() =>
            {
                var bundles = Directory.GetFiles(mtdDir, "*.mtdbnd.dcx")
                    .Concat(Directory.GetFiles(mtdDir, "*.mtdbnd"))
                    .OrderBy(x => x).ToArray();

                LogBundle($"Found {bundles.Length} MTD bundle(s)");

                int total = 0, errors = 0;
                foreach (var bundlePath in bundles)
                {
                    string bundleName = Path.GetFileName(bundlePath);
                    LogBundle($"\n--- {bundleName} ---");

                    try
                    {
                        byte[] bytes = bundlePath.EndsWith(".dcx", StringComparison.OrdinalIgnoreCase)
                            ? DCX.Decompress(bundlePath)
                            : File.ReadAllBytes(bundlePath);

                        var bnd = BND3.Read(bytes);
                        foreach (var file in bnd.Files)
                        {
                            try
                            {
                                string mtdName = Path.GetFileName(file.Name);
                                var mtd = MTD.Read(file.Bytes);

                                // Build text output
                                var sb = new System.Text.StringBuilder();
                                sb.AppendLine($"// MTD: {mtdName}");
                                sb.AppendLine($"// Shader: {mtd.ShaderPath}");
                                sb.AppendLine($"// Description: {mtd.Description}");
                                sb.AppendLine();

                                sb.AppendLine("// Textures:");
                                foreach (var tex in mtd.Textures)
                                    sb.AppendLine($"  {tex.Type,-30} path={tex.Path}  uv={tex.UVNumber}  shaderDataIndex={tex.ShaderDataIndex}");

                                sb.AppendLine();
                                sb.AppendLine("// Params:");
                                foreach (var param in mtd.Params)
                                {
                                    string valStr = param.Value is System.Array arr
                                        ? "[" + string.Join(", ", arr.Cast<object>()) + "]"
                                        : param.Value?.ToString() ?? "null";
                                    sb.AppendLine($"  {param.Name,-40} type={param.Type,-10} value={valStr}");
                                }

                                string outPath = Path.Combine(outDir, Path.ChangeExtension(mtdName, ".txt"));
                                File.WriteAllText(outPath, sb.ToString());
                                total++;
                            }
                            catch (Exception ex)
                            {
                                LogBundle($"  FAIL {Path.GetFileName(file.Name)}: {ex.Message}");
                                errors++;
                            }
                        }
                        LogBundle($"  {bnd.Files.Count} entries processed");
                    }
                    catch (Exception ex)
                    {
                        LogBundle($"  Bundle read FAILED: {ex.Message}");
                        errors++;
                    }
                }

                LogBundle($"\nDone. Extracted: {total}  Errors: {errors} → {outDir}");
            });
        }

        // ================================================================
        // Reference tab — Unpack & disassemble to reference\ folder
        // ================================================================

        private string GetReferenceBase()
        {
            // reference\ is always next to the project root (two levels up from ShaderCompiler\)
            string exeDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)!;
            return Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", "reference"));
        }

        private void LogRef(string msg) =>
            Dispatcher.Invoke(() => { TxtRefLog.AppendText(msg + "\n"); TxtRefLog.ScrollToEnd(); });

        // ── Unpack DSR Windows ──────────────────────────────────────────
        private async void UnpackDSRToReference_Click(object sender, RoutedEventArgs e)
        {
            // Read all UI values on UI thread BEFORE entering Task.Run
            string srcDir  = Path.Combine(TxtDSR.Text, "shader");  // always DSR\shader\
            string fxcPath = TxtFXC.Text;
            string fxc81Path = TxtFXC81.Text;
            bool   disasm  = ChkRefDSRDisasm.IsChecked == true;

            if (string.IsNullOrWhiteSpace(TxtDSR.Text) || !Directory.Exists(srcDir))
            {
                System.Windows.MessageBox.Show("Set 'DSR game folder' in Settings first.", "Reference");
                return;
            }
            if (!File.Exists(fxcPath))
            {
                System.Windows.MessageBox.Show("fxc.exe not found.", "Reference");
                return;
            }

            string outBase = Path.Combine(GetReferenceBase(), "DSR_Windows");
            Directory.CreateDirectory(outBase);

            TxtRefLog.Clear();
            LogRef($"DSR Windows → {outBase}");
            LogRef($"Source: {srcDir}");

            var bundles = Directory.GetFiles(srcDir, "*.shaderbnd.dcx")
                .Concat(Directory.GetFiles(srcDir, "*.shaderbnd"))
                .Where(f => !f.EndsWith(".bak", StringComparison.OrdinalIgnoreCase))
                .OrderBy(f => f).ToArray();

            LogRef($"Found {bundles.Length} bundles\n");

            // Create services on UI thread (paths already captured)
            DisasmService? svc   = disasm ? new DisasmService(fxcPath) : null;
            DisasmService? svc81 = null;
            if (disasm && !string.IsNullOrWhiteSpace(fxc81Path) && File.Exists(fxc81Path) && fxc81Path != fxcPath)
                svc81 = new DisasmService(fxc81Path);

            if (disasm)
            {
                string fxcLabel = svc81 != null ? $"new fxc + fxc 8.1" : "new fxc only (fxc 8.1 not set)";
                LogRef($"Disassembly: {fxcLabel}");
                if (svc81 != null) LogRef("  .asm = fxc 8.1 (reference)  |  .new.asm = new fxc");
            }

            await Task.Run(async () =>
            {
                int totalBundles = 0, totalFiles = 0, totalErrors = 0;

                foreach (var bundlePath in bundles)
                {
                    string bundleName = Path.GetFileName(bundlePath)
                        .Replace(".shaderbnd.dcx", "").Replace(".shaderbnd", "");
                    string outDir = Path.Combine(outBase, bundleName);
                    Directory.CreateDirectory(outDir);

                    LogRef($"--- {Path.GetFileName(bundlePath)} ---");

                    try
                    {
                        byte[] raw = bundlePath.EndsWith(".dcx", StringComparison.OrdinalIgnoreCase)
                            ? DCX.Decompress(bundlePath) : File.ReadAllBytes(bundlePath);
                        var bnd = BND3.Read(raw);

                        int unpacked = 0;
                        foreach (var file in bnd.Files)
                        {
                            string fname = Path.GetFileName(file.Name);
                            await File.WriteAllBytesAsync(Path.Combine(outDir, fname), file.Bytes);
                            unpacked++;
                        }
                        LogRef($"  Unpacked {unpacked} files");
                        totalBundles++;

                        if (svc != null)
                        {
                            var shaders = Directory.GetFiles(outDir, "*.fpo")
                                .Concat(Directory.GetFiles(outDir, "*.vpo"))
                                .Concat(Directory.GetFiles(outDir, "*.cpo")).ToList();

                            int done = 0, errs = 0;
                            int shaderTotal = shaders.Count;
                            for (int si = 0; si < shaderTotal; si++)
                            {
                                var sf = shaders[si];
                                try
                                {
                                    // New fxc → .new.asm + .translated.hlsl
                                    string asmNew = await svc.DisassembleAsync(sf);
                                    string hlsl   = DisasmService.TranslateAsm(asmNew);
                                    await File.WriteAllTextAsync(sf + ".new.asm", asmNew);
                                    await File.WriteAllTextAsync(sf + ".translated.hlsl", hlsl);

                                    // fxc 8.1 → .asm  (primary reference, matches original DSR compiler)
                                    if (svc81 != null)
                                    {
                                        string asm81 = await svc81.DisassembleAsync(sf);
                                        await File.WriteAllTextAsync(sf + ".asm", asm81);
                                    }
                                    else
                                    {
                                        // No fxc 8.1 — use new fxc output as .asm too
                                        await File.WriteAllTextAsync(sf + ".asm", asmNew);
                                    }

                                    done++;
                                }
                                catch { errs++; }

                                // Update progress per-file so bar doesn't freeze on large bundles
                                if ((si + 1) % 50 == 0 || si == shaderTotal - 1)
                                {
                                    int pct = shaderTotal > 0 ? (si + 1) * 100 / shaderTotal : 0;
                                    Dispatcher.Invoke(() =>
                                    {
                                        Progress.Value = pct;
                                        TxtStatus.Text = $"{bundleName}: {si + 1}/{shaderTotal}";
                                    });
                                }
                            }
                            LogRef($"  Disassembled {done}/{shaderTotal}  (.asm=fxc8.1  .new.asm=new fxc)  errors={errs}");
                            totalFiles += done;
                            totalErrors += errs;
                        }
                    }
                    catch (Exception ex)
                    {
                        LogRef($"  ERROR: {ex.Message}");
                        totalErrors++;
                    }

                    Dispatcher.Invoke(() => { Progress.Value = (totalBundles * 100.0 / bundles.Length); TxtStatus.Text = bundleName; });
                }

                LogRef($"\n=== Done: {totalBundles} bundles, {totalFiles} shaders disassembled, {totalErrors} errors ===");
                LogRef($"Output: {outBase}");
                Dispatcher.Invoke(() => { Progress.Value = 100; TxtStatus.Text = "Done"; });
            });
        }

        // ── Unpack PTDE Windows ─────────────────────────────────────────
        private async void UnpackPTDEToReference_Click(object sender, RoutedEventArgs e)
        {
            // Read all UI values on UI thread BEFORE entering Task.Run
            string srcDir  = TxtPTDEShaders.Text;
            string fxcPath = TxtFXC.Text;
            bool   disasm  = ChkRefPTDEDisasm.IsChecked == true;

            if (string.IsNullOrWhiteSpace(srcDir) || !Directory.Exists(srcDir))
            {
                System.Windows.MessageBox.Show("Set 'PTDE shaders folder' in Settings first.", "Reference");
                return;
            }
            if (!File.Exists(fxcPath))
            {
                System.Windows.MessageBox.Show("fxc.exe not found.", "Reference");
                return;
            }
            string outBase = Path.Combine(GetReferenceBase(), "PTDE_Windows");
            Directory.CreateDirectory(outBase);

            TxtRefLog.Clear();
            LogRef($"PTDE Windows → {outBase}");
            LogRef($"Source: {srcDir}");

            // PTDE bundles have no DCX — plain BND3
            var bundles = Directory.GetFiles(srcDir, "*.shaderbnd")
                .Where(f => !f.EndsWith(".bak", StringComparison.OrdinalIgnoreCase))
                .OrderBy(f => f).ToArray();

            LogRef($"Found {bundles.Length} bundles\n");

            await Task.Run(async () =>
            {
                int totalBundles = 0, totalFiles = 0, totalErrors = 0;

                foreach (var bundlePath in bundles)
                {
                    string bundleName = Path.GetFileNameWithoutExtension(bundlePath);
                    string outDir = Path.Combine(outBase, bundleName);
                    Directory.CreateDirectory(outDir);

                    LogRef($"--- {Path.GetFileName(bundlePath)} ---");

                    byte[] data;
                    try { data = File.ReadAllBytes(bundlePath); }
                    catch (Exception ex) { LogRef($"  READ ERROR: {ex.Message}"); continue; }

                    if (data.Length < 4 || data[0] != 'B' || data[1] != 'N' || data[2] != 'D' || data[3] != '3')
                    {
                        LogRef($"  SKIP: not a BND3");
                        continue;
                    }

                    int fileCount = BitConverter.ToInt32(data, 0x10);
                    int unpacked = 0, done = 0, errs = 0;

                    for (int i = 0; i < fileCount; i++)
                    {
                        int b = 0x20 + i * 0x18;
                        if (b + 0x18 > data.Length) break;
                        int dataSize = BitConverter.ToInt32(data, b + 4);
                        int dataOff  = BitConverter.ToInt32(data, b + 8);
                        int nameOff  = BitConverter.ToInt32(data, b + 16);

                        string fname = $"shader_{i}.fpo";
                        if (nameOff > 0 && nameOff < data.Length)
                        {
                            int end = nameOff;
                            while (end < data.Length && data[end] != 0) end++;
                            string raw = System.Text.Encoding.ASCII.GetString(data, nameOff, end - nameOff);
                            if (!string.IsNullOrEmpty(raw)) fname = Path.GetFileName(raw);
                        }

                        if (dataOff <= 0 || dataSize <= 0 || dataOff + dataSize > data.Length) continue;

                        string fpoPath = Path.Combine(outDir, fname);
                        await File.WriteAllBytesAsync(fpoPath, data[dataOff..(dataOff + dataSize)]);
                        unpacked++;

                        if (disasm)
                        {
                            string tmpFpo = Path.Combine(Path.GetTempPath(), fname);
                            try
                            {
                                File.WriteAllBytes(tmpFpo, data[dataOff..(dataOff + dataSize)]);
                                var psi = new System.Diagnostics.ProcessStartInfo(fxcPath, $"/dumpbin \"{tmpFpo}\"")
                                {
                                    RedirectStandardOutput = true, RedirectStandardError = true,
                                    UseShellExecute = false, CreateNoWindow = true
                                };
                                using var proc = System.Diagnostics.Process.Start(psi)!;
                                string asm = await proc.StandardOutput.ReadToEndAsync();
                                await proc.WaitForExitAsync();
                                if (!string.IsNullOrWhiteSpace(asm))
                                {
                                    await File.WriteAllTextAsync(fpoPath + ".asm", asm);
                                    string hlsl = DisasmService.TranslateAsm(asm);
                                    await File.WriteAllTextAsync(fpoPath + ".translated.hlsl", hlsl);
                                    done++;
                                }
                            }
                            catch { errs++; }
                            finally { try { File.Delete(tmpFpo); } catch { } }
                        }
                    }

                    LogRef($"  Unpacked {unpacked}  disassembled {done}  errors {errs}");
                    totalBundles++;
                    totalFiles += done;
                    totalErrors += errs;

                    Dispatcher.Invoke(() => { Progress.Value = totalBundles * 100.0 / bundles.Length; TxtStatus.Text = bundleName; });
                }

                LogRef($"\n=== Done: {totalBundles} bundles, {totalFiles} shaders, {totalErrors} errors ===");
                LogRef($"Output: {outBase}");
                Dispatcher.Invoke(() => { Progress.Value = 100; TxtStatus.Text = "Done"; });
            });
        }

        // ── Copy Switch shaders ─────────────────────────────────────────
        private async void CopySwitchToReference_Click(object sender, RoutedEventArgs e)
        {
            // Read all UI values on UI thread BEFORE entering Task.Run
            string srcDir    = TxtSwitchShaders.Text;
            string fxcPath   = TxtFXC.Text;
            bool   tryDisasm = ChkRefSwitchDisasm.IsChecked == true;

            if (string.IsNullOrWhiteSpace(srcDir) || !Directory.Exists(srcDir))
            {
                System.Windows.MessageBox.Show("Set 'Switch shaders folder' in Settings first.", "Reference");
                return;
            }
            string outBase = Path.Combine(GetReferenceBase(), "DSR_Switch");
            Directory.CreateDirectory(outBase);

            TxtRefLog.Clear();
            LogRef($"DSR Switch → {outBase}");
            LogRef($"Source: {srcDir}");
            LogRef("Format: NVfp5.0 (Nvidia Tegra fragment program)");
            LogRef("Step 1: Copy .fpo binaries");
            if (tryDisasm) LogRef("Step 2: Extract !!NVfp5.0 asm text");
            LogRef("Step 3: Translate NVfp5 → HLSL skeleton\n");

            await Task.Run(async () =>
            {
                // Preserve subfolder structure from source
                var allFiles = Directory.GetFiles(srcDir, "*.fpo", SearchOption.AllDirectories)
                    .Concat(Directory.GetFiles(srcDir, "*.vpo", SearchOption.AllDirectories))
                    .Concat(Directory.GetFiles(srcDir, "*.cpo", SearchOption.AllDirectories))
                    .OrderBy(f => f).ToArray();

                LogRef($"Found {allFiles.Length} shader files\n");

                int copied = 0, extracted = 0, translated = 0, failed = 0;

                foreach (var srcFile in allFiles)
                {
                    // Preserve relative subfolder structure
                    string rel = Path.GetRelativePath(srcDir, srcFile);
                    string destFile = Path.Combine(outBase, rel);
                    Directory.CreateDirectory(Path.GetDirectoryName(destFile)!);

                    // Step 1: Copy binary
                    await File.WriteAllBytesAsync(destFile, await File.ReadAllBytesAsync(srcFile));
                    copied++;

                    if (tryDisasm)
                    {
                        // Step 2: Extract NVfp5 asm text from binary
                        try
                        {
                            byte[] data = await File.ReadAllBytesAsync(srcFile);
                            string? nvfp5Asm = ExtractNvfp5Asm(data);

                            if (nvfp5Asm != null)
                            {
                                string asmPath = destFile + ".nvfp5.asm";
                                await File.WriteAllTextAsync(asmPath, nvfp5Asm);
                                extracted++;

                                // Step 3: Translate NVfp5 → HLSL using Python script
                                string? hlsl = await TranslateNvfp5ToHlslAsync(asmPath);
                                if (hlsl != null)
                                {
                                    await File.WriteAllTextAsync(destFile + ".translated.hlsl", hlsl);
                                    translated++;
                                }
                            }
                            else
                            {
                                // Not NVfp5 — try fxc /dumpbin (might be DXBC)
                                if (File.Exists(fxcPath))
                                {
                                    try
                                    {
                                        var svc = new DisasmService(fxcPath);
                                        string asm = await svc.DisassembleAsync(destFile);
                                        if (!string.IsNullOrWhiteSpace(asm))
                                        {
                                            await File.WriteAllTextAsync(destFile + ".asm", asm);
                                            extracted++;
                                        }
                                    }
                                    catch { failed++; }
                                }
                            }
                        }
                        catch { failed++; }
                    }

                    if (copied % 100 == 0 || copied == allFiles.Length)
                    {
                        int pct = allFiles.Length > 0 ? copied * 100 / allFiles.Length : 0;
                        LogRef($"  [{pct,3}%] {copied}/{allFiles.Length}  {Path.GetFileName(srcFile)}");
                        Dispatcher.Invoke(() => { Progress.Value = pct; TxtStatus.Text = $"{copied}/{allFiles.Length}"; });
                    }
                }

                LogRef($"\n=== Done ===");
                LogRef($"  Copied:     {copied} .fpo files");
                if (tryDisasm)
                {
                    LogRef($"  Extracted:  {extracted} NVfp5 asm files");
                    LogRef($"  Translated: {translated} HLSL skeletons");
                    LogRef($"  Failed:     {failed}");
                }
                LogRef($"Output: {outBase}");
                Dispatcher.Invoke(() => { Progress.Value = 100; TxtStatus.Text = "Done"; });
            });
        }

        // Extract !!NVfp5.0 or !!NVvp5.0 ASCII text from Switch .fpo binary
        private static string? ExtractNvfp5Asm(byte[] data)
        {
            foreach (var marker in new[] { "!!NVfp5.0"u8.ToArray(), "!!NVvp5.0"u8.ToArray() })
            {
                int idx = IndexOf(data, marker);
                if (idx < 0) continue;

                // Find null terminator or end of file
                int end = idx;
                while (end < data.Length && data[end] != 0) end++;

                return System.Text.Encoding.ASCII.GetString(data, idx, end - idx).Trim();
            }
            return null;
        }

        private static int IndexOf(byte[] haystack, byte[] needle)
        {
            for (int i = 0; i <= haystack.Length - needle.Length; i++)
            {
                bool found = true;
                for (int j = 0; j < needle.Length; j++)
                    if (haystack[i + j] != needle[j]) { found = false; break; }
                if (found) return i;
            }
            return -1;
        }

        // Translate NVfp5 asm → HLSL using tools/nvfp5_to_hlsl.py
        private async Task<string?> TranslateNvfp5ToHlslAsync(string asmPath)
        {
            // Find nvfp5_to_hlsl.py relative to project root
            string exeDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)!;
            string scriptPath = Path.GetFullPath(Path.Combine(exeDir, "..", "..", "..", "..", "tools", "nvfp5_to_hlsl.py"));

            if (!File.Exists(scriptPath))
                return null;

            try
            {
                string outPath = asmPath.Replace(".nvfp5.asm", ".translated.hlsl");
                var psi = new System.Diagnostics.ProcessStartInfo("python", $"\"{scriptPath}\" \"{asmPath}\" \"{outPath}\"")
                {
                    RedirectStandardOutput = true,
                    RedirectStandardError  = true,
                    UseShellExecute        = false,
                    CreateNoWindow         = true
                };
                using var proc = System.Diagnostics.Process.Start(psi)!;
                await proc.WaitForExitAsync();

                if (File.Exists(outPath))
                    return await File.ReadAllTextAsync(outPath);
            }
            catch { }
            return null;
        }

        // ── Unpack ALL platforms ────────────────────────────────────────
        private async void UnpackAllToReference_Click(object sender, RoutedEventArgs e)
        {
            TxtRefLog.Clear();
            LogRef("=== Unpack ALL platforms ===\n");

            if (!string.IsNullOrWhiteSpace(TxtDSR.Text) && Directory.Exists(Path.Combine(TxtDSR.Text, "shader")))
            {
                LogRef("▶ DSR Windows...");
                UnpackDSRToReference_Click(sender, e);
                await Task.Delay(200); // let async start
            }
            else LogRef("  SKIP DSR Windows — folder not set");

            if (!string.IsNullOrWhiteSpace(TxtPTDEShaders.Text) && Directory.Exists(TxtPTDEShaders.Text))
            {
                LogRef("\n▶ PTDE Windows...");
                UnpackPTDEToReference_Click(sender, e);
                await Task.Delay(200);
            }
            else LogRef("  SKIP PTDE Windows — folder not set");

            if (!string.IsNullOrWhiteSpace(TxtSwitchShaders.Text) && Directory.Exists(TxtSwitchShaders.Text))
            {
                LogRef("\n▶ DSR Switch...");
                CopySwitchToReference_Click(sender, e);
            }
            else LogRef("  SKIP DSR Switch — folder not set");
        }

        // ── Clear reference\ ────────────────────────────────────────────
        private void ClearReference_Click(object sender, RoutedEventArgs e)
        {
            string refDir = GetReferenceBase();
            if (!Directory.Exists(refDir))
            {
                LogRef($"reference\\ does not exist: {refDir}");
                return;
            }

            var result = System.Windows.MessageBox.Show(
                $"Delete entire reference\\ folder?\n\n{refDir}\n\nThis cannot be undone.",
                "Clear reference\\", MessageBoxButton.YesNo, MessageBoxImage.Warning);

            if (result != MessageBoxResult.Yes) return;

            try
            {
                Directory.Delete(refDir, recursive: true);
                LogRef($"Deleted: {refDir}");
            }
            catch (Exception ex)
            {
                LogRef($"ERROR: {ex.Message}");
            }
        }
    }
}
