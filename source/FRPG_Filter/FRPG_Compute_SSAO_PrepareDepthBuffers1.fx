// FRPG_Compute_SSAO_PrepareDepthBuffers1.fx
// Reconstructed from DSR DXBC cs_5_0.
// SSAO depth preparation: linearizes depth and builds mip chain.
// Depth=raw depth, LinearZ=full-res linearZ, DS2x=half-res DS2x, DS2xAtlas=DS2xAtlas,
//              DS4x=quarter-res DS4x, DS4xAtlas=DS4xAtlas
//
// cbuffer CB0: { float ZNear; float ZFar; uint FrameIndexMod2; }
// Linearization: viewZ = (ZNear + ZFar) / ((ZNear + ZFar) - depth * (ZFar - ZNear))
//
// ASM: imad r0.xy, groupID.xy, 16, groupThreadID.xy  → pixel coord = groupID*16 + threadID
//      Each thread processes 4 pixels (2x2 block at base, base+(8,0), base+(0,8), base+(8,8))
//      Stores to groupshared, then builds DS2x/DS4x via LDS reduction

cbuffer CB0 : register(b0)
{
    float ZNear;
    float ZFar;
    uint  FrameIndexMod2;
}

Texture2D<float>           Depth : register(t0);
RWTexture2D<float>         LinearZ : register(u0);
RWTexture2D<float>         DS2x : register(u1);
RWTexture2DArray<float>    DS2xAtlas : register(u2);
RWTexture2D<float>         DS4x : register(u3);
RWTexture2DArray<float>    DS4xAtlas : register(u4);

groupshared float g0[256];

float LinearizeDepth(float depth, float r1y, float r1z, float r0w)
{
    // ASM: mad r0.z, -depth, r0.w, r1.z  → r1.z - depth*r0.w = (ZNear+ZFar) - depth*(ZFar-ZNear)
    //      div r0.z, r1.y, r0.z           → (ZNear+ZNear) / above  [note: r1.y = ZNear+ZNear!]
    return r1y / (r1z - depth * r0w);
}

[numthreads(8, 8, 1)]
void ComputeMain(
    uint3 vThreadID      : SV_DispatchThreadID,
    uint3 vGroupThread   : SV_GroupThreadID,
    uint3 vGroupID       : SV_GroupID,
    uint  vGroupIndex    : SV_GroupIndex)
{
    // ASM: imad r0.xy, groupID.xy, 16, groupThreadID.xy
    uint2 base = vGroupID.xy * 16u + vGroupThread.xy;
    uint  lsIdx = vGroupThread.y * 16u + vGroupThread.x;  // imad r1.x, threadID.y, 16, threadID.x

    // ASM: add r1.yz, cb0[0].xxxx, cb0[0].xxyx  → r1.y = ZNear+ZNear, r1.z = ZFar+ZNear
    float r1y = ZNear + ZNear;
    float r1z = ZFar + ZNear;
    float r0w = ZFar - ZNear;

    // Pixel 0: base — load with Depth.yzxw swizzle (reads .y as first component)
    float d0 = Depth.Load(int3(base, 0));
    float z0 = LinearizeDepth(d0, r1y, r1z, r0w);
    LinearZ[base] = z0;
    g0[lsIdx] = z0;

    // Pixel 1: base + (8,0) — right neighbor → g0[lsIdx + 8]
    uint2 p1 = base + uint2(8, 0);
    float d1 = Depth.Load(int3(p1, 0));
    float z1 = LinearizeDepth(d1, r1y, r1z, r0w);
    LinearZ[p1] = z1;
    g0[lsIdx + 8u] = z1;

    // Pixel 2: base + (0,8) — down neighbor → g0[lsIdx + 128]
    uint2 p2 = base + uint2(0, 8);
    float d2 = Depth.Load(int3(p2, 0));
    float z2 = LinearizeDepth(d2, r1y, r1z, r0w);
    LinearZ[p2] = z2;
    g0[lsIdx + 128u] = z2;

    // Pixel 3: base + (8,8)
    uint2 p3 = base + uint2(8, 8);
    float d3 = Depth.Load(int3(p3, 0));
    float z3 = LinearizeDepth(d3, r1y, r1z, r0w);
    LinearZ[p3] = z3;
    g0[lsIdx + 136u] = z3;

    GroupMemoryBarrierWithGroupSync();

    // DS2x: read from LDS at stride 2
    // ASM: ishl r0.x, groupThreadID.x, 1; imad r0.x, groupThreadID.y, 32, r0.x
    uint lsDS2x = vGroupThread.y * 32u + (vGroupThread.x << 1u);
    float zDS2x = g0[lsDS2x];

    // Write DS2x with interleaved addressing
    // ASM: bfi r0.y, 2, 2, threadID.y, 0  → r0.y = (threadID.y & 3) << 2... simplified
    DS2x[vThreadID.xy] = zDS2x;

    // DS2xAtlas: bfi r0.y, 2, 2, threadID.y, 0; bfi r1.zw, 2, 0, threadID.x, r0.y
    uint2 atlasCoord2x = vThreadID.xy >> 2u;
    uint  r0y2 = (vThreadID.y & 3u) << 2u;
    uint  u2layer = (r0y2 & ~3u) | (vThreadID.x & 3u);
    DS2xAtlas[uint3(atlasCoord2x, u2layer)] = zDS2x;

    // DS4x: only every 9th thread (and & 9 == 0)
    if ((vGroupIndex & 9u) == 0u)
    {
        uint2 ds4xCoord = vThreadID.xy >> 1u;
        DS4x[ds4xCoord] = zDS2x;

        uint2 atlasCoord4x = ds4xCoord >> 2u;
        uint  r0y4 = (ds4xCoord.y & 3u) << 2u;
        uint  u4layer = (r0y4 & ~3u) | (ds4xCoord.x & 3u);
        DS4xAtlas[uint3(atlasCoord4x, u4layer)] = zDS2x;
    }
}
