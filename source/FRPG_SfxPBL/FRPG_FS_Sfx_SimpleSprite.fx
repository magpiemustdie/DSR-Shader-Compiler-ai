// FRPG_FS_Sfx_SimpleSprite.fx вЂ” SFX SimpleSprite pixel shaders (SimpleSpriteType0-8)
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11)
// Compile: /E FragmentMain /T ps_5_0 /DSIMPLE_SPRITE_TYPE=0..8
//
// Feature matrix:
//   Type0: multi-tex (t0 x2, blend TEXCOORD4)                  вЂ” fog c4, rim c7
//   Type1: multi-tex + light (t1 normal, c1/c2/c3)             вЂ” fog/rim
//   Type2: multi-tex + depth fade (t2, screen-proj, c0/c32)    вЂ” fog/rim
//   Type3: multi-tex + light + depth                           вЂ” fog/rim
//   Type4: single texture (no blend)                           вЂ” fog/rim
//   Type5: tex pair (t1 x t3)                                  вЂ” fog/rim
//   Type6: tex pair + depth                                    вЂ” fog/rim
//   Type7: t1 only (no t3)                                     вЂ” fog/rim
//   Type8: t1 only + depth                                     вЂ” fog/rim

#ifndef SIMPLE_SPRITE_TYPE
#define SIMPLE_SPRITE_TYPE 0
#endif
#define SFXPBL_HAS_ALPHATEST
#define SFXPBL_C4_IS_DL_FREG_004
#include "FRPG_SfxPBL_Common.fxh"

// Slot 1..3 resource names vary per type in the reference:
//   t1: NormalSampler (1,3) | MultiAlphaSampler0 (5-8)
//   t2: DepthTexSampler (2,3,6,8)
//   t3: MultiAlphaSampler1 (5,6)
#if SIMPLE_SPRITE_TYPE == 1 || SIMPLE_SPRITE_TYPE == 3
Texture2D    NormalSampler        : register(t1);
SamplerState NormalSamplerSampler : register(s1);
#define gSMP_1        NormalSampler
#define gSMP_1Sampler NormalSamplerSampler
#elif SIMPLE_SPRITE_TYPE >= 5
Texture2D    MultiAlphaSampler0        : register(t1);
SamplerState MultiAlphaSampler0Sampler : register(s1);
#define gSMP_1        MultiAlphaSampler0
#define gSMP_1Sampler MultiAlphaSampler0Sampler
#endif
#if SIMPLE_SPRITE_TYPE == 2 || SIMPLE_SPRITE_TYPE == 3 || SIMPLE_SPRITE_TYPE == 6 || SIMPLE_SPRITE_TYPE == 8
Texture2D    DepthTexSampler        : register(t2);
SamplerState DepthTexSamplerSampler : register(s2);
#define gSMP_2        DepthTexSampler
#define gSMP_2Sampler DepthTexSamplerSampler
#endif
#if SIMPLE_SPRITE_TYPE == 5 || SIMPLE_SPRITE_TYPE == 6
Texture2D    MultiAlphaSampler1        : register(t3);
SamplerState MultiAlphaSampler1Sampler : register(s3);
#define gSMP_3        MultiAlphaSampler1
#define gSMP_3Sampler MultiAlphaSampler1Sampler
#endif

// Shared tail: fog + alpha + rim + gamma + alpha test + tone
float4 SfxSpriteTail(float4 dif, float2 fog, float3 rim1, float3 rim2, float4 rimUV)
{
    float3 fogged = lerp(abs(dif.xyz), g_fog_color.xyz, g_fog_color.w * fog.y);
    float alpha = dif.w * (1.0f - fog.x * g_fog_color.w);
    float3 rimA = fogged.xyz * rim1 + rim2;
    float4 Out = mad(DL_FREG_7.x, float4(rimA - fogged.xyz, 0.0f), float4(fogged, alpha));
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    Out.xyz = pow(abs(Out.xyz), 2.2f);
    return SfxToneMap(Out);
}

