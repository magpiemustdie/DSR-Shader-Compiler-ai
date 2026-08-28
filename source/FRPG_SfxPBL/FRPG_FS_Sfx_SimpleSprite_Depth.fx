// FRPG_FS_Sfx_SimpleSprite_Depth.fx — SFX SimpleSprite_Depth pixel shaders
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11)
// Compile: /E FragmentMain /T ps_5_0 /DDEPTH_SPRITE_TYPE=0,1,4,5,7
//
// Depth family: the RGB channel carries an 8-bit-per-channel depth encoding
// (255.999985*d -> floor/frac split), alpha = w-channel sample blend.
// DepthType2/3/6/8 are BINARY IDENTICAL to SimpleSpriteType2/3/6/8
// (build those from FRPG_FS_Sfx_SimpleSprite.fx).
//
// Feature matrix:
//   Type0: multi-tex (t0 x2, w-channel, blend TEXCOORD4.x)  — depth pair TEXCOORD4.yz
//   Type1: multi-tex (blend TEXCOORD0.w)                    — depth pair TEXCOORD4.zw
//   Type4: single texture                                   — depth pair TEXCOORD1.zw
//   Type5: tex pair (t1 x t3) x t0, tint TEXCOORD2.w        — depth pair TEXCOORD5.xy
//   Type7: t1 x t0 (no t3)                                  — depth pair TEXCOORD1.zw
// All: fog alpha TEXCOORDn.z, NO fog color, NO rim, NO 2.2 round trip.

#ifndef DEPTH_SPRITE_TYPE
#define DEPTH_SPRITE_TYPE 0
#endif
#define SFXPBL_HAS_ALPHATEST
#include "FRPG_SfxPBL_Common.fxh"

// Slot 1..3 names per reference: t1 = MultiAlphaSampler0 (5,7), NormalSampler (3
// is binary-identical to SimpleSpriteType3 and builds from the other file);
// t3 = MultiAlphaSampler1 (5). Depth2/3/6/8 come from FRPG_FS_Sfx_SimpleSprite.fx.
#if DEPTH_SPRITE_TYPE == 5 || DEPTH_SPRITE_TYPE == 7
Texture2D    MultiAlphaSampler0        : register(t1);
SamplerState MultiAlphaSampler0Sampler : register(s1);
#define gSMP_1        MultiAlphaSampler0
#define gSMP_1Sampler MultiAlphaSampler0Sampler
#endif
#if DEPTH_SPRITE_TYPE == 5
Texture2D    MultiAlphaSampler1        : register(t3);
SamplerState MultiAlphaSampler1Sampler : register(s3);
#define gSMP_3        MultiAlphaSampler1
#define gSMP_3Sampler MultiAlphaSampler1Sampler
#endif

#if DEPTH_SPRITE_TYPE == 0
struct SD_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;        // xy = uv0, z = fog
    float4 Tint : TEXCOORD1;        // w = tint
    float4 Uv1x : TEXCOORD2;        // w = uv1.x
    float4 Uv1y : TEXCOORD3;        // w = uv1.y
    float  Blend : TEXCOORD4;       // x = blend
    float4 Depth : TEXCOORD5;       // yz = depth pair
};
float4 FragmentMain(SD_PS_IN In) : SV_Target0
{
    float w0 = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy).w;
    float w1 = gSMP_0.Sample(gSMP_0Sampler, float2(In.Uv1x.w, In.Uv1y.w)).w;
    float a = lerp(w0, w1, In.Blend) * In.Tint.w;
    float alpha = a * (1.0f - In.Tex0.z * g_fog_color.w);
    return SfxToneMapDepth(SfxEncodeDepth(In.Depth.yz), alpha);
}

#elif DEPTH_SPRITE_TYPE == 1
struct SD_PS_IN
{
    float4 Pos : SV_Position;
    float4 Blend : TEXCOORD0;       // w = blend
    float3 TexFog : TEXCOORD2;      // xy = uv0, z = fog
    float4 Tint : TEXCOORD3;        // w = tint
    float4 Depth : TEXCOORD7;       // zw = depth pair
    float4 Uv1x : TEXCOORD5;        // w = uv1.x
    float4 Uv1y : TEXCOORD6;        // w = uv1.y
};
float4 FragmentMain(SD_PS_IN In) : SV_Target0
{
    float w0 = gSMP_0.Sample(gSMP_0Sampler, In.TexFog.xy).w;
    float w1 = gSMP_0.Sample(gSMP_0Sampler, float2(In.Uv1x.w, In.Uv1y.w)).w;
    float a = lerp(w0, w1, In.Blend.w) * In.Tint.w;
    float alpha = a * (1.0f - In.TexFog.z * g_fog_color.w);
    return SfxToneMapDepth(SfxEncodeDepth(In.Depth.zw), alpha);
}

#elif DEPTH_SPRITE_TYPE == 4
struct SD_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;        // xy = uv0, z = fog
    float4 Depth : TEXCOORD5;       // zw = depth pair
    float4 Tint : TEXCOORD2;        // w = tint
};
float4 FragmentMain(SD_PS_IN In) : SV_Target0
{
    float a = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy).w * In.Tint.w;
    float alpha = a * (1.0f - In.Tex0.z * g_fog_color.w);
    return SfxToneMapDepth(SfxEncodeDepth(In.Depth.zw), alpha);
}

#elif DEPTH_SPRITE_TYPE == 5
struct SD_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;        // xy = uv0, zw = t1 uv
    float3 Tex3Fog : TEXCOORD1;     // xy = t3 uv, z = fog
    float4 Tint : TEXCOORD2;        // w = tint
    float2 Depth : TEXCOORD5;       // xy = depth pair
};
float4 FragmentMain(SD_PS_IN In) : SV_Target0
{
    float pair = gSMP_1.Sample(gSMP_1Sampler, In.Tex0.zw).w
               * gSMP_3.Sample(gSMP_3Sampler, In.Tex3Fog.xy).w;
    float tinted = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy).w * In.Tint.w;
    float a = tinted * pair;
    float alpha = a * (1.0f - In.Tex3Fog.z * g_fog_color.w);
    return SfxToneMapDepth(SfxEncodeDepth(In.Depth.xy), alpha);
}

#elif DEPTH_SPRITE_TYPE == 7
struct SD_PS_IN
{
    float4 Pos : SV_Position;
    float4 Tex0 : TEXCOORD0;        // xy = uv0, zw = t1 uv
    float  Fog : TEXCOORD1;         // x = fog
    float4 Depth : TEXCOORD5;       // zw = depth pair
    float4 Tint : TEXCOORD2;        // w = tint
};
float4 FragmentMain(SD_PS_IN In) : SV_Target0
{
    float pair = gSMP_1.Sample(gSMP_1Sampler, In.Tex0.zw).w;
    float tinted = gSMP_0.Sample(gSMP_0Sampler, In.Tex0.xy).w * In.Tint.w;
    float a = tinted * pair;
    float alpha = a * (1.0f - In.Fog * g_fog_color.w);
    return SfxToneMapDepth(SfxEncodeDepth(In.Depth.zw), alpha);
}

#else
#error "Unknown DEPTH_SPRITE_TYPE"
#endif
