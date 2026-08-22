// FRPG_Fil_CalcAdaptedLum.fx
// Reconstructed from DSR DXBC ps_5_0.
// Adapts luminance over time using exponential smoothing.
// t0=current adapted lum, t1=new measured lum
// cb0[54] = (deltaTime, minLum, maxLum, keyValue)

#include "FRPG_Fil_Common.fxh"

float4 gFC_AdaptParam2 : register(c54); // x:deltaTime, y:minLum, z:maxLum, w:keyValue

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float adaptSpeed = 1.0f - exp2(-0.0291463174f * gFC_AdaptParam2.x);

    float newLum = gSMP_1.Sample(gSMP_1Sampler, float2(0.5f, 0.5f)).r;
    // min first, then max — matches ASM order
    newLum = min(newLum, gFC_AdaptParam2.z);
    newLum = max(newLum, gFC_AdaptParam2.y);
    newLum = newLum + 0.001f;
    newLum = gFC_AdaptParam2.w / newLum;

    float curLum = gSMP_0.Sample(gSMP_0Sampler, float2(0.5f, 0.5f)).r;
    float adapted = adaptSpeed * (newLum - curLum) + curLum;

    Out.Color.xyz = adapted;
    Out.Color.w   = 1.0f;
    return Out;
}
