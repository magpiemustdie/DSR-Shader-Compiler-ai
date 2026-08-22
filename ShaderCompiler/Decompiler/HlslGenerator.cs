using System;
using System.Collections.Generic;
using System.Text;

namespace ShaderCompiler.Decompiler
{
    /// <summary>Generates HLSL skeleton from parsed DXBC metadata + disassembly text.</summary>
    public static class HlslGenerator
    {
        private static readonly Dictionary<string, string> TexTypeMap = new()
        {
            ["2D"]      = "Texture2D",
            ["3D"]      = "Texture3D",
            ["Cube"]    = "TextureCube",
            ["1D"]      = "Texture1D",
            ["1DArray"] = "Texture1DArray",
            ["2DArray"] = "Texture2DArray",
        };

        public static string Generate(DxbcParser info, string asmText)
        {
            var sb = new StringBuilder();
            sb.AppendLine($"// Decompiled {info.ShaderType}_{info.ModelMajor}_{info.ModelMinor}");
            sb.AppendLine("// NOTE: Variable names are reconstructed from DXBC metadata.");
            sb.AppendLine("// This is a best-effort reconstruction from DXBC bytecode.");
            sb.AppendLine();

            // Constant buffers — use real variable names from RDEF if available
            if (info.CBuffers.Count > 0)
            {
                foreach (var cb in info.CBuffers)
                {
                    sb.AppendLine($"cbuffer {cb.Name} : register(b{cb.Slot})");
                    sb.AppendLine("{");
                    if (cb.Variables.Count > 0)
                    {
                        foreach (var (vname, voff, vsize) in cb.Variables)
                            sb.AppendLine($"    {SizeToType(vsize)} {vname}; // offset {voff}");
                    }
                    else
                    {
                        // Fallback: generic float4 array
                        sb.AppendLine($"    float4 data[256]; // no variable info");
                    }
                    sb.AppendLine("};");
                    sb.AppendLine();
                }
            }
            else
            {
                // No RDEF — emit generic cbuffer
                sb.AppendLine("cbuffer Globals : register(b0)");
                sb.AppendLine("{");
                sb.AppendLine("    float4 cb0[256];");
                sb.AppendLine("};");
                sb.AppendLine();
            }

            // Textures and samplers — deduplicate (RDEF lists both texture and sampler separately)
            var emittedTex = new HashSet<int>();
            foreach (var r in info.Resources)
            {
                if (r.Type == "texture" && !emittedTex.Contains(r.Slot))
                {
                    string texType = TexTypeMap.TryGetValue(r.Dim, out var t) ? t : "Texture2D";
                    sb.AppendLine($"{texType}<float4> {r.Name} : register(t{r.Slot});");
                    sb.AppendLine($"SamplerState {r.Name}Sampler : register(s{r.Slot});");
                    emittedTex.Add(r.Slot);
                }
                else if (r.Type == "sampler")
                {
                    // Only emit if no matching texture was emitted for this slot
                    if (!emittedTex.Contains(r.Slot))
                        sb.AppendLine($"SamplerState {r.Name} : register(s{r.Slot});");
                }
                else if (r.Type == "uav")
                    sb.AppendLine($"RWTexture2D<float4> {r.Name} : register(u{r.Slot});");
            }
            if (info.Resources.Count > 0) sb.AppendLine();

            // Input struct
            bool isVs = info.ShaderType == "vs";
            if (info.Inputs.Count > 0)
            {
                sb.AppendLine(isVs ? "struct VS_IN" : "struct PS_IN");
                sb.AppendLine("{");
                if (!isVs)
                    sb.AppendLine("    float4 pos : SV_Position;");
                foreach (var e in info.Inputs)
                {
                    if (e.Semantic == "SV_Position" && !isVs) continue;
                    string t   = MaskToType(e.Mask, e.ComponentType);
                    string sem = e.Index > 0 ? $"{e.Semantic}{e.Index}" : e.Semantic;
                    sb.AppendLine($"    {t} {SemToVar(e.Semantic, e.Index)} : {sem};");
                }
                sb.AppendLine("};");
                sb.AppendLine();
            }

            // Output struct
            if (info.Outputs.Count > 0)
            {
                sb.AppendLine(isVs ? "struct VS_OUT" : "struct PS_OUT");
                sb.AppendLine("{");
                if (isVs)
                    sb.AppendLine("    float4 pos : SV_Position;");
                foreach (var e in info.Outputs)
                {
                    if (e.Semantic == "SV_Position" && isVs) continue;
                    string t   = MaskToType(e.Mask, e.ComponentType);
                    string sem = e.Index > 0 ? $"{e.Semantic}{e.Index}" : e.Semantic;
                    sb.AppendLine($"    {t} {SemToVar(e.Semantic, e.Index)} : {sem};");
                }
                sb.AppendLine("};");
                sb.AppendLine();
            }

            // Main function
            string inType  = info.Inputs.Count  > 0 ? (isVs ? "VS_IN"  : "PS_IN")  : "void";
            string outType = info.Outputs.Count > 0 ? (isVs ? "VS_OUT" : "PS_OUT") : "void";
            sb.AppendLine($"{outType} main({inType} input)");
            sb.AppendLine("{");
            if (info.Outputs.Count > 0)
            {
                sb.AppendLine($"    {outType} output = ({outType})0;");
                sb.AppendLine();
            }

            // Embed disassembly as comments
            sb.AppendLine("    // === DXBC Disassembly (reference) ===");
            foreach (var line in asmText.Split('\n'))
                sb.AppendLine($"    // {line.TrimEnd()}");
            sb.AppendLine();
            sb.AppendLine("    // TODO: Translate the above asm to HLSL manually.");
            sb.AppendLine("    // Registers r0-rN map to local float4 variables.");
            sb.AppendLine("    // v0-vN are inputs, o0-oN are outputs.");
            sb.AppendLine();

            if (info.Outputs.Count > 0)
            {
                foreach (var e in info.Outputs)
                    sb.AppendLine($"    output.{SemToVar(e.Semantic, e.Index)} = 0;");
                sb.AppendLine();
                sb.AppendLine("    return output;");
            }
            sb.AppendLine("}");

            return sb.ToString();
        }

        private static string SizeToType(int size) => size switch
        {
            <= 4   => "float",
            <= 8   => "float2",
            <= 12  => "float3",
            <= 16  => "float4",
            <= 64  => "float4x4",
            _      => $"float4 _var[{(size + 15) / 16}]"
        };

        private static string MaskToType(string mask, string base_)
        {
            int n = mask.Length;
            return n <= 1 ? base_ : $"{base_}{n}";
        }

        private static string SemToVar(string semantic, int index)
        {
            string clean = semantic.Replace("SV_", "").ToLower();
            return index > 0 ? $"{clean}{index}" : clean;
        }
    }
}
