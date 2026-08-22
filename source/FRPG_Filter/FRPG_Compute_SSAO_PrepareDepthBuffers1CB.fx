// FRPG_Compute_SSAO_PrepareDepthBuffers1CB.fx
// Reconstructed from DSR DXBC cs_5_0.
// Checkerboard variant of PrepareDepthBuffers1.
// Reads from MSAA depth (Texture2DMS) with checkerboard sample index.
// Depth=MSAA depth, LinearZ=LinearZ, DS2x=DS2x, DS2xAtlas=DS2xAtlas, DS4x=DS4x, DS4xAtlas=DS4xAtlas

cbuffer CB0 : register(b0)
{
    float ZNear;
    float ZFar;
    uint  FrameIndexMod2;
}

Texture2DMS<float>         Depth : register(t0);
RWTexture2D<float>         LinearZ : register(u0);
RWTexture2D<float>         DS2x : register(u1);
RWTexture2DArray<float>    DS2xAtlas : register(u2);
RWTexture2D<float>         DS4x : register(u3);
RWTexture2DArray<float>    DS4xAtlas : register(u4);

groupshared float g0[256];

float LinearizeDepth(float depth, float r1z, float r1w, float r2x)
{
    // ASM: mad r1.y, -depth, r2.x, r1.w  → r1.w - depth*r2.x
    //      div r1.y, r1.z, r1.y           → r1.z / above
    return r1z / (r1w - depth * r2x);
}

[numthreads(8, 8, 1)]
void ComputeMain(
    uint3 vThreadGroupID          : SV_GroupID,
    uint3 vThreadIDInGroup        : SV_GroupThreadID,
    uint3 vThreadID               : SV_DispatchThreadID,
    uint  vThreadIDInGroupFlattened : SV_GroupIndex)
{
    // imad r0.yz, groupID.xy, 16, threadInGroup.xy  (note: x uses groupID.x*16, y uses groupID.y*16)
    uint2 r0yz = vThreadGroupID.xy * 16u + vThreadIDInGroup.xy;
    // imad r1.x, threadInGroup.y, 16, threadInGroup.x
    uint  r1x  = vThreadIDInGroup.y * 16u + vThreadIDInGroup.x;

    // Precompute linearization constants
    // add r1.zw, cb0[0].x, cb0[0].xy  → r1.z = ZNear+ZNear, r1.w = ZNear+ZFar
    float r1z = ZNear + ZNear;
    float r1w = ZNear + ZFar;
    // add r2.x, -cb0[0].x, cb0[0].y  → r2.x = ZFar - ZNear
    float r2x = ZFar - ZNear;

    // Pixel 0: r0.yz
    {
        uint2 pix = r0yz;
        uint  sampleIdx = (pix.x + pix.y + FrameIndexMod2) & 1u;
        uint  halfX = pix.x >> 1u;
        float depth = Depth.Load(uint2(halfX, pix.y), sampleIdx).r;
        float viewZ = LinearizeDepth(depth, r1z, r1w, r2x);
        LinearZ[pix] = viewZ;
        g0[r1x] = viewZ;
    }

    // iadd r2.yz, r1.x, l(8, 136)  → LDS indices for pixels 1 and 3
    uint r2y = r1x + 8u;
    uint r2z = r1x + 136u;

    // iadd r3.xyzw, r0.yz, l(8,0,0,8)  → pixel coords for pixels 1,2,3
    uint2 r3xy = r0yz + uint2(8, 0);   // pixel 1: +x
    uint2 r3zw = r0yz + uint2(0, 8);   // pixel 2: +y

    // Pixel 1: r3.xy (base + (8,0))
    {
        uint2 pix = r3xy;
        // iadd r4.xy, r3.yw, r3.xz  → pix.x+pix.y (for checkerboard)
        uint  sampleIdx = (pix.x + pix.y + FrameIndexMod2) & 1u;
        uint  halfX = pix.x >> 1u;
        float depth = Depth.Load(uint2(halfX, pix.y), sampleIdx).r;
        float viewZ = LinearizeDepth(depth, r1z, r1w, r2x);
        LinearZ[pix] = viewZ;
        g0[r2y] = viewZ;
    }

    // Pixel 2: r3.zw (base + (0,8)) — uses r4.y for sample index
    {
        uint2 pix = r3zw;
        uint  sampleIdx = (pix.x + pix.y + FrameIndexMod2) & 1u;
        // ASM: mov r5.xzw, r0.xxww; mov r5.y, r3.w  → halfX from r0.x (original x>>1)
        uint  halfX = r0yz.x >> 1u;  // uses original x, not pix.x
        float depth = Depth.Load(uint2(halfX, pix.y), sampleIdx).r;
        float viewZ = LinearizeDepth(depth, r1z, r1w, r2x);
        LinearZ[pix] = viewZ;
        uint lsIdx2 = r1x + 128u;
        g0[lsIdx2] = viewZ;
    }

    // Pixel 3: base + (8,8)
    {
        uint2 pix = r0yz + uint2(8, 8);
        uint  sampleIdx = (pix.x + pix.y + FrameIndexMod2) & 1u;
        uint  halfX = pix.x >> 1u;
        float depth = Depth.Load(uint2(halfX, pix.y), sampleIdx).r;
        float viewZ = LinearizeDepth(depth, r1z, r1w, r2x);
        LinearZ[pix] = viewZ;
        g0[r2z] = viewZ;
    }

    GroupMemoryBarrierWithGroupSync();

    // DS2x from LDS
    uint lsDS2x = vThreadIDInGroup.y * 32u + (vThreadIDInGroup.x << 1u);
    float zDS2x = g0[lsDS2x];

    // Store DS2x and DS2xAtlas with interleaved addressing
    uint  r0y2 = (vThreadID.y & 3u) << 2u;
    uint2 r1zw;
    r1zw.x = (r0y2 & ~3u) | (vThreadID.x & 3u);
    r1zw.y = 0u;
    uint2 r1xy2 = vThreadID.xy >> 2u;

    DS2x[vThreadID.xy] = zDS2x;
    DS2xAtlas[uint3(r1xy2, r1zw.x)] = zDS2x;

    if ((vThreadIDInGroupFlattened & 9u) == 0u)
    {
        uint2 r0yz2 = vThreadID.xy >> 1u;
        uint  r0w2  = (r0yz2.y & 3u) << 2u;
        uint2 r1zw2;
        r1zw2.x = (r0w2 & ~3u) | (r0yz2.x & 3u);
        r1zw2.y = 0u;
        uint2 r1xy3 = r0yz2 >> 2u;

        DS4x[r0yz2] = zDS2x;
        DS4xAtlas[uint3(r1xy3, r1zw2.x)] = zDS2x;
    }
}
