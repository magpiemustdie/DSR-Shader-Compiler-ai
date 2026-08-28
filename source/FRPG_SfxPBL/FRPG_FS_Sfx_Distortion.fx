// FRPG_FS_Sfx_Distortion.fx вЂ” SFX Distortion pixel shaders (DistortionType0-5)
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11)
// Compile: /E FragmentMain /T ps_5_0 /DDISTORTION_TYPE=0..5
//
// Feature matrix:
//   Type0: angle-swirl (sincos), radial fade, alpha = exp2(dist)
//   Type1: normal-map offset (t1), radial fade
//   Type2: 3-light specular (t1 normal, t3 refl), radial fade
//   Type3: two-step rotation (angle + optional fixed c10.x)
//   Type4: Type0 + DistortionColor texture (t2)
//   Type5: Type1 + t2
//
// Tail: color = sample * g_DistortionColor, Out = col*v3.w + v3.z*col,
//       alpha test on Out.w (ref: ge/ieq/and/discard_nz)

#ifndef DISTORTION_TYPE
#define DISTORTION_TYPE 0
#endif
#define SFXPBL_NO_REG67
#define SFXPBL_HAS_ALPHATEST
#include "FRPG_SfxPBL_Common.fxh"

float4 DL_FREG_010 : register(c10);              // x = angle / light2 dir.xyz, y = radial fade
float  g_val_1     : register(c11);              // amplitude
float  g_val_2     : register(c12);              // Type3 radius offset
float  g_val_3     : register(c13);              // Type1/2/5 uvN.x offset
float  g_val_4     : register(c14);              // Type1/2/5 uvN.y offset
float4 g_Distortion_light_1_dir : register(c15);
float4 g_Distortion_light_2_dir : register(c16);
float4 g_DistortionColor : register(c17);

#if DISTORTION_TYPE == 1 || DISTORTION_TYPE == 2 || DISTORTION_TYPE == 5
Texture2D    NormalSampler        : register(t1);
SamplerState NormalSamplerSampler : register(s1);
#define gSMP_1        NormalSampler
#define gSMP_1Sampler NormalSamplerSampler
#endif
#if DISTORTION_TYPE == 4 || DISTORTION_TYPE == 5
Texture2D    DistortionColorSampler        : register(t2);
SamplerState DistortionColorSamplerSampler : register(s2);
#define gSMP_2        DistortionColorSampler
#define gSMP_2Sampler DistortionColorSamplerSampler
#endif
#if DISTORTION_TYPE == 2
Texture2D    RefSampler        : register(t3);
SamplerState RefSamplerSampler : register(s3);
#define gSMP_3        RefSampler
#define gSMP_3Sampler RefSamplerSampler
#endif

struct DS_PS_IN
{
    float4 Pos : SV_Position;
    float2 Uv : TEXCOORD0;       // v1.xy
    float2 UvPair : TEXCOORD1;   // v1.zw (screen-proj pair)
    float3 View : TEXCOORD2;     // v2 (Type2 only)
    float4 V3 : TEXCOORD3;       // x = angle flag (Type0/4), y = proj div, zw = blend
};

float4 SfxDistortionTail(float4 col, float4 V3)
{
    // term order matches ref codegen: mul(col*V3.w) first, then mad(V3.z, col, +)
    float4 Out = V3.z * col + col * V3.w;
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    return Out;
}

#if DISTORTION_TYPE == 0
float4 FragmentMain(DS_PS_IN In) : SV_Target0
{
    float angle = (In.V3.x != 0.0f) ? (3.14f - DL_FREG_010.x) : DL_FREG_010.x;
    float dist = length(2.0f * abs(In.Uv.xy - 0.5f));
    angle = dist * g_val_2 - angle;
    float s, c;
    sincos(angle, s, c);
    float2 off;
    off.x = c * g_val_1;
    off.y = s * g_val_1;
    float fade = 1.0f - DL_FREG_010.y * dist;
    float alpha = exp2(dist);
    fade = max(fade, 0.0f) * 0.01f;
    float2 uvP = (In.UvPair.xy / In.V3.y + 1.0f) * 0.5f;
    float2 uv = uvP + off * fade;
    float3 dif = gSMP_0.Sample(gSMP_0Sampler, uv).xyz;
    float4 col = float4(dif, alpha) * g_DistortionColor;
    return SfxDistortionTail(col, In.V3);
}

#elif DISTORTION_TYPE == 1
float4 FragmentMain(DS_PS_IN In) : SV_Target0
{
    float2 uvN = float2(g_val_3 * DL_FREG_010.x + In.Uv.x, In.Uv.y - g_val_4 * DL_FREG_010.x);
    float2 n2 = 2.0f * gSMP_1.Sample(gSMP_1Sampler, uvN).xy - 1.0f;
    float2 off = n2 * g_val_1;
    float dist = length(2.0f * abs(In.Uv.xy - 0.5f));
    float fade = 1.0f - DL_FREG_010.y * dist;
    float alpha = exp2(dist);
    fade = max(fade, 0.0f) * 0.01f;
    off *= fade;
    float2 uv = (In.UvPair.xy / In.V3.y + 1.0f) * 0.5f + off;
    float3 dif = gSMP_0.Sample(gSMP_0Sampler, uv).xyz;
    float4 col = float4(dif, alpha) * g_DistortionColor;
    return SfxDistortionTail(col, In.V3);
}

