// FRPG_Fil_ShadowMapDbg.fx
// Reconstructed from DSR DXBC.
// Shadow map debug visualizer: samples t1 (shadow map) with a small offset,
// outputs .zxy swizzle (depth in red channel).
// t1=shadow map

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float2 uv = In.UV + float2(0.00026041668f, 0.000462962955f);
    float4 s  = gSMP_1.Sample(gSMP_1Sampler, uv);

    // DXBC: sample t1.xywz → r0=(t.x,t.y,t.w,t.z), then o0.xyz = r0.zxy = (t.w, t.x, t.y)
    Out.Color = float4(s.w, s.x, s.y, 1.0f);
    return Out;
}
