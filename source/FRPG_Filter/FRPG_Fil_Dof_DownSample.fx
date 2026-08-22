// FRPG_Fil_Dof_DownSample.fx
// Reconstructed from DSR DXBC.
// Simple passthrough downsample — just samples t0 at UV.

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT
{
    float4 Color : SV_Target0;
};

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;
    Out.Color = gSMP_0.Sample(gSMP_0Sampler, In.UV);
    return Out;
}
