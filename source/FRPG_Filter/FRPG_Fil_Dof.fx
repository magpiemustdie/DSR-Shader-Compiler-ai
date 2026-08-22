// FRPG_Fil_Dof.fx
// Reconstructed from DSR DXBC ps_5_0.
// DOF composite: blends 4 DOF layers based on DOF rate + vignette.
// Non-checkerboard variant — reads depth from t5 via Sample (not Load).
// t0=sharp, t1=near blur, t2=mid blur, t3=far blur, t4=DOF rate override, t5=depth
// cb0[7]  = AimBloomParam (x:vignette start[pix], y:1/(end-start), z:strength)
// cb0[8]  = CameraParam (x:near*far, y:far, z:unused, w:near*far)
// cb0[9]  = DofFarParam (x:start, y:end, z:scale)
// cb0[12] = ScreenSize
// cb0[66] = DOF blend range (xyzw)
// cb0[67] = DOF blend offset (xyzw)
//
// Original DXBC key sequences:
//   add r0.y, -cb0[8].y, cb0[8].x   ; r0.y = near*far - far
//   mad r0.x, r0.x, r0.y, cb0[8].y
//   div r0.x, cb0[8].x, r0.x
//   ...
//   mad_sat r0.xyzw, r0.x, cb0[66], cb0[67]
//   add r0.yzw, -r0.xxyz, r0.yyzw   ; differences BEFORE any texture sampling
//   sample t1 -> mul r1, r0.y, t1
//   sample t0 -> mad r1, t0, r0.x, r1
//   sample t2 -> mad r1, t2, r0.z, r1
//   sample t3 -> mad o0, t3, r0.w, r1

#include "FRPG_Fil_Common.fxh"

Texture2D gSMP_NearBlur : register(t1); SamplerState gSMP_NearBlurSampler : register(s1);
Texture2D gSMP_MidBlur  : register(t2); SamplerState gSMP_MidBlurSampler  : register(s2);
Texture2D gSMP_FarBlur  : register(t3); SamplerState gSMP_FarBlurSampler  : register(s3);
Texture2D gSMP_DofRate  : register(t4); SamplerState gSMP_DofRateSampler  : register(s4);
Texture2D gSMP_Depth5   : register(t5); SamplerState gSMP_Depth5Sampler   : register(s5);

float4 gFC_DofBlendRange  : register(c66);
float4 gFC_DofBlendOffset : register(c67);

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    // Sample depth from t5
    float depth = gSMP_Depth5.Sample(gSMP_Depth5Sampler, In.UV).r;

    // Linearize depth — exact DXBC:
    //   add r0.y, -cb0[8].y, cb0[8].x
    //   mad r0.x, r0.x, r0.y, cb0[8].y
    //   div r0.x, cb0[8].x, r0.x
    float r0y = gFC_CameraParam.x - gFC_CameraParam.y;
    float viewZ = gFC_CameraParam.x / (depth * r0y + gFC_CameraParam.y);

    // DOF far rate
    float dofStartN = gFC_DofFarParam.x / gFC_CameraParam.y;
    float dofEndN   = gFC_DofFarParam.y / gFC_CameraParam.y;
    float dofFar    = saturate((viewZ - dofStartN) / (dofEndN - dofStartN));
    dofFar = saturate(dofFar * gFC_DofFarParam.z);

    // Vignette
    float2 vigUV  = (In.UV - 0.5f) * gFC_ScreenSize.xy;
    float  vigDist = sqrt(dot(vigUV, vigUV));
    float  vignette = saturate((vigDist - gFC_AimBloomParam.x) * gFC_AimBloomParam.y);
    float  dofRate  = vignette * gFC_AimBloomParam.z + dofFar;

    // DOF rate override from t4 — sample t4.xwyz reads .w channel
    float dofOverride = gSMP_DofRate.Sample(gSMP_DofRateSampler, In.UV).w;
    dofRate = max(dofRate, dofOverride);

    // Map to 4 blend weights — saturate(mad_sat equivalent)
    float4 r0 = saturate(dofRate * gFC_DofBlendRange + gFC_DofBlendOffset);

    // Compute differences — DXBC: add r0.yzw, -r0.xxyz, r0.yyzw
    // Simultaneous: new_y=y-x, new_z=z-y, new_w=w-z (using OLD values)
    float3 diffs = r0.yzw - r0.xyz;
    r0.yzw = diffs;

    // Sample in original DXBC order: t1, t0, t2, t3
    float4 r1 = gSMP_NearBlur.Sample(gSMP_NearBlurSampler, In.UV);
    r1 = r1 * r0.y;
    float4 r2 = gSMP_0.Sample(gSMP_0Sampler, In.UV);
    r1 = mad(r2, r0.x, r1);
    r2 = gSMP_MidBlur.Sample(gSMP_MidBlurSampler, In.UV);
    r1 = mad(r2, r0.z, r1);
    r2 = gSMP_FarBlur.Sample(gSMP_FarBlurSampler, In.UV);
    Out.Color = mad(r2, r0.w, r1);
    return Out;
}
