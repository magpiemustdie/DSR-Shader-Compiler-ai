// FRPG_WWS_WaterWave.fx — Water wave mask shader
// Reconstructed from FRPG_WWS_Dif________________WaterWave.fpo.hlsl

#define FC_REG(x) register(x)
#include "FRPG_Water_Common.fxh"

// gFC_DifMapMulCol from common FC (cb0[c9])
float4 gFC_DifMapMulCol : register(c9);

WV_OUT FragmentMain_WaterWave(WV_IN In)
{
    float4 s = gSMP_WaveMask.Sample(gSMP_WaveMaskSampler, In.TexUV);
    float2 tex = float2(s.x, s.w);
    tex *= gFC_DifMapMulCol.xw;
    tex *= float2(In.MulA.x, In.MulA.w);
    tex *= float2(In.MulB.x, In.MulB.w);

    WV_OUT Out;
    Out.Color.x = tex.x * tex.y;
    Out.Color.yzw = float3(1.0f, 1.0f, 1.0f);
    return Out;
}

WV_OUT FragmentMain_WaterWaveMul(WV_MUL_IN In)
{
    float4 maskSample = gSMP_MaskMap.Sample(gSMP_MaskMapSampler, In.TexUV.zw);
    float4 waveSample = gSMP_WaveMask.Sample(gSMP_WaveMaskSampler, In.TexUV.xy);
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
