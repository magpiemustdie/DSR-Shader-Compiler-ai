// FRPG_Compute_SSAO_BlurUpsampleBlendOut.fx
// Reconstructed from DSR DXBC cs_5_0 (08/17). MiniEngine AoBlurAndUpsampleCS.hlsli,
// BLEND_WITH_HIGHER_RESOLUTION variant: result = HiAO * WeightedSum / TotalWeight
// with HiAO gathered from t4 (HiResAO). Ref gather order in Phase D: t4, t0, t1.
// Textures: t0 = LoResDB, t1 = HiResDB, t2 = LoResAO1, t4 = HiResAO; u0 = AoResult; s0.
// cbuffer CB0 (b0): InvLowResolution cb0[0].xy, InvHighResolution cb0[0].zw,
//                   NoiseFilterStrength cb0[1].x, StepSize cb0[1].y,
//                   kBlurTolerance cb0[1].z, kUpsampleTolerance cb0[1].w.

Texture2D<float> LoResDB : register(t0);
Texture2D<float> HiResDB : register(t1);
Texture2D<float> LoResAO1 : register(t2);
Texture2D<float> HiResAO : register(t4);
RWTexture2D<float> AoResult : register(u0);
SamplerState LinearSampler : register(s0);

cbuffer CB0 : register(b0)
{
    float2 InvLowResolution;
    float2 InvHighResolution;
    float NoiseFilterStrength;
    float StepSize;
    float kBlurTolerance;
    float kUpsampleTolerance;
};

groupshared float DepthCache[256];
groupshared float AOCache1[256];
groupshared float AOCache2[256];

void PrefetchData(uint index, float2 uv)
{
    float4 AO1 = LoResAO1.Gather(LinearSampler, uv);

    AOCache1[index] = AO1.w;
    AOCache1[index + 1] = AO1.z;
    AOCache1[index + 16] = AO1.x;
    AOCache1[index + 17] = AO1.y;

    float4 ID = 1.0 / LoResDB.Gather(LinearSampler, uv);
    DepthCache[index] = ID.w;
    DepthCache[index + 1] = ID.z;
    DepthCache[index + 16] = ID.x;
    DepthCache[index + 17] = ID.y;
}

float SmartBlur(float a, float b, float c, float d, float e, bool Left, bool Middle, bool Right)
{
    b = Left | Middle ? b : c;
    a = Left ? a : b;
    d = Right | Middle ? d : c;
    e = Right ? e : d;
    return ((a + e) / 2.0 + b + c + d) / 4.0;
}

bool CompareDeltas(float d1, float d2, float l1, float l2)
{
    float temp = d1 * d2 + StepSize;
    return temp * temp > l1 * l2 * kBlurTolerance;
}

void BlurHorizontally(uint leftMostIndex)
{
    float a0 = AOCache1[leftMostIndex];
    float a1 = AOCache1[leftMostIndex + 1];
    float a2 = AOCache1[leftMostIndex + 2];
    float a3 = AOCache1[leftMostIndex + 3];
    float a4 = AOCache1[leftMostIndex + 4];
    float a5 = AOCache1[leftMostIndex + 5];
    float a6 = AOCache1[leftMostIndex + 6];

    float d0 = DepthCache[leftMostIndex];
    float d1 = DepthCache[leftMostIndex + 1];
    float d2 = DepthCache[leftMostIndex + 2];
    float d3 = DepthCache[leftMostIndex + 3];
    float d4 = DepthCache[leftMostIndex + 4];
    float d5 = DepthCache[leftMostIndex + 5];
    float d6 = DepthCache[leftMostIndex + 6];

    float d01 = d1 - d0;
    float d12 = d2 - d1;
    float d23 = d3 - d2;
    float d34 = d4 - d3;
    float d45 = d5 - d4;
    float d56 = d6 - d5;

    float l01 = d01 * d01 + StepSize;
    float l12 = d12 * d12 + StepSize;
    float l23 = d23 * d23 + StepSize;
    float l34 = d34 * d34 + StepSize;
    float l45 = d45 * d45 + StepSize;
    float l56 = d56 * d56 + StepSize;

    bool c02 = CompareDeltas(d01, d12, l01, l12);
    bool c13 = CompareDeltas(d12, d23, l12, l23);
    bool c24 = CompareDeltas(d23, d34, l23, l34);
    bool c35 = CompareDeltas(d34, d45, l34, l45);
    bool c46 = CompareDeltas(d45, d56, l45, l56);

    AOCache2[leftMostIndex] = SmartBlur(a0, a1, a2, a3, a4, c02, c13, c24);
    AOCache2[leftMostIndex + 1] = SmartBlur(a1, a2, a3, a4, a5, c13, c24, c35);
    AOCache2[leftMostIndex + 2] = SmartBlur(a2, a3, a4, a5, a6, c24, c35, c46);
}

