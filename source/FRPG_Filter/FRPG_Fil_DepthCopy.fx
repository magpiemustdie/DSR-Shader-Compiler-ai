// FRPG_Fil_DepthCopy.fx
// Reconstructed from DSR DXBC.
// Depth copy: samples t0 and outputs to both color and depth.
// t0=source depth texture

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT
{
    float4 Color : SV_Target0;
    float  Depth : SV_Depth;
};

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float4 s = gSMP_0.Sample(gSMP_0Sampler, In.UV);
    Out.Color = s;
    Out.Depth = s.x;
    return Out;
}
