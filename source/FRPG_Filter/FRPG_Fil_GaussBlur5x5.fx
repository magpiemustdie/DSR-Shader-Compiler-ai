// FRPG_Fil_GaussBlur5x5.fx
// Reconstructed from DSR DXBC.
// 13-tap weighted Gaussian blur.
// Sample offsets: cb0[22..34] = gFC_avSampleOffsets0..12
// Sample weights: cb0[38..50] = gFC_avSampleWeights0..12
// Center tap is offsets1/weights1 (cb0[23]/cb0[39]).

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT
{
    float4 Color : SV_Target0;
};

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float4 acc;
    acc  = gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets0.xy)  * gFC_avSampleWeights0;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets1.xy)  * gFC_avSampleWeights1;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets2.xy)  * gFC_avSampleWeights2;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets3.xy)  * gFC_avSampleWeights3;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets4.xy)  * gFC_avSampleWeights4;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets5.xy)  * gFC_avSampleWeights5;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets6.xy)  * gFC_avSampleWeights6;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets7.xy)  * gFC_avSampleWeights7;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets8.xy)  * gFC_avSampleWeights8;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets9.xy)  * gFC_avSampleWeights9;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets10.xy) * gFC_avSampleWeights10;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets11.xy) * gFC_avSampleWeights11;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets12.xy) * gFC_avSampleWeights12;

    Out.Color = acc;
    return Out;
}
