// FRPG_Compute_SAO_Blur.fx
// Reconstructed from DSR DXBC cs_5_0.
// SAO bilateral blur (compute): 9-tap depth-aware blur of AO value.
// t0=SAO result (xyz=AO+packed depth), u0=blurred AO
// cb0[0].xy = (width, height)
// cb0[3].zw = blur step (pixel offset per tap)

Texture2D<float3>    InputTex : register(t0);
RWTexture2D<float3>  OutputTex : register(u0);

cbuffer Constants : register(b0)
{
    float4 cb0_0;  // xy=size
    float4 cb0_1;
    float4 cb0_2;
    float4 cb0_3;  // zw=step
}

float DecodeDepth_CS(float2 enc)
{
    return dot(enc, float2(0.996108949f, 0.00389105058f));
}

float BilateralWeight(float centerDepth, float sDepth)
{
    float diff = centerDepth - sDepth;
    return max(1.0f - abs(diff) * 2000.0f, 0.0f);
}

[numthreads(32, 32, 1)]
void ComputeMain(
    uint3 groupID       : SV_GroupID,
    uint3 groupThreadID : SV_GroupThreadID)
{
    // imad r0.xy, vThreadGroupID, 32, vThreadIDInGroup
    uint2 coord = groupID.xy * 32u + groupThreadID.xy;

    // Bounds check: uge r1.xy, coord, cb0[0].xy
    if (coord.x >= (uint)cb0_0.x || coord.y >= (uint)cb0_0.y) return;

    float2 fcoord = float2(coord);
    float2 step   = cb0_3.zw;

    // Load center
    float3 center = InputTex.Load(int3(coord, 0)).xyz;
    float  cDepth = DecodeDepth_CS(center.yz);

    // Tap at -8 and -6 (packed: mad step*(-8,-8,-6,-6) + fcoord.xyxy)
    float4 uv46 = step.xyxy * float4(-8,-8,-6,-6) + fcoord.xyxy;
    int2   sc8n = (int2)uv46.xy;  // -8 tap
    int2   sc6n = (int2)uv46.zw;  // -6 tap

    float3 s8n = InputTex.Load(int3(sc8n, 0)).xyz;
    float  w8n = BilateralWeight(cDepth, DecodeDepth_CS(s8n.yz));
    float  aoAcc  = s8n.x * (w8n * 0.362970f) + center.x * 0.153170f;
    float  wTotal = w8n * 0.362970f + 0.153170f;

    float3 s6n = InputTex.Load(int3(sc6n, 0)).xyz;
    float  w6n = BilateralWeight(cDepth, DecodeDepth_CS(s6n.yz));
    aoAcc  += s6n.x * (w6n * 0.392902017f);
    wTotal += w6n * 0.392902017f;

    // Tap at -4 and -2
    float4 uv24 = step.xyxy * float4(-4,-4,-2,-2) + fcoord.xyxy;
    int2   sc4n = (int2)uv24.xy;
    int2   sc2n = (int2)uv24.zw;

    float3 s4n = InputTex.Load(int3(sc4n, 0)).xyz;
    float  w4n = BilateralWeight(cDepth, DecodeDepth_CS(s4n.yz));
    aoAcc  += s4n.x * (w4n * 0.422649026f);
    wTotal += w4n * 0.422649026f;

    float3 s2n = InputTex.Load(int3(sc2n, 0)).xyz;
    float  w2n = BilateralWeight(cDepth, DecodeDepth_CS(s2n.yz));
    aoAcc  += s2n.x * (w2n * 0.444893f);
    wTotal += w2n * 0.444893f;

    // Tap at +2
    int2   sc2p = (int2)(step * 2.0f + fcoord);
    float3 s2p = InputTex.Load(int3(sc2p, 0)).xyz;
    float  w2p = BilateralWeight(cDepth, DecodeDepth_CS(s2p.yz));
    aoAcc  += s2p.x * (w2p * 0.444893f);
    wTotal += w2p * 0.444893f;

    // Tap at +4 and +6
    float4 uv46p = step.xyxy * float4(4,4,6,6) + fcoord.xyxy;
    int2   sc4p = (int2)uv46p.xy;
    int2   sc6p = (int2)uv46p.zw;

    float3 s4p = InputTex.Load(int3(sc4p, 0)).xyz;
    float  w4p = BilateralWeight(cDepth, DecodeDepth_CS(s4p.yz));
    aoAcc  += s4p.x * (w4p * 0.422649026f);
    wTotal += w4p * 0.422649026f;

    float3 s6p = InputTex.Load(int3(sc6p, 0)).xyz;
    float  w6p = BilateralWeight(cDepth, DecodeDepth_CS(s6p.yz));
    aoAcc  += s6p.x * (w6p * 0.392902017f);
    wTotal += w6p * 0.392902017f;

    // Tap at +8
    int2   sc8p = (int2)(step * 8.0f + fcoord);
    float3 s8p = InputTex.Load(int3(sc8p, 0)).xyz;
    float  w8p = BilateralWeight(cDepth, DecodeDepth_CS(s8p.yz));
    aoAcc  += s8p.x * (w8p * 0.362970f);
    wTotal += w8p * 0.362970f;

    float ao = aoAcc / (wTotal + 0.0001f);
    OutputTex[coord] = float3(ao, center.yz);
}
