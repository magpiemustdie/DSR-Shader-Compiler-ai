// FRPG_SfxPBL_Common.fxh вЂ” PS common header for FRPG_SfxPBL family
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11.shaderbnd.dcx)
// cb0 layout matches reference _Globals, cb1 = AlphaTestBuffer
//
// Guards:
//   SFXPBL_NO_GLOBALS     вЂ” no cb0 registers at all (BlurType0: no cbuffer in ref)
//   SFXPBL_NO_SCREENSIZE  вЂ” c32 absent (Tracer: ref has no gFC_ScreenSize)
//   SFXPBL_NO_REG67       вЂ” c6/c7 absent (only SimpleSprite/PointSprite have DL_FREG_6/7)
//   SFXPBL_HAS_ALPHATEST  вЂ” declare AlphaTestBuffer (b1) + helper
// Textures t0/s0 and t4/s4 are always available; t1/t2/t3 are declared per-family.

#ifndef ___FRPG_SfxPBL_Common_fxh___
#define ___FRPG_SfxPBL_Common_fxh___

#ifndef SFXPBL_NO_GLOBALS
// ---- cbuffer $Globals (b0) ----
// Declaration ORDER matters: RDEF lists variables in source order, and the
// reference declares DL_FREG_5/6/7 *after* gFC_ScreenSize despite lower slots.
float4 DL_FREG_000          : register(c0);
float4 DL_FREG_001          : register(c1);
float4 DL_FREG_002          : register(c2);
float4 DL_FREG_003          : register(c3);
#ifdef SFXPBL_C4_IS_DL_FREG_004
float4 DL_FREG_004          : register(c4);   // SimpleSprite/PointSprite naming
#define g_fog_color DL_FREG_004
#else
float4 g_fog_color          : register(c4);
#endif
float4 g_glowColor          : register(c8);
float4 g_toneCorrectParams  : register(c9);
float4 gFC_AdaptParam       : register(c30);  // x=invScale, y=scale, zw=lum clamp
float4 gFC_InverseToneMapEnable : register(c31);
#ifndef SFXPBL_NO_SCREENSIZE
float4 gFC_ScreenSize       : register(c32);  // xy=size, zw=1/size
#endif
float4 DL_FREG_5            : register(c5);   // gamma pair (Tracer/Line), light (SimpleSprite)
#ifndef SFXPBL_NO_REG67
float4 DL_FREG_6            : register(c6);
float4 DL_FREG_7            : register(c7);
#endif

#ifdef SFXPBL_HAS_ALPHATEST
// ---- cbuffer AlphaTestBuffer (b1) ----
// int + float3 share c0 via packoffset (float3 would otherwise move to c1)
cbuffer AlphaTestBuffer : register(b1)
{
    int    AlphaTest         : packoffset(c0);
    float3 AlphaTestRef      : packoffset(c0.y);
    float4 AlphaTest_padding : packoffset(c1);
};
#endif
#endif // !SFXPBL_NO_GLOBALS

// ---- Textures / samplers ----
// RDEF names must match reference exactly ("DiffuseSamplerSampler" doubling
// is the original FromSoft naming, not a typo).
Texture2D    DiffuseSampler        : register(t0);
SamplerState DiffuseSamplerSampler : register(s0);
#define gSMP_0        DiffuseSampler
#define gSMP_0Sampler DiffuseSamplerSampler
Texture2D    gSMP_LumTex : register(t4);    // luminance sample
SamplerState gSMP_LumTexSampler : register(s4);

// ---- Helpers ----
#ifndef SFXPBL_NO_GLOBALS
// Reference tone map: col * tone.x, optional lum-adapted rescale, saturate w
float4 SfxToneMap(float4 col)
{
    float4 Out = g_toneCorrectParams.xxxx * col;
    if (gFC_InverseToneMapEnable.x != 0.0f)
    {
        float lum = gSMP_LumTex.Sample(gSMP_LumTexSampler, float2(0.5f, 0.5f)).x;
        lum = clamp(lum, gFC_AdaptParam.z, gFC_AdaptParam.w);
        Out.xyz = gFC_AdaptParam.yyy * Out.xyz * (lum + 1e-4f) / gFC_AdaptParam.x;
    }
    Out.w = saturate(Out.w);
    return Out;
}

// Reference depth encode: d = pair.x/pair.y -> RGB bytes of 255.999985*d
float3 SfxEncodeDepth(float2 depthPair)
{
    float d = depthPair.x / depthPair.y;
    float t = 255.999985f * d;
    float R = trunc(t);
    float f = t - R;
    float gv = 256.0f * f;
    float G = trunc(gv);
    float B = 256.0f * f - G;
    return float3(R, G, B);
}

// Reference depth tone map: encoded RGB * tone.x, * (1/255, 1/255, 1.0039, tone.x), lum branch
float4 SfxToneMapDepth(float3 encoded, float alpha)
{
    float4 Out;
    Out.xyz = g_toneCorrectParams.xxx * encoded;
    Out.w = alpha;
#ifdef SFXPBL_HAS_ALPHATEST
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
#endif
    Out *= float4(0.00392156886f, 0.00392156886f, 1.00392163f, g_toneCorrectParams.x);
    if (gFC_InverseToneMapEnable.x != 0.0f)
    {
        float lum = gSMP_LumTex.Sample(gSMP_LumTexSampler, float2(0.5f, 0.5f)).x;
        lum = clamp(lum, gFC_AdaptParam.z, gFC_AdaptParam.w);
        Out.xyz = gFC_AdaptParam.yyy * Out.xyz * (lum + 1e-4f) / gFC_AdaptParam.x;
    }
    Out.w = saturate(Out.w);
    return Out;
}
#endif // !SFXPBL_NO_GLOBALS

#endif // ___FRPG_SfxPBL_Common_fxh___
