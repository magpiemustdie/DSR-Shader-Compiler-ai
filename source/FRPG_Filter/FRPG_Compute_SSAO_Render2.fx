// FRPG_Compute_SSAO_Render2.fx
// Reconstructed from DSR DXBC cs_5_0 (ref 275 instr, 08/17 — full reconstruction).
// SSAO render pass 2 (16x16 thread group), same algorithm as Render1 but with
// 1024-entry groupshared grid and different sample index set.
//
// Ref cbuffer (RDEF):
//   cbuffer CB0 { float4 gInvThicknessTable[3]; float4 gSampleWeightTable[3];
//                 float2 gInvSliceDimension; float gRejectFadeoff;
//                 float gRcpAccentuation; float gMultiplier; }
//
// Per-thread (idx = gid.y*32 + gid.x):
//   center = rcp(g0[idx+264])
//   s1..s7 / o1..o7 — same thickness sets as Render1:
//     s1=[0].y s2=[0].w s3=[1].x s4=[1].z s5=[2].x s6=[2].w s7=[2].z
//   pair(a,b,set) = min(max(satA', b'),1) + min(max(a', satB'),1) - satA'*satB'
//   weights (acc = sum w_l * k_l * (pairs)):
//     w*0.5:  [0].y*((260,268)+(136,392) s1), [0].w*((520,8)+(256,272) s2),
//             [1].x*((202,326)+(198,330) s3), [2].x*((140,388)+(132,396) s5),
//             [2].w*((78,450)+(66,462) s6)
//     w*0.25: [1].z*((70,458)+(74,454)+(334,194)+(206,322) s4),
//             [2].z*((524,4)+(12,516)+(400,128)+(144,384) s7)
//   ao = 1 - (1 - acc*gRcpAccentuation) * gMultiplier
//
// Gather: uv = (gid.xy + tid.xy - 7) * gInvSliceDimension — INT iadd l(-7,-7)
//   base = (gid.x<<1) + gid.y*64; g0[base]=w g0[base+1]=z g0[base+32]=x g0[base+33]=y
// Output: u0[tid.xy] directly (no address shift, unlike Render1).

Texture2D<float>       DepthTex : register(t0);
SamplerState           LinearBorderSampler : register(s1);
RWTexture2D<float>     Occlusion : register(u0);

cbuffer CB0 : register(b0)
{
    float4 gInvThicknessTable[3];
    float4 gSampleWeightTable[3];
    float2 gInvSliceDimension;
    float  gRejectFadeoff;
    float  gRcpAccentuation;
    float  gMultiplier;
};

groupshared float g_AO[1024];

static float g_g;

float SSAOPair(float va, float vb, float sc, float off)
{
    float a = va * sc - off;
    float b = vb * sc - off;
    float sa = saturate(a * g_g);
    float sb = saturate(b * g_g);
    return min(max(sa, b), 1.0f) + min(max(a, sb), 1.0f) - sa * sb;
}

