using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace ShaderCompiler.Decompiler
{
    /// <summary>
    /// Translates DX9 ps_3_0/vs_3_0 assembly text to compilable HLSL.
    /// Handles: r0-r31, v0-v9, oC0, c0-c255, s0-s15, def, dcl_*, texld, nrm, lrp, cmp, dp2add, etc.
    /// </summary>
    public class Dx9AsmToHlsl
    {
        private readonly StringBuilder _sb = new();
        private int _indent = 1;
        private string _shaderType = "ps";
        private string _shaderModel = "3_0";

        // Declared resources
        private readonly HashSet<string> _temps       = new();  // r0, r1, ...
        private readonly HashSet<int>    _samplers2D  = new();  // s0, s2, ...
        private readonly HashSet<int>    _samplersCube= new();
        private readonly HashSet<int>    _samplers3D  = new();
        private readonly HashSet<int>    _constRegs   = new();  // c0, c103, ...
        private readonly Dictionary<string, string> _constDefs = new(); // def c0 = float4(...)

        // Input/output declarations
        private readonly List<(string sem, string mask)> _inputs  = new();
        private readonly List<(string sem, string mask)> _outputs = new();

        // Parameter names from CTAB comment (// Parameters: float4 DL_FREG_103; ...)
        private readonly Dictionary<int, string> _paramNames = new(); // c103 → "DL_FREG_103"

        public string Translate(string asmText)
        {
            var lines = asmText.Split('\n');
            ParseCtab(lines);
            CollectDecls(lines);
            GenHeader();
            TranslateBody(lines);
            string hlsl = _sb.ToString();
            
            // Post-process: fix invalid swizzles from literal DXBC translation
            hlsl = FixInvalidSwizzles(hlsl);
            
            return hlsl;
        }
        
        /// <summary>
        /// Fix invalid swizzles in machine-translated HLSL from DXBC.
        /// Patterns like "v3.xyzx.xyz" or "cb0[73].xyzx.xyz" are invalid HLSL
        /// but appear in literal translations of DXBC assembly.
        /// </summary>
        private static string FixInvalidSwizzles(string hlsl)
        {
            // Match any expression ending with ] or word char, followed by .swizzle4.swizzle3-4
            // Examples:
            //   v3.xyzx.xyz        -> v3.xyz
            //   r4.yzwy.xyz        -> r4.yzw
            //   cb0[73].xyzx.xyz   -> cb0[73].xyz
            //   float4(...).xyzx.xyz -> float4(...).xyz
            
            var pattern = @"([\w\])])\.(([xyzw]{4})\.(([xyzw]{3,4})))";
            
            hlsl = Regex.Replace(hlsl, pattern, match =>
            {
                string prefix   = match.Groups[1].Value;
                string swizzle1 = match.Groups[3].Value;
                string swizzle2 = match.Groups[5].Value;
                
                if (swizzle2 == "xyz")
                    return $"{prefix}.{swizzle1.Substring(0, 3)}";
                if (swizzle2 == "xyzw")
                    return $"{prefix}.{swizzle1}";
                
                try
                {
                    var result = "";
                    foreach (char c in swizzle2)
                    {
                        int idx = "xyzw".IndexOf(c);
                        if (idx >= 0 && idx < swizzle1.Length)
                            result += swizzle1[idx];
                        else
                            return match.Value;
                    }
                    return $"{prefix}.{result}";
                }
                catch
                {
                    return match.Value;
                }
            });
            
            return hlsl;
        }

        // ----------------------------------------------------------------
        // Parse CTAB parameter names from comment block
        // ----------------------------------------------------------------
        private void ParseCtab(string[] lines)
        {
            bool inParams = false;
            foreach (var raw in lines)
            {
                var line = raw.Trim();
                if (line == "// Parameters:") { inParams = true; continue; }
                if (inParams && line == "//") { inParams = false; continue; }
                if (inParams && line.StartsWith("//"))
                {
                    // "//   float4 DL_FREG_103;" or "//   sampler2D gSMP_0;"
                    var content = line.TrimStart('/').Trim().TrimEnd(';');
                    var parts = content.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length >= 2)
                    {
                        string typeName = parts[0];
                        string varName  = parts[1];
                        // Extract register number from name like DL_FREG_103
                        var m = Regex.Match(varName, @"_(\d+)$");
                        if (m.Success)
                            _paramNames[int.Parse(m.Groups[1].Value)] = varName;
                    }
                }
            }
        }

        // ----------------------------------------------------------------
        // Collect declarations
        // ----------------------------------------------------------------
        private void CollectDecls(string[] lines)
        {
            int maxTemp = 0;
            foreach (var raw in lines)
            {
                var line = raw.Trim();

                // Shader model
                var m = Regex.Match(line, @"^(ps|vs)_(\d+_\d+)");
                if (m.Success) { _shaderType = m.Groups[1].Value; _shaderModel = m.Groups[2].Value; continue; }

                // def c0, 1, 0, 0, 1
                m = Regex.Match(line, @"^def\s+c(\d+),\s*(.+)");
                if (m.Success)
                {
                    int idx = int.Parse(m.Groups[1].Value);
                    _constDefs[$"c{idx}"] = $"float4({m.Groups[2].Value.Trim()})";
                    _constRegs.Add(idx);
                    continue;
                }

                // dcl_2d s2
                m = Regex.Match(line, @"^dcl_2d\s+s(\d+)");
                if (m.Success) { _samplers2D.Add(int.Parse(m.Groups[1].Value)); continue; }

                // dcl_cube s11
                m = Regex.Match(line, @"^dcl_cube\s+s(\d+)");
                if (m.Success) { _samplersCube.Add(int.Parse(m.Groups[1].Value)); continue; }

                // dcl_volume s3
                m = Regex.Match(line, @"^dcl_volume\s+s(\d+)");
                if (m.Success) { _samplers3D.Add(int.Parse(m.Groups[1].Value)); continue; }

                // dcl_texcoord2_pp v0 etc.
                m = Regex.Match(line, @"^dcl_\w+\s+(v\d+)(\.\w+)?");
                if (m.Success)
                {
                    string reg  = m.Groups[1].Value;
                    string mask = m.Groups[2].Success ? m.Groups[2].Value : ".xyzw";
                    _inputs.Add((reg, mask));
                    continue;
                }

                // Temp registers r0-r31
                m = Regex.Match(line, @"\br(\d+)\b");
                while (m.Success)
                {
                    int idx = int.Parse(m.Groups[1].Value);
                    if (idx > maxTemp) maxTemp = idx;
                    _temps.Add($"r{idx}");
                    m = m.NextMatch();
                }

                // Constant registers used
                m = Regex.Match(line, @"\bc(\d+)\b");
                while (m.Success)
                {
                    _constRegs.Add(int.Parse(m.Groups[1].Value));
                    m = m.NextMatch();
                }
            }
        }

        // ----------------------------------------------------------------
        // Generate HLSL header
        // ----------------------------------------------------------------
        private void GenHeader()
        {
            L($"// Translated from DX9 {_shaderType}_{_shaderModel}");
            L();

            // Constant registers as cbuffer
            // Group: def constants as static const, param constants as cbuffer
            var defConsts   = new List<(int idx, string val)>();
            var paramConsts = new List<(int idx, string name)>();

            foreach (int idx in _constRegs)
            {
                if (_constDefs.ContainsKey($"c{idx}"))
                    defConsts.Add((idx, _constDefs[$"c{idx}"]));
                else if (_paramNames.ContainsKey(idx))
                    paramConsts.Add((idx, _paramNames[idx]));
                else
                    paramConsts.Add((idx, $"c{idx}"));
            }

            // Static defs
            foreach (var (idx, val) in defConsts)
                L($"static const float4 c{idx} = {val};");
            if (defConsts.Count > 0) L();

            // cbuffer for parameters
            if (paramConsts.Count > 0)
            {
                L("cbuffer Params : register(b0)");
                L("{");
                foreach (var (idx, name) in paramConsts)
                    L($"    float4 {name}; // c{idx}");
                L("};");
                // Aliases: #define c103 DL_FREG_103
                L();
                foreach (var (idx, name) in paramConsts)
                    if (name != $"c{idx}")
                        L($"#define c{idx} {name}");
                L();
            }

            // Samplers
            foreach (int s in _samplers2D)
            {
                L($"Texture2D    s{s}_tex : register(t{s});");
                L($"SamplerState s{s}_smp : register(s{s});");
            }
            foreach (int s in _samplersCube)
            {
                L($"TextureCube  s{s}_tex : register(t{s});");
                L($"SamplerState s{s}_smp : register(s{s});");
            }
            foreach (int s in _samplers3D)
            {
                L($"Texture3D    s{s}_tex : register(t{s});");
                L($"SamplerState s{s}_smp : register(s{s});");
            }
            if (_samplers2D.Count + _samplersCube.Count + _samplers3D.Count > 0) L();

            // Input struct
            L("struct PS_IN {");
            L("    float4 pos : SV_Position;");
            var usedInputs = new HashSet<string>();
            foreach (var (reg, mask) in _inputs)
            {
                if (usedInputs.Contains(reg)) continue;
                usedInputs.Add(reg);
                int n = CountSwizzle(mask.TrimStart('.'));
                string t = n > 1 ? $"float{n}" : "float";
                L($"    {t} {reg} : TEXCOORD{reg.Substring(1)};");
            }
            L("};");
            L();

            // Output struct
            L("struct PS_OUT {");
            L("    float4 oC0 : SV_Target0;");
            L("};");
            L();

            // Main
            L("PS_OUT main(PS_IN input) {");
            L("    PS_OUT output = (PS_OUT)0;");

            // Temp regs
            foreach (var r in _temps)
                L($"    float4 {r} = 0;");

            // Input aliases
            foreach (var (reg, mask) in _inputs)
            {
                if (!usedInputs.Contains(reg)) continue;
                usedInputs.Remove(reg); // emit once
                int n = CountSwizzle(mask.TrimStart('.'));
                if (n >= 4)
                    L($"    float4 {reg} = float4(input.{reg});");
                else
                {
                    string zeros = string.Join(", ", new string[4 - n]).Replace(",", "0,").TrimEnd(',');
                    L($"    float4 {reg} = float4(input.{reg}, {zeros});");
                }
            }

            L("    float4 oC0 = 0;");
            L();
        }

        // ----------------------------------------------------------------
        // Translate body
        // ----------------------------------------------------------------
        private void TranslateBody(string[] lines)
        {
            var skipRe   = new Regex(@"^(dcl_|def |//|$)");
            var shaderRe = new Regex(@"^(ps|vs)_\d");

            foreach (var raw in lines)
            {
                var line = raw.Trim();
                line = Regex.Replace(line, @"\s*//.*$", "").Trim();
                if (string.IsNullOrEmpty(line) || skipRe.IsMatch(line) || shaderRe.IsMatch(line))
                    continue;
                TranslateInstr(line);
            }

            L();
            L("    output.oC0 = oC0;");
            L("    return output;");
            L("}");
        }

        // ----------------------------------------------------------------
        // Translate single instruction
        // ----------------------------------------------------------------
        private void TranslateInstr(string line)
        {
            // Strip _pp, _sat modifiers from opcode, remember them
            bool sat = line.Contains("_sat");
            // Remove modifier suffixes from opcode only (not from operands)
            var m = Regex.Match(line, @"^([\w]+(?:_(?:pp|sat|x2|x4|d2|d4|d8))*)\s*(.*)");
            if (!m.Success) { Emit($"// UNHANDLED: {line}"); return; }

            string opRaw  = m.Groups[1].Value.ToLower();
            string argsStr = m.Groups[2].Value;

            // Strip _pp (precision hint, irrelevant in HLSL)
            string op = Regex.Replace(opRaw, @"_pp$|_pp_|_pp(?=_)", "");
            // Extract _sat
            bool hasSat = op.Contains("_sat");
            op = op.Replace("_sat", "");

            var args = ParseArgs(argsStr);
            string D()      => args.Count > 0 ? Reg(args[0]) : "_";
            string A(int i) => i < args.Count ? Reg(args[i]) : "0";
            void Assign(string expr) => Emit($"{D()} = {(hasSat ? $"saturate({expr})" : expr)};");

            switch (op)
            {
                case "mov":   Assign(A(1)); return;
                case "add":   Assign($"{A(1)} + {A(2)}"); return;
                case "sub":   Assign($"{A(1)} - {A(2)}"); return;
                case "mul":   Assign($"{A(1)} * {A(2)}"); return;
                case "mad":   Assign($"{A(1)} * {A(2)} + {A(3)}"); return;
                case "dp2":   Assign($"dot({A(1)}.xy, {A(2)}.xy)"); return;
                case "dp3":   Assign($"dot({A(1)}.xyz, {A(2)}.xyz)"); return;
                case "dp4":   Assign($"dot({A(1)}, {A(2)})"); return;
                case "dp2add":
                    // dp2add dst, src0, src1, src2 = dot(src0.xy, src1.xy) + src2
                    Assign($"dot({A(1)}.xy, {A(2)}.xy) + {A(3)}");
                    return;
                case "abs":   Assign($"abs({A(1)})"); return;
                case "nrm":   Assign($"float4(normalize({A(1)}.xyz), 0)"); return;
                case "rcp":   Assign($"1.0 / {A(1)}"); return;
                case "rsq":   Assign($"rsqrt({A(1)})"); return;
                case "sqrt":  Assign($"sqrt({A(1)})"); return;
                case "exp":   Assign($"exp2({A(1)})"); return;
                case "log":   Assign($"log2({A(1)})"); return;
                case "frc":   Assign($"frac({A(1)})"); return;
                case "min":   Assign($"min({A(1)}, {A(2)})"); return;
                case "max":   Assign($"max({A(1)}, {A(2)})"); return;
                case "pow":   Assign($"pow(abs({A(1)}), {A(2)})"); return;
                case "lrp":   Assign($"lerp({A(3)}, {A(2)}, {A(1)})"); return; // lrp dst, t, a, b = lerp(b,a,t)
                case "cmp":   Assign($"({A(1)} >= 0) ? {A(2)} : {A(3)}"); return;
                case "slt":   Assign($"(float)({A(1)} < {A(2)})"); return;
                case "sge":   Assign($"(float)({A(1)} >= {A(2)})"); return;
                case "sincos":
                    if (args.Count >= 3)
                    {
                        Emit($"{Reg(args[0])} = sin({A(2)});");
                        Emit($"{Reg(args[1])} = cos({A(2)});");
                    }
                    return;
                case "texld":
                case "tex":
                {
                    // texld dst, uv, sampler
                    string dst = Reg(args[0]);
                    string uv  = Reg(args[1]);
                    string smp = args.Count > 2 ? args[2].Trim() : "s0";
                    int sIdx   = int.Parse(Regex.Match(smp, @"\d+").Value);
                    if (_samplersCube.Contains(sIdx))
                        Emit($"{dst} = s{sIdx}_tex.Sample(s{sIdx}_smp, {uv}.xyz);");
                    else if (_samplers3D.Contains(sIdx))
                        Emit($"{dst} = s{sIdx}_tex.Sample(s{sIdx}_smp, {uv}.xyz);");
                    else
                        Emit($"{dst} = s{sIdx}_tex.Sample(s{sIdx}_smp, {uv}.xy);");
                    return;
                }
                case "texldb":
                {
                    string dst = Reg(args[0]);
                    string uv  = Reg(args[1]);
                    string smp = args.Count > 2 ? args[2].Trim() : "s0";
                    int sIdx   = int.Parse(Regex.Match(smp, @"\d+").Value);
                    Emit($"{dst} = s{sIdx}_tex.SampleBias(s{sIdx}_smp, {uv}.xy, {uv}.w);");
                    return;
                }
                case "texldl":
                {
                    string dst = Reg(args[0]);
                    string uv  = Reg(args[1]);
                    string smp = args.Count > 2 ? args[2].Trim() : "s0";
                    int sIdx   = int.Parse(Regex.Match(smp, @"\d+").Value);
                    if (_samplersCube.Contains(sIdx))
                        Emit($"{dst} = s{sIdx}_tex.SampleLevel(s{sIdx}_smp, {uv}.xyz, {uv}.w);");
                    else
                        Emit($"{dst} = s{sIdx}_tex.SampleLevel(s{sIdx}_smp, {uv}.xy, {uv}.w);");
                    return;
                }
                case "texkill":
                    Emit($"if (any({A(0)}.xyz < 0)) discard;");
                    return;
                case "ret": return;
                case "nop": return;
            }

            Emit($"// UNHANDLED: {line}");
        }

        // ----------------------------------------------------------------
        // Register/operand translation
        // ----------------------------------------------------------------
        private static string Reg(string raw)
        {
            raw = raw.Trim();
            bool neg  = raw.StartsWith('-');
            bool abso = raw.Contains('|');
            raw = raw.TrimStart('-').Trim('|');

            string Wrap(string s)
            {
                if (abso) s = $"abs({s})";
                if (neg)  s = $"-{s}";
                return s;
            }

            // r0.xyz, v0.xyzw, oC0.xyzw
            var m = Regex.Match(raw, @"^(r\d+|v\d+|oC\d+)(\.\w+)?$");
            if (m.Success)
                return Wrap(m.Groups[1].Value + m.Groups[2].Value);

            // c103.xyzw or c103
            m = Regex.Match(raw, @"^c(\d+)(\.\w+)?$");
            if (m.Success)
                return Wrap($"c{m.Groups[1].Value}{m.Groups[2].Value}");

            // Literal: 1.0, -0.5 etc.
            if (Regex.IsMatch(raw, @"^-?[\d.]+([eE][+-]?\d+)?$"))
                return Wrap(raw);

            return Wrap(raw);
        }

        // ----------------------------------------------------------------
        // Helpers
        // ----------------------------------------------------------------
        private static List<string> ParseArgs(string s)
        {
            var result = new List<string>();
            int depth = 0;
            var cur   = new StringBuilder();
            foreach (char c in s)
            {
                if (c == '(' || c == '[') { depth++; cur.Append(c); }
                else if (c == ')' || c == ']') { depth--; cur.Append(c); }
                else if (c == ',' && depth == 0) { result.Add(cur.ToString().Trim()); cur.Clear(); }
                else cur.Append(c);
            }
            if (cur.Length > 0) result.Add(cur.ToString().Trim());
            return result;
        }

        private static int CountSwizzle(string s)
        {
            int n = 0;
            foreach (char c in s) if ("xyzw".Contains(c)) n++;
            return Math.Max(n, 1);
        }

        private void Emit(string line) => _sb.AppendLine(new string(' ', _indent * 4) + line);
        private void L(string line = "") => _sb.AppendLine(line);
    }
}
