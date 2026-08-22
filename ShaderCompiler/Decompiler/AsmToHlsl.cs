using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace ShaderCompiler.Decompiler
{
    /// <summary>Translates DXBC assembly text to compilable HLSL (port of dxbc_asm_to_hlsl.py).</summary>
    public class AsmToHlsl
    {
        private readonly StringBuilder _sb = new();
        private int _indent = 1;
        private string _shaderType = "ps";
        private string _shaderModel = "5_0";
        private readonly HashSet<string> _temps = new();
        private readonly Dictionary<int, string> _samplers = new();
        private readonly HashSet<int> _comparisonSamplers = new(); // samplers used in sample_c
        private readonly Dictionary<int, (string type, string name)> _textures = new();
        private readonly HashSet<string> _rawBuffers = new(); // ByteAddressBuffer names (t5, etc.)
        private readonly Dictionary<int, (string name, int stride)> _structuredBuffers = new();
        private readonly Dictionary<int, (string type, string name)> _uavs = new();
        private readonly Dictionary<int, (string type, int count)> _indexableTemps = new();
        private readonly Dictionary<int, (string type, int count)> _groupshared = new();
        private readonly Dictionary<int, int> _constantBuffers = new(); // slot -> size
        private readonly Dictionary<int, List<(string name, string type, int offset, int size)>> _constantBufferVars = new(); // slot -> variables
        private readonly List<string?> _inputs  = new();
        private readonly List<string?> _outputs = new();
        private readonly Dictionary<int, string> _systemValueInputs = new(); // register -> semantic (e.g., "vertex_id")
        private readonly Dictionary<int, string> _inputSemantics = new(); // register -> semantic (e.g., "COLOR", "TEXCOORD")
        private readonly Dictionary<int, int> _inputSemanticIndices = new(); // register -> semantic index
        private readonly Dictionary<int, string> _inputFormats = new(); // register -> format (e.g., "int", "float")
        private readonly Dictionary<int, string> _outputSemantics = new(); // register -> semantic (e.g., "COLOR", "TEXCOORD")
        private readonly Dictionary<int, int> _outputSemanticIndices = new(); // register -> semantic index
        private bool _hasDepthOutput = false;
        private bool _hasImmediateConstantBuffer = false;
        private int _numThreadsX = 8, _numThreadsY = 8, _numThreadsZ = 1;
        private int _vfaceReg = -1; // register index for SV_IsFrontFace

        public string Translate(string asmText)
        {
            var lines = asmText.Split('\n');
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
            // Fix invalid infinity literals: -1.#INF00 -> -1.#INF
            hlsl = Regex.Replace(hlsl, @"-1\.#INF00\b", "-1.#INF");
            
            // Fix assignments where LHS has smaller swizzle than RHS
            // Example: r0.xy = r0.xyxx * float4(...) -> r0.xy = r0.xy * float2(...)
            hlsl = Regex.Replace(hlsl, @"(\w+)\.([xyzw]{1,3})\s*=\s*(\w+)\.([xyzw]{4})\s*\*\s*float4\(([^)]+)\)", match =>
            {
                string lhsVar = match.Groups[1].Value;
                string lhsSwizzle = match.Groups[2].Value;
                string rhsVar = match.Groups[3].Value;
                string rhsSwizzle = match.Groups[4].Value;
                string literal = match.Groups[5].Value;
                
                int lhsSize = lhsSwizzle.Length;
                
                // Truncate RHS swizzle to match LHS size
                string rhsSwizzleTrunc = rhsSwizzle.Substring(0, lhsSize);
                
                // Truncate literal components
                var literalParts = literal.Split(',').Select(s => s.Trim()).ToArray();
                var literalTrunc = string.Join(", ", literalParts.Take(lhsSize));
                
                string floatType = lhsSize switch
                {
                    1 => "float",
                    2 => "float2",
                    3 => "float3",
                    _ => "float4"
                };
                
                return $"{lhsVar}.{lhsSwizzle} = {rhsVar}.{rhsSwizzleTrunc} * {floatType}({literalTrunc})";
            });
            
            // Match any expression ending with ] or word char, followed by .swizzle4.swizzle3-4
            // Examples:
            //   v3.xyzx.xyz        -> v3.xyz
            //   r4.yzwy.xyz        -> r4.yzw
            //   cb0[73].xyzx.xyz   -> cb0[73].xyz
            //   float4(...).xyzx.xyz -> float4(...).xyz
            
            var pattern = @"([\w\])])\.(([xyzw]{4})\.(([xyzw]{3,4})))";
            
            hlsl = Regex.Replace(hlsl, pattern, match =>
            {
                string prefix   = match.Groups[1].Value; // last char before first dot
                string swizzle1 = match.Groups[3].Value; // e.g. xyzx
                string swizzle2 = match.Groups[5].Value; // e.g. xyz
                
                // If swizzle2 is xyz or xyzw, just take first N chars of swizzle1
                if (swizzle2 == "xyz")
                    return $"{prefix}.{swizzle1.Substring(0, 3)}";
                if (swizzle2 == "xyzw")
                    return $"{prefix}.{swizzle1}";
                
                // Otherwise resolve: swizzle2 indexes into swizzle1
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
        private void CollectDecls(string[] lines)
        {
            // First pass: parse cbuffer variables from comments (Buffer Definitions section)
            bool inBufferDefs = false;
            int currentCbSlot = -1;
            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i].Trim();
                
                // Detect Buffer Definitions section
                if (line.Contains("// Buffer Definitions:"))
                {
                    inBufferDefs = true;
                    continue;
                }
                
                // Detect end of Buffer Definitions
                if (inBufferDefs && (line.Contains("// Resource Bindings:") || line.StartsWith("ps_") || line.StartsWith("vs_")))
                {
                    inBufferDefs = false;
                    break;
                }
                
                // Parse cbuffer declaration: // cbuffer $Globals
                if (inBufferDefs && line.StartsWith("// cbuffer"))
                {
                    // Extract slot from register binding later, for now just mark we're in a cbuffer
                    currentCbSlot = 0; // Default to cb0
                    continue;
                }
                
                // Parse variable: //   float4x4 gVC_WorldViewClipMtx;     // Offset:    0 Size:    64
                if (inBufferDefs && currentCbSlot >= 0 && line.StartsWith("//   ") && line.Contains("Offset:"))
                {
                    var match = Regex.Match(line, @"//\s+(\S+)\s+(\w+);\s+//\s+Offset:\s+(\d+)\s+Size:\s+(\d+)");
                    if (match.Success)
                    {
                        string varType = match.Groups[1].Value;
                        string varName = match.Groups[2].Value;
                        int offset = int.Parse(match.Groups[3].Value);
                        int size = int.Parse(match.Groups[4].Value);
                        
                        if (!_constantBufferVars.ContainsKey(currentCbSlot))
                            _constantBufferVars[currentCbSlot] = new();
                        
                        _constantBufferVars[currentCbSlot].Add((varName, varType, offset, size));
                    }
                }
            }
            
            // Second pass: parse Input signature from comments
            bool inInputSig = false;
            bool inOutputSig = false;
            for (int i = 0; i < lines.Length; i++)
            {
                var line = lines[i].Trim();
                
                // Detect start of Input signature section
                if (line.Contains("// Input signature:"))
                {
                    inInputSig = true;
                    inOutputSig = false;
                    continue;
                }
                
                // Detect start of Output signature section
                if (line.Contains("// Output signature:"))
                {
                    inInputSig = false;
                    inOutputSig = true;
                    continue;
                }
                
                // Detect end of signature sections
                if ((inInputSig || inOutputSig) && (line.StartsWith("ps_") || line.StartsWith("vs_") || line.StartsWith("cs_")))
                {
                    inInputSig = false;
                    inOutputSig = false;
                    break;
                }
                
                // Parse input signature lines
                // Format: // NAME                 Index   Mask Register SysValue  Format   Used
                //         // SV_Position              0   xyzw        0      POS   float
                //         // COLOR                    0   xyzw        1     NONE   float   xyzw
                if (inInputSig && line.StartsWith("//") && !line.Contains("----"))
                {
                    var parts = line.Substring(2).Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    // Skip header line (Name Index Mask...) and empty lines
                    if (parts.Length >= 6 && int.TryParse(parts[3], out int reg))
                    {
                        string semantic = parts[0];
                        int semIndex = int.Parse(parts[1]);
                        string format = parts.Length >= 6 ? parts[5] : "float"; // Format is at index 5
                        
                        // Skip SV_Position and SV_IsFrontFace - they're handled separately
                        if (semantic == "SV_Position" || semantic == "SV_IsFrontFace") continue;
                        
                        _inputSemantics[reg] = semantic;
                        _inputSemanticIndices[reg] = semIndex;
                        _inputFormats[reg] = format;
                    }
                }
                
                // Parse output signature lines (same format as input)
                if (inOutputSig && line.StartsWith("//") && !line.Contains("----"))
                {
                    var parts = line.Substring(2).Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    // Skip header line and empty lines
                    if (parts.Length >= 6 && int.TryParse(parts[3], out int reg))
                    {
                        string semantic = parts[0];
                        int semIndex = int.Parse(parts[1]);
                        
                        // Skip SV_Position - it's handled separately
                        if (semantic == "SV_Position") continue;
                        
                        if (!_outputSemantics.ContainsKey(reg))
                        {
                            _outputSemantics[reg] = semantic;
                            _outputSemanticIndices[reg] = semIndex;
                        }
                    }
                }
            }
            
            // Second pass: collect declarations
            foreach (var raw in lines)
            {
                var line = raw.Trim();
                var m = Regex.Match(line, @"^(ps|vs|gs|hs|ds|cs)_(\d+_\d+)");
                if (m.Success) { _shaderType = m.Groups[1].Value; _shaderModel = m.Groups[2].Value; continue; }

                // Parse constant buffers
                m = Regex.Match(line, @"dcl_constantbuffer\s+[Cc][Bb](\d+)\[(\d+)\]");
                if (m.Success) 
                { 
                    int slot = int.Parse(m.Groups[1].Value);
                    int size = int.Parse(m.Groups[2].Value);
                    _constantBuffers[slot] = size;
                    continue; 
                }

                m = Regex.Match(line, @"dcl_temps\s+(\d+)");
                if (m.Success) { for (int i = 0; i < int.Parse(m.Groups[1].Value); i++) _temps.Add($"r{i}"); continue; }

                m = Regex.Match(line, @"dcl_sampler\s+s(\d+)");
                if (m.Success) { _samplers[int.Parse(m.Groups[1].Value)] = $"s{m.Groups[1].Value}"; continue; }

                m = Regex.Match(line, @"dcl_resource_texture2d\s+.*\s+t(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _textures[s] = ("Texture2D", $"t{s}"); continue; }

                m = Regex.Match(line, @"dcl_resource_texturecube\s+.*\s+t(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _textures[s] = ("TextureCube", $"t{s}"); continue; }

                m = Regex.Match(line, @"dcl_resource_structured\s+t(\d+),\s*(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _structuredBuffers[s] = ($"t{s}", int.Parse(m.Groups[2].Value)); continue; }

                // 3D / 1D / cube array textures
                m = Regex.Match(line, @"dcl_resource_texture3d\s+.*\s+t(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _textures[s] = ("Texture3D", $"t{s}"); continue; }
                m = Regex.Match(line, @"dcl_resource_texture1d\s+.*\s+t(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _textures[s] = ("Texture1D", $"t{s}"); continue; }
                m = Regex.Match(line, @"dcl_resource_texture2darray\s+.*\s+t(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _textures[s] = ("Texture2DArray", $"t{s}"); continue; }
                m = Regex.Match(line, @"dcl_resource_texturecubearray\s+.*\s+t(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _textures[s] = ("TextureCubeArray", $"t{s}"); continue; }
                m = Regex.Match(line, @"dcl_resource_texture2dms\(?\d*\)?\s+.*\s+t(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _textures[s] = ("Texture2DMS<float4>", $"t{s}"); continue; }
                
                // Buffer resources
                m = Regex.Match(line, @"dcl_resource_buffer\s+\((\w+),.*\)\s+t(\d+)");
                if (m.Success) 
                { 
                    int s = int.Parse(m.Groups[2].Value);
                    string type = m.Groups[1].Value == "uint" ? "Buffer<uint4>" : "Buffer<float4>";
                    _textures[s] = (type, $"t{s}"); 
                    continue; 
                }
                
                // Raw buffer (ByteAddressBuffer)
                m = Regex.Match(line, @"dcl_resource_raw\s+t(\d+)");
                if (m.Success)
                {
                    int s = int.Parse(m.Groups[1].Value);
                    string name = $"t{s}";
                    _textures[s] = ("ByteAddressBuffer", name);
                    _rawBuffers.Add(name);
                    continue;
                }
                
                // Immediate constant buffer
                m = Regex.Match(line, @"dcl_immediateConstantBuffer\s+\{");
                if (m.Success) 
                { 
                    _hasImmediateConstantBuffer = true;
                    continue; 
                }

                // UAV
                m = Regex.Match(line, @"dcl_uav_typed_texture2d\s+.*\s+u(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _uavs[s] = ("RWTexture2D<float4>", $"u{s}"); continue; }
                m = Regex.Match(line, @"dcl_uav_typed_texture2darray\s+.*\s+u(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _uavs[s] = ("RWTexture2DArray<float4>", $"u{s}"); continue; }
                m = Regex.Match(line, @"dcl_uav_typed_texture3d\s+.*\s+u(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _uavs[s] = ("RWTexture3D<float4>", $"u{s}"); continue; }
                m = Regex.Match(line, @"dcl_uav_typed_buffer\s+\((\w+),.*\)\s+u(\d+)");
                if (m.Success) 
                { 
                    int s = int.Parse(m.Groups[2].Value);
                    string type = m.Groups[1].Value == "uint" ? "RWBuffer<uint4>" : "RWBuffer<float4>";
                    _uavs[s] = (type, $"u{s}"); 
                    continue; 
                }
                m = Regex.Match(line, @"dcl_uav_structured\s+u(\d+),\s*(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _uavs[s] = ($"RWStructuredBuffer<uint4>", $"u{s}"); continue; }
                m = Regex.Match(line, @"dcl_uav_raw\s+u(\d+)");
                if (m.Success) { int s = int.Parse(m.Groups[1].Value); _uavs[s] = ("RWByteAddressBuffer", $"u{s}"); continue; }

                // Indexable temps
                m = Regex.Match(line, @"dcl_indexableTemp\s+x(\d+)\[(\d+)\]");
                if (m.Success) { _indexableTemps[int.Parse(m.Groups[1].Value)] = ("float4", int.Parse(m.Groups[2].Value)); continue; }

                // Groupshared
                m = Regex.Match(line, @"dcl_tgsm_structured\s+g(\d+),\s*(\d+),\s*(\d+)");
                if (m.Success) { _groupshared[int.Parse(m.Groups[1].Value)] = ("uint", int.Parse(m.Groups[3].Value)); continue; }
                m = Regex.Match(line, @"dcl_tgsm_raw\s+g(\d+),\s*(\d+)");
                if (m.Success) { _groupshared[int.Parse(m.Groups[1].Value)] = ("uint", int.Parse(m.Groups[2].Value) / 4); continue; }

                // numthreads
                m = Regex.Match(line, @"dcl_thread_group\s+(\d+),\s*(\d+),\s*(\d+)");
                if (m.Success) { _numThreadsX = int.Parse(m.Groups[1].Value); _numThreadsY = int.Parse(m.Groups[2].Value); _numThreadsZ = int.Parse(m.Groups[3].Value); continue; }

                // dcl_input_ps_sgv vN, isFrontFace — SV_IsFrontFace
                m = Regex.Match(line, @"dcl_input_ps_sgv\s+v(\d+).*isFrontFace", RegexOptions.IgnoreCase);
                if (m.Success)
                {
                    int idx = int.Parse(m.Groups[1].Value);
                    _vfaceReg = idx;
                    while (_inputs.Count <= idx) _inputs.Add(null);
                    _inputs[idx] = ".x"; // scalar
                    continue;
                }

                m = Regex.Match(line, @"dcl_input(?:_ps\w*)?\s+(?:\w+\s+)?v(\d+)(\.\w+)?");
                if (m.Success)
                {
                    int idx = int.Parse(m.Groups[1].Value);
                    while (_inputs.Count <= idx) _inputs.Add(null);
                    _inputs[idx] = m.Groups[2].Success ? m.Groups[2].Value : ".xyzw";
                    continue;
                }
                
                // System value inputs (e.g., vertex_id, instance_id)
                m = Regex.Match(line, @"dcl_input_sgv\s+v(\d+)(\.\w+)?,\s*(\w+)");
                if (m.Success)
                {
                    int idx = int.Parse(m.Groups[1].Value);
                    string semantic = m.Groups[3].Value;
                    while (_inputs.Count <= idx) _inputs.Add(null);
                    _inputs[idx] = m.Groups[2].Success ? m.Groups[2].Value : ".xyzw";
                    _systemValueInputs[idx] = semantic;
                    continue;
                }

                m = Regex.Match(line, @"dcl_output\w*\s+o(\d+)(\.\w+)?");
                if (m.Success)
                {
                    int idx = int.Parse(m.Groups[1].Value);
                    while (_outputs.Count <= idx) _outputs.Add(null);
                    _outputs[idx] = m.Groups[2].Success ? m.Groups[2].Value : ".xyzw";
                    continue;
                }
                
                // Check for depth output
                m = Regex.Match(line, @"dcl_output\s+oDepth");
                if (m.Success)
                {
                    _hasDepthOutput = true;
                    continue;
                }
                
                // Scan for sample_c instructions to detect comparison samplers
                if (line.Contains("sample_c"))
                {
                    // sample_c_aoffimmi_indexable(...) dst, uv, tex, samp, cmp
                    // Find the sampler argument - it's the one starting with 's' followed by digit
                    var sm = Regex.Match(line, @"\bs(\d+)\b");
                    if (sm.Success)
                    {
                        int sampNum = int.Parse(sm.Groups[1].Value);
                        _comparisonSamplers.Add(sampNum);
                        // Debug output will be visible in generated HLSL
                    }
                }
            }
        }

        private void GenHeader()
        {
            L($"// Translated from DXBC {_shaderType}_{_shaderModel}");
            L();
            
            // Generate constant buffers
            if (_constantBuffers.Count == 0)
            {
                // Default: cb0 with 256 slots
                L("cbuffer Globals : register(b0) {");
                L("    float4 cb0[256]; // cb0[N] maps to slot N");
                L("};");
            }
            else
            {
                foreach (var (slot, size) in _constantBuffers.OrderBy(kv => kv.Key))
                {
                    string bufferName = slot switch
                    {
                        0 => "Globals",
                        1 => "AlphaTestBuffer",
                        2 => "ClipPlaneBuffer",
                        _ => $"ConstantBuffer{slot}"
                    };
                    L($"cbuffer {bufferName} : register(b{slot}) {{");
                    
                    // Special case: cb1 for pixel shaders uses named fields instead of array
                    if (slot == 1 && _shaderType == "ps")
                    {
                        L("    int AlphaTest;");
                        L("    float3 AlphaTestRef;");
                        L("    float4 _pad;");
                    }
                    else
                    {
                        // Use named variables if available from RDEF
                        if (_constantBufferVars.TryGetValue(slot, out var vars) && vars.Count > 0)
                        {
                            foreach (var (name, type, offset, varSize) in vars)
                            {
                                // Add row_major for matrices to match ASM behavior
                                string typePrefix = type.Contains("float4x4") || type.Contains("float3x3") || type.Contains("float2x2") 
                                    ? "row_major " 
                                    : "";
                                L($"    {typePrefix}{type} {name};");
                            }
                        }
                        else
                        {
                            L($"    float4 cb{slot}[{size}];");
                        }
                    }
                    L("};");
                }
            }
            
            // Immediate constant buffer
            if (_hasImmediateConstantBuffer)
            {
                L("static const float4 icb[16] = {"); // Placeholder size, will be filled from ASM
                L("    float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0),");
                L("    float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0),");
                L("    float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0),");
                L("    float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0)");
                L("};");
            }
            L();

            foreach (var (slot, (ttype, name)) in _textures)
            {
                L($"{ttype} {name} : register(t{slot});");
                // Use SamplerComparisonState for comparison samplers, SamplerState otherwise
                string samplerType = _comparisonSamplers.Contains(slot) ? "SamplerComparisonState" : "SamplerState";
                L($"{samplerType} {name}Sampler : register(s{slot});");
            }
            // Declare standalone comparison samplers (used in sample_c but no matching texture)
            foreach (int slot in _comparisonSamplers)
            {
                if (!_textures.ContainsKey(slot))
                    L($"SamplerComparisonState s{slot} : register(s{slot});");
            }
            
            // Structured buffers (e.g., clustered point lights t16-t18)
            foreach (var (slot, (name, stride)) in _structuredBuffers)
            {
                // For structured buffers, declare as StructuredBuffer<uint> and access via byte offset
                // This is the most flexible approach that works with any stride
                L($"StructuredBuffer<uint> {name} : register(t{slot});");
            }
            
            foreach (var (slot, (utype, name)) in _uavs)
            {
                // Add globallycoherent to suppress race condition warnings in compute shaders
                if (_shaderType == "cs")
                    L($"globallycoherent {utype} {name} : register(u{slot});");
                else
                    L($"{utype} {name} : register(u{slot});");
            }
            L();

            // Groupshared memory
            foreach (var (idx, (gtype, count)) in _groupshared)
                L($"groupshared {gtype} g{idx}[{count}];");
            if (_groupshared.Count > 0) L();

            if (_shaderType == "cs")
            {
                L($"[numthreads({_numThreadsX}, {_numThreadsY}, {_numThreadsZ})]");
                L("void main(");
                L("    uint3 vThreadID      : SV_DispatchThreadID,");
                L("    uint3 vThreadGroupID : SV_GroupThreadID,");
                L("    uint3 vGroupID       : SV_GroupID,");
                L("    uint  vThreadIndex   : SV_GroupIndex)");
                L("{");
                L("    uint3 vThreadIDInGroup = vThreadGroupID;");
                L("    uint  vThreadIDInGroupFlattened = vThreadIndex;");
            }
            else if (_shaderType == "vs")
            {
                L("struct VS_IN {");
                for (int i = 0; i < _inputs.Count; i++)
                {
                    if (_inputs[i] == null) continue;
                    int n = CountSwizzle(_inputs[i]!.TrimStart('.'));
                    
                    // Determine type from Format in Input Signature
                    string baseType = "float";
                    if (_inputFormats.TryGetValue(i, out string? format))
                    {
                        baseType = format switch
                        {
                            "int" => "int",
                            "uint" => "uint",
                            _ => "float"
                        };
                    }
                    string t = n > 1 ? $"{baseType}{n}" : baseType;
                    
                    // Use system value semantic if available
                    string semantic;
                    if (_systemValueInputs.TryGetValue(i, out string? sysVal))
                    {
                        semantic = sysVal switch
                        {
                            "vertex_id" => "SV_VertexID",
                            "instance_id" => "SV_InstanceID",
                            _ => $"TEXCOORD{i}"
                        };
                        t = "uint"; // System values are typically uint
                    }
                    else if (_inputSemantics.TryGetValue(i, out string? sem))
                    {
                        // Use semantic from Input Signature
                        int semIdx = _inputSemanticIndices.TryGetValue(i, out int idx) ? idx : 0;
                        semantic = $"{sem}{semIdx}";
                    }
                    else
                    {
                        semantic = $"TEXCOORD{i}";
                    }
                    
                    L($"    {t} v{i} : {semantic};");
                }
                L("};");
                L("struct VS_OUT {");
                L("    float4 pos : SV_Position;");
                int structIdx = 0;
                for (int i = 1; i < _outputs.Count; i++)
                {
                    if (_outputs[i] == null) continue;
                    int n = CountSwizzle(_outputs[i]!.TrimStart('.'));
                    string t = n > 1 ? $"float{n}" : "float";
                    
                    // Use semantic from Output Signature if available
                    string semantic;
                    if (_outputSemantics.TryGetValue(i, out string? sem))
                    {
                        int semIdx = _outputSemanticIndices.TryGetValue(i, out int idx) ? idx : 0;
                        semantic = $"{sem}{semIdx}";
                    }
                    else
                    {
                        semantic = $"TEXCOORD{structIdx}";
                    }
                    
                    L($"    {t} o{structIdx} : {semantic};");
                    structIdx++;
                }
                L("};");
                L("VS_OUT main(VS_IN input) {");
                L("    VS_OUT output = (VS_OUT)0;");
            }
            else
            {
                L("struct PS_IN {");
                L("    float4 pos : SV_Position;");
                for (int i = 1; i < _inputs.Count; i++)
                {
                    if (_inputs[i] == null) continue;
                    if (i == _vfaceReg)
                    {
                        L($"    uint vface : SV_IsFrontFace;");
                        continue;
                    }
                    int n = CountSwizzle(_inputs[i]!.TrimStart('.'));
                    string t = n > 1 ? $"float{n}" : "float";
                    
                    // Use semantic from Input Signature if available
                    string semantic;
                    if (_inputSemantics.TryGetValue(i, out string? sem))
                    {
                        int semIdx = _inputSemanticIndices.TryGetValue(i, out int idx) ? idx : 0;
                        semantic = $"{sem}{semIdx}";
                    }
                    else
                    {
                        semantic = $"TEXCOORD{i}";
                    }
                    
                    L($"    {t} v{i} : {semantic};");
                }
                // Don't add SV_IsFrontFace automatically - only if it's in the original shader
                L("};");
                L("struct PS_OUT {");
                for (int i = 0; i < _outputs.Count; i++)
                {
                    if (_outputs[i] == null) continue;
                    int n = CountSwizzle(_outputs[i]!.TrimStart('.'));
                    string t = n > 1 ? $"float{n}" : "float";
                    L($"    {t} o{i} : SV_Target{i};");
                }
                if (_hasDepthOutput)
                    L("    float oDepth : SV_Depth;");
                L("};");
                L("PS_OUT main(PS_IN input) {");
                L("    PS_OUT output = (PS_OUT)0;");
            }

            foreach (var r in _temps)
                L($"    float4 {r} = 0;");

            // Indexable temps
            foreach (var (idx, (itype, count)) in _indexableTemps)
                L($"    {itype} x{idx}[{count}];");

            if (_shaderType == "ps")
            {
                L("    float4 v0 = input.pos;");
                for (int i = 1; i < _inputs.Count; i++)
                {
                    if (_inputs[i] == null) continue;
                    if (i == _vfaceReg)
                    {
                        L($"    uint v{i}x = input.vface;");
                        continue;
                    }
                    int n = CountSwizzle(_inputs[i]!.TrimStart('.'));
                    if (n >= 4)
                        L($"    float4 v{i} = float4(input.v{i});");
                    else if (n == 0)
                        L($"    float4 v{i} = 0;");
                    else
                    {
                        string zeros = string.Join(", ", Enumerable.Repeat("0", 4 - n));
                        L($"    float4 v{i} = float4(input.v{i}, {zeros});");
                    }
                }
                for (int i = 0; i < _outputs.Count; i++)
                    L($"    float4 o{i} = 0;");
                if (_hasDepthOutput)
                    L("    float oDepth = 0;");
            }
            else if (_shaderType == "vs")
            {
                for (int i = 0; i < _inputs.Count; i++)
                {
                    if (_inputs[i] == null) continue;
                    int n = CountSwizzle(_inputs[i]!.TrimStart('.'));
                    
                    // System value inputs are uint, need to convert
                    if (_systemValueInputs.ContainsKey(i))
                    {
                        if (n >= 4)
                            L($"    float4 v{i} = float4(input.v{i}, 0, 0, 0);");
                        else if (n == 1)
                            L($"    float4 v{i} = float4(input.v{i}, 0, 0, 0);");
                        else
                        {
                            string zeros = string.Join(", ", Enumerable.Repeat("0", 4 - n));
                            L($"    float4 v{i} = float4(input.v{i}, {zeros});");
                        }
                    }
                    else if (n >= 4)
                        L($"    float4 v{i} = float4(input.v{i});");
                    else if (n == 0)
                        L($"    float4 v{i} = 0;");
                    else
                    {
                        string zeros = string.Join(", ", Enumerable.Repeat("0", 4 - n));
                        L($"    float4 v{i} = float4(input.v{i}, {zeros});");
                    }
                }
                L("    float4 o0 = 0; // SV_Position");
                for (int i = 1; i < _outputs.Count; i++)
                    L($"    float4 o{i} = 0;");
            }
            L();
        }

        private void TranslateBody(string[] lines)
        {
            var skipRe  = new Regex(@"^(dcl_|//|#line\b|$)");
            var shaderRe = new Regex(@"^(ps|vs|gs|cs|hs|ds)_\d");

            foreach (var raw in lines)
            {
                var line = raw.Trim();
                // Strip inline comments
                line = Regex.Replace(line, @"\s*//.*$", "").Trim();
                if (string.IsNullOrEmpty(line) || skipRe.IsMatch(line) || shaderRe.IsMatch(line))
                    continue;
                TranslateInstr(line);
            }

            L();
            if (_shaderType != "cs")
            {
                if (_shaderType == "vs")
                {
                    L("    output.pos = o0;");
                    // For vertex shaders, outputs start from o1 in ASM but from o0 in struct (after pos)
                    int structIdx = 0;
                    for (int i = 1; i < _outputs.Count; i++)
                    {
                        if (_outputs[i] != null)
                        {
                            L($"    output.o{structIdx} = o{i};");
                            structIdx++;
                        }
                    }
                }
                else
                {
                    for (int i = 0; i < _outputs.Count; i++)
                    {
                        if (_outputs[i] != null)
                            L($"    output.o{i} = o{i};");
                    }
                    if (_hasDepthOutput)
                        L("    output.oDepth = oDepth;");
                }
                L("    return output;");
            }
            L("}");
        }

        private void TranslateInstr(string line)
        {
            // Split opcode from args
            var m = Regex.Match(line, @"^(\w+(?:\([^)]*\))*)\s*(.*)");
            if (!m.Success) { Emit($"// UNHANDLED: {line}"); return; }

            string op      = Regex.Replace(m.Groups[1].Value.ToLower(), @"\(.*", "");
            string argsStr = m.Groups[2].Value;
            var    args    = ParseArgs(argsStr);

            string A(int i) => i < args.Count ? RegToVar(args[i]) : "0";
            string D()      => args.Count > 0 ? RegToVar(args[0]) : "_";
            void   Assign(string expr) => Emit($"{D()} = {expr};");
            
            // Strip swizzle from UAV/groupshared for indexed access
            string StripSwizzle(string reg)
            {
                // u0.xyzw -> u0, g0.xy -> g0
                var m = Regex.Match(reg, @"^([ug]\d+)\.\w+$");
                return m.Success ? m.Groups[1].Value : reg;
            }

            switch (op)
            {
                case "ret": return;
                case "if_nz":  Emit($"if ({A(0)}) {{"); _indent++; return;
                case "if_z":   Emit($"if (!({A(0)})) {{"); _indent++; return;
                case "else":   _indent--; Emit("} else {"); _indent++; return;
                case "endif":  _indent--; Emit("}"); return;
                case "loop":   Emit("[loop] while (true) {"); _indent++; return;
                case "endloop":_indent--; Emit("}"); return;
                case "breakc_nz": Emit($"if ({A(0)}) break;"); return;
                case "breakc_z":  Emit($"if (!({A(0)})) break;"); return;
                case "break":  Emit("break;"); return;
                case "switch": Emit($"switch ((int){A(0)}) {{"); _indent++; return;
                case "endswitch": _indent--; Emit("}"); return;
                case "case":   _indent--; Emit($"case {A(0)}:"); _indent++; return;
                case "default":_indent--; Emit("default:"); _indent++; return;
                case "discard_nz": Emit($"if ({A(0)}) discard;"); return;
                case "discard_z":  Emit($"if (!({A(0)})) discard;"); return;

                case "mov":     Assign(A(1)); return;
                case "mov_sat": Assign($"saturate({A(1)})"); return;
                case "movc":    Assign($"({A(1)} != 0) ? {A(2)} : {A(3)}"); return;
                case "add":     Assign($"{A(1)} + {A(2)}"); return;
                case "mul":     Assign($"{A(1)} * {A(2)}"); return;
                case "mul_sat": Assign($"saturate({A(1)} * {A(2)})"); return;
                case "mad":     Assign($"{A(1)} * {A(2)} + {A(3)}"); return;
                case "mad_sat": Assign($"saturate({A(1)} * {A(2)} + {A(3)})"); return;
                case "div":     Assign($"{A(1)} / {A(2)}"); return;
                case "div_sat": Assign($"saturate({A(1)} / {A(2)})"); return;
                case "dp2":     Assign($"dot({A(1)}.xy, {A(2)}.xy)"); return;
                case "dp3":     Assign($"dot({A(1)}.xyz, {A(2)}.xyz)"); return;
                case "dp4":     Assign($"dot({A(1)}, {A(2)})"); return;
                case "dp3_sat": Assign($"saturate(dot({A(1)}.xyz, {A(2)}.xyz))"); return;
                case "dp2_sat": Assign($"saturate(dot({A(1)}.xy, {A(2)}.xy))"); return;
                case "sqrt":    Assign($"sqrt({A(1)})"); return;
                case "rsq":     Assign($"rsqrt({A(1)})"); return;
                case "log":     Assign($"log2({A(1)})"); return;
                case "exp":     Assign($"exp2({A(1)})"); return;
                case "abs":     Assign($"abs({A(1)})"); return;
                case "min":     Assign($"min({A(1)}, {A(2)})"); return;
                case "max":     Assign($"max({A(1)}, {A(2)})"); return;
                case "frc":     Assign($"frac({A(1)})"); return;
                case "round_ni":Assign($"floor({A(1)})"); return;
                case "round_pi":Assign($"ceil({A(1)})"); return;
                case "round_z": Assign($"trunc({A(1)})"); return;
                case "round_ne":Assign($"round({A(1)})"); return;
                case "ftou":    Assign($"(uint)({A(1)})"); return;
                case "ftoi":    Assign($"(int)({A(1)})"); return;
                case "utof":    
                case "itof":    
                {
                    // Determine vector size from destination
                    string dst = args[0];
                    int vecSize = 1;
                    if (dst.Contains("."))
                    {
                        var swizzle = dst.Split('.')[1];
                        vecSize = swizzle.Length;
                    }
                    string castType = vecSize switch
                    {
                        1 => "float",
                        2 => "float2",
                        3 => "float3",
                        4 => "float4",
                        _ => "float"
                    };
                    Assign($"({castType})({A(1)})");
                    return;
                }
                case "lt":      Assign($"(float)({A(1)} < {A(2)})"); return;
                case "ge":      Assign($"(float)({A(1)} >= {A(2)})"); return;
                case "eq":      Assign($"(float)({A(1)} == {A(2)})"); return;
                case "ne":      Assign($"(float)({A(1)} != {A(2)})"); return;
                case "and":     Assign($"asfloat(asuint({A(1)}) & asuint({A(2)}))"); return;
                case "or":      Assign($"asfloat(asuint({A(1)}) | asuint({A(2)}))"); return;
                case "iadd":    Assign($"(int)({A(1)}) + (int)({A(2)})"); return;
                case "imad":    Assign($"(int)({A(1)}) * (int)({A(2)}) + (int)({A(3)})"); return;
                case "ishl":    Assign($"asfloat(asuint({A(1)}) << (uint)({A(2)}))"); return;
                case "ushr":    Assign($"asfloat(asuint({A(1)}) >> (uint)({A(2)}))"); return;
                case "umin":    Assign($"asfloat(min(asuint({A(1)}), asuint({A(2)})))"); return;
                case "umax":    Assign($"asfloat(max(asuint({A(1)}), asuint({A(2)})))"); return;
                case "ieq":     Assign($"(float)((int)asuint({A(1)}) == (int)asuint({A(2)}))"); return;
                case "ine":     Assign($"(float)((int)asuint({A(1)}) != (int)asuint({A(2)}))"); return;
                case "ilt":     Assign($"(float)((int)asuint({A(1)}) < (int)asuint({A(2)}))"); return;
                case "ige":     Assign($"(float)((int)asuint({A(1)}) >= (int)asuint({A(2)}))"); return;
                case "ubfe":    Assign($"asfloat((asuint({A(3)}) >> (uint)({A(2)})) & ((1u << (uint)({A(1)})) - 1u))"); return;
                case "ftou_sat":Assign($"(uint)(saturate({A(1)}))"); return;

                // Integer arithmetic
                case "imul":
                    // imul dst_hi, dst_lo, src1, src2  — dst_hi is often null (_)
                    if (args.Count >= 4)
                    {
                        string dhi = RegToVar(args[0]);
                        string dlo = RegToVar(args[1]);
                        if (dhi != "_") Emit($"{dhi} = 0; // imul hi (ignored)");
                        Emit($"{dlo} = (float)((int)({A(2)}) * (int)({A(3)}));");
                    }
                    return;
                case "udiv":    Assign($"(uint)({A(2)}) / max((uint)({A(3)}), 1u)"); return;
                case "umod":    Assign($"(uint)({A(2)}) % max((uint)({A(3)}), 1u)"); return;
                case "ineg":    Assign($"-(int)({A(1)})"); return;
                case "ishr":    Assign($"asfloat((uint)((int)asuint({A(1)}) >> (int)({A(2)})))"); return;
                case "uge":     Assign($"(float)((uint)asuint({A(1)}) >= (uint)asuint({A(2)}))"); return;
                case "ult":     Assign($"(float)((uint)asuint({A(1)}) < (uint)asuint({A(2)}))"); return;

                // Bit operations
                case "not":     Assign($"asfloat(~asuint({A(1)}))"); return;
                case "xor":     Assign($"asfloat(asuint({A(1)}) ^ asuint({A(2)}))"); return;
                case "ibfe":    Assign($"asfloat((uint)(((int)asuint({A(3)}) << (32-(int)({A(1)})-(int)({A(2)}))) >> (32-(int)({A(1)}))))"); return;
                case "bfi":     Assign($"asfloat((asuint({A(4)}) & ~(((1u<<(uint)({A(0)}))-1u)<<(uint)({A(1)}))) | ((asuint({A(3)})&((1u<<(uint)({A(0)}))-1u))<<(uint)({A(1)})))"); return;
                case "countbits": Assign($"(float)countbits(asuint({A(1)}))"); return;
                case "firstbit_hi": Assign($"(float)firstbithigh(asuint({A(1)}))"); return;
                case "firstbit_lo": Assign($"(float)firstbitlow(asuint({A(1)}))"); return;
                case "firstbit_shi": Assign($"(float)firstbithigh((uint)((int)asuint({A(1)}) < 0 ? ~asuint({A(1)}) : asuint({A(1)})))"); return;
                case "bfrev":   Assign($"asfloat(reversebits(asuint({A(1)})))"); return;

                // Float misc
                case "sincos":
                    // sincos dst_sin, dst_cos, src  — either dst can be null
                    if (args.Count >= 3)
                    {
                        string dsin = RegToVar(args[0]);
                        string dcos = RegToVar(args[1]);
                        if (dsin != "_") Emit($"{dsin} = sin({A(2)});");
                        if (dcos != "_") Emit($"{dcos} = cos({A(2)});");
                    }
                    return;
                case "nop": return;
                case "add_sat": Assign($"saturate({A(1)} + {A(2)})"); return;
                case "dp4_sat": Assign($"saturate(dot({A(1)}, {A(2)}))"); return;

                // Derivatives
                case "deriv_rtx":     Assign($"ddx({A(1)})"); return;
                case "deriv_rty":     Assign($"ddy({A(1)})"); return;
                case "deriv_rtx_fine":Assign($"ddx_fine({A(1)})"); return;
                case "deriv_rty_fine":Assign($"ddy_fine({A(1)})"); return;
                case "deriv_rtx_coarse":Assign($"ddx_coarse({A(1)})"); return;
                case "deriv_rty_coarse":Assign($"ddy_coarse({A(1)})"); return;

                // Atomics (UAV)
                case "atomic_and":   Emit($"InterlockedAnd({StripSwizzle(A(0))}, asuint({A(1)}));"); return;
                case "atomic_or":    Emit($"InterlockedOr({StripSwizzle(A(0))}, asuint({A(1)}));"); return;
                case "atomic_xor":   Emit($"InterlockedXor({StripSwizzle(A(0))}, asuint({A(1)}));"); return;
                case "atomic_iadd":  Emit($"InterlockedAdd({StripSwizzle(A(0))}, (int)asuint({A(1)}));"); return;
                case "atomic_imax":  Emit($"InterlockedMax({StripSwizzle(A(0))}, (int)asuint({A(1)}));"); return;
                case "atomic_imin":  Emit($"InterlockedMin({StripSwizzle(A(0))}, (int)asuint({A(1)}));"); return;
                case "atomic_umax":  Emit($"InterlockedMax({StripSwizzle(A(0))}, asuint({A(1)}));"); return;
                case "atomic_umin":  Emit($"InterlockedMin({StripSwizzle(A(0))}, asuint({A(1)}));"); return;
                case "atomic_cmp_store": Emit($"InterlockedCompareStore({StripSwizzle(A(0))}, asuint({A(1)}), asuint({A(2)}));"); return;
                case "imm_atomic_iadd": Emit($"InterlockedAdd({StripSwizzle(A(1))}, (int)asuint({A(2)}), {A(0)});"); return;
                case "imm_atomic_alloc": Emit($"{D()} = asfloat({StripSwizzle(A(1))}.IncrementCounter());"); return;
                case "imm_atomic_consume": Emit($"{D()} = asfloat({StripSwizzle(A(1))}.DecrementCounter());"); return;

                // UAV store/load
                case "store_uav_typed":
                    {
                        string uav = StripSwizzle(A(0));
                        string idx = A(1);
                        // For buffers (u0-uN), use scalar index (.x) and cast to int
                        // For 2D textures, use int2(.xy); for 2DArray/3D, use int3(.xyz)
                        if (uav.StartsWith("u") && int.TryParse(uav.Substring(1), out int uavSlot) && _uavs.TryGetValue(uavSlot, out var uavInfo))
                        {
                            if (uavInfo.type.Contains("Buffer"))
                            {
                                idx = Regex.Replace(idx, @"\.(xy|xyz|xyzw)$", ".x");
                                idx = $"(int)({idx})";
                            }
                            else if (uavInfo.type.Contains("2DArray") || uavInfo.type.Contains("3D"))
                            {
                                if (!idx.EndsWith(".xyz")) idx += ".xyz";
                                idx = $"int3({idx})";
                            }
                            else if (uavInfo.type.Contains("2D"))
                            {
                                if (!idx.EndsWith(".xy")) idx += ".xy";
                                idx = $"int2({idx})";
                            }
                        }
                        Emit($"{uav}[{idx}] = {A(2)};");
                    }
                    return;
                case "ld_uav_typed":
                    {
                        string uav = StripSwizzle(A(2));
                        string idx = A(1);
                        if (uav.StartsWith("u") && int.TryParse(uav.Substring(1), out int uavSlot) && _uavs.TryGetValue(uavSlot, out var uavInfo))
                        {
                            if (uavInfo.type.Contains("Buffer"))
                            {
                                idx = Regex.Replace(idx, @"\.(xy|xyz|xyzw)$", ".x");
                                idx = $"(int)({idx})";
                            }
                            else if (uavInfo.type.Contains("2DArray") || uavInfo.type.Contains("3D"))
                            {
                                if (!idx.EndsWith(".xyz")) idx += ".xyz";
                                idx = $"int3({idx})";
                            }
                            else if (uavInfo.type.Contains("2D"))
                            {
                                if (!idx.EndsWith(".xy")) idx += ".xy";
                                idx = $"int2({idx})";
                            }
                        }
                        Assign($"{uav}[{idx}]");
                    }
                    return;
                case "store_raw":       Emit($"{StripSwizzle(A(0))}.Store({A(1)}, asuint({A(2)}));"); return;
                case "ld_raw":          Assign($"asfloat({StripSwizzle(A(2))}.Load({A(1)}))"); return;
                case "store_structured":
                    // Groupshared uses direct indexing: g0[idx] = value
                    // Structured buffers would use different syntax (not common for output)
                    {
                        string buf = StripSwizzle(A(0));
                        string idx = A(1);
                        // Ensure index is scalar - take .x if it's a vector
                        if (Regex.IsMatch(idx, @"\.(xy|xyz|xyzw)$"))
                            idx = Regex.Replace(idx, @"\.(xy|xyz|xyzw)$", ".x");
                        Emit($"{buf}[{idx}] = {A(3)};");
                    }
                    return;

                // Groupshared / sync
                case "sync_g_t":
                case "sync_uglobal":
                case "sync_ugroup":
                case "sync_g":          Emit("GroupMemoryBarrierWithGroupSync();"); return;
                case "sync_t":          Emit("DeviceMemoryBarrierWithGroupSync();"); return;
                case "sync":            Emit("AllMemoryBarrierWithGroupSync();"); return;

                // GS emit/cut
                case "emit":            Emit("RestartStrip();"); return;
                case "cut":             Emit("RestartStrip();"); return;
                case "emitthencut":     Emit("RestartStrip();"); return;
                case "emit_stream":     Emit($"triStream.Append(output);"); return;
                case "cut_stream":      Emit($"triStream.RestartStrip();"); return;

                // Misc
                case "resinfo":         Assign($"float4(0,0,0,0) /* resinfo {A(1)} */"); return;
                case "samplepos":       Assign($"float2(0,0) /* samplepos */"); return;
                case "eval_snapped":    Assign(A(1)); return;
                case "eval_centroid":   Assign(A(1)); return;
                case "eval_sample_index": Assign(A(1)); return;
            }

            if (op.StartsWith("sample"))    { TranslateSample(op, args); return; }
            if (op.StartsWith("gather4"))   { TranslateGather(op, args); return; }
            if (op.StartsWith("ld_struct")) { TranslateLdStructured(args); return; }
            if (op.StartsWith("ldms"))      { TranslateLdms(args); return; }
            if (op.StartsWith("ld"))        { TranslateLd(args); return; }

            Emit($"// UNHANDLED: {line}");
        }

        private void TranslateGather(string op, List<string> args)
        {
            if (args.Count < 3) { Emit($"// UNHANDLED gather: {op}"); return; }
            string dst = RegToVar(args[0]);
            string uv  = RegToVar(args[1]);
            string tex = RegToVar(args[2]).Split('.')[0];
            // gather4 samples 4 texels and returns one component from each
            // gather4_c is comparison gather
            if (op.Contains("_c"))
            {
                string cmp = args.Count > 4 ? RegToVar(args[4]) : "0.0";
                Emit($"{dst} = {tex}.GatherCmp({tex}Sampler, {uv}, {cmp});");
            }
            else
                Emit($"{dst} = {tex}.Gather({tex}Sampler, {uv});");
        }

        private void TranslateSample(string op, List<string> args)
        {
            if (args.Count < 4) { Emit($"// UNHANDLED sample: {op}"); return; }
            // DXBC sample format: sample dst, uv, tex, samp[, extra][, offset]
            string dst  = RegToVar(args[0]);
            string uv   = RegToVar(args[1]);
            string tex  = RegToVar(args[2]).Split('.')[0];
            // args[3] = sampler (same name as tex in our mapping)

            // Detect integer offset — last arg that looks like (N,N) or (N,N,N)
            string? offset = null;
            if (args.Count > 4 && Regex.IsMatch(args[^1].Trim(), @"^\(-?\d+\s*,\s*-?\d+"))
                offset = args[^1].Trim();

            string OffsetSuffix() => offset != null ? $", {offset}" : "";

            if (op.Contains("sample_l"))
            {
                // sample_l dst, uv, tex, samp, lod
                string lod = args.Count > 4 ? RegToVar(args[4]) : "0.0";
                Emit($"{dst} = {tex}.SampleLevel({tex}Sampler, {uv}, {lod}{OffsetSuffix()});");
            }
            else if (op.Contains("sample_d"))
            {
                // sample_d dst, uv, tex, samp, ddx, ddy
                string ddx_ = args.Count > 4 ? RegToVar(args[4]) : "0.0";
                string ddy_ = args.Count > 5 ? RegToVar(args[5]) : "0.0";
                Emit($"{dst} = {tex}.SampleGrad({tex}Sampler, {uv}, {ddx_}, {ddy_}{OffsetSuffix()});");
            }
            else if (op.Contains("sample_b"))
            {
                // sample_b dst, uv, tex, samp, bias
                string bias = args.Count > 4 ? RegToVar(args[4]) : "0.0";
                Emit($"{dst} = {tex}.SampleBias({tex}Sampler, {uv}, {bias}{OffsetSuffix()});");
            }
            else if (op.Contains("sample_c_lz"))
            {
                // sample_c_lz dst, uv, tex, samp, cmp
                string cmp = args.Count > 4 ? RegToVar(args[4]) : "0.0";
                // Use texture's sampler name (e.g., t7Sampler) instead of standalone s7
                string samp = $"{tex}Sampler";
                // Track comparison sampler usage
                if (args.Count > 3 && args[3].StartsWith("s"))
                {
                    var m = Regex.Match(args[3], @"s(\d+)");
                    if (m.Success) _comparisonSamplers.Add(int.Parse(m.Groups[1].Value));
                }
                Emit($"{dst} = {tex}.SampleCmpLevelZero({samp}, {uv}, {cmp}{OffsetSuffix()});");
            }
            else if (op.Contains("sample_c"))
            {
                // sample_c dst, uv, tex, samp, cmp
                string cmp = args.Count > 4 ? RegToVar(args[4]) : "0.0";
                // Use texture's sampler name (e.g., t7Sampler) instead of standalone s7
                string samp = $"{tex}Sampler";
                // Track comparison sampler usage
                if (args.Count > 3 && args[3].StartsWith("s"))
                {
                    var m = Regex.Match(args[3], @"s(\d+)");
                    if (m.Success) _comparisonSamplers.Add(int.Parse(m.Groups[1].Value));
                }
                Emit($"{dst} = {tex}.SampleCmp({samp}, {uv}, {cmp}{OffsetSuffix()});");
            }
            else
            {
                // sample dst, uv, tex, samp
                // For 2D textures, UV should be float2 (.xy), not float4 (.xyxx)
                // Strip unnecessary swizzle components
                string uvFixed = uv;
                if (uv.Contains("."))
                {
                    var parts = uv.Split('.');
                    if (parts.Length == 2 && parts[1].Length > 2)
                    {
                        // v2.xyxx -> v2.xy
                        uvFixed = $"{parts[0]}.{parts[1].Substring(0, 2)}";
                    }
                }
                Emit($"{dst} = {tex}.Sample({tex}Sampler, {uvFixed}{OffsetSuffix()});");
            }
        }

        private void TranslateLdStructured(List<string> args)
        {
            if (args.Count < 4) { Emit("// UNHANDLED ld_structured"); return; }
            string dst = RegToVar(args[0]);
            string idx = RegToVar(args[1]);
            string buf = RegToVar(args[3]).Split('.')[0];
            
            // Ensure index is scalar - take .x if it's a vector
            if (Regex.IsMatch(idx, @"\.(xy|xyz|xyzw)$"))
                idx = Regex.Replace(idx, @"\.(xy|xyz|xyzw)$", ".x");
            
            // Groupshared uses direct indexing: g0[idx]
            // Structured buffers use .Load(): t16.Load(idx)
            if (buf.StartsWith("g"))
                Emit($"{dst} = asfloat({buf}[{idx}]);");
            else
                Emit($"{dst} = asfloat({buf}.Load((uint)({idx})));");
        }

        private void TranslateLd(List<string> args)
        {
            if (args.Count < 3) { Emit("// UNHANDLED ld"); return; }
            string dst = RegToVar(args[0]);
            string uv  = RegToVar(args[1]);
            string tex = RegToVar(args[2]).Split('.')[0];
            
            // ByteAddressBuffer uses Load(int offset), not Load(int3)
            if (_rawBuffers.Contains(tex))
            {
                // Extract scalar from uv if it has swizzle
                string offset = uv;
                if (Regex.IsMatch(offset, @"\.(xy|xyz|xyzw)$"))
                    offset = Regex.Replace(offset, @"\.(xy|xyz|xyzw)$", ".x");
                Emit($"{dst} = {tex}.Load({offset});");
            }
            else
            {
                Emit($"{dst} = {tex}.Load(int3({uv}.xy, 0));");
            }
        }
        
        private void TranslateLdms(List<string> args)
        {
            // ldms dst, uv, tex, sampleIndex
            if (args.Count < 4) { Emit("// UNHANDLED ldms"); return; }
            string dst = RegToVar(args[0]);
            string uv  = RegToVar(args[1]);
            string tex = RegToVar(args[2]).Split('.')[0];
            string sampleIdx = RegToVar(args[3]);
            Emit($"{dst} = {tex}.Load(int2({uv}.xy), {sampleIdx});");
        }

        // ----------------------------------------------------------------
        private string RegToVar(string reg)
        {
            reg = reg.Trim();
            // null register — unused destination
            if (reg == "null" || reg == "_") return "_";

            bool neg  = reg.StartsWith('-');
            bool abso = reg.Contains('|');
            reg = reg.TrimStart('-').Trim('|');

            string Wrap(string s)
            {
                if (abso) s = $"abs({s})";
                if (neg)  s = $"-{s}";
                return s;
            }

            // r0.xyz, v1.xy, o0.xyzw, t0.x (indexable temp read)
            var m = Regex.Match(reg, @"^([rvot])(\d+)(\.\w+)?$");
            if (m.Success)
                return Wrap(m.Groups[1].Value + m.Groups[2].Value + m.Groups[3].Value);

            // x0[r0.x].xyzw — indexable temp
            m = Regex.Match(reg, @"^x(\d+)\[(.+?)\](\.\w+)?$");
            if (m.Success)
                return Wrap($"x{m.Groups[1].Value}[{RegToVar(m.Groups[2].Value)}]{m.Groups[3].Value}");

            // g0[N].xyz — groupshared
            m = Regex.Match(reg, @"^g(\d+)\[(.+?)\](\.\w+)?$");
            if (m.Success)
                return Wrap($"g{m.Groups[1].Value}[{RegToVar(m.Groups[2].Value)}]{m.Groups[3].Value}");

            // u0[N].xyz — UAV
            m = Regex.Match(reg, @"^u(\d+)\[(.+?)\](\.\w+)?$");
            if (m.Success)
                return Wrap($"u{m.Groups[1].Value}[{RegToVar(m.Groups[2].Value)}]{m.Groups[3].Value}");

            // cb0[5].xyz or cb0[r0.x].xyz
            m = Regex.Match(reg, @"^cb(\d+)\[(.+?)\](\.\w+)?$");
            if (m.Success)
            {
                string bufNum = m.Groups[1].Value;
                string idx = m.Groups[2].Value;
                string swizzle = m.Groups[3].Value;
                
                // Special case: cb1[0].x -> AlphaTest, cb1[0].y -> AlphaTestRef
                if (bufNum == "1" && idx == "0")
                {
                    if (swizzle == ".x")
                        return Wrap("(float)AlphaTest");
                    else if (swizzle == ".y")
                        return Wrap("AlphaTestRef.x");
                    else if (swizzle == ".z")
                        return Wrap("AlphaTestRef.y");
                    else if (swizzle == ".w")
                        return Wrap("AlphaTestRef.z");
                }
                
                // Try to translate to named variable if index is constant
                if (Regex.IsMatch(idx, @"^\d+$"))
                {
                    int slot = int.Parse(bufNum);
                    int index = int.Parse(idx);
                    return Wrap(TranslateCbufferAccess(slot, index, swizzle));
                }
                
                // Dynamic index: keep as cb0[...]
                string idxStr = RegToVar(idx);
                return Wrap($"cb{bufNum}[{idxStr}]{swizzle}");
            }

            // icb[N].xyz — immediate constant buffer
            m = Regex.Match(reg, @"^icb\[(\d+)\](\.\w+)?$");
            if (m.Success)
                return Wrap($"icb[{m.Groups[1].Value}]{m.Groups[2].Value}");

            // vThreadID.xyz, vGroupID.xyz etc. — system value registers
            m = Regex.Match(reg, @"^(vThreadID|vGroupID|vThreadGroupID|vThreadIDInGroup|vThreadIndex|vThreadIDInGroupFlattened)(\.\w+)?$");
            if (m.Success)
                return Wrap(m.Groups[1].Value + m.Groups[2].Value);

            // l(1.0, 2.0, ...) — literal
            m = Regex.Match(reg, @"^l\((.+)\)$");
            if (m.Success)
            {
                var parts = m.Groups[1].Value.Split(',');
                // Convert hex float literals like 0x3f800000
                var converted = new List<string>();
                foreach (var p in parts)
                {
                    var pt = p.Trim();
                    if (Regex.IsMatch(pt, @"^-?0x[0-9a-fA-F]+$"))
                    {
                        try
                        {
                            bool pneg = pt.StartsWith('-');
                            uint bits = Convert.ToUInt32(pt.TrimStart('-'), 16);
                            float f   = BitConverter.ToSingle(BitConverter.GetBytes(bits), 0);
                            // Use InvariantCulture to ensure dot as decimal separator
                            string formatted = f.ToString("G8", System.Globalization.CultureInfo.InvariantCulture);
                            converted.Add(pneg ? $"-{formatted}" : formatted);
                        }
                        catch { converted.Add(pt); }
                    }
                    else converted.Add(pt);
                }
                if (converted.Count == 1) return Wrap(converted[0]);
                return Wrap($"float{converted.Count}({string.Join(", ", converted)})");
            }

            return Wrap(reg);
        }

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
        
        // Translate cb0[N] to named variable access
        private string TranslateCbufferAccess(int slot, int index, string swizzle)
        {
            // If we have named variables for this cbuffer, translate to named access
            if (_constantBufferVars.TryGetValue(slot, out var vars) && vars.Count > 0)
            {
                int byteOffset = index * 16; // Each float4 is 16 bytes
                
                // Find the variable that contains this offset
                foreach (var (name, type, varOffset, varSize) in vars)
                {
                    if (byteOffset >= varOffset && byteOffset < varOffset + varSize)
                    {
                        // Calculate index within the variable
                        int relativeOffset = byteOffset - varOffset;
                        int elementIndex = relativeOffset / 16;
                        
                        // Handle different types
                        if (type.Contains("float4x4"))
                        {
                            // Matrix: access as matrix[row]
                            return $"{name}[{elementIndex}]{swizzle}";
                        }
                        else if (type == "float4" && elementIndex == 0)
                        {
                            // Single float4: direct access
                            return $"{name}{swizzle}";
                        }
                        else if (type.Contains("["))
                        {
                            // Array: access as array[index]
                            return $"{name}[{elementIndex}]{swizzle}";
                        }
                        else
                        {
                            // Fallback: direct access
                            return $"{name}{swizzle}";
                        }
                    }
                }
            }
            
            // Fallback to generic cb0[N] if no named variables
            return $"cb{slot}[{index}]{swizzle}";
        }

        private void Emit(string line) => _sb.AppendLine(new string(' ', _indent * 4) + line);
        private void L(string line = "") => _sb.AppendLine(line);
    }
}
