// FRPG_Fil_SAO_Depth.fx
// Reconstructed from DSR DXBC.
// SAO depth prepass: linearizes depth buffer to view-space Z.
// t0=depth buffer
// cb0[8] = CameraParam (x:near*far, y:far, z:near-far, w:near*far)

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float depth = gSMP_0.Sample(gSMP_0Sampler, In.UV).r;
    float viewZ = gFC_CameraParam.w / (depth * gFC_CameraParam.z + gFC_CameraParam.y);

    Out.Color = float4(viewZ, 1.0f, 1.0f, 1.0f);
    return Out;
}
