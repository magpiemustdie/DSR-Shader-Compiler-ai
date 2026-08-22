// FRPG_FS_Sfx_Blur.fx — SFX Blur pixel shader (BlurType0-3)
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11)
// Compile: /E FragmentMain /T ps_5_0 /DBLUR_TYPE=n
//   Type0: depth copy to SV_Depth, NO cbuffer (4 instructions)
//   Type1: radial vignette, g_screen_center/g_radial_dist
//   Type2: 13-tap weighted blur, g_avSampleOffsets[16]
//   Type3: normal-based discard + 10-tap radial blur

#ifndef BLUR_TYPE
#define BLUR_TYPE 0
#endif

#if BLUR_TYPE == 0
#define SFXPBL_NO_GLOBALS
#endif
#include "FRPG_SfxPBL_Common.fxh"

#if BLUR_TYPE != 0
float4 g_blur_color          : register(c10);
float  g_radial_dist         : register(c11);
float2 g_screen_center       : register(c12);
float4 g_avSampleOffsets[16] : register(c13);
#endif

#if BLUR_TYPE == 3
Texture2D    gSMP_1 : register(t1);   // NormalSampler
SamplerState gSMP_1Sampler : register(s1);
#endif

struct BLUR_PS_IN
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD0;
#if BLUR_TYPE == 3
    float2 UV1 : TEXCOORD1;   // normal sample uv (packs into v1.zw)
#endif
};

#if BLUR_TYPE == 0
float4 FragmentMain(BLUR_PS_IN In, out float oDepth : SV_Depth) : SV_Target0
{
    float4 Out = float4(0, 0, 0, 0);
    oDepth = gSMP_0.Sample(gSMP_0Sampler, In.UV).x;
    return Out;
}
#elif BLUR_TYPE == 1
float4 FragmentMain(BLUR_PS_IN In) : SV_Target0
{
    float3 c = gSMP_0.Sample(gSMP_0Sampler, In.UV).xyz;
    float3 d = max(0.0f, c - g_screen_center.xxx);
    float3 den = g_radial_dist * 0.5f + d;
    den = den + den;
    return float4(d / den, 1.0f);
}
#elif BLUR_TYPE == 2
float4 FragmentMain(BLUR_PS_IN In) : SV_Target0
{
    float4 acc = 0.0f;
    [loop]
    for (int i = 0; i < 13; ++i)
    {
        float2 uv = g_avSampleOffsets[i].xy * g_blur_color.x + In.UV;
        acc += g_avSampleOffsets[i].z * gSMP_0.Sample(gSMP_0Sampler, uv);
    }
    return acc;
}
#else
float4 FragmentMain(BLUR_PS_IN In) : SV_Target0
{
    float n = gSMP_1.Sample(gSMP_1Sampler, In.UV1).w;
    if (ceil(n) - 1.0f < 0.0f) discard;
    float2 dir = (g_screen_center.xy - In.UV) * g_radial_dist;
    float3 acc = 0.0f;
    float2 uv = In.UV;
    [loop]
    for (int i = 0; i < 10; ++i)
    {
        acc += gSMP_0.Sample(gSMP_0Sampler, uv).xyz;
        uv += dir * 0.1f;
    }
    float3 col = g_blur_color.xyz * acc;
    col *= 0.1f;
    return float4(col, g_blur_color.w * n);
}
#endif