#elif DISTORTION_TYPE == 2
float4 FragmentMain(DS_PS_IN In) : SV_Target0
{
    float2 uvN = float2(g_val_3 * DL_FREG_010.x + In.Uv.x, In.Uv.y - g_val_4 * DL_FREG_010.x);
    float3 n2 = 2.0f * gSMP_1.Sample(gSMP_1Sampler, uvN).xyz - 1.0f;
    float3 N = normalize(n2);
    float2 off = n2.xy * g_val_1;
    float3 Vn = normalize(In.View);

    float3 L1 = -g_Distortion_light_1_dir.xyz;
    float3 H1 = L1 * rsqrt(dot(L1, L1)) + Vn;
    H1 = normalize(H1);
    float ndh1 = dot(N, H1);
    float spec1 = pow(max(ndh1 + ndh1, 0.0f), 200.0f);
    float3 refTex = gSMP_3.Sample(gSMP_3Sampler, In.Uv.xy).xyz;
    float3 acc = spec1 * refTex * 0.5f;

    float3 L2 = -DL_FREG_010.xyz;
    float3 H2 = L2 * rsqrt(dot(L2, L2)) + Vn;
    H2 = normalize(H2);
    float ndh2 = dot(N, H2);
    float spec2 = pow(max(ndh2 + ndh2, 0.0f), 200.0f);
    acc += spec2 * refTex * 0.5f;

    float3 L3 = -g_Distortion_light_2_dir.xyz;
    float3 H3 = L3 * rsqrt(dot(L3, L3)) + Vn;
    H3 = normalize(H3);
    float ndh3 = dot(N, H3);
    float spec3 = pow(max(ndh3 + ndh3, 0.0f), 200.0f);
    acc += spec3 * refTex * 0.5f;

    float dist = length(2.0f * abs(In.Uv.xy - 0.5f));
    float fade = 1.0f - DL_FREG_010.y * dist;
    float alpha = exp2(dist);
    fade = max(fade, 0.0f) * 0.01f;
    float2 uv = (In.UvPair.xy / In.V3.y + 1.0f) * 0.5f + off * fade;
    float3 dif = gSMP_0.Sample(gSMP_0Sampler, uv).xyz;
    float4 col = float4(acc + dif, alpha) * g_DistortionColor;
    return SfxDistortionTail(col, In.V3);
}

#elif DISTORTION_TYPE == 3
float4 FragmentMain(DS_PS_IN In) : SV_Target0
{
    float2 a = In.Uv.xy - 0.5f;
    float d2 = dot(a, a);
    float dist1 = length(2.0f * abs(a));
    float alpha = exp2(dist1);
    float dist2 = sqrt(d2);
    float t = dist2 - 0.5f * g_val_2;
    t += 1.0f;
    float angle = max(1.0f - DL_FREG_010.y * t, 0.0f) * g_val_1;
    float s, c;
    sincos(angle, s, c);
    float2 uv2 = float2(In.UvPair.y, In.UvPair.x) / In.V3.y;
    uv2 += 1.0f;
    uv2 = uv2 * 0.5f - 0.5f;
    float2 rot1;
    rot1.x = uv2.y * c - uv2.x * s;
    rot1.y = uv2.x * c + uv2.y * s;
    float s2, c2;
    sincos(DL_FREG_010.x, s2, c2);
    float2 rot2;
    rot2.x = rot1.x * c2 - rot1.y * s2;
    rot2.y = rot1.y * c2 + rot1.x * s2;
    float2 uvF = (DL_FREG_010.x == 0.0f) ? rot1 : rot2;
    uvF += 0.5f;
    float3 dif = gSMP_0.Sample(gSMP_0Sampler, uvF).xyz;
    float4 col = float4(dif, alpha) * g_DistortionColor;
    return SfxDistortionTail(col, In.V3);
}

#elif DISTORTION_TYPE == 4
float4 FragmentMain(DS_PS_IN In) : SV_Target0
{
    float angle = (In.V3.x != 0.0f) ? (3.14f - DL_FREG_010.x) : DL_FREG_010.x;
    float dist = length(2.0f * abs(In.Uv.xy - 0.5f));
    angle = dist * g_val_2 - angle;
    float s, c;
    sincos(angle, s, c);
    float2 off;
    off.x = c * g_val_1;
    off.y = s * g_val_1;
    float fade = 1.0f - DL_FREG_010.y * dist;
    float alpha = exp2(dist);
    fade = max(fade, 0.0f) * 0.01f;
    float2 uvP = (In.UvPair.xy / In.V3.y + 1.0f) * 0.5f;
    float2 uv = uvP + off * fade;
    float3 dif = gSMP_0.Sample(gSMP_0Sampler, uv).xyz;
    float4 col = float4(dif, alpha) * g_DistortionColor;
    col *= gSMP_2.Sample(gSMP_2Sampler, In.Uv.xy);
    return SfxDistortionTail(col, In.V3);
}

#elif DISTORTION_TYPE == 5
float4 FragmentMain(DS_PS_IN In) : SV_Target0
{
    float2 uvN = float2(g_val_3 * DL_FREG_010.x + In.Uv.x, In.Uv.y - g_val_4 * DL_FREG_010.x);
    float2 n2 = 2.0f * gSMP_1.Sample(gSMP_1Sampler, uvN).xy - 1.0f;
    float2 off = n2 * g_val_1;
    float dist = length(2.0f * abs(In.Uv.xy - 0.5f));
    float fade = 1.0f - DL_FREG_010.y * dist;
    float alpha = exp2(dist);
    fade = max(fade, 0.0f) * 0.01f;
    off *= fade;
    float2 uv = (In.UvPair.xy / In.V3.y + 1.0f) * 0.5f + off;
    float3 dif = gSMP_0.Sample(gSMP_0Sampler, uv).xyz;
    float4 col = float4(dif, alpha) * g_DistortionColor;
    col *= gSMP_2.Sample(gSMP_2Sampler, In.Uv.xy);
    return SfxDistortionTail(col, In.V3);
}

#endif
