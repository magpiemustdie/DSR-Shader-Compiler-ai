// Copyright (c) FromSoftware, Inc.

#ifndef ___FRPG_Flver_FRPG_Common_SMP_fxh___
#define ___FRPG_Flver_FRPG_Common_SMP_fxh___

#include "../Common/dx11.h"

// Sampler register macro — on X360 VS/PS share register(cN) space, so we only bind in FS
#ifdef _FRAGMENT_SHADER
    #define SMP_REG(reg) register(reg)
#else
    #define SMP_REG(reg) reg
#endif

#ifdef _DX11
    SAMPLER2D(gSMP_0,  0);  // texture slot 0
    SAMPLER2D(gSMP_1,  1);  // texture slot 1
    SAMPLER2D(gSMP_2,  2);  // texture slot 2
    SAMPLER2D(gSMP_3,  3);  // texture slot 3
    SAMPLER2D(gSMP_4,  4);  // texture slot 4
    SAMPLER2D(gSMP_5,  5);  // texture slot 5
    SAMPLER2D(gSMP_6,  6);  // texture slot 6
#if defined(WITH_GBuffer) || defined(WITH_HemDir3)
    SAMPLER2D(gSMP_7, 7); // GB/HemDir3 path: 16-tap shadow decode uses plain Sample (ref Sample(gSMP_7Sampler_s))
#else
    SAMPLERCMP2D(gSMP_7, 7); // comparison sampler (shadow map)
#endif
    SAMPLER2D(gSMP_8,  8);  // texture slot 8
    SAMPLER2D(gSMP_9,  9);  // texture slot 9
    SAMPLER2D(gSMP_10, 10); // texture slot 10
    SAMPLER2D(gSMP_15, 15); // texture slot 15

    SAMPLERCUBE(gSMP_11_CUBE, 11); // cube slot 11
    SAMPLERCUBE(gSMP_12_CUBE, 12); // cube slot 12
#ifdef USE_SH
    SAMPLER3D(gSMP_13_3D, 13);     // 3D slot 13 (SH volume)
#else
    SAMPLERCUBE(gSMP_13_CUBE, 13); // cube slot 13
#endif
    SAMPLERCUBE(gSMP_14_CUBE, 14); // cube slot 14
#else
    sampler2D gSMP_0  : SMP_REG(s0);
    sampler2D gSMP_1  : SMP_REG(s1);
    sampler2D gSMP_2  : SMP_REG(s2);
    sampler2D gSMP_3  : SMP_REG(s3);
    sampler2D gSMP_4  : SMP_REG(s4);
    sampler2D gSMP_5  : SMP_REG(s5);
    sampler2D gSMP_6  : SMP_REG(s6);
    sampler2D gSMP_7  : SMP_REG(s7);
    sampler2D gSMP_8  : SMP_REG(s8);
    sampler2D gSMP_9  : SMP_REG(s9);
    sampler2D gSMP_10 : SMP_REG(s10);
    sampler2D gSMP_15 : SMP_REG(s15);

    samplerCUBE gSMP_11_CUBE : SMP_REG(s11);
    samplerCUBE gSMP_12_CUBE : SMP_REG(s12);
#ifdef USE_SH
    sampler3D   gSMP_13_3D   : SMP_REG(s13);
#else
    samplerCUBE gSMP_13_CUBE : SMP_REG(s13);
#endif
    samplerCUBE gSMP_14_CUBE : SMP_REG(s14);
#endif

// Named sampler aliases
#define gSMP_DiffuseMap     gSMP_0
#define gSMP_SpecularMap    gSMP_1
#define gSMP_BumpMap        gSMP_2
#define gSMP_DiffuseMap2    gSMP_3
#define gSMP_SpecularMap2   gSMP_4
#define gSMP_BumpMap2       gSMP_5
#define gSMP_LightMap       gSMP_6
#define gSMP_LumTex         gSMP_6  // reused for reverse tonemap
#define gSMP_ShadowMap      gSMP_7
#define gSMP_EnvMap         gSMP_12_CUBE
#define gSMP_AOMap          gSMP_8
#define gSMP_PBLMap         gSMP_1  // reuse specular slot as PBL data
#define gSMP_PBLMap2        gSMP_4
#define gSMP_DFG            gSMP_9
#define gSMP_Subsurf        gSMP_10
#define gSMP_Height         gSMP_10 // reused as heightmap for parallax
#define gSMP_EnvDifMap      gSMP_11_CUBE
#define gSMP_EnvSpcMap      gSMP_12_CUBE
#ifdef USE_SH
#define gSMP_SHMap          gSMP_13_3D
#define gSMP_EnvDifMap2     gSMP_12_CUBE
#else
#define gSMP_EnvDifMap2     gSMP_13_CUBE
#endif
#define gSMP_EnvSpcMap2     gSMP_14_CUBE
#define gSMP_DetailBumpMap  gSMP_15

#ifdef _DX11
#define gSMP_DiffuseMapSampler      gSMP_0Sampler
#define gSMP_SpecularMapSampler     gSMP_1Sampler
#define gSMP_BumpMapSampler         gSMP_2Sampler
#define gSMP_DiffuseMap2Sampler     gSMP_3Sampler
#define gSMP_SpecularMap2Sampler    gSMP_4Sampler
#define gSMP_BumpMap2Sampler        gSMP_5Sampler
#define gSMP_LightMapSampler        gSMP_6Sampler
#define gSMP_ShadowMapSampler       gSMP_7Sampler
#define gSMP_EnvMapSampler          gSMP_12_CUBESampler
#define gSMP_AOMapSampler           gSMP_8Sampler
#define gSMP_PBLMapSampler          gSMP_1Sampler
#define gSMP_DFGMapSampler          gSMP_9Sampler
#define gSMP_SubsurfMapSampler      gSMP_10Sampler
#define gSMP_EnvDifMapSampler       gSMP_11_CUBESampler
#define gSMP_EnvSpcMapSampler       gSMP_12_CUBESampler
#ifdef USE_SH
#define gSMP_SHMapSampler           gSMP_13_3DSampler
#define gSMP_EnvDifMap2Sampler      gSMP_12_CUBESampler
#else
#define gSMP_EnvDifMap2Sampler      gSMP_13_CUBESampler
#endif
#define gSMP_EnvSpcMap2Sampler      gSMP_14_CUBESampler
#define gSMP_DetailBumpMapSampler   gSMP_15Sampler
#endif

#define gSMP_Reflection  gSMP_0
#define gSMP_Refraction  gSMP_1
#define gSMP_WaterHeight gSMP_2

#endif // ___FRPG_Flver_FRPG_Common_SMP_fxh___
