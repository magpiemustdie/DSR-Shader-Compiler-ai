// FRPG_Fil_DownScale.fx
// Reconstructed from DSR DXBC.
// Two entry points: 2x2 (4 samples) and 4x4 (16 samples).
// Sample offsets in cb0[22..37] = gFC_avSampleOffsets0..15

#include "FRPG_Fil_Common.fxh"
#include "FRPG_Filter_FC_ext.fxh"

struct FIL_OUT
{
    float4 Color : SV_Target0;
};

// 2x2 downsample — 4 samples, weight 0.25
FIL_OUT FragmentMain_2x2(FIL_IN In)
{
    FIL_OUT Out;
    float4 acc = gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets0.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets1.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets2.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets3.xy);
    Out.Color  = acc * 0.25f;
    return Out;
}

// 4x4 downsample — 16 samples, weight 1/16
FIL_OUT FragmentMain_4x4(FIL_IN In)
{
    FIL_OUT Out;
    float4 acc = gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets0.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets1.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets2.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets3.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets4.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets5.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets6.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets7.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets8.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets9.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets10.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets11.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets12.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets13.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets14.xy);
    acc       += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets15.xy);
    Out.Color  = acc * 0.0625f;  // 1/16
    return Out;
}
