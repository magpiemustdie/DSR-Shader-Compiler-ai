// FRPG_Compute_SSAO_Render1.fx
// Reconstructed from DSR DXBC cs_5_0 (ref 280 instr). SSAO render pass 1.
// 8x8 thread group, gathers 16x16 depth grid into groupshared, computes
// occlusion via 18 soft-shadow sample pairs in 7 thickness layers.
//
// Ref cbuffer (RDEF):
//   cbuffer CB0 { float4 gInvThicknessTable[3]; float4 gSampleWeightTable[3];
//                 float2 gInvSliceDimension; float gRejectFadeoff;
//                 float gRcpAccentuation; float gMultiplier; }
//
// Per-thread (idx = gid.y*16+gid.x):
//   center = rcp(g0[idx+68])
//   s1..s7: scale = center*gInvThicknessTable[k].m, offset = table[k].m - 0.5
//     s1=[0].y  s2=[0].w  s3=[1].x  s4=[1].z  s5=[2].x  s6=[2].w  s7=[2].z
//   g = gRejectFadeoff (cb0[6].z)
//   pair(a,b): a' = g0[a]*s - o, satA = sat(a'*g), same for b
//     return min(max(satA, b'), 1) + min(max(a', satB), 1) - satA*satB
//   weights (acc = sum w_l * k_l * (pairs)):
//     w*0.5:  [0].y*((66,70)+(36,100) s1), [0].w*((132,4)+(64,72) s2),
//             [1].x*((53,83)+(51,85) s3),  [2].x*((38,98)+(34,102) s5),
//             [2].w*((23,113)+(17,119) s6)
//     w*0.25: [1].z*((19,117)+(21,115)+(87,49)+(55,81) s4),
//             [2].z*((134,2)+(6,130)+(104,32)+(40,96) s7)
//   ao = 1 - (1 - acc*gRcpAccentuation) * gMultiplier  (ref: mad -x, cb, 1)
//
// Gather phase: uv = (gid.xy + tid.xy - 3) * gInvSliceDimension — INT iadd l(-3,-3)
//   base = (gid.x<<1) + gid.y*32; g0[base]=w g0[base+1]=z g0[base+16]=x g0[base+17]=y
// Output addr: (tid.xy << 2) | (tid.z&3, tid.z>>2)

Texture2DArray<float>  DepthTex : register(t0);
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

groupshared float g_AO[256];

static float g_g;

float SSAOPair(float va, float vb, float sc, float off)
{
    float a = va * sc - off;
    float b = vb * sc - off;
    float sa = saturate(a * g_g);
    float sb = saturate(b * g_g);
    return min(max(sa, b), 1.0f) + min(max(a, sb), 1.0f) - sa * sb;
}

[numthreads(8, 8, 1)]
void ComputeMain(
    uint3 threadID      : SV_DispatchThreadID,
    uint3 groupThreadID : SV_GroupThreadID)
{
    int2 uvI = (int2)(groupThreadID.xy + threadID.xy) + int2(-3, -3);
    float2 uv = float2(uvI) * gInvSliceDimension;
    float4 depths = DepthTex.Gather(LinearBorderSampler, float3(uv, (float)threadID.z));

    uint2 lsBase = uint2(groupThreadID.x << 1u, groupThreadID.y * 32u);
    g_AO[lsBase.y + lsBase.x]      = depths.w;
    g_AO[lsBase.y + lsBase.x + 1u] = depths.z;
    g_AO[lsBase.y + lsBase.x + 16u] = depths.x;
    g_AO[lsBase.y + lsBase.x + 17u] = depths.y;

    GroupMemoryBarrierWithGroupSync();

    uint  idx = groupThreadID.y * 16u + groupThreadID.x;
    g_g = gRejectFadeoff;

    float center = rcp(g_AO[idx + 68u]);
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

    float p1  = SSAOPair(g_AO[idx + 66u], g_AO[idx + 70u], s1, o1);
    float p2  = SSAOPair(g_AO[idx + 36u],  g_AO[idx + 100u], s1, o1);
    float p3  = SSAOPair(g_AO[idx + 132u], g_AO[idx + 4u],   s2, o2);
    float p4  = SSAOPair(g_AO[idx + 64u],  g_AO[idx + 72u],  s2, o2);
    float p5  = SSAOPair(g_AO[idx + 53u],  g_AO[idx + 83u],  s3, o3);
    float p6  = SSAOPair(g_AO[idx + 51u],  g_AO[idx + 85u],  s3, o3);
    float p7  = SSAOPair(g_AO[idx + 38u],  g_AO[idx + 98u],  s5, o5);
    float p8  = SSAOPair(g_AO[idx + 34u],  g_AO[idx + 102u], s5, o5);
    float p9  = SSAOPair(g_AO[idx + 23u],  g_AO[idx + 113u], s6, o6);
    float p10 = SSAOPair(g_AO[idx + 17u],  g_AO[idx + 119u], s6, o6);
    float p11 = SSAOPair(g_AO[idx + 19u],  g_AO[idx + 117u], s4, o4);
    float p12 = SSAOPair(g_AO[idx + 21u],  g_AO[idx + 115u], s4, o4);
    float p13 = SSAOPair(g_AO[idx + 87u],  g_AO[idx + 49u],  s4, o4);
    float p14 = SSAOPair(g_AO[idx + 55u],  g_AO[idx + 81u],  s4, o4);
    float p15 = SSAOPair(g_AO[idx + 134u], g_AO[idx + 2u],   s7, o7);
    float p16 = SSAOPair(g_AO[idx + 6u],   g_AO[idx + 130u], s7, o7);
    float p17 = SSAOPair(g_AO[idx + 104u], g_AO[idx + 32u],  s7, o7);
    float p18 = SSAOPair(g_AO[idx + 40u],  g_AO[idx + 96u],  s7, o7);

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

    uint4 outAddr = (uint4(threadID.xyyy) << 2u)
                  | uint4(threadID.z & 3u, threadID.z >> 2u, threadID.z >> 2u, threadID.z >> 2u);
    Occlusion[uint2(outAddr.xy)] = ao;
}