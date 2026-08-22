// FRPG_Compute_SAO_Depth.fx
// Reconstructed from DSR DXBC cs_5_0 (fxc 6.3.9600.16384).
// SAO depth prepass (compute): linearizes depth and writes a sparse cascade
// of 6 mip levels (u0..u5). Each mipN level (size>>N) is filled by exactly
// 1/4^N of full-res pixels:
//   mip1: write iff (bit1_y != bit0_x) && (bit1_x != bit0_y) && in bounds
//         (crossed axes) and mip2 nested inside with (bit2_y != bit1_x) &&
//         (bit2_x != bit1_y)
//   mip3-5: same crossed-axes form on cur: write iff (bit1_y != bit0_x) &&
//         (bit1_x != bit0_y), only reached when the previous mip was
//         written (guard ~skip & ~f)
// else-branches set skip flags to -1; final `if (skip5) return;`
// t0=raw depth buffer, u0..u5=linearized depth mips

Texture2D<float> DepthMap : register(t0);
RWTexture2D<float> OutputTex[6] : register(u0);

cbuffer Constants : register(b0)
{
    uint2 screenSize : packoffset(c0);
    float projScale : packoffset(c0.z);
    float radius : packoffset(c0.w);
    float4 clipInfo : packoffset(c1);
    float4 projInfo : packoffset(c2);
    float bias : packoffset(c3);
    float intensity : packoffset(c3.y);
    float2 axis : packoffset(c3.z);
    uint offsets[6] : packoffset(c4);
};

[numthreads(32, 32, 1)]
void ComputeMain(uint3 threadID : SV_DispatchThreadID)
{
    uint2 coord = threadID.xy;

    float rawDepth = DepthMap.Load(int3(coord, 0));
    float viewZ = clipInfo.w / (rawDepth * clipInfo.z + clipInfo.y);

    // mip0
    if (all(coord < screenSize.xy))
        OutputTex[0][coord] = viewZ;

    // mip1
    uint2 half = coord >> 1u;
    uint2 b0 = coord & 1u;
    uint2 b1 = (coord >> 1u) & 1u;
    uint2 size1 = screenSize.xy >> 1u;
    uint2 quarter = half >> 1u;

    uint f2, skip2;
    if (!((b1.y == b0.x) || (b1.x == b0.y) || (half.x >= size1.x) || (half.y >= size1.y)))
    {
        OutputTex[1][half] = viewZ;

        // mip2 (nested)
        uint2 b2 = (coord >> 2u) & 1u;
        uint2 size2 = screenSize.xy >> 2u;
        skip2 = (uint)((b2.y == b1.x) || (b2.x == b1.y) || (quarter.x >= size2.x) || (quarter.y >= size2.y));
        if (skip2 == 0u)
            OutputTex[2][quarter] = viewZ;
        f2 = skip2;
    }
    else
    {
        skip2 = ~0u;
        f2 = ~0u;
    }

    // mip3
    uint2 cur = quarter;
    uint f3 = ~0u, skip3 = ~0u;
    if ((~skip2 & ~f2) != 0u)
    {
        uint2 oct = cur >> 1u;
        uint2 b0c = cur & 1u;
        uint2 b1c = (cur >> 1u) & 1u;
        uint2 size3 = screenSize.xy >> 3u;
        skip3 = (uint)((b1c.y == b0c.x) || (b1c.x == b0c.y) || (oct.x >= size3.x) || (oct.y >= size3.y));
        if (skip3 == 0u)
            OutputTex[3][oct] = viewZ;
        cur = oct;
        f3 = skip3;
    }
    else
    {
        skip3 = ~0u;
    }

    // mip4
    uint f4 = ~0u, skip4 = ~0u;
    if ((~skip3 & ~f3) != 0u)
    {
        uint2 sext = cur >> 1u;
        uint2 b0c = cur & 1u;
        uint2 b1c = (cur >> 1u) & 1u;
        uint2 size4 = screenSize.xy >> 4u;
        skip4 = (uint)((b1c.y == b0c.x) || (b1c.x == b0c.y) || (sext.x >= size4.x) || (sext.y >= size4.y));
        if (skip4 == 0u)
            OutputTex[4][sext] = viewZ;
        cur = sext;
        f4 = skip4;
    }
    else
    {
        skip4 = ~0u;
    }

    // mip5
    uint skip5 = ~0u;
    if ((~skip4 & ~f4) != 0u)
    {
        uint2 dbl = cur >> 1u;
        uint2 b0c = cur & 1u;
        uint2 b1c = (cur >> 1u) & 1u;
        uint2 size5 = screenSize.xy >> 5u;
        skip5 = (uint)((b1c.y == b0c.x) || (b1c.x == b0c.y) || (dbl.x >= size5.x) || (dbl.y >= size5.y));
        if (skip5 == 0u)
            OutputTex[5][dbl] = viewZ;
    }

    if (skip5 != 0u)
        return;
}