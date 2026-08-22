// FRPG_Fil_ThruWithDepth.fx
// Reconstructed from DSR DXBC.
// Passthrough color + copy depth from t1.
// t0 = color (s0), t1 = depth (s1)

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT
{
    float4 Color : SV_Target0;
    float  Depth : SV_Depth;
};

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;
    Out.Color = gSMP_0.Sample(gSMP_0Sampler, In.UV);
    Out.Depth  = gSMP_1.Sample(gSMP_1Sampler, In.UV).r;
    return Out;
}
