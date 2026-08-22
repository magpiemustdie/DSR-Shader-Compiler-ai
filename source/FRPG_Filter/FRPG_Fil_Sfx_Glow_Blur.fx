// FRPG_Fil_Sfx_Glow_Blur.fx
// Reconstructed from DSR DXBC ps_5_0.
// SFX glow blur: 15-tap weighted blur.
// t0=source
// Tap order exactly as in DXBC:
//   tap0:  offset=cb0[23], weight=cb0[39]   (gFC_avSampleOffsets1, gFC_avSampleWeights1)
//   tap1:  offset=cb0[22], weight=cb0[38]   (gFC_avSampleOffsets0, gFC_avSampleWeights0)
//   tap2:  offset=cb0[24], weight=cb0[40]   (gFC_avSampleOffsets2, gFC_avSampleWeights2)
//   tap3:  offset=cb0[25], weight=cb0[41]
//   ...
//   tap14: offset=cb0[36], weight=cb0[52]   (gFC_avSampleOffsets14, gFC_avSampleWeights14)

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    // tap0: cb0[22]/cb0[38]
    float4 acc = gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets0.xy) * gFC_avSampleWeights0;
    // tap1: cb0[23]/cb0[39]
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets1.xy) * gFC_avSampleWeights1;
    // tap2..14: cb0[24..36]/cb0[40..52]
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
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets13.xy) * gFC_avSampleWeights13;
    acc += gSMP_0.Sample(gSMP_0Sampler, In.UV + gFC_avSampleOffsets14.xy) * gFC_avSampleWeights14;

    Out.Color = acc;
    return Out;
}
