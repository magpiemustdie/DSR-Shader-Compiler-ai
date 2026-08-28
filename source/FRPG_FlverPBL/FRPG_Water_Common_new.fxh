// FRPG_Water_Common.fxh — resources + shared helpers for FRPG_Water_* shaders.
// Reconstructed 1:1 from reference RDEF / 3DMigoto decompiles (see AGENTS.md п.19).
// Constants live in FRPG_Water_FC.fxh (standard forward FC layout, c1..c245+38x2).

#ifndef ___FRPG_Water_Common_fxh___
#define ___FRPG_Water_Common_fxh___

#include "FRPG_Water_FC.fxh"

// ---- Textures / samplers (names must match reference RDEF exactly) ----
SamplerState gSMP_1Sampler       : register(s1);
SamplerState gSMP_2Sampler       : register(s2);
SamplerState gSMP_3Sampler       : register(s3);
SamplerState gSMP_12_CUBESampler : register(s12);
Texture2D    gSMP_1              : register(t1);   // scene color (refraction)
Texture2D    gSMP_2              : register(t2);   // wave height
Texture2D    gSMP_3              : register(t3);   // refraction mask
TextureCube  gSMP_12_CUBE        : register(t12);  // environment (Env path)

#ifdef WATER_REFLECT
Texture2D    gSMP_0              : register(t0);
SamplerState gSMP_0Sampler       : register(s0);
#endif

#ifdef WITH_ShadowMap
Texture2D              gSMP_7        : register(t7);
SamplerComparisonState gSMP_7Sampler : register(s7);
#endif

// ---- Clustered light buffers (same layout as other PBL families) ----
struct s_numLights   { uint offsetNum; };
struct s_lightID     { uint id; };
struct s_lightParams { float4 position; float4 color; float attenuation;
                       uint falloffMode; uint padding0; uint padding1; };
StructuredBuffer<s_numLights>   numLightsBuffer  : register(t16);
StructuredBuffer<s_lightID>     lightIDBuffer    : register(t17);
StructuredBuffer<s_lightParams> lightParamBuffer : register(t18);

// ---- Input vertices ----
struct WATER_IN_BASE
{
    float4 VtxClp   : SV_Position0;
    float4 VecPos   : TEXCOORD0;   // world pos
    float4 VtxFog   : TEXCOORD1;   // w = fog blend
    float4 VecNrmW  : TEXCOORD2;   // world normal (view-facing for fresnel dot)
    float4 VtxLit   : TEXCOORD3;   // unused in base paths
    float4 ColVtx   : COLOR0;      // xyz tint, w alpha
    float4 WldNrm_0 : TEXCOORD6;   // decoded wave normal A (xyz), .y reused
    float4 WldNrm_1 : TEXCOORD7;   // decoded wave normal B
    float4 TexUV_A  : TEXCOORD8;   // xy = uv, zw = screen uv (parallax pair)
    float4 TexUV_B  : TEXCOORD9;   // second parallax pair
};
#define WATER_IN_BASE_NAME WATER_IN_BASE

// ---- Output ----
struct WATER_OUT
{
    float4 Color : SV_Target0;
};

#endif // ___FRPG_Water_Common_fxh___