#if SIMPLE_SPRITE_TYPE == 0
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;    // xy = uv0, zw = fog
    float4 Tint : TEXCOORD1;
    float4 Rim1 : TEXCOORD2;    // xyz = rim1, w = uv1.x
    float4 Rim2 : TEXCOORD3;    // xyz = rim2, w = uv1.y
    float  Blend : TEXCOORD4;
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 dif0 = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy);
    float4 dif1 = gSMP_0.Sample(gSMP_0Sampler, float2(In.Rim1.w, In.Rim2.w));
    float4 dif = lerp(dif0, dif1, In.Blend) * In.Tint;
    return SfxSpriteTail(dif, In.Tex0.zw, In.Rim1.xyz, In.Rim2.xyz, 0.0f);
}

#elif SIMPLE_SPRITE_TYPE == 1
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 LightDir : TEXCOORD0;    // xyz = light dir, w = blend
    float3 Normal : TEXCOORD1;
    float4 TexUV : TEXCOORD2;       // xy = uv0, zw = fog
    float4 Tint : TEXCOORD3;
    float2 Ramp : TEXCOORD4;
    float4 Rim1 : TEXCOORD5;        // xyz = rim1, w = uv1.x
    float4 Rim2 : TEXCOORD6;        // xyz = rim2, w = uv1.y
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 dif0 = gSMP_0.Sample(gSMP_0Sampler, In.TexUV.xy);
    float4 dif1 = gSMP_0.Sample(gSMP_0Sampler, float2(In.Rim1.w, In.Rim2.w));
    float4 dif = lerp(dif0, dif1, In.LightDir.w) * In.Tint;
    float3 lin = pow(abs(dif.xyz), 2.2f);
    float3 n = 2.0f * gSMP_1.Sample(gSMP_1Sampler, In.TexUV.xy).xyz - 1.0f;
    float3 lightA = (dot(n, In.Normal) + 1.0f) * DL_FREG_002.xyz + DL_FREG_003.xyz;
    float ramp = saturate(dot(In.LightDir.xyz, n) * In.Ramp.y + In.Ramp.x);
    float3 lit = pow(abs(lin * (DL_FREG_001.xyz * ramp + lightA)), 1.0f / 2.2f);
    float3 fogged = lerp(lit, g_fog_color.xyz, g_fog_color.w * In.TexUV.w);
    float alpha = dif.w * (1.0f - In.TexUV.z * g_fog_color.w);
    float3 rimA = fogged.xyz * In.Rim1.xyz + In.Rim2.xyz;
    float4 Out = mad(DL_FREG_7.x, float4(rimA - fogged.xyz, 0.0f), float4(fogged, alpha));
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    Out.xyz = pow(abs(Out.xyz), 2.2f);
    return SfxToneMap(Out);
}

#elif SIMPLE_SPRITE_TYPE == 2
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;    // xy = uv0, zw = fog
    float4 Tint : TEXCOORD1;
    float4 Depth : TEXCOORD2;   // z = particle depth, w = fade max
    float4 Rim1 : TEXCOORD3;    // xyz = rim1, w = uv1.x
    float4 Rim2 : TEXCOORD4;    // xyz = rim2, w = uv1.y
    float  Blend : TEXCOORD5;
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 dif0 = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy);
    float4 dif1 = gSMP_0.Sample(gSMP_0Sampler, float2(In.Rim1.w, In.Rim2.w));
    float4 dif = lerp(dif0, dif1, In.Blend) * In.Tint;
    float d = gSMP_2.Sample(gSMP_2Sampler, In.Pos.xy * gFC_ScreenSize.zw).x;
    d = d * DL_FREG_000.y - DL_FREG_000.z;
    d = -DL_FREG_000.x / d;
    dif.w *= min(d - In.Depth.z, In.Depth.w);
    return SfxSpriteTail(dif, In.Tex0.zw, In.Rim1.xyz, In.Rim2.xyz, 0.0f);
}

