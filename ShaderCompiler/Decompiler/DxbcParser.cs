using System;
using System.Collections.Generic;
using System.Text;

namespace ShaderCompiler.Decompiler
{
    /// <summary>Parses DXBC container metadata (ISGN/OSGN/RDEF/SHDR chunks).</summary>
    public class DxbcParser
    {
        public string ShaderType  { get; private set; } = "ps";
        public int    ModelMajor  { get; private set; } = 5;
        public int    ModelMinor  { get; private set; } = 0;

        public List<IoElement>       Inputs    { get; } = new();
        public List<IoElement>       Outputs   { get; } = new();
        public List<ResourceBinding> Resources { get; } = new();
        public List<CBufferInfo>     CBuffers  { get; } = new();

        private static readonly Dictionary<int, (string type, string stage)> ShaderTypeMap = new()
        {
            [0xFFFF] = ("ps", "fragment"),
            [0xFFFE] = ("vs", "vertex"),
            [0x4753] = ("gs", "geometry"),
            [0x4853] = ("hs", "hull"),
            [0x4453] = ("ds", "domain"),
            [0x4353] = ("cs", "compute"),
        };

        public bool Parse(byte[] data)
        {
            if (data.Length < 8 || data[0] != 'D' || data[1] != 'X' || data[2] != 'B' || data[3] != 'C')
                return false;

            try
            {
                int chunkCount = BitConverter.ToInt32(data, 60);
                var chunks = new Dictionary<string, (int offset, int size)>();

                for (int i = 0; i < Math.Min(chunkCount, 64); i++)
                {
                    int off  = BitConverter.ToInt32(data, 64 + i * 4);
                    if (off + 8 > data.Length) continue;
                    string fourcc = Encoding.ASCII.GetString(data, off, 4);
                    int    size   = BitConverter.ToInt32(data, off + 4);
                    if (off + 8 + size > data.Length) continue;
                    chunks[fourcc] = (off + 8, size);
                }

                foreach (var key in new[] { "SHDR", "SHEX" })
                {
                    if (chunks.TryGetValue(key, out var c))
                    {
                        int ver = BitConverter.ToUInt16(data, c.offset);
                        int typ = BitConverter.ToUInt16(data, c.offset + 2);
                        ModelMinor = ver & 0xF;
                        ModelMajor = (ver >> 4) & 0xF;
                        if (ShaderTypeMap.TryGetValue(typ, out var st))
                            ShaderType = st.type;
                        break;
                    }
                }

                if (chunks.TryGetValue("ISGN", out var isgn))
                    Inputs.AddRange(ParseSignature(data, isgn.offset));
                if (chunks.TryGetValue("OSGN", out var osgn))
                    Outputs.AddRange(ParseSignature(data, osgn.offset));
                if (chunks.TryGetValue("RDEF", out var rdef))
                    ParseRdef(data, rdef.offset, rdef.size);

                return true;
            }
            catch { return false; }
        }

        private static List<IoElement> ParseSignature(byte[] data, int base_)
        {
            var result = new List<IoElement>();
            if (base_ + 8 > data.Length) return result;
            int count = BitConverter.ToInt32(data, base_);
            for (int i = 0; i < Math.Min(count, 64); i++)
            {
                int b = base_ + 8 + i * 24;
                if (b + 24 > data.Length) break;
                int nameOff  = BitConverter.ToInt32(data, b);
                int semIdx   = BitConverter.ToInt32(data, b + 4);
                int compType = BitConverter.ToInt32(data, b + 12);
                int reg      = BitConverter.ToInt32(data, b + 16);
                int mask     = data[b + 20];

                string name = ReadCString(data, base_ + nameOff);
                string type = compType switch { 1 => "uint", 2 => "int", _ => "float" };
                result.Add(new IoElement(name, semIdx, reg, MaskToStr(mask), type));
            }
            return result;
        }

