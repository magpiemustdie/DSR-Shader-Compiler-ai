// FRPG_Snow_Common.fxh – Common definitions for all snow shaders
// Reconstructed from DSR Windows DXBC (FRPG_Snow_______.fpo.asm)
#ifndef FRPG_SNOW_COMMON_FXH
#define FRPG_SNOW_COMMON_FXH

#include "FRPG_Common.fxh"
#ifndef WITH_GBuffer
#include "FRPG_Common_ForwardPBL.fxh"
#endif
#include "FRPG_ShadowFunc.fxh"

// ---------------------------------------------------------------------------
// HeightMap pass input/output
// ---------------------------------------------------------------------------
struct HM_IN {
    float4 Pos   : SV_Position;
    float4 TexUV : TEXCOORD0;   // v1: xy=tile1 UV, zw=tile0 UV
    float4 TexUV2: TEXCOORD1;   // v2: xy=tile2 UV, z=viewZ
};

// ---------------------------------------------------------------------------
// Main snow pass input
// v0 = SV_Position (xy used for screen UV)
// v1 = TEXCOORD0: worldPos.xyz
// v2 = TEXCOORD1: worldNrm.xyz + fogFactor.w
// v3 = TEXCOORD2: VecEye.xyz (unnormalized, camera-vertex)
// v4 = TEXCOORD3: worldTan.xyz + handedness.w
// v5 = COLOR0: vertexColor (only .w used = snowCoverage)
// v6 = TEXCOORD6: snowNrmUV.xy + diffuseUV.zw
// v7 = TEXCOORD7: bitanScaled*2 (TanFrame)
// v8 = TEXCOORD8: projA.xyzw
// v9 = TEXCOORD9: projA.w + projB.w (as xy)
// ---------------------------------------------------------------------------
#ifndef SNOW_IN_DEFINED
#define SNOW_IN_DEFINED
struct SNOW_IN {
    float4 Pos      : SV_Position;  // v0
    float4 WorldPos : TEXCOORD0;    // v1.xyzw (w unused in PS)
    float4 WorldNrm : TEXCOORD1;    // v2.xyzw (w=fogFactor)
    float4 VecEye   : TEXCOORD2;    // v3.xyzw (w unused in PS)
    float4 WorldTan : TEXCOORD3;    // v4.xyzw (w=handedness)
    float4 Color    : COLOR0;       // v5 (w=snowCoverage)
    float4 TexSnow  : TEXCOORD6;    // v6: xy=snowNrmUV, zw=diffuseUV
    float4 TanFrame : TEXCOORD7;    // v7: bitanScaled*2
    float4 ProjPos  : TEXCOORD8;    // v8
    float4 ProjW    : TEXCOORD9;    // v9.xy=projA.w+projB.w, v9.zw=lightmapUV (Lit only)
};
#endif

// AlphaTest/AlphaTestRef come from AlphaTestBuffer (register b1) via dx11.h

#endif // FRPG_SNOW_COMMON_FXH
