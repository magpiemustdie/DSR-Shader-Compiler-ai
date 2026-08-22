// FRPG_Fil_Common.fxh — Filter shader common header
// Reconstructed from DSR DXBC + vanilla source (FRPG_Fil_Common.fxh)
// cbuffer layout matches cb0[N] = register cN

#ifndef ___FRPG_Filter_FRPG_Fil_Common_fxh___
#define ___FRPG_Filter_FRPG_Fil_Common_fxh___

// Individual float4 registers — no packoffset mixing
float4 gFC_AimBloomParam     : register(c7);   // x:vignette start[pix], y:1/(end-start), z:strength
float4 gFC_CameraParam       : register(c8);   // x:near*far, y:far, z:near-far, w:near*far
float4 gFC_DofFarParam       : register(c9);   // x:start, y:end, z:scale
float4 gFC_DofNearParam      : register(c10);  // x:start, y:end, z:scale
float4 gFC_BloomParam        : register(c11);  // x:threshold, y:scale
float4 gFC_ScreenSize        : register(c12);  // xy:size[pix], zw:1/size[pix]
float4 gFC_GaussWeight0      : register(c13);
float4 gFC_GaussWeight1      : register(c14);
float4 gFC_GaussWeight2      : register(c15);
float4 gFC_GaussWeight3      : register(c16);
float4 gFC_GaussWeight4      : register(c17);
float4 gFC_GaussWeight5      : register(c18);
float4 gFC_GaussWeight6      : register(c19);
float4 gFC_GaussWeight7      : register(c20);
float4 gFC_GaussOffset       : register(c21);
float4 gFC_avSampleOffsets0  : register(c22);
float4 gFC_avSampleOffsets1  : register(c23);
float4 gFC_avSampleOffsets2  : register(c24);
float4 gFC_avSampleOffsets3  : register(c25);
float4 gFC_avSampleOffsets4  : register(c26);
float4 gFC_avSampleOffsets5  : register(c27);
float4 gFC_avSampleOffsets6  : register(c28);
float4 gFC_avSampleOffsets7  : register(c29);
float4 gFC_avSampleOffsets8  : register(c30);
float4 gFC_avSampleOffsets9  : register(c31);
float4 gFC_avSampleOffsets10 : register(c32);
float4 gFC_avSampleOffsets11 : register(c33);
float4 gFC_avSampleOffsets12 : register(c34);
float4 gFC_avSampleOffsets13 : register(c35);
float4 gFC_avSampleOffsets14 : register(c36);
float4 gFC_avSampleOffsets15 : register(c37);
float4 gFC_avSampleWeights0  : register(c38);
float4 gFC_avSampleWeights1  : register(c39);
float4 gFC_avSampleWeights2  : register(c40);
float4 gFC_avSampleWeights3  : register(c41);
float4 gFC_avSampleWeights4  : register(c42);
float4 gFC_avSampleWeights5  : register(c43);
float4 gFC_avSampleWeights6  : register(c44);
float4 gFC_avSampleWeights7  : register(c45);
float4 gFC_avSampleWeights8  : register(c46);
float4 gFC_avSampleWeights9  : register(c47);
float4 gFC_avSampleWeights10 : register(c48);
float4 gFC_avSampleWeights11 : register(c49);
float4 gFC_avSampleWeights12 : register(c50);
float4 gFC_avSampleWeights13 : register(c51);
float4 gFC_avSampleWeights14 : register(c52);
float4 gFC_avSampleWeights15 : register(c53);
// NOTE: c71 (gFC_BloomDistParam) is declared per-shader to avoid conflicts

// Samplers (DX11 style) — t0 and t1 always available via Common
Texture2D    gSMP_0 : register(t0);
SamplerState gSMP_0Sampler : register(s0);
Texture2D    gSMP_1 : register(t1);
SamplerState gSMP_1Sampler : register(s1);
// NOTE: gSMP_2 (t2) is NOT declared here — shaders declare t2 themselves to avoid conflicts

// Common PS input for fullscreen quad shaders
struct FIL_IN
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD0;
};

// PS input for shaders that use two UV sets (xy=scene, zw=noise/secondary)
struct FIL_IN4
{
    float4 Pos : SV_Position;
    float4 UV  : TEXCOORD1; // xy=primary, zw=secondary (noise etc.)
};

#endif // ___FRPG_Filter_FRPG_Fil_Common_fxh___
