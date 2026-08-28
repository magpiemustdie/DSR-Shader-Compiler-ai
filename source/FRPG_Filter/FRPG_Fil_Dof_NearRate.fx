// FRPG_Fil_Dof_NearRate.fx
// Reconstructed from DSR DXBC (FRPG_Fil_Dof_NearRate.fpo).
// t1 = depth texture (s1)
// cb0[8]  = gFC_CameraParam   (x:near*far, y:far)
// cb0[10] = gFC_DofNearParam  (x:start, y:end, z:scale)
//
// Original instructions:
//   r0.x = t1.sample(uv)
//   r0.y = -cb0[8].y + cb0[8].x
//   r0.x = r0.x * r0.y + cb0[8].y
//   r0.x = cb0[8].x / r0.x               в†’ viewZ
//   r0.yz = cb0[10].xy / cb0[8].y        в†’ nearStart, nearEnd (normalized)
//   r0.x = -r0.y + r0.x                  в†’ viewZ - nearStart
//   r0.y = -r0.y + r0.z                  в†’ nearEnd - nearStart
//   r0.x = div_sat(r0.x, r0.y)           в†’ nearRate
//   o0.w = r0.x * cb0[10].z              в†’ alpha = nearRate * scale
//   o0.xyz = 0

#include "FRPG_Fil_Common.fxh"
#include "FRPG_Filter_FC_ext.fxh"

struct FIL_OUT
{
    float4 Color : SV_Target0;
};

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float depth  = gSMP_1.Sample(gSMP_1Sampler, In.UV).r;
    float range  = gFC_CameraParam.x - gFC_CameraParam.y;
    float mapped = depth * range + gFC_CameraParam.y;
    float viewZ  = gFC_CameraParam.x / mapped;

    float nearStart = gFC_DofNearParam.x / gFC_CameraParam.y;
    float nearEnd   = gFC_DofNearParam.y / gFC_CameraParam.y;
    float nearRate  = saturate((viewZ - nearStart) / (nearEnd - nearStart));

    Out.Color.rgb = 0.0f;
    Out.Color.a   = nearRate * gFC_DofNearParam.z;
    return Out;
}
