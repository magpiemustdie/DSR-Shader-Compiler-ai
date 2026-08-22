// FRPG_Fil_Star.fx
// Reconstructed from DSR DXBC.
// 8-tap weighted star/streak filter (same structure as GaussBlur5x5 but 8 taps).
// Sample offsets: cb0[22..29] = gFC_avSampleOffsets0..7
// Sample weights: cb0[38..45] = gFC_avSampleWeights0..7

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float4 acc;
    acc  = gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets0.xy) * gFC_avSampleWeights0;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets1.xy) * gFC_avSampleWeights1;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets2.xy) * gFC_avSampleWeights2;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets3.xy) * gFC_avSampleWeights3;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets4.xy) * gFC_avSampleWeights4;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets5.xy) * gFC_avSampleWeights5;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets6.xy) * gFC_avSampleWeights6;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets7.xy) * gFC_avSampleWeights7;

    Out.Color = acc;
    return Out;
}
