// FRPG_Fil_CameraBlurPower.fx
// Reconstructed from DSR DXBC.
// Computes camera blur power from depth.
// t0 = depth (s0)
// cb0[8] = gFC_CameraParam (y:bias, z:scale, w:key)
// Output: (key / (depth*scale + bias)) * (1/32)

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float depth = gSMP_0.Sample(gSMP_0Sampler, In.UV).r;
    float mapped = depth * gFC_CameraParam.z + gFC_CameraParam.y;
    float power  = gFC_CameraParam.w / mapped;

    Out.Color = power * 0.03125f; // 1/32
    return Out;
}
