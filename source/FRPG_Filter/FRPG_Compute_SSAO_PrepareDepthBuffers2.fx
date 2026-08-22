// FRPG_Compute_SSAO_PrepareDepthBuffers2.fx
// Reconstructed from DSR DXBC cs_5_0.
// SSAO depth preparation pass 2: downsamples linearized depth from DS4x
// to DS8x/DS8xAtlas (half-res 2D/2DArray) and DS16x/DS16xAtlas (quarter-res 2D/2DArray).
// Uses interleaved addressing via bfi for cache-friendly access.
// DS4x=DS4x (linearized depth), DS8x=DS8x, DS8xAtlas=DS8xAtlas, DS16x=DS16x, DS16xAtlas=DS16xAtlas
// cb0 = InvSourceDimension (unused)

Texture2D<float>           DS4x : register(t0);
RWTexture2D<float>         DS8x : register(u0);
RWTexture2DArray<float>    DS8xAtlas : register(u1);
RWTexture2D<float>         DS16x : register(u2);
RWTexture2DArray<float>    DS16xAtlas : register(u3);

// cbuffer must be declared AFTER the resources: fxc emits
// dcl_constantbuffer cb0[1], immediateIndexed only then (0xb7 vs 0xb3)
cbuffer CB0 : register(b0) { float2 InvSourceDimension; }

[numthreads(8, 8, 1)]
void ComputeMain(
    uint3 threadID   : SV_DispatchThreadID,
    uint  groupIndex : SV_GroupIndex)
{
    // Load from DS4x at 2x stride (InvSourceDimension from CB0 is declared but unused)
    uint2 srcCoord = threadID.xy << 1u;
    float viewZ = DS4x.Load(int3(srcCoord, 0));

    // Interleaved addressing for DS8xAtlas (DS8xAtlas):
    // r1.xy = threadID.xy >> 2  (atlas tile)
    // r0.y = bfi(2, 2, threadID.y, 0)  = (threadID.y & 3) << 0 ... actually:
    // bfi(width=2, offset=2, src=threadID.y, dst=0) = insert bits[1:0] of threadID.y at offset 2
    // = (threadID.y & 3) << 2  ... wait, bfi(width, offset, src, dst):
    // result = (dst & ~(mask << offset)) | ((src & mask) << offset) where mask = (1<<width)-1
    // bfi(2, 2, threadID.y, 0) = (0 & ~(3<<2)) | ((threadID.y & 3) << 2) = (threadID.y & 3) << 2
    uint2 r1xy = threadID.xy >> 2u;
    uint  r0y  = (threadID.y & 3u) << 2u;  // bfi(2,2,threadID.y,0)
    // bfi r1.zw, l(2,2), l(0,0), threadID.x, r0.y
    // bfi(2, 0, threadID.x, r0.y) = (r0.y & ~3) | (threadID.x & 3)
    uint2 r1zw;
    r1zw.x = (r0y & ~3u) | (threadID.x & 3u);  // bfi(2,0,threadID.x,r0.y)
    r1zw.y = 0u;  // array slice

    // Store to DS8x and DS8xAtlas
    DS8x[threadID.xy] = viewZ;
    DS8xAtlas[uint3(r1xy, r1zw.x)] = viewZ;  // atlas: xy=tile, z=interleaved index

    // Quarter-res: only when (groupIndex & 9) == 0
    if ((groupIndex & 9u) == 0u)
    {
        // ASM: ushr r1.xyzw, threadID.xyyy, 1 → r1.w = threadID.y >> 1
        uint4 r1xyzw = uint4(threadID.x >> 1u, threadID.y >> 1u, threadID.y >> 1u, threadID.y >> 1u);
        uint2 r2xy = r1xyzw.xw >> 2u;  // (r1.x>>2, r1.w>>2) = (x>>3, y>>3)
        uint  r0y2 = (r1xyzw.w & 3u) << 2u;  // bfi(2,2,r1.w,0)
        uint2 r2zw;
        r2zw.x = (r0y2 & ~3u) | (r1xyzw.x & 3u);  // bfi(2,0,r1.x,r0y2)
        r2zw.y = 0u;

        DS16x[r1xyzw.xy] = viewZ;
        DS16xAtlas[uint3(r2xy, r2zw.x)] = viewZ;
    }
}
