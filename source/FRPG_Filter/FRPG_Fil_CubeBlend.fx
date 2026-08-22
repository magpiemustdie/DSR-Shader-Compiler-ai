// FRPG_Fil_CubeBlend.fx
// Reconstructed from DSR DXBC.
// Outputs black (stub — cube blend done elsewhere).

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_NOUV { float4 Pos : SV_Position; };
struct FIL_OUT     { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_NOUV In)
{
    FIL_OUT Out;
    Out.Color = float4(0, 0, 0, 0);
    return Out;
}
