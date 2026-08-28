// FRPG_WWS_WaterWave.fx — Water wave mask shader (WWS family).
// Reconstructed 1:1 from FRPG_WWS_Dif________________WaterWave.fpo decompile.
// Constants: full forward FC layout via FRPG_Water_FC.fxh (ref RDEF = 93 members).
// Resources: gSMP_0 (wave mask, t0), + gSMP_3 (mask map) for the Mul variant.

#include "FRPG_Water_FC.fxh"

SamplerState gSMP_0Sampler       : register(s0);
Texture2D    gSMP_0              : register(t0);

#ifdef WITH_MultiTexture
SamplerState gSMP_3Sampler       : register(s3);
Texture2D    gSMP_3              : register(t3);
#endif

struct WV_IN
{
    float4 Pos    : SV_Position0;
    float4 MulA   : COLOR0;
    float4 MulB   : COLOR1;
    float2 TexUV  : TEXCOORD7;
};

struct WV_MUL_IN
{
    float4 Pos    : SV_Position0;
    float4 MulA   : COLOR0;
    float4 MulB   : COLOR1;
    float4 TexUV  : TEXCOORD7;   // xy = wave uv, zw = mask uv
};

struct WV_OUT
{
    float4 Color : SV_Target0;
};

WV_OUT FragmentMain_WaterWave(WV_IN In)
{
    float4 s = gSMP_0.Sample(gSMP_0Sampler, In.TexUV);
    float2 tex = float2(s.x, s.w);
    tex *= gFC_DifMapMulCol.xw;
    tex *= float2(In.MulA.x, In.MulA.w);
    tex *= float2(In.MulB.x, In.MulB.w);

    WV_OUT Out;
    Out.Color.x = tex.x * tex.y;
    Out.Color.yzw = float3(1.0f, 1.0f, 1.0f);
    return Out;
}

#ifdef WITH_MultiTexture
WV_OUT FragmentMain_WaterWaveMul(WV_MUL_IN In)
{
    float4 maskSample = gSMP_3.Sample(gSMP_3Sampler, In.TexUV.zw);
    float4 waveSample = gSMP_0.Sample(gSMP_0Sampler, In.TexUV.xy);
    float2 texA = float2(maskSample.x, maskSample.w);
    float2 texB = float2(waveSample.x, waveSample.w);
    float2 tex = lerp(texB, texA, In.MulA.w);
    tex *= gFC_DifMapMulCol.xw;
    tex *= float2(In.MulA.x, In.MulA.w);
    tex *= float2(In.MulB.x, In.MulB.w);

    WV_OUT Out;
    Out.Color.x = tex.x * tex.y;
    Out.Color.yzw = float3(1.0f, 1.0f, 1.0f);
    return Out;
}
#endif
