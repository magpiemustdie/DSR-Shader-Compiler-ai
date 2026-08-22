// FRPG_Fil_Dbg_LogTex.fx
// Reconstructed from DSR DXBC.
// Debug log-space texture visualizer: exp2(sample * log2(e)) = e^sample, clamped to 1.
// Converts log-encoded texture to linear for display.
// t0=log-encoded texture

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float4 s = gSMP_0.Sample(gSMP_0Sampler, In.UV);
    // 1.442695 = log2(e), so exp2(s * log2(e)) = e^s
    float4 result = exp2(s * 1.442695f);
    Out.Color = min(result, 1.0f);
    return Out;
}
