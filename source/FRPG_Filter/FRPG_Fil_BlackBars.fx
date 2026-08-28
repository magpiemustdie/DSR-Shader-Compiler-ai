// FRPG_Fil_BlackBars.fx
// Reconstructed from DSR DXBC.
// Outputs black — used for letterbox bars.

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_NOUV { float4 Pos : SV_POSITION; };
struct FIL_OUT     { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_NOUV In)
{
    FIL_OUT Out;
    Out.Color = float4(0, 0, 0, 0);
    return Out;
}
