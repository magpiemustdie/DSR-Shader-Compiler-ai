// FRPG_FS_Sfx_Tracer.fx вЂ” SFX Tracer pixel shader (TracerType0-3)
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11)
// Compile: /E FragmentMain /T ps_5_0 /DTRACER_TYPE=n
//   Type0: diffuse + fog + tone (no lum branch)
//   Type1: perspective frame-blend (t2) + diffuse + fog, alpha raw
//   Type2: magenta constant + tone
//   Type3: Type1 + normal offset (t1)

#ifndef TRACER_TYPE
#define TRACER_TYPE 0
#endif
#define SFXPBL_NO_SCREENSIZE   // ref Tracer has no c32
#define SFXPBL_HAS_ALPHATEST
#include "FRPG_SfxPBL_Common.fxh"

float4 DL_FREG_010 : register(c10);

#if TRACER_TYPE == 1 || TRACER_TYPE == 3
Texture2D    FrameSampler        : register(t2);
SamplerState FrameSamplerSampler : register(s2);
#define gSMP_2        FrameSampler
#define gSMP_2Sampler FrameSamplerSampler
#endif
#if TRACER_TYPE == 3
Texture2D    NormalSampler        : register(t1);
SamplerState NormalSamplerSampler : register(s1);
#define gSMP_1        NormalSampler
#define gSMP_1Sampler NormalSamplerSampler
#endif

#if TRACER_TYPE == 0 || TRACER_TYPE == 2
struct TRACER_PS_IN
{
    float4 Pos    : SV_Position;
    float4 TC0    : TEXCOORD0;
    float4 TC1    : TEXCOORD1;
    float4 TC2    : TEXCOORD2;
    float2 TC3    : TEXCOORD3;   // diffuse uv
    float  TC4    : TEXCOORD4;
    float4 Color0 : COLOR0;
    float2 Color1 : COLOR1;
};
#else
struct TRACER_PS_IN
{
    float4 Pos     : SV_Position;
    float2 DiffUV  : TEXCOORD0;
    float2 FrameUV : TEXCOORD1;
    float3 Params  : TEXCOORD2;  // x=fogAmt, y=fogBlend, z=clipW
    float4 Color0  : COLOR0;
};
#endif

#if TRACER_TYPE == 0
float4 FragmentMain(TRACER_PS_IN In) : SV_Target0
{
    float4 dif = gSMP_0.Sample(gSMP_0Sampler, In.TC3) * In.Color0;
    float alpha = dif.w * (1.0f - In.Color1.x * g_fog_color.w);
    if (AlphaTestRef.x >= alpha) { if (AlphaTest == 1) discard; }
    float3 col = lerp(dif.xyz * 0.5f, g_fog_color.xyz, g_fog_color.w * In.Color1.y);
    float4 Out = g_toneCorrectParams.xxxx * float4(col, alpha);
    Out.w = saturate(Out.w);
    return Out;
}
#elif TRACER_TYPE == 2
float4 FragmentMain(TRACER_PS_IN In) : SV_Target0
{
    float alpha = gSMP_0.Sample(gSMP_0Sampler, In.TC3).w * In.Color0.w
                * (1.0f - In.Color1.x * g_fog_color.w);
    if (AlphaTestRef.x >= alpha) { if (AlphaTest == 1) discard; }
    float4 Out = g_toneCorrectParams.xxxx * float4(1, 0, 1, alpha);
    Out.w = saturate(Out.w);
    return Out;
}
#else
float4 FragmentMain(TRACER_PS_IN In) : SV_Target0
{
    float alpha = 1.0f - In.Params.x * g_fog_color.w;
    float4 Out;
    Out.w = alpha;
    if (AlphaTestRef.x >= alpha) { if (AlphaTest == 1) discard; }
#if TRACER_TYPE == 3
    float2 nrm = gSMP_1.Sample(gSMP_1Sampler, In.DiffUV).xy * 2.0f - 1.0f;
    nrm *= DL_FREG_010.x;
    nrm *= In.Color0.w;
#endif
    float2 uv = (In.FrameUV / In.Params.z + 1.0f) * 0.5f
#if TRACER_TYPE == 3
              + nrm
#endif
        ;
    float3 frame = gSMP_2.Sample(gSMP_2Sampler, uv).xyz;
    frame = frame * DL_FREG_5.y / DL_FREG_5.x;
    float4 dif = gSMP_0.Sample(gSMP_0Sampler, In.DiffUV);
    float3 difCol = dif.xyz * dif.w * In.Color0.w;
    float3 col = frame * (In.Color0.w * (In.Color0.xyz - 1.0f) + 1.0f) + difCol;
    float3 fogged = lerp(col * 0.5f, g_fog_color.xyz, g_fog_color.w * In.Params.y);
    Out.xyz = fogged;
    return Out;
}
#endif