        private void ParseRdef(byte[] data, int base_, int size)
        {
            if (base_ + 32 > data.Length) return;

            // RDEF structure:
            // DX10: cbCount(4) cbOff(4) bindCount(4) bindOff(4) ...
            // DX11: cbCount(4) cbOff(4) bindCount(4) bindOff(4) + 16-byte header before
            // Try DX11 first (offset +16)
            int cbCount   = BitConverter.ToInt32(data, base_ + 16);
            int cbOff     = BitConverter.ToInt32(data, base_ + 20);
            int bindCount = BitConverter.ToInt32(data, base_ + 24);
            int bindOff   = BitConverter.ToInt32(data, base_ + 28);

            // Sanity check — if offsets are out of range, try DX10 layout
            if (cbCount > 256 || cbOff >= size || bindOff >= size)
            {
                cbCount   = BitConverter.ToInt32(data, base_);
                cbOff     = BitConverter.ToInt32(data, base_ + 4);
                bindCount = BitConverter.ToInt32(data, base_ + 8);
                bindOff   = BitConverter.ToInt32(data, base_ + 12);
            }

            // Parse cbuffers
            for (int i = 0; i < Math.Min(cbCount, 64); i++)
            {
                int b = base_ + cbOff + i * 24;
                if (b + 12 > data.Length) break;
                int nameOff  = BitConverter.ToInt32(data, b);
                int varCount = BitConverter.ToInt32(data, b + 4);
                int varOff   = BitConverter.ToInt32(data, b + 8);
                if (nameOff >= size || varCount > 256 || varOff >= size) break;
                string cbName = ReadCString(data, base_ + nameOff);
                var vars = new List<(string, int, int)>();
                for (int j = 0; j < varCount; j++)
                {
                    int vb = base_ + varOff + j * 40;
                    if (vb + 12 > data.Length) break;
                    int vnOff  = BitConverter.ToInt32(data, vb);
                    int vstart = BitConverter.ToInt32(data, vb + 4);
                    int vsize  = BitConverter.ToInt32(data, vb + 8);
                    if (vnOff >= size) break;
                    vars.Add((ReadCString(data, base_ + vnOff), vstart, vsize));
                }
                CBuffers.Add(new CBufferInfo(cbName, 0, vars));
            }

            // Parse resource bindings
            for (int i = 0; i < Math.Min(bindCount, 256); i++)
            {
                int b = base_ + bindOff + i * 32;
                if (b + 28 > data.Length) break;
                int nameOff = BitConverter.ToInt32(data, b);
                int rtype   = BitConverter.ToInt32(data, b + 4);
                int dim     = BitConverter.ToInt32(data, b + 12);
                int slot    = BitConverter.ToInt32(data, b + 20);
                if (nameOff >= size) break;

                string name    = ReadCString(data, base_ + nameOff);
                string typeStr = rtype switch { 0 => "cbuffer", 1 => "tbuffer", 2 => "texture", 3 => "sampler", 4 => "uav", _ => "res" };
                string dimStr  = dim switch { 2 => "1D", 3 => "2D", 4 => "3D", 5 => "Cube", 6 => "1DArray", 7 => "2DArray", _ => "" };
                Resources.Add(new ResourceBinding(name, typeStr, slot, dimStr));

                // Link slot to cbuffer
                if (rtype == 0)
                {
                    for (int k = 0; k < CBuffers.Count; k++)
                    {
                        if (CBuffers[k].Name == name)
                        {
                            CBuffers[k] = CBuffers[k] with { Slot = slot };
                            break;
                        }
                    }
                }
            }
        }

        private static string ReadCString(byte[] data, int offset)
        {
            if (offset < 0 || offset >= data.Length) return $"_v{offset:x}";
            int end = Array.IndexOf(data, (byte)0, offset);
            if (end < 0) end = data.Length;
            return Encoding.ASCII.GetString(data, offset, end - offset);
        }

        private static string MaskToStr(int mask)
        {
            var s = new StringBuilder();
            if ((mask & 1) != 0) s.Append('x');
            if ((mask & 2) != 0) s.Append('y');
            if ((mask & 4) != 0) s.Append('z');
            if ((mask & 8) != 0) s.Append('w');
            return s.Length > 0 ? s.ToString() : "x";
        }
    }

    public record IoElement(string Semantic, int Index, int Register, string Mask, string ComponentType);
    public record ResourceBinding(string Name, string Type, int Slot, string Dim);
    public record CBufferInfo(string Name, int Slot, List<(string name, int offset, int size)> Variables);
}
