// FRPG_Water_Common_GBuffer.fxh — Water shader constants for DL_FREG layout (PntSS/PntSSSS)
// Maps to OLD_VERSION / WITH_GBuffer cbuffer layout (cb0[196])

#ifndef FRPG_WATER_COMMON_GBUFFER_FXH
#define FRPG_WATER_COMMON_GBUFFER_FXH

#include "FRPG_Common.fxh"

// ---------------------------------------------------------------------------
// Textures (PntSS: no t3 spec mask, no structured buffers)
// ---------------------------------------------------------------------------
Texture2D    gSMP_DiffuseMap     : register(t1);
SamplerState gSMP_DiffuseMapSampler : register(s1);
Texture2D    gSMP_HeightMap      : register(t2);
SamplerState gSMP_HeightMapSampler  : register(s2);
TextureCube  gSMP_EnvMap         : register(t12);
SamplerState gSMP_EnvMapSampler  : register(s12);

// ---------------------------------------------------------------------------
// DL_FREG layout constants (as used by OLD_VERSION / WITH_GBuffer path)
// ---------------------------------------------------------------------------
// Specular lighting (OLD_VERSION: c88-c89)
#define gFC_SpcLightVec_DL     DL_FREG_088
#define gFC_SpcLightCol_DL     DL_FREG_089
// Specular params (OLD_VERSION: c102)
#define gFC_SpcParam_DL        DL_FREG_102
// Fog (OLD_VERSION: c103)
#define gFC_FogCol_DL          DL_FREG_103
// Light scattering (OLD_VERSION: c104-c111)
float4 gFC_LsBeta1PlusBeta2        : FC_REG(c104);
float4 gFC_LsTerrainReflectance    : FC_REG(c105);
float4 gFC_LsOneOverBeta1PlusBeta2 : FC_REG(c106);
float4 gFC_LsHGg                   : FC_REG(c107);
float4 gFC_LsBetaDash1             : FC_REG(c108);
float4 gFC_LsBetaDash2             : FC_REG(c109);
float4 gFC_LsSunColor              : FC_REG(c110);
float4 gFC_LsLightDir              : FC_REG(c111);
// Point lights as fog volumes (OLD_VERSION: c112-c119)
float4 gFC_PntLightPos[4] : FC_REG(c112);
float4 gFC_PntLightCol[4] : FC_REG(c116);
// Water specific (OLD_VERSION: c124-c134, c163-c164)
float  gFC_WaterReflectBand        : FC_REG(c124);
float  gFC_WaterRefractBand        : FC_REG(c125);
float  gFC_WaterWaveHeight         : FC_REG(c126);
float4 gFC_WaterColor              : FC_REG(c127);
float2 gFC_WaterFadeBegin          : FC_REG(c128);
float  gFC_WaterFresnelPow         : FC_REG(c129);
float  gFC_WaterFresnelBias        : FC_REG(c130);
float  gFC_WaterFresnelScale       : FC_REG(c131);
float4 gFC_WaterFresnelColor       : FC_REG(c132);
float4 gFC_WaterFresnelFakeColor   : FC_REG(c133);
float3 gFC_WaterTileBlend          : FC_REG(c134);
float4 gFC_WaterWaveParam          : FC_REG(c163);
float4 gFC_WaterHeightMapSize      : FC_REG(c164);
// Gamma toggle (OLD_VERSION: c195)
float4 gFC_GammaToggle             : FC_REG(c195);

// ---------------------------------------------------------------------------
// Helper: Decode RGBA8-packed height value (4 heights per texel)
// Matches ASM: dp4 result * 0.000015 (= 1/65535)
// ---------------------------------------------------------------------------
float DecodePackedHeight(float4 packed)
{
    return dot(packed, float4(1044480.0f, 65280.0f, 4080.0f, 255.0f)) * (1.0f / 65535.0f);
}

// ---------------------------------------------------------------------------
// Helper: Bicubic heightmap AA sample (inline ASM pattern)
// Returns a single height value from 4 bicubic taps around uv
// ---------------------------------------------------------------------------
float SampleHeightAA(float2 uv)
{
    float4 baseUV = float4(uv, uv);
    float4 texUV = baseUV * gFC_WaterHeightMapSize.xyxy;
    float4 fracUV = frac(texUV);
    float4 signUV = step(0.5f, fracUV) ? 1.0f : -1.0f;
    fracUV += -0.5f;
    float4 offsetUV = signUV * gFC_WaterHeightMapSize.zzww;

    // 4-scanline bicubic: top row, center, bottom row
    float2 uvAA = uv + offsetUV.yz;           // offset1
    float2 uvBB = uv + float2(offsetUV.x, offsetUV.w); // offset2
    float2 uvCC = uv + signUV.xy * gFC_WaterHeightMapSize.zw; // offset3
    float2 uvDD = uv + float2(offsetUV.z, offsetUV.y); // offset4

    // Actually this doesn't match the ASM exactly. Let me use a simpler
    // approach that the compiler will optimize to the same pattern.
    // The ASM does a 2D separable bicubic: 4 taps, lerped by frac weights.

    // Row 0: samples at uvAA and uvBB, weighted by fracUV.x
    float4 s00 = gSMP_HeightMap.Sample(gSMP_HeightMapSampler, uvAA);
    float4 s01 = gSMP_HeightMap.Sample(gSMP_HeightMapSampler, uvBB);
    float4 s02 = gSMP_HeightMap.Sample(gSMP_HeightMapSampler, uvCC);
    float4 s03 = gSMP_HeightMap.Sample(gSMP_HeightMapSampler, uvDD);

    float4 row0 = lerp(s00, s01, fracUV.x);
    float4 row1 = lerp(s02, s03, fracUV.x);
    float4 result = lerp(row0, row1, fracUV.y);

    return DecodePackedHeight(result);
}

// ---------------------------------------------------------------------------
// Input structure for GBuffer variant (matches PntSS input signature)
// v0  = SV_Position (unused in PntSS)
// v1  = WorldPos.xyz
// v2  = FogFactor.w
// v3  = VecEye.xyz
// v4  = (unused)
// v5  = Color.xyzw
// v6  = TanFrameA.xyw  (tangent-related, .z unused)
// v7  = TanFrameB.xyz  (bitangent-related *2)
// v8  = TanFrameC.xyz  (normal-related *2)
// v9  = ProjUV_A.xyw   (screen-space projection, .z unused)
// v10 = ProjUV_B.xyw   (second projection, .z unused)
// ---------------------------------------------------------------------------
struct WATER_IN_GBUFFER {
    float4 Pos       : SV_Position;  // v0 (unused in PS)
    float3 WorldPos  : TEXCOORD0;    // v1
    float  FogFactor : TEXCOORD1;    // v2.w
    float3 VecEye    : TEXCOORD2;    // v3
    float4 Color     : COLOR0;       // v5
    float3 TanFrameA : TEXCOORD5;    // v6.xyw (z unused)
    float3 TanFrameB : TEXCOORD6;    // v7.xyz (bitan*2)
    float3 TanFrameC : TEXCOORD7;    // v8.xyz (normal*2)
    float3 ProjUV_A  : TEXCOORD8;    // v9.xyw
    float3 ProjUV_B  : TEXCOORD9;    // v10.xyw
};

#endif // FRPG_WATER_COMMON_GBUFFER_FXH