[numthreads(16, 16, 1)]
void ComputeMain(
    uint3 threadID      : SV_DispatchThreadID,
    uint3 groupThreadID : SV_GroupThreadID)
{
    int2 uvI = (int2)(groupThreadID.xy + threadID.xy) + int2(-7, -7);
    float2 uv = float2(uvI) * gInvSliceDimension;
    float4 depths = DepthTex.Gather(LinearBorderSampler, uv);

    uint2 lsBase = uint2(groupThreadID.x << 1u, groupThreadID.y * 64u);
    g_AO[lsBase.y + lsBase.x]      = depths.w;
    g_AO[lsBase.y + lsBase.x + 1u] = depths.z;
    g_AO[lsBase.y + lsBase.x + 32u] = depths.x;
    g_AO[lsBase.y + lsBase.x + 33u] = depths.y;

    GroupMemoryBarrierWithGroupSync();

    uint  idx = groupThreadID.y * 32u + groupThreadID.x;
    g_g = gRejectFadeoff;

    float center = rcp(g_AO[idx + 264u]);
    float s1 = center * gInvThicknessTable[0].y;
    float s2 = center * gInvThicknessTable[0].w;
    float s3 = center * gInvThicknessTable[1].x;
    float s4 = center * gInvThicknessTable[1].z;
    float s5 = center * gInvThicknessTable[2].x;
    float s6 = center * gInvThicknessTable[2].w;
    float s7 = center * gInvThicknessTable[2].z;
    float o1 = gInvThicknessTable[0].y - 0.5f;
    float o2 = gInvThicknessTable[0].w - 0.5f;
    float o3 = gInvThicknessTable[1].x - 0.5f;
    float o4 = gInvThicknessTable[1].z - 0.5f;
    float o5 = gInvThicknessTable[2].x - 0.5f;
    float o6 = gInvThicknessTable[2].w - 0.5f;
    float o7 = gInvThicknessTable[2].z - 0.5f;

    float p1  = SSAOPair(g_AO[idx + 260u], g_AO[idx + 268u], s1, o1);
    float p2  = SSAOPair(g_AO[idx + 136u], g_AO[idx + 392u], s1, o1);
    float p3  = SSAOPair(g_AO[idx + 520u], g_AO[idx + 8u],   s2, o2);
    float p4  = SSAOPair(g_AO[idx + 256u], g_AO[idx + 272u], s2, o2);
    float p5  = SSAOPair(g_AO[idx + 202u], g_AO[idx + 326u], s3, o3);
    float p6  = SSAOPair(g_AO[idx + 198u], g_AO[idx + 330u], s3, o3);
    float p7  = SSAOPair(g_AO[idx + 140u], g_AO[idx + 388u], s5, o5);
    float p8  = SSAOPair(g_AO[idx + 132u], g_AO[idx + 396u], s5, o5);
    float p9  = SSAOPair(g_AO[idx + 78u],  g_AO[idx + 450u], s6, o6);
    float p10 = SSAOPair(g_AO[idx + 66u],  g_AO[idx + 462u], s6, o6);
    float p11 = SSAOPair(g_AO[idx + 70u],  g_AO[idx + 458u], s4, o4);
    float p12 = SSAOPair(g_AO[idx + 74u],  g_AO[idx + 454u], s4, o4);
    float p13 = SSAOPair(g_AO[idx + 334u], g_AO[idx + 194u], s4, o4);
    float p14 = SSAOPair(g_AO[idx + 206u], g_AO[idx + 322u], s4, o4);
    float p15 = SSAOPair(g_AO[idx + 524u], g_AO[idx + 4u],   s7, o7);
    float p16 = SSAOPair(g_AO[idx + 12u],  g_AO[idx + 516u], s7, o7);
    float p17 = SSAOPair(g_AO[idx + 400u], g_AO[idx + 128u], s7, o7);
    float p18 = SSAOPair(g_AO[idx + 144u], g_AO[idx + 384u], s7, o7);

    float t1 = 0.5f * (p1 + p2);
    float t2 = 0.5f * (p3 + p4);
    float t3 = 0.5f * (p5 + p6);
    float t4 = 0.5f * (p7 + p8);
    float t5 = 0.5f * (p9 + p10);
    float t6 = 0.25f * (p11 + p12 + p13 + p14);
    float t7 = 0.25f * (p15 + p16 + p17 + p18);

    float acc = gSampleWeightTable[0].y * t1
              + gSampleWeightTable[0].w * t2
              + gSampleWeightTable[1].x * t3
              + gSampleWeightTable[2].x * t4
              + gSampleWeightTable[2].w * t5
              + gSampleWeightTable[1].z * t6
              + gSampleWeightTable[2].z * t7;

    float ao = 1.0f - acc * gRcpAccentuation;
    ao = 1.0f - ao * gMultiplier;

    Occlusion[threadID.xy] = ao;
}