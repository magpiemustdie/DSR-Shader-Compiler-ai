// FRPG_Snow_Common_new.fxh — common definitions for snow shaders, NEW layout.
// $Globals = full forward FC+gVC via FRPG_Water_FC.fxh (ref RDEF 94 members).
// Resources: exact reference names/slots (LitCsd table):
//   t0 scene, t1 diffuse?, t2 bump/height, t5 detail?, t6 lightmap,
//   t7 shadow (sampler_c in shadow variants), t8 SAO, t9 SH-LUT,
//   t10 env-dif?, t11 CUBE, t12 CUBE, t15 spec/subsurf.
// Body-level aliases keep legacy semantic names working.

#ifndef FRPG_SNOW_COMMON_NEW_FXH
#define FRPG_SNOW_COMMON_NEW_FXH

#include "FRPG_Snow_FC.fxh"

// ---- resources ----
SamplerState gSMP_0Sampler        : register(s0);
SamplerState gSMP_1Sampler        : register(s1);
SamplerState gSMP_2Sampler        : register(s2);
#ifdef WITH_ShadowMap
SamplerComparisonState gSMP_7Sampler : register(s7);
#endif
SamplerState gSMP_5Sampler        : register(s5);
SamplerState gSMP_6Sampler        : register(s6);
SamplerState gSMP_8Sampler        : register(s8);
SamplerState gSMP_9Sampler        : register(s9);
SamplerState gSMP_10Sampler       : register(s10);
SamplerState gSMP_11_CUBESampler  : register(s11);
SamplerState gSMP_12_CUBESampler  : register(s12);
SamplerState gSMP_15Sampler       : register(s15);
Texture2D    gSMP_0               : register(t0);
Texture2D    gSMP_1               : register(t1);
Texture2D    gSMP_2               : register(t2);
Texture2D    gSMP_5               : register(t5);
Texture2D    gSMP_6               : register(t6);
Texture2D    gSMP_7               : register(t7);
Texture2D    gSMP_8               : register(t8);
Texture2D    gSMP_9               : register(t9);
Texture2D    gSMP_10              : register(t10);
TextureCube  gSMP_11_CUBE         : register(t11);
TextureCube  gSMP_12_CUBE         : register(t12);
Texture2D    gSMP_15              : register(t15);

// ---- legacy-name aliases (body compatibility) ----
// slot map VERIFIED against ref asm sampling inventory (08/25):
//   t8=AO, t9=DFG LUT (.x=F0-scale, .y=intensity-scale), t10=detail-normal LUT,
//   t11=CUBE EnvDif, t12=CUBE EnvSpc, t15=DetailBump LUT
#define gSMP_DiffuseMap         gSMP_0
#define gSMP_DiffuseMapSampler  gSMP_0Sampler
#define gSMP_SpecularMap        gSMP_1
#define gSMP_SpecularMapSampler gSMP_1Sampler
#define gSMP_BumpMap            gSMP_2
#define gSMP_BumpMapSampler     gSMP_2Sampler
#define gSMP_BumpMap2           gSMP_5
#define gSMP_BumpMap2Sampler    gSMP_5Sampler
#define gSMP_LightMap           gSMP_6
#define gSMP_LightMapSampler    gSMP_6Sampler
#define gSMP_ShadowMap          gSMP_7
#define gSMP_ShadowMapSampler   gSMP_7Sampler
#define gSMP_AOMap              gSMP_8
#define gSMP_AOMapSampler       gSMP_8Sampler
#define gSMP_SHMap              gSMP_9
#define gSMP_SHMapSampler       gSMP_9Sampler
#define gSMP_DFG                gSMP_9
#define gSMP_DFGMapSampler      gSMP_9Sampler
#define gSMP_DetailNormalLUT      gSMP_10
#define gSMP_DetailNormalLUTSampler gSMP_10Sampler
#define gSMP_EnvDifMap          gSMP_11_CUBE
#define gSMP_EnvDifMapSampler   gSMP_11_CUBESampler
#define gSMP_EnvSpcMap          gSMP_12_CUBE
#define gSMP_EnvSpcMapSampler   gSMP_12_CUBESampler
#define gSMP_Subsurf            gSMP_15
#define gSMP_SubsurfMapSampler  gSMP_15Sampler
#define gSMP_DetailBumpMap      gSMP_15
#define gSMP_DetailBumpMapSampler gSMP_15Sampler

// ---- input/output ----
struct SNOW_IN {
    float4 Pos      : SV_Position;
    float4 WorldPos : TEXCOORD0;
    float4 WorldNrm : TEXCOORD1;
    float4 VecEye   : TEXCOORD2;
    float4 WorldTan : TEXCOORD3;
    float4 Color    : COLOR0;
    float4 TexSnow  : TEXCOORD6;
    float4 TanFrame : TEXCOORD7;
    float4 ProjPos  : TEXCOORD8;
    float4 ProjW    : TEXCOORD9;
};

struct HM_IN {
    float4 Pos   : SV_Position;
    float4 TexUV : TEXCOORD0;
    float4 TexUV2: TEXCOORD1;
};


// normal-remap scale lives in LightProbeParam.zzz for snow (ref line 318)
#define gFC_NormalScale gFC_LightProbeParam.zzz

// ---- clustered light buffers (same layout as water/other PBL families) ----
struct s_numLights   { uint offsetNum; };
struct s_lightID     { uint id; };
struct s_lightParams { float4 position; float4 color; float attenuation;
                       uint falloffMode; uint padding0; uint padding1; };
StructuredBuffer<s_numLights>   numLightsBuffer  : register(t16);
StructuredBuffer<s_lightID>     lightIDBuffer    : register(t17);
StructuredBuffer<s_lightParams> lightParamBuffer : register(t18);

// ---- AlphaTestBuffer (b1): present in ref RDEF even though forward snow
//      never reads it (no discard). Declaration alone keeps RDEF entry. ----
cbuffer AlphaTestBuffer : register(b1)
{
    int    AlphaTest         : packoffset(c0);
    float3 AlphaTestRef      : packoffset(c0.y);
    float4 AlphaTest_padding : packoffset(c1);
}


// ---- shadow aliases for ShadowFunc.fxh compatibility ----
#define gFC_ShadowMapClamp0    gFC_ShadowMapClamp[0]
#define gFC_ShadowMapMtxArray0 gFC_ShadowMapMtxArray[0]
#define gFC_ShadowMapMtxArray1 gFC_ShadowMapMtxArray[1]
#define gFC_ShadowMapMtxArray2 gFC_ShadowMapMtxArray[2]
#define gFC_ShadowMapMtxArray3 gFC_ShadowMapMtxArray[3]

#ifdef WITH_ShadowMap
#include "FRPG_ShadowFunc.fxh"
#endif


// ---- VTX_OUT input for HemEnv/Non forward shaders ----
struct VTX_OUT {
    float4 Pos       : SV_Position0;
    float4 WorldPos  : TEXCOORD0;
    float4 WorldNrm  : TEXCOORD1;
    float4 VecEye    : TEXCOORD2;
    float4 WorldTan  : TEXCOORD3;
    float4 ColVtx    : COLOR0;
    float4 TexSnow   : TEXCOORD6;
    float4 TanFrame  : TEXCOORD7;
    float4 ProjPos   : TEXCOORD8;
    float4 ProjW     : TEXCOORD9;
    bool  isFrontFace : SV_IsFrontFace;
};

#endif // FRPG_SNOW_COMMON_NEW_FXH
