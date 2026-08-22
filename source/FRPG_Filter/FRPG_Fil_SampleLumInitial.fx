// FRPG_Fil_SampleLumInitial.fx
// Reconstructed from DSR DXBC ps_5_0.
// 9-tap log-luminance downsample for HDR adaptation.
// t0=HDR scene, cb0[22..30]=sample offsets, cb0[56].zw=scale factors
// Per tap: rgb * scale.z * scale.w → lum → log2(lum)*ln(2) → accumulate
// Output: sum * (1/9) in xyz, w=1

#include "FRPG_Fil_Common.fxh"

float4 gFC_PostEffectScale2 : register(c56); // z:bloom scale, w:exposure scale

static const float3 kLumWeights = float3(0.2125f, 0.7154f, 0.0721f);

struct FIL_OUT { float4 Color : SV_Target0; };

float SampleLogLum(float2 uv)
{
    float3 c = gSMP_0.Sample(gSMP_0Sampler, uv).rgb;
    c *= gFC_PostEffectScale2.z;
    c *= gFC_PostEffectScale2.w;
    float lum = max(dot(c, kLumWeights), 0.0001f);
    return log2(lum) * 0.693147182f;
}

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    // DXBC tap order: cb0[23] first, then cb0[22], then cb0[24..30]
    float acc = 0.0f;
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets1.xy);  // cb0[23]
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets0.xy);  // cb0[22]
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets2.xy);  // cb0[24]
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets3.xy);  // cb0[25]
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets4.xy);  // cb0[26]
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets5.xy);  // cb0[27]
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets6.xy);  // cb0[28]
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets7.xy);  // cb0[29]
    acc += SampleLogLum(In.UV + gFC_avSampleOffsets8.xy);  // cb0[30]

    Out.Color.xyz = acc * 0.111111112f; // 1/9
    Out.Color.w   = 1.0f;
    return Out;
}
