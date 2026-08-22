// Copyright (c) FromSoftware, Inc.

#ifndef ___FRPG_Flver_FRPG_Common_VTX_IN_fxh___
#define ___FRPG_Flver_FRPG_Common_VTX_IN_fxh___

// Feature combination flags (define before including):
// #define WITH_BumpMap
// #define WITH_LightMap
// #define WITH_Skin

struct VTX_IN
{
    float3 VecPos    : POSITION;
    uint4  BlendIdx  : BLENDINDICES; // local->world matrix index (all components equal for non-skinned)
#ifdef WITH_Skin
    float4 BlendWeight : BLENDWEIGHT;
#endif
    float3 VecNrm : NORMAL;
#ifdef WITH_BumpMap
    float4 VecTan : TANGENT;
    #ifdef WITH_MultiTexture
        float4 VecTan2 : BINORMAL; // actually a second tangent
    #endif
#endif

    float4 ColVtx : COLOR0; // vertex color

#ifdef WITH_MultiTexture
    #ifdef WITH_LightMap
        QLOC_int4 TexDifDif_int_qloc : TEXCOORD0; // diffuse UV + diffuse UV2
        QLOC_int2 TexLit_int_qloc    : TEXCOORD1; // lightmap UV
        #ifdef WITH_Wind
            half4 WindParam : TEXCOORD2;
        #endif
    #else
        QLOC_int4 TexDifDif_int_qloc : TEXCOORD0; // diffuse UV + diffuse UV2
        #ifdef With_Wind
            QLOC_int4 WindParam : TEXCOORD1;
        #endif
    #endif
#else
    #ifdef WITH_LightMap
        QLOC_int4 TexDifLit_int_qloc : TEXCOORD0; // diffuse UV + lightmap UV
    #else
        QLOC_int2 TexDif_int_qloc : TEXCOORD0;    // diffuse UV
    #endif
    #ifdef WITH_Wind
        QLOC_int4 WindParam : TEXCOORD1;
    #endif
#endif
#ifdef WITH_INSTANCE
    float4 InstCol : INSTANCECOLOR;
    float4 InstUV : INSTANCEUV;
    float4 InstMtx0 : INSTANCEMTX;
    float4 InstMtx1 : INSTANCEMTX1;
    float4 InstMtx2 : INSTANCEMTX2;
    float4 PInstMtx0 : P_INSTANCEMTX;
    float4 PInstMtx1 : P_INSTANCEMTX1;
    float4 PInstMtx2 : P_INSTANCEMTX2;
#endif
};

#endif // ___FRPG_Flver_FRPG_Common_VTX_IN_fxh___