void BlurVertically(uint topMostIndex)
{
    float a0 = AOCache2[topMostIndex];
    float a1 = AOCache2[topMostIndex + 16];
    float a2 = AOCache2[topMostIndex + 32];
    float a3 = AOCache2[topMostIndex + 48];
    float a4 = AOCache2[topMostIndex + 64];
    float a5 = AOCache2[topMostIndex + 80];

    float d0 = DepthCache[topMostIndex + 2];
    float d1 = DepthCache[topMostIndex + 18];
    float d2 = DepthCache[topMostIndex + 34];
    float d3 = DepthCache[topMostIndex + 50];
    float d4 = DepthCache[topMostIndex + 66];
    float d5 = DepthCache[topMostIndex + 82];

    float d01 = d1 - d0;
    float d12 = d2 - d1;
    float d23 = d3 - d2;
    float d34 = d4 - d3;
    float d45 = d5 - d4;

    float l01 = d01 * d01 + StepSize;
    float l12 = d12 * d12 + StepSize;
    float l23 = d23 * d23 + StepSize;
    float l34 = d34 * d34 + StepSize;
    float l45 = d45 * d45 + StepSize;

    bool c02 = CompareDeltas(d01, d12, l01, l12);
    bool c13 = CompareDeltas(d12, d23, l12, l23);
    bool c24 = CompareDeltas(d23, d34, l23, l34);
    bool c35 = CompareDeltas(d34, d45, l34, l45);

    float aoResult1 = SmartBlur(a0, a1, a2, a3, a4, c02, c13, c24);
    float aoResult2 = SmartBlur(a1, a2, a3, a4, a5, c13, c24, c35);

    AOCache1[topMostIndex] = aoResult1;
    AOCache1[topMostIndex + 16] = aoResult2;
}

float BilateralUpsample(float HiDepth, float HiAO, float4 LowDepths, float4 LowAO)
{
    float4 weights = float4(9, 3, 1, 3) / (abs(HiDepth - LowDepths) + kUpsampleTolerance);
    float TotalWeight = dot(weights, 1) + NoiseFilterStrength;
    float WeightedSum = dot(LowAO, weights) + NoiseFilterStrength;
    return HiAO * WeightedSum / TotalWeight;
}

[numthreads(8, 8, 1)]
void ComputeMain(
    uint3 threadID      : SV_DispatchThreadID,
    uint  groupIndex    : SV_GroupIndex,
    uint3 groupThreadID : SV_GroupThreadID)
{
    PrefetchData(groupThreadID.x << 1 | groupThreadID.y << 5,
                 int2(threadID.xy + groupThreadID.xy - 2) * InvLowResolution);
    GroupMemoryBarrierWithGroupSync();

    if (groupIndex < 39)
        BlurHorizontally((groupIndex / 3) * 16 + (groupIndex % 3) * 3);
    GroupMemoryBarrierWithGroupSync();

    if (groupIndex < 45)
        BlurVertically((groupIndex / 9) * 32 + groupIndex % 9);
    GroupMemoryBarrierWithGroupSync();

    uint Idx0 = groupThreadID.x + groupThreadID.y * 16;
    float4 LoSSAOs = float4(AOCache1[Idx0 + 16], AOCache1[Idx0 + 17], AOCache1[Idx0 + 1], AOCache1[Idx0]);

    float2 UV0 = threadID.xy * InvLowResolution;
    float2 UV1 = threadID.xy * 2 * InvHighResolution;

    float4 HiSSAOs = HiResAO.Gather(LinearSampler, UV1);
    float4 LoDepths = LoResDB.Gather(LinearSampler, UV0);
    float4 HiDepths = HiResDB.Gather(LinearSampler, UV1);

    int2 OutST = threadID.xy << 1;
    AoResult[OutST + int2(-1, 0)] = BilateralUpsample(HiDepths.x, HiSSAOs.x, LoDepths.xyzw, LoSSAOs.xyzw);
    AoResult[OutST + int2(0, 0)] = BilateralUpsample(HiDepths.y, HiSSAOs.y, LoDepths.yzwx, LoSSAOs.yzwx);
    AoResult[OutST + int2(0, -1)] = BilateralUpsample(HiDepths.z, HiSSAOs.z, LoDepths.zwxy, LoSSAOs.zwxy);
    AoResult[OutST + int2(-1, -1)] = BilateralUpsample(HiDepths.w, HiSSAOs.w, LoDepths.wxyz, LoSSAOs.wxyz);
}