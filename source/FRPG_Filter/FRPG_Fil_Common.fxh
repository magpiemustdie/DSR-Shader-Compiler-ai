// FRPG_Fil_Common.fxh — Filter shader common header
// Reconstructed from DSR DXBC + vanilla source (FRPG_Fil_Common.fxh)
// cbuffer layout matches cb0[N] = register cN

#ifndef ___FRPG_Filter_FRPG_Fil_Common_fxh___
#define ___FRPG_Filter_FRPG_Fil_Common_fxh___

// Individual float4 registers — no packoffset mixing
float4 DL_FREG_007              : register(c7);// x:vignette start[pix], y:1/(end-start), z:strength
float4 DL_FREG_008              : register(c8);// x:near*far, y:far, z:near-far, w:near*far
float4 DL_FREG_009              : register(c9);// x:start, y:end, z:scale
float4 DL_FREG_010              : register(c10);// x:start, y:end, z:scale
float4 DL_FREG_011              : register(c11);// x:threshold, y:scale
float4 DL_FREG_012              : register(c12);// xy:size[pix], zw:1/size[pix]
float4 DL_FREG_013              : register(c13);
float4 DL_FREG_014              : register(c14);
float4 DL_FREG_015              : register(c15);
float4 DL_FREG_016              : register(c16);
float4 DL_FREG_017              : register(c17);
float4 DL_FREG_018              : register(c18);
float4 DL_FREG_019              : register(c19);
float4 DL_FREG_020              : register(c20);
float4 DL_FREG_021              : register(c21);
float4 DL_FREG_022              : register(c22);
float4 DL_FREG_023              : register(c23);
float4 DL_FREG_024              : register(c24);
float4 DL_FREG_025              : register(c25);
float4 DL_FREG_026              : register(c26);
float4 DL_FREG_027              : register(c27);
float4 DL_FREG_028              : register(c28);
float4 DL_FREG_029              : register(c29);
float4 DL_FREG_030              : register(c30);
float4 DL_FREG_031              : register(c31);
float4 DL_FREG_032              : register(c32);
float4 DL_FREG_033              : register(c33);
float4 DL_FREG_034              : register(c34);
float4 DL_FREG_035              : register(c35);
float4 DL_FREG_036              : register(c36);
float4 DL_FREG_037              : register(c37);
float4 DL_FREG_038              : register(c38);
float4 DL_FREG_039              : register(c39);
float4 DL_FREG_040              : register(c40);
float4 DL_FREG_041              : register(c41);
float4 DL_FREG_042              : register(c42);
float4 DL_FREG_043              : register(c43);
float4 DL_FREG_044              : register(c44);
float4 DL_FREG_045              : register(c45);
float4 DL_FREG_046              : register(c46);
float4 DL_FREG_047              : register(c47);
float4 DL_FREG_048              : register(c48);
float4 DL_FREG_049              : register(c49);
float4 DL_FREG_050              : register(c50);
float4 DL_FREG_051              : register(c51);
float4 DL_FREG_052              : register(c52);
float4 DL_FREG_053              : register(c53);
// NOTE: c71 (gFC_BloomDistParam) is declared per-shader to avoid conflicts

// Samplers (DX11 style) — t0 and t1 always available via Common

// ---- legacy-name aliases ----
#define gFC_AimBloomParam DL_FREG_007
#define gFC_CameraParam DL_FREG_008
#define gFC_DofFarParam DL_FREG_009
#define gFC_DofNearParam DL_FREG_010
#define gFC_BloomParam DL_FREG_011
#define gFC_ScreenSize DL_FREG_012
#define gFC_GaussWeight0 DL_FREG_013
#define gFC_GaussWeight1 DL_FREG_014
#define gFC_GaussWeight2 DL_FREG_015
#define gFC_GaussWeight3 DL_FREG_016
#define gFC_GaussWeight4 DL_FREG_017
#define gFC_GaussWeight5 DL_FREG_018
#define gFC_GaussWeight6 DL_FREG_019
#define gFC_GaussWeight7 DL_FREG_020
#define gFC_GaussOffset DL_FREG_021
#define gFC_avSampleOffsets0 DL_FREG_022
#define gFC_avSampleOffsets1 DL_FREG_023
#define gFC_avSampleOffsets2 DL_FREG_024
#define gFC_avSampleOffsets3 DL_FREG_025
#define gFC_avSampleOffsets4 DL_FREG_026
#define gFC_avSampleOffsets5 DL_FREG_027
#define gFC_avSampleOffsets6 DL_FREG_028
#define gFC_avSampleOffsets7 DL_FREG_029
#define gFC_avSampleOffsets8 DL_FREG_030
#define gFC_avSampleOffsets9 DL_FREG_031
#define gFC_avSampleOffsets10 DL_FREG_032
#define gFC_avSampleOffsets11 DL_FREG_033
#define gFC_avSampleOffsets12 DL_FREG_034
#define gFC_avSampleOffsets13 DL_FREG_035
#define gFC_avSampleOffsets14 DL_FREG_036
#define gFC_avSampleOffsets15 DL_FREG_037
#define gFC_avSampleWeights0 DL_FREG_038
#define gFC_avSampleWeights1 DL_FREG_039
#define gFC_avSampleWeights2 DL_FREG_040
#define gFC_avSampleWeights3 DL_FREG_041
#define gFC_avSampleWeights4 DL_FREG_042
#define gFC_avSampleWeights5 DL_FREG_043
#define gFC_avSampleWeights6 DL_FREG_044
#define gFC_avSampleWeights7 DL_FREG_045
#define gFC_avSampleWeights8 DL_FREG_046
#define gFC_avSampleWeights9 DL_FREG_047
#define gFC_avSampleWeights10 DL_FREG_048
#define gFC_avSampleWeights11 DL_FREG_049
#define gFC_avSampleWeights12 DL_FREG_050
#define gFC_avSampleWeights13 DL_FREG_051
#define gFC_avSampleWeights14 DL_FREG_052
#define gFC_avSampleWeights15 DL_FREG_053

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