// FRPG_Fil_Dof_DofRate.fx
// Reconstructed from DSR DXBC (FRPG_Fil_Dof_DofRate.fpo).
// t1 = depth texture (s1)
// cb0[7]  = gFC_AimBloomParam  (x:vignette start radius[pix], y:1/(end-start), z:strength)
// cb0[8]  = gFC_CameraParam    (x:near*far, y:far)
// cb0[9]  = gFC_DofFarParam    (x:start, y:end, z:scale)
// cb0[12] = gFC_ScreenSize     (xy:size[pix], zw:1/size[pix])
//
// Original instructions:
//   r0.x = t1.sample(uv)
//   r0.y = -cb0[8].y + cb0[8].x          → range = CameraParam.x - CameraParam.y
//   r0.x = r0.x * r0.y + cb0[8].y        → mapped = depth * range + CameraParam.y
//   r0.x = cb0[8].x / r0.x               → viewZ = CameraParam.x / mapped
//   r0.yz = cb0[9].xy / cb0[8].y         → farStart = DofFarParam.x/CameraParam.y, farEnd = DofFarParam.y/CameraParam.y
//   r0.x = -r0.y + r0.x                  → viewZ - farStart
//   r0.y = -r0.y + r0.z                  → farEnd - farStart
//   r0.x = div_sat(r0.x, r0.y)           → dofRate = saturate((viewZ-farStart)/(farEnd-farStart))
//   r0.x = mul_sat(r0.x, cb0[9].z)       → dofRate *= DofFarParam.z (scale)
//   r0.yz = (uv - 0.5) * ScreenSize.xy   → screen-space offset from center
//   r0.y = length(r0.yz)                 → distance from center
//   r0.y = r0.y - cb0[7].x               → dist - vignetteStart
//   r0.y = mul_sat(r0.y, cb0[7].y)       → vignette = saturate((dist-start)*invRange)
//   o0 = r0.y * cb0[7].z + r0.x          → vignette*strength + dofRate (all 4 channels)

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT
{
    float4 Color : SV_Target0;
};

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    // Sample depth from t1
    float depth = gSMP_1.Sample(gSMP_1Sampler, In.UV).r;

    // Linearize depth
    float range  = gFC_CameraParam.x - gFC_CameraParam.y;
    float mapped = depth * range + gFC_CameraParam.y;
    float viewZ  = gFC_CameraParam.x / mapped;

    // Far DoF rate
    float farStart = gFC_DofFarParam.x / gFC_CameraParam.y;
    float farEnd   = gFC_DofFarParam.y / gFC_CameraParam.y;
    float dofRate  = saturate((viewZ - farStart) / (farEnd - farStart));
    dofRate        = saturate(dofRate * gFC_DofFarParam.z);

    // Vignette from screen-space distance from center
    float2 centered = (In.UV - 0.5f) * gFC_ScreenSize.xy;
    float  dist     = length(centered);
    float  vignette = saturate((dist - gFC_AimBloomParam.x) * gFC_AimBloomParam.y);

    // Output: vignette*strength + dofRate (all channels)
    Out.Color = vignette * gFC_AimBloomParam.z + dofRate;
    return Out;
}