#elif SIMPLE_SPRITE_TYPE == 3
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 LightDir : TEXCOORD0;    // xyz = light dir, w = blend
    float3 Normal : TEXCOORD1;
    float4 TexUV : TEXCOORD2;       // xy = uv0, zw = fog
    float4 Tint : TEXCOORD3;
    float4 RampFade : TEXCOORD4;    // xy = ramp, zw = depth fade
    float3 Depth : TEXCOORD5;       // z = particle depth
    float4 Rim1 : TEXCOORD6;        // xyz = rim1, w = uv1.x
    float4 Rim2 : TEXCOORD7;        // xyz = rim2, w = uv1.y
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 dif0 = gSMP_0.Sample(gSMP_0Sampler, In.TexUV.xy);
    float4 dif1 = gSMP_0.Sample(gSMP_0Sampler, float2(In.Rim1.w, In.Rim2.w));
    float4 dif = lerp(dif0, dif1, In.LightDir.w) * In.Tint;
    float3 lin = pow(abs(dif.xyz), 2.2f);
    float d = gSMP_2.Sample(gSMP_2Sampler, In.Pos.xy * gFC_ScreenSize.zw).x;
    d = d * DL_FREG_000.y - DL_FREG_000.z;
    d = -DL_FREG_000.x / d;
    dif.w *= min(d - In.Depth.z, In.RampFade.z) * In.RampFade.w;
    float3 n = 2.0f * gSMP_1.Sample(gSMP_1Sampler, In.TexUV.xy).xyz - 1.0f;
    float3 lightA = (dot(n, In.Normal) + 1.0f) * DL_FREG_002.xyz + DL_FREG_003.xyz;
    float ramp = saturate(dot(In.LightDir.xyz, n) * In.RampFade.y + In.RampFade.x);
    float3 lit = pow(abs(lin * (DL_FREG_001.xyz * ramp + lightA)), 1.0f / 2.2f);
    float3 fogged = lerp(lit, g_fog_color.xyz, g_fog_color.w * In.TexUV.w);
    float alpha = dif.w * (1.0f - In.TexUV.z * g_fog_color.w);
    float3 rimA = fogged.xyz * In.Rim1.xyz + In.Rim2.xyz;
    float4 Out = mad(DL_FREG_7.x, float4(rimA - fogged.xyz, 0.0f), float4(fogged, alpha));
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    Out.xyz = pow(abs(Out.xyz), 2.2f);
    return SfxToneMap(Out);
}

#elif SIMPLE_SPRITE_TYPE == 4
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;    // xy = uv0, zw = fog
    float4 Unused1 : TEXCOORD1;
    float4 Tint : TEXCOORD2;
    float3 Rim1 : TEXCOORD3;
    float3 Rim2 : TEXCOORD4;
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 dif = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy) * In.Tint;
    return SfxSpriteTail(dif, In.Tex0.zw, In.Rim1.xyz, In.Rim2.xyz, 0.0f);
}

#elif SIMPLE_SPRITE_TYPE == 5
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;    // xy = uv0, zw = t1 uv
    float4 Tex1 : TEXCOORD1;    // xy = t3 uv, zw = fog
    float4 Tint : TEXCOORD2;
    float3 Rim1 : TEXCOORD3;
    float3 Rim2 : TEXCOORD4;
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 pair = gSMP_1.Sample(gSMP_1Sampler, In.Tex0.zw) * gSMP_3.Sample(gSMP_3Sampler, In.Tex1.xy);
    float4 dif = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy) * In.Tint;
    float3 lin = pow(abs(dif.xyz), 2.2f);
    float4 col4 = pair * float4(lin, dif.w);
    float3 back = pow(abs(col4.xyz), 1.0f / 2.2f);
    float3 fogged = lerp(back, g_fog_color.xyz, g_fog_color.w * In.Tex1.w);
    float alpha = col4.w * (1.0f - In.Tex1.z * g_fog_color.w);
    float3 rimA = fogged.xyz * In.Rim1.xyz + In.Rim2.xyz;
    float4 Out = mad(DL_FREG_7.x, float4(rimA - fogged.xyz, 0.0f), float4(fogged, alpha));
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    Out.xyz = pow(abs(Out.xyz), 2.2f);
    return SfxToneMap(Out);
}

