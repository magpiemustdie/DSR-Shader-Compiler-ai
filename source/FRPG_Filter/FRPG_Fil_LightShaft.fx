// FRPG_Fil_LightShaft.fx
// Reconstructed from DSR DXBC ps_5_0.
// Radial blur toward screen-space light position (10 samples).
// t0=scene(s0)
// cb0[12]=ScreenSize, cb0[69]=ScreenLightPos, cb0[70]=LightShaftParam

#include "FRPG_Fil_Common.fxh"

float4 gFC_ScreenLightPos2  : register(c69); // xy:light UV
float4 gFC_LightShaftParam2 : register(c70); // x:max length, y:color scale, z:decay

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float2 dir = (In.UV - gFC_ScreenLightPos2.xy) * gFC_ScreenSize.xy;
    float  len = max(length(dir), 0.0001f);
    float  clampedLen = min(len, gFC_LightShaftParam2.x);
    dir = (clampedLen / len) * dir * gFC_ScreenSize.zw;

    float2 uv  = In.UV;
    float4 acc = float4(0, 0, 0, 1);
    [loop]
    for (int i = 0; i < 10; i++)
    {
        float3 s = gSMP_0.Sample(gSMP_0Sampler, uv).rgb;
        acc.xyz += s * acc.w;
        uv      -= dir * 0.1f;
        acc.w   *= gFC_LightShaftParam2.z;
    }
    Out.Color.xyz = acc.xyz * gFC_LightShaftParam2.y;
    Out.Color.w   = 1.0f;
    return Out;
}
