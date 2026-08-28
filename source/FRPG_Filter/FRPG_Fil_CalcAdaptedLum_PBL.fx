// FRPG_Fil_CalcAdaptedLum_PBL.fx
// Reconstructed from DSR DXBC ps_5_0.
// PBL variant of adapted luminance вЂ” no min/max clamp.
// t0=current adapted lum, t1=new measured lum
// cb0[54].x = deltaTime

#include "FRPG_Fil_Common.fxh"
#include "FRPG_Filter_FC_ext.fxh"


struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float adaptSpeed = 1.0f - exp2(-0.0291463174f * DL_FREG_054.x);

    float newLum = gSMP_1.Sample(gSMP_1Sampler, float2(0.5f, 0.5f)).r;
    float curLum = gSMP_0.Sample(gSMP_0Sampler, float2(0.5f, 0.5f)).r;
    float adapted = adaptSpeed * (newLum - curLum) + curLum;

    float isNaN = (float)(adapted != adapted);
    Out.Color.xyz = (isNaN != 0) ? 0.25f : adapted;
    Out.Color.w   = 1.0f;
    return Out;
}
