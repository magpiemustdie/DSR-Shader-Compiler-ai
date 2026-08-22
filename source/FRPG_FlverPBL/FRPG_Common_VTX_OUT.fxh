// Copyright (c) FromSoftware, Inc.

#ifndef ___FRPG_Flver_FRPG_Common_VTX_OUT_fxh___
#define ___FRPG_Flver_FRPG_Common_VTX_OUT_fxh___

// Enabled feature combinations:
// #define WITH_GhostMap
// #define WITH_BumpMap
// #define WITH_LightMap
// #define WITH_ShadowMap

struct VTX_OUT
{
    float4 VtxClp : SV_Position; // vertex position (clip space)
    float4 VtxWld : TEXCOORD0;   // vertex position (world space): xyz=position, w=view-space Z

#if WITH_ShadowMap == CalcLispPos_VS
    float4 VtxLit : TEXCOORD1;   // vertex position (light space)
#endif

    float4 VecNrm : TEXCOORD2;   // normal: xyz=normal, w=fog coefficient
    float4 VecEye : TEXCOORD3;   // eye vector (world space): xyz=normalized vertex->camera, w=distance
  #ifdef WITH_BumpMap
    #ifdef WITH_MultiTexture
        float4 VecTan  : TEXCOORD4;
        float4 VecTan2 : TEXCOORD5;
        #ifdef CALC_VS_BINORMAL
            float3 VecBin  : TEXCOORD8;
            float3 VecBin2 : TEXCOORD9;
        #endif
    #else
        float4 VecTan : TEXCOORD4;
        #ifdef CALC_VS_BINORMAL
            float3 VecBin : TEXCOORD5;
        #endif
    #endif
  #endif

    float4 ColVtx : COLOR; // vertex color

#ifdef WITH_LightMap
    #ifdef WITH_MultiTexture
        float4 TexDifDif : TEXCOORD6; // diffuse UV + diffuse UV2
        float2 TexLit    : TEXCOORD7; // lightmap UV
    #else
        float4 TexDifLit : TEXCOORD6; // diffuse UV + lightmap UV
    #endif
#else
    #ifdef WITH_MultiTexture
        float4 TexDifDif : TEXCOORD6; // diffuse UV + diffuse UV2
    #else
        float2 TexDif : TEXCOORD6;    // diffuse UV
    #endif
#endif

#ifdef VSLS
    float3 LsMul : TEXCOORD8;
    float3 LsAdd : COLOR1;
#endif

#if defined(_DX11) && defined(WITH_ClipPlane)
    float oClip0 : SV_ClipDistance0;
#endif

#if defined(_DX11) && defined(_FRAGMENT_SHADER) && !defined(WITH_AlphaBlend) && !defined(WITH_GBuffer) && !defined(WITH_HemDir3)
    uint isFrontFace : SV_IsFrontFace;
#endif
};

#endif // ___FRPG_Flver_FRPG_Common_VTX_OUT_fxh___