#elif SIMPLE_SPRITE_TYPE == 6
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;    // xy = uv0, zw = t1 uv
    float4 Tex1 : TEXCOORD1;    // xy = t3 uv, zw = fog
    float4 Tint : TEXCOORD2;
    float4 Depth : TEXCOORD3;   // z = particle depth, w = fade max
    float3 Rim1 : TEXCOORD4;
    float3 Rim2 : TEXCOORD5;
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 pair = gSMP_1.Sample(gSMP_1Sampler, In.Tex0.zw) * gSMP_3.Sample(gSMP_3Sampler, In.Tex1.xy);
    float4 dif = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy) * In.Tint;
    float3 lin = pow(abs(dif.xyz), 2.2f);
    float4 col4 = pair * float4(lin, dif.w);
    float d = gSMP_2.Sample(gSMP_2Sampler, In.Pos.xy * gFC_ScreenSize.zw).x;
    d = d * DL_FREG_000.y - DL_FREG_000.z;
    d = -DL_FREG_000.x / d;
    col4.w *= min(d - In.Depth.z, In.Depth.w);
    float3 back = pow(abs(col4.xyz), 1.0f / 2.2f);
    float3 fogged = lerp(back, g_fog_color.xyz, g_fog_color.w * In.Tex1.w);
    float alpha = col4.w * (1.0f - In.Tex1.z * g_fog_color.w);
    float3 rimA = fogged.xyz * In.Rim1.xyz + In.Rim2.xyz;
    float4 Out = mad(DL_FREG_7.x, float4(rimA - fogged.xyz, 0.0f), float4(fogged, alpha));
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    Out.xyz = pow(abs(Out.xyz), 2.2f);
    return SfxToneMap(Out);
}

#elif SIMPLE_SPRITE_TYPE == 7
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;    // xy = uv0, zw = t1 uv
    float2 Fog : TEXCOORD1;     // x = alpha fog, y = color fog
    float4 Tint : TEXCOORD2;
    float3 Rim1 : TEXCOORD3;
    float3 Rim2 : TEXCOORD4;
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 dif = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy) * In.Tint;
    float3 lin = pow(abs(dif.xyz), 2.2f);
    float4 col4 = gSMP_1.Sample(gSMP_1Sampler, In.Tex0.zw) * float4(lin, dif.w);
    float3 back = pow(abs(col4.xyz), 1.0f / 2.2f);
    float3 fogged = lerp(back, g_fog_color.xyz, g_fog_color.w * In.Fog.y);
    float alpha = col4.w * (1.0f - In.Fog.x * g_fog_color.w);
    float3 rimA = fogged.xyz * In.Rim1.xyz + In.Rim2.xyz;
    float4 Out = mad(DL_FREG_7.x, float4(rimA - fogged.xyz, 0.0f), float4(fogged, alpha));
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    Out.xyz = pow(abs(Out.xyz), 2.2f);
    return SfxToneMap(Out);
}

#elif SIMPLE_SPRITE_TYPE == 8
struct SS_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;    // xy = uv0, zw = t1 uv
    float2 Fog : TEXCOORD1;     // x = alpha fog, y = color fog
    float4 Tint : TEXCOORD2;
    float4 Depth : TEXCOORD3;   // z = particle depth, w = fade max
    float3 Rim1 : TEXCOORD4;
    float3 Rim2 : TEXCOORD5;
};
float4 FragmentMain(SS_PS_IN In) : SV_Target0
{
    float4 dif = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy) * In.Tint;
    float3 lin = pow(abs(dif.xyz), 2.2f);
    float4 col4 = gSMP_1.Sample(gSMP_1Sampler, In.Tex0.zw) * float4(lin, dif.w);
    float d = gSMP_2.Sample(gSMP_2Sampler, In.Pos.xy * gFC_ScreenSize.zw).x;
    d = d * DL_FREG_000.y - DL_FREG_000.z;
    d = -DL_FREG_000.x / d;
    col4.w *= min(d - In.Depth.z, In.Depth.w);
    float3 back = pow(abs(col4.xyz), 1.0f / 2.2f);
    float3 fogged = lerp(back, g_fog_color.xyz, g_fog_color.w * In.Fog.y);
    float alpha = col4.w * (1.0f - In.Fog.x * g_fog_color.w);
    float3 rimA = fogged.xyz * In.Rim1.xyz + In.Rim2.xyz;
    float4 Out = mad(DL_FREG_7.x, float4(rimA - fogged.xyz, 0.0f), float4(fogged, alpha));
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    Out.xyz = pow(abs(Out.xyz), 2.2f);
    return SfxToneMap(Out);
}

#else
#error "Unknown SIMPLE_SPRITE_TYPE"
#endif
