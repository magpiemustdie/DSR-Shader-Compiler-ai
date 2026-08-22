/***************************************************************************//**

    @file       FRPG_Common.fxh
    @brief      Common shader utilities and lighting functions
    @par        Shared header for vertex and fragment shaders
    @author     itoj
    @version    v1.0

    @note       //<port source info>

    @note       //<port source copyright>

    @note       //<FromSoftware copyright>

    Copyright &copy; @YEAR@ FromSoftware, Inc.

*//***************************************************************************/
/*!
    @par
*/
#ifndef ___FRPG_Flver_FRPG_Common_fxh___
#define ___FRPG_Flver_FRPG_Common_fxh___

#ifdef _PS3
#define _PS3_   //PS3
#endif

#ifdef _X360
#define _Xenon_  //Xbox360
#endif

#ifdef _WIN32
#define _WIN32_  //Windows
#endif

#if defined(_ORBIS) && defined(_NEO) // QLOC: 4k checkerboard rendering, this will increase texture quality when rendering checkerboarded - MPursche
#pragma argument(gradientadjust=always)
#pragma argument(barycentricmode=sample)
#pragma argument(nofastmath)
#endif

//** vertex shader constants
#ifdef ENABLE_VS
    #include "FRPG_Common_VC.fxh"
#endif

//** fragment shader constants
#ifdef ENABLE_FS
    #include "FRPG_Common_FC.fxh"
#endif

#include "../Common/dx11.h" //qloc: dx11
#include "../Common/FRPG_HALFDefine.fxh"

#if defined(_PS3_)//PS3
#elif defined(_Xenon_)//XBOX360
#elif defined(_WIN32_)//WIN32
    //2012.02.17:itoj>disable warning X3205: conversion from larger type to smaller, possible loss of data
    //#pragma warning( disable : 3205 3205 )
    #pragma warning( once : 3205 )
    //#pragma warning( error : 3205 )
#else
    unknown // unrecognized platform
#endif

#define MAX_POINT_LIGHTS 4
#define MAX_DIR_LIGHTS 3

#define SHADOWMAP_ENABLE
#define CLIPPLANE_ENABLE

// Perform tonemapping linearly (tonemap in range 0 to Range)
// Brightness exceeding Range cannot be represented
// Setting to 0 uses a non-linear tonemapping formula (can represent infinite brightness)
#define TONEMAP_LINEAR_VER      1

// Define "PS3_NORMAL_REMAP" to use the PS3 remap normal format
#define PS3_NORMAL_REMAP

//2012.01.04:itoj>deprecated
//// Define "VSLS" to process light scattering in the vertex shader
////#define VSLS

// Define "CALC_VS_BINORMAL" to calculate the binormal in the vertex shader
#define CALC_VS_BINORMAL
#ifdef _WIN32
#ifndef _DX11 //qloc: removed in dx11
    #undef CALC_VS_BINORMAL //On Win32, output registers are insufficient to calculate in the vertex shader
#endif
#endif //_WIN32

#define EMISSIVE_STRENGTH 10.f //qloc

// Where to calculate the shadow map position
#define CalcLispPos_VS 1
#define CalcLispPos_PS 2

#define CalcLispPos_PS_Csd 2
#define CalcLispPos_PS_NoCsd 3

//** vertex shader input
#ifdef ENABLE_VS
    #include "FRPG_Common_VTX_IN.fxh"
#endif

//** vertex shader output
#include "FRPG_Common_VTX_OUT.fxh"

//** fragment shader output
#ifdef ENABLE_FS
    //! fragment shader output
    struct GBUFFER_OUT
    {
        float4 GBuffer0 : SV_Target0;
        float4 GBuffer1 : SV_Target1; //qloc: subsurface scattering strength. We don't seem to ever modify it so it might be a good idea to move it to the stencil
    };
    //! fragment shader output
    struct FRAGMENT_OUT
    {
        float4 Color : SV_Target0;
    };
    //qloc
    struct PS_OUT_SFX
    {
        float4 Color : SV_Target0;
        float4 Glow : SV_Target1;
    };
#endif

//** sampler
#ifdef ENABLE_FS
    #include "FRPG_Common_SMP.fxh"
#endif

#ifdef ENABLE_FS
#ifndef WITH_GBuffer
    #include "FRPG_Common_ForwardPBL.fxh"
#endif
#endif

//** point light type definitions
#define POINT_LIGHT_TYPE_None 0     //!< none
#define POINT_LIGHT_TYPE_Distance 1 //!< distance attenuation
#define POINT_LIGHT_TYPE_Diffuse 2  //!< diffuse + distance attenuation
#define POINT_LIGHT_TYPE_Specular 3 //!< specular + diffuse + distance attenuation
// To enable point lights, #undef the settings below and apply the settings above
#define POINT_LIGHT_0 POINT_LIGHT_TYPE_None //!< point light 0
#define POINT_LIGHT_1 POINT_LIGHT_TYPE_None //!< point light 1
#define POINT_LIGHT_2 POINT_LIGHT_TYPE_None //!< point light 2
#define POINT_LIGHT_3 POINT_LIGHT_TYPE_None //!< point light 3

// Macro to convert the calculated color to the format for output to the framebuffer
//QLOC: removed tonemapping from base shader - it will be reapplied in the PostFX
#ifdef _DX11 //qloc: apply alpha test
    //#define         FS_FINAL_COLOR(col)         (qlocDoAlphaTest(col))
    #define         FS_FINAL_COLOR(col)         (qlocDoAlphaTest(ToneMap_FS(col)))
    //#define         FS_FINAL_COLOR( col )       (qlocDoAlphaTest( col * gFC_ColorRangeScale ))
#else
    //#define         FS_FINAL_COLOR(col)         (col)
    #define         FS_FINAL_COLOR(col)         (ToneMap_FS(col))
    //#define         FS_FINAL_COLOR( col )       ( col * gFC_ColorRangeScale )
#endif

#ifdef _PS3
#define         FRPG_H4Tex2D(tex, coord)            h4tex2D(tex, coord)
#define         FRPG_H2Tex2D(tex, coord)            h2tex2D(tex, coord)
#else
#define         FRPG_H4Tex2D(tex, coord)            tex2D(tex, coord)
#define         FRPG_H2Tex2D(tex, coord)            (tex2D(tex, coord).xy)
#endif

#ifndef WITHOUT_DETAILBUMP
#define WITH_DETAILBUMP
#endif
#ifdef WITH_DETAILBUMP
    #define APPLY_DETAIL_BUMP_TAN( pixNrm, vecTan, texUv )  pixNrm = ApplyDetailBump( texUv, pixNrm, vecTan )
    #define APPLY_DETAIL_BUMP( pixNrm, texUv )  pixNrm = ApplyDetailBump( texUv, pixNrm )
#else
    #define APPLY_DETAIL_BUMP_TAN( pixNrm, vecTan, texUv )
    #define APPLY_DETAIL_BUMP( pixNrm, texUv )
#endif

#define FRPG_CLAMP(_x, _fmin, _fmax) max(_fmin, min(_x, _fmax))

/*-------------------------------------------------------------------*//*!
@brief Compress color with tonemap
@param[in] col color
@return Tonemapped color (alpha value unchanged)
@par
*/
float4
ToneMap_FS(float4 col)
{
    // exposure scale
    col.rgb *= gFC_ToneMap.x;

    // tonemap
#if TONEMAP_LINEAR_VER
    col.rgb /= gFC_ToneMap.y;
    col.rgb = saturate(col.rgb);
#else
    col.rgb /= (gFC_ToneMap.y+col.rgb);
#endif

    return col;
}

/*-------------------------------------------------------------------*//*!
@brief Calculate and get the eye vector (vertex shader side)
@param[in] vecPos vertex position (world space)
@param[in] camPos camera position (world space)
@return eye vector (world space) (xyz: unnormalized vertex-to-camera vector, w: 0.0)
@par
    Storing the vertex-to-camera distance would break interpolation when w=0 is inserted, so it is not stored.<br>
    Therefore, the eye vector is stored unnormalized, and normalization and distance calculation are done on the fragment shader side.<br>
*/
float4
CalcGetVecEye_VS(float4 vecPos, float4 camPos)
{
    float4 vecEye;
    vecEye.xyz = camPos.xyz - vecPos.xyz;   //vector from vertex to camera (world space)
    vecEye.w = 0.0f;    //0.0
    return vecEye;
}

/*-------------------------------------------------------------------*//*!
@brief Calculate and get the eye vector (fragment shader side)
@param[in] vsVecEye eye vector calculated in the vertex shader
@return eye vector (world space) (xyz: normalized vertex-to-camera vector, w: vertex-to-camera distance)
@par
    Calculates the distance that could not be obtained on the vertex shader side, and also normalizes the vector.<br>
*/
float4
CalcGetVecEye_FS(float4 vsVecEye)
{
    float4 vecEye;
    vecEye.w = length(vsVecEye.xyz);    //distance from vertex to camera
    vecEye.xyz = vsVecEye.xyz / vecEye.w;   //normalize
    return vecEye;
}

/*-------------------------------------------------------------------*//*!
@brief Decode normal from normal texture
@param[in] normalTexSmp normal texture sampler
@param[in] texUv texture UV
@return decoded normal // normalized
@par
*/
float3
DecodeNormalMap(TEX2DSAMPLERDECL(normalTexSmp), float2 texUv)
{
    HALF3 vecTex;
    #ifdef PS3_NORMAL_REMAP //PS3 remap format; 360 CTX1/DXN also use PS3_NORMAL_REMAP decoding
        vecTex.xy = FRPG_H2Tex2D(normalTexSmp, texUv) * 2.0f - 1.0f; //decode texture normal
    #else //PS3_NORMAL_REMAP //standard format
        //Normal texture decoding
        //DXT1 encoding: (r,g,b,a) = (x, y, 1, 1)
        //DXT5 encoding: (r,g,b,a) = (1, y, 1, x)
        //Encoding differs by texture format, but
        //(X, Y, Z) = (r*a, g, Z), Z = sqrt(1-X*X-Y*Y)
        //allows format differences to be ignored
        HALF4 colTex = FRPG_H4tex2D(normalTexSmp, texUv);  //sample normal texture
        vecTex.xy = colTex.rg * colTex.ab * 2.0f - 1.0f;  //decode texture normal
    #endif //PS3_NORMAL_REMAP
    vecTex.z = sqrt(1.0f - saturate(dot(vecTex.xy, vecTex.xy)));
    //vecTex = normalize(vecTex); //unnecessary
    return vecTex;
}

/*-------------------------------------------------------------------*//*!
@brief Apply Detail Bump - version with tangent and binormal
@param[in] texUv texture UV
@param[in] normal // normalized
@param[in] tangent // normalized
@param[in] binormal // normalized
@return normal with detail bump applied
@par
*/
HALF3
_ApplyDetailBump(float2 texUv, HALF3 vecNrm, HALF3 vecTan, HALF3 vecBin)
{
    HALF3 detailBump = DecodeNormalMap(TEX2DSAMPLER(gSMP_DetailBumpMap), (texUv*gFC_DetailBumpParam.xx) );
    detailBump.xy *= gFC_DetailBumpParam.w;
    detailBump.z += (dot(detailBump.xy,detailBump.xy) < 0.00001f); //avoid zero divide; detailBump.z will not go negative
    detailBump = normalize(detailBump); //normalize

    HALF3 pixDNormal = normalize(vecBin*detailBump.x+vecTan*detailBump.y+vecNrm*detailBump.z);
    return pixDNormal;
}

/*-------------------------------------------------------------------*//*!
@brief Apply Detail Bump - version with tangent
@param[in] texUv texture UV
@param[in] normal // normalized
@param[in] tangent // normalized
@return normal with detail bump applied
@par
*/
HALF3
ApplyDetailBump(float2 texUv, HALF3 vecNrm, HALF4 vecTan)
{
    HALF3 vecBin = normalize(cross(vecNrm, vecTan.xyz))*vecTan.w;
    vecTan.xyz = normalize(cross(vecBin, vecNrm));

    return _ApplyDetailBump(texUv, vecNrm, vecTan.xyz, vecBin);
}

/*-------------------------------------------------------------------*//*!
@brief Apply Detail Bump - version without tangent
@param[in] texUv texture UV
@param[in] normal // normalized
@return normal with detail bump applied
@par
*/
HALF3
ApplyDetailBump(float2 texUv, HALF3 vecNrm)
{
    HALF3 vecBin = vecNrm.zyx;
    HALF3 vecTan = vecNrm.xzy;

    return _ApplyDetailBump(texUv, vecNrm, vecTan, vecBin);
}

/*-------------------------------------------------------------------*//*!
@brief Calculate normal from normal texture
@param[in] normalTexSmp normal texture sampler
@param[in] texUv texture UV
@param[in] vecNrm primary normal
@param[in] vecTan tangent (w: binormal direction)
@return normal
@par
    Calculates the binormal from the primary normal and tangent.<br>
    The primary normal and tangent do not need to be normalized (normalized internally).<br>
    vecTan.w is multiplied into the resulting binormal.<br>
*/
HALF3
CalcGetNormal_FromNormalTex(TEX2DSAMPLERDECL(normalTexSmp), float2 texUv, HALF3 vecNrm, HALF4 vecTan)
{
    HALF3 vecTex = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp), texUv);

    //decode primary normal, tangent, binormal
    vecNrm = normalize(vecNrm);         //normal normalize
    vecTan.xyz = normalize(vecTan.xyz); //tangent normalize

    HALF3 vecBin = normalize(cross(vecNrm, vecTan.xyz) * vecTan.w); //generate binormal
    /*if being thorough, recalculate tangent here*/
    //  vecTan.xyz = cross(vecBin, vecNrm) * vecTan.w; //recalculate tangent
    /**/

    //calculate final normal from texture normal, primary normal, tangent, and binormal
    HALF3 pixNrm = normalize(vecBin*vecTex.x + vecTan.xyz*vecTex.y + vecNrm*vecTex.z);

    APPLY_DETAIL_BUMP_TAN(pixNrm, vecTan, texUv );
    return pixNrm;
}

/*-------------------------------------------------------------------*//*!
@brief Calculate normal from normal texture - multi version
@param[in] normalTexSmp normal texture sampler
@param[in] texUv texture UV + UV2
@param[in] vecNrm primary normal
@param[in] vecTan tangent (w: binormal direction)
@param[in] vecTan2 tangent (w: binormal direction)
@param[in] blendRate blend rate
@return normal
@par
    Calculates the binormal from the primary normal and tangent.<br>
    The primary normal and tangent do not need to be normalized (normalized internally).<br>
    vecTan.w is multiplied into the resulting binormal.<br>
*/
HALF3
CalcGetNormal_FromNormalTex_Mul(TEX2DSAMPLERDECL(normalTexSmp), TEX2DSAMPLERDECL(normalTexSmp2), float4 texUv, HALF3 vecNrm, HALF4 vecTan, HALF4 vecTan2, HALF blendRate)
{
    HALF3 vecTex = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp), texUv.xy);
    HALF3 vecTex2 = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp2), texUv.zw);

    //decode primary normal, tangent, binormal
    vecNrm = normalize(vecNrm);             //normal normalize
    vecTan.xyz = normalize(vecTan.xyz);     //tangent normalize
    vecTan2.xyz = normalize(vecTan2.xyz);   //tangent normalize

    HALF3 vecBin = normalize(cross(vecNrm, vecTan.xyz) * vecTan.w);   //generate binormal
    HALF3 vecBin2 = normalize(cross(vecNrm, vecTan2.xyz) * vecTan2.w); //generate binormal
    /*if being thorough, recalculate tangent here*/
    //  vecTan.xyz = cross(vecBin, vecNrm) * vecTan.w; //recalculate tangent
    /***/

    //calculate final normal from texture normal, primary normal, tangent, and binormal
    HALF3 vecNrmA = normalize(vecBin*vecTex.x + vecTan.xyz*vecTex.y + vecNrm*vecTex.z);
    HALF3 vecNrmB = normalize(vecBin2*vecTex2.x + vecTan.xyz*vecTex2.y + vecNrm*vecTex2.z);

    HALF3 pixNrm = normalize(lerp(vecNrmA, vecNrmB, blendRate));    //blend normals

    APPLY_DETAIL_BUMP_TAN(pixNrm, vecTan, texUv.xy );
    return pixNrm;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate normal from normal texture (with explicit binormal)
@param[in] normalTexSmp normal texture sampler
@param[in] texUv texture UV
@param[in] vecNrm primary normal
@param[in] vecTan tangent (w: binormal direction)
@param[in] vecBin binormal
@return normal
@par
    Calculates the binormal from the primary normal and tangent.<br>
    The primary normal and tangent do not need to be normalized (normalized internally).<br>
    vecTan.w is multiplied into the resulting binormal.<br>
*/
HALF3
CalcGetNormal_FromNormalTex_Bin(TEX2DSAMPLERDECL(normalTexSmp), float2 texUv, HALF3 vecNrm, HALF4 vecTan, HALF3 vecBin)
{
    HALF3 vecTex = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp), texUv);

    //decode primary normal, tangent, binormal
    vecNrm = normalize(vecNrm);         //normal normalize
    vecTan.xyz = normalize(vecTan.xyz); //tangent normalize

    vecBin = normalize(vecBin); //normalize

    /*if being thorough, recalculate tangent here*/
    //  vecTan.xyz = cross(vecBin, vecNrm) * vecTan.w; //recalculate tangent
    /***/

#ifndef WITH_GBuffer
    // GB ref does NOT apply normalScale (no c194.z in ref PntSS asm)
    vecTex = lerp(float3(0,0,1), vecTex, gFC_NormalScale);
#endif

    //calculate final normal from texture normal, primary normal, tangent, and binormal
    HALF3 pixNrm = normalize(vecBin*vecTex.x + vecTan.xyz*vecTex.y + vecNrm*vecTex.z);

    APPLY_DETAIL_BUMP_TAN(pixNrm, vecTan, texUv );
    return pixNrm;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate normal from normal texture - multi version (with explicit binormals)
@param[in] normalTexSmp normal texture sampler
@param[in] texUv texture UV + UV2
@param[in] vecNrm primary normal
@param[in] vecTan tangent (w: binormal direction)
@param[in] vecTan2 tangent (w: binormal direction)
@param[in] vecBin binormal
@param[in] vecBin2 binormal 2
@param[in] blendRate blend rate
@return normal
@par
    Calculates the binormal from the primary normal and tangent.<br>
    The primary normal and tangent do not need to be normalized (normalized internally).<br>
    vecTan.w is multiplied into the resulting binormal.<br>
*/
HALF3
CalcGetNormal_FromNormalTex_Mul_Bin(TEX2DSAMPLERDECL(normalTexSmp), TEX2DSAMPLERDECL(normalTexSmp2), float4 texUv, HALF3 vecNrm, HALF4 vecTan, HALF4 vecTan2, HALF3 vecBin, HALF3 vecBin2, HALF blendRate)
{
    HALF3 vecTex = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp), texUv.xy);
    HALF3 vecTex2 = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp2), texUv.zw);

    //decode primary normal, tangent, binormal
    vecNrm = normalize(vecNrm);             //normal normalize
    vecTan.xyz = normalize(vecTan.xyz);     //tangent normalize
    vecTan2.xyz = normalize(vecTan2.xyz);   //tangent normalize

    vecBin = normalize(vecBin);   //normalize
    vecBin2 = normalize(vecBin2); //normalize

    /*if being thorough, recalculate tangent here*/
    //  vecTan.xyz = cross(vecBin, vecNrm) * vecTan.w; //recalculate tangent
    /***/
#ifndef WITH_GBuffer
    // GB ref does NOT apply normalScale (no c194.z in ref PntSS asm)
    vecTex = lerp(float3(0, 0, 1), vecTex, gFC_NormalScale);
    vecTex2 = lerp(float3(0, 0, 1), vecTex2, gFC_NormalScale);
#endif

    //calculate final normal from texture normal, primary normal, tangent, and binormal
    HALF3 vecNrmA = normalize(vecBin*vecTex.x + vecTan.xyz*vecTex.y + vecNrm*vecTex.z);
    HALF3 vecNrmB = normalize(vecBin2*vecTex2.x + vecTan.xyz*vecTex2.y + vecNrm*vecTex2.z);

    HALF3 pixNrm = normalize(lerp(vecNrmA, vecNrmB, blendRate));    //blend normals

    APPLY_DETAIL_BUMP_TAN(pixNrm, vecTan, texUv.xy );
    return pixNrm;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get hemisphere light color
@param[in] hemLightCol_u upper hemisphere color
@param[in] hemLightCol_d lower hemisphere color
@param[in] lerpRate 0.0:hemLightCol_d ~ 1.0:hemLightCol_u
@return hemisphere light color
@par
    Calculates output color from the y component of the normal.<br>
*/
float3
CalcGetHemLightCol(float3 hemLightCol_u, float3 hemLightCol_d, float lerpRate)
{
    return lerp(hemLightCol_d, hemLightCol_u, lerpRate);
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get directional light diffuse color (single directional light)
@param[in] vecNrm normal (normalized)
@param[in] vecLightA directional light A direction (normalized)
@param[in] colLightA directional light A color
@return directional light diffuse color
@par
*/
float3
CalcGetDirDifLightCol_1(float3 vecNrm, float3 vecLightA, float3 colLightA)
{
    return colLightA*max(-dot(vecLightA.xyz, vecNrm), 0.0f);
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get directional light diffuse color
@param[in] vecNrm normal (normalized)
@param[in] vecLightA directional light A direction (normalized)
@param[in] vecLightB directional light B direction (normalized)
@param[in] vecLightC directional light C direction (normalized)
@param[in] colLightA directional light A color
@param[in] colLightB directional light B color
@param[in] colLightC directional light C color
@return directional light diffuse color
@par
*/
float3
CalcGetDirDifLightCol(float3 vecNrm, float3 vecLightA, float3 vecLightB, float3 vecLightC, float3 colLightA, float3 colLightB, float3 colLightC)
{
    return colLightA*max(-dot(vecLightA.xyz, vecNrm), 0.0f)
         + colLightB*max(-dot(vecLightB.xyz, vecNrm), 0.0f)
         + colLightC*max(-dot(vecLightC.xyz, vecNrm), 0.0f);
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get reflected eye vector
@param[in] vecNrm normal (normalized)
@param[in] vecEye eye direction vector (normalized)
@return reflected eye vector
@par
    vecEye is the vector from the vertex to the viewpoint.<br>
*/
float3
CalcGetDirSpcLightCol(float3 vecNrm, float3 vecEye)
{
    return -vecEye + 2.0f * dot( vecNrm, vecEye ) * vecNrm;    //eye vector reflected across the normal
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get directional light specular color (single directional light)
@param[in] vecRef reflected eye direction vector (normalized)
@param[in] spcParam specular parameter
@param[in] vecLightA directional light A direction (normalized)
@param[in] colLightA directional light A color
@return directional light specular color
@par
    vecEye is the vector from the vertex to the viewpoint.<br>
*/
float3
CalcGetDirSpcLightCol_1(float3 vecRef, float4 spcParam, float3 vecLightA, float3 colLightA)
{
    float spcInt;   //specular intensity
    spcInt = -dot(vecRef, vecLightA);
    spcInt = pow(max(spcInt, 0.0f), spcParam.x);

    return colLightA*spcInt;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get directional light specular color
@param[in] vecRef reflected eye direction vector (normalized)
@param[in] spcParam specular parameter
@param[in] vecLightA directional light A direction (normalized)
@param[in] vecLightB directional light B direction (normalized)
@param[in] vecLightC directional light C direction (normalized)
@param[in] colLightA directional light A color
@param[in] colLightB directional light B color
@param[in] colLightC directional light C color
@return directional light specular color
*/
float3
CalcGetDirSpcLightCol(float3 vecRef, float4 spcParam, float3 vecLightA, float3 vecLightB, float3 vecLightC, float3 colLightA, float3 colLightB, float3 colLightC)
{
    float3 spcInt;  //specular intensity
    spcInt.x = -dot(vecRef, vecLightA);
    spcInt.y = -dot(vecRef, vecLightB);
    spcInt.z = -dot(vecRef, vecLightC);
    spcInt = pow(max(spcInt, 0.0f), spcParam.x);

    return colLightA*spcInt.x + colLightB*spcInt.y + colLightC*spcInt.z;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get environment diffuse light color
@param[in] vecNrm normal (normalized)
@param[in] envLightTexSmp environment light texture sampler
@return environment diffuse light color
@par
*/
float3
CalcGetEnvDifLightCol(float3 vecNrm, TEXCUBESAMPLERDECL(envLightTexSmp))
{
//  return texCUBE(envLightTexSmp, vecNrm).rgb;
    float4 col = texCUBE(envLightTexSmp, vecNrm);// , gFC_LightProbeSlot);
//  return (col.rgb / col.a); //col.rgb/max(col.a, 1.f/255.f);
    return col.rgb; //col.rgb/max(col.a, 1.f/255.f);
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get environment specular light color
@param[in] vecRef reflected eye direction vector (normalized)
@param[in] envLightTexSmp environment light texture sampler
@return environment specular light color
*/
float3
CalcGetEnvSpcLightCol(float3 vecRef, TEXCUBESAMPLERDECL(envLightTexSmp))
{
//  return texCUBE(envLightTexSmp, vecRef).rgb;
    float4 col = texCUBE(envLightTexSmp, vecRef);// , gFC_LightProbeSlot);
//  return (col.rgb / col.a); //col.rgb/max(col.a, 1.f/255.f);
    return col.rgb; //col.rgb/max(col.a, 1.f/255.f);
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get point light distance-attenuated color
@param[in] vecVtx vertex position (world space)
@param[in] pntLitPos point light position (xyz: position, w: 1/(attenuation end distance - attenuation start distance)) (world space)
@param[in] pntLitCol point light color (rgb: color, a: attenuation end distance)
@return point light distance-attenuated color
@par
*/
float3
CalcGetPntLengthLightCol(float3 vecVtx, float4 pntLitPos, float4 pntLitCol)
{
    const float len = length(pntLitPos.xyz - vecVtx);   //distance from vertex to point light
    return pntLitCol.rgb * saturate((pntLitCol.w-len)*pntLitPos.w);
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get point light direction and attenuation factor
@param[in] vecVtx vertex position (world space)
@param[in] pntLitPos point light position (xyz: position, w: 1/(attenuation end distance - attenuation start distance)) (world space)
@param[in] pntLitCol point light color (rgb: color, a: attenuation end distance)
@return point light direction and attenuation factor (xyz: point light direction (normalized), w: attenuation factor)
@par
*/
float4
CalcGetVecPnt(float3 vecVtx, float4 pntLitPos, float4 pntLitCol)
{
    float4 vecPnt;
    vecPnt.xyz = pntLitPos.xyz - vecVtx;    //vector from vertex to point light
    vecPnt.w = length(vecPnt.xyz);          //distance from vertex to point light
    vecPnt.xyz /= vecPnt.w;                 //normalize vector from vertex to point light
    vecPnt.w = saturate((pntLitCol.w-vecPnt.w)*pntLitPos.w);
    return vecPnt;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get point light diffuse color
@param[in] vecNrm normal (normalized)
@param[in] vecPnt point light direction (xyz: vertex to light) (normalized)
@param[in] colPnt point light color (rgb: color) (attenuated)
@return point light diffuse color
@par
*/
float3
CalcGetPntDifLightCol(float3 vecNrm, float3 vecPnt, float3 colPnt)
{
    return colPnt*max(dot(vecPnt.xyz, vecNrm), 0.0f);
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get point light specular color
@param[in] vecRef reflected eye direction vector (normalized)
@param[in] spcParam specular parameter
@param[in] vecPnt point light direction (xyz: vertex to light) (normalized)
@param[in] colPnt point light color (rgb: color) (attenuated)
@return point light specular color
@par
    vecEye is the vector from the vertex to the viewpoint.<br>
*/
float3
CalcGetPntSpcLightCol(float3 vecRef, float4 spcParam, float3 vecPnt, float3 colPnt)
{
    float spcInt;   //specular intensity
    spcInt = dot(vecRef, vecPnt);
    spcInt = pow(max(spcInt, 0.0f), spcParam.x);

    return colPnt*spcInt;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get ghost light source direction and attenuation factor
@param[in] vecVtx vertex position (world space)
@return ghost light source direction and attenuation factor (xyz: light direction (normalized), w: attenuation factor)
@par
*/
float4
CalcGetGhostLightVec(float3 vecVtx)
{
    //@param[in] gFC_GhostLightPos light position (xyz: position, w: 1/(attenuation end distance - attenuation start distance)) (world space)
    //@param[in] gFC_GhostLightCol light color (rgb: color, a: attenuation end distance)

    float4 vecPnt;
    vecPnt.xyz = gFC_GhostLightPos.xyz - vecVtx;    //vector from vertex to point light
    vecPnt.w = length(vecPnt.xyz);  //distance from vertex to point light
    vecPnt.xyz /= vecPnt.w;         //normalize vector from vertex to point light
    vecPnt.w = saturate((gFC_GhostLightCol.w-vecPnt.w)*gFC_GhostLightPos.w);
    return vecPnt;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get ghost light diffuse color
@param[in] vecNrm normal (normalized)
@param[in] vecPnt point light direction (xyz: vertex to light) (normalized)
@param[in] colPnt point light color (rgb: color) (attenuated)
@return ghost light diffuse color
@par
*/
float3
CalcGetGhostLightDifLightCol(float3 vecNrm, float3 vecPnt, float3 colPnt)
{
    return colPnt*max(dot(vecPnt.xyz, vecNrm), 0.0f);
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get ghost light specular color
@param[in] vecRef reflected eye direction vector (normalized)
@param[in] spcParam specular parameter
@param[in] vecPnt ghost light direction (xyz: vertex to light) (normalized)
@param[in] colPnt ghost light color (rgb: color) (attenuated)
@return ghost light specular color
@par
    vecEye is the vector from the vertex to the viewpoint.<br>
*/
float3
CalcGetGhostLightSpcLightCol(float3 vecRef, float4 spcParam, float3 vecPnt, float3 colPnt)
{
    float spcInt;   //specular intensity
    spcInt = dot(vecRef, vecPnt);
    spcInt = pow(max(spcInt, 0.0f), spcParam.x);

    return colPnt*spcInt;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get fog coefficient from fog parameters
@param[in] vecPos vertex position in clip space
@param[in] fogParam fog parameters (x: start position in view space, y: end position in view space - start position in view space, z: unknown/unclear, w: fog coefficient multiplier)
@return fog coefficient
*/
float
CalcGetFogCoef(float4 vecPos, float4 fogParam)
{
    {//GL_LINEAR equivalent
        //f = (z - start)/(end - start)
        //return (vecPos.w-fogParam.x)/fogParam.y;
        //float fogCoef = saturate( (vecPos.w-fogParam.x)/fogParam.y );
        float fogCoef = (vecPos.w-fogParam.x)*fogParam.y ;
        //return saturate(fogCoef); //saturate is done on the PS side
        return fogCoef;
    }

    //GL_EXP equivalent
    //f = exp(-(density - z))


    //GL_EXP2 equivalent
    //f = exp(-((density - z)^2))
}
/*-------------------------------------------------------------------*//*!
@brief Blend input color with fog color using fog coefficient
@param[in] inCol input color
@param[in] fogCol fog color
@param[in] fogCoef fog coefficient (0.0: input color, 1.0: fog color)
@return output color
*/
float4
CalcGetFogCol(float4 inCol, float4 fogCol, float fogCoef)
{
    //Note: blending alpha would break translucency, so alpha is excluded for now
    //return float4(lerp(inCol.rgb, fogCol.rgb, fogCol.a*saturate(fogCoef)), inCol.a);
    //return float4(lerp(inCol.rgb, fogCol.rgb, fogCol.a*saturate(fogCoef)), inCol.a);

    float mulFogCoef = fogCol.a*saturate(fogCoef);
    return float4(lerp(inCol.rgb, fogCol.rgb, saturate(mulFogCoef) ), inCol.a);
}
/*-------------------------------------------------------------------*//*!
@brief Blend input color with light scattering color
@param[in] inCol input color
@param[in] eyeVec eye vector (world space) (xyz: normalized vertex-to-camera vector, w: vertex-to-camera distance)
@return output color
*/
float4
CalcGetLightScatteringCol(float4 inCol, float4 eyeVec)
{
    float dotEL = -dot(eyeVec.xyz, gFC_LsLightDir.xyz);    //dot product of eye vector and light vector
    float phase1 = dotEL * dotEL + 1.0f;


    //Is this multiplication necessary...??
    //ref: exp2(2.08136892 * (-LsBeta1PlusBeta2 * dist * LsLightDir.w)) — 2.08136892 = log2(e)^2, literal must match ref
    float3 extinction = exp2(-gFC_LsBeta1PlusBeta2.xyz * eyeVec.w * gFC_LsLightDir.w * 2.08136892f);    //Note: gFC_LsLightDir.w is the distance multiplier

    //value to multiply into pixel color
    float3 totalExtinction = extinction * gFC_LsTerrainReflectance.rgb;

    //itoj: not sure, but since we convert the light vector direction to vertex->camera when computing dotEL, the minus sign is unnecessary? //original implementation had no minus sign, accounting for light vector inversion
    float tmp = gFC_LsHGg.z * dotEL + gFC_LsHGg.y;//minus sign is unnecessary //float tmp = -gFC_LsHGg.z * dotEL + gFC_LsHGg.y;
    float phase2 = rsqrt(tmp) * (1.0f/tmp) * gFC_LsHGg.x;


    float3 inscattering = (gFC_LsBetaDash1.xyz*phase1 + gFC_LsBetaDash2.xyz*phase2) * (1.0f - extinction) * gFC_LsOneOverBeta1PlusBeta2.xyz;

    //coefficient
    inscattering *= gFC_LsTerrainReflectance.w;    //Note: gFC_LsTerrainReflectance.w is the inscattering multiplier

    //color after scattering
    float3 scatCol = inCol.rgb*totalExtinction + gFC_LsSunColor.rgb*inscattering;

    //blend
    float3 outcol = float3(lerp(inCol.rgb, scatCol, gFC_LsSunColor.a));
    return float4(outcol, inCol.a);    //Note: gFC_LsSunColor.a is the blend rate
}

#ifdef OLD_VERSION

//VSLS
/*-------------------------------------------------------------------*//*!
@brief Light scattering color
@param[in] eyeVec eye vector (world space) (xyz: normalized vertex-to-camera vector, w: vertex-to-camera distance)
@return Extinction
*/

float3
CalcGetLightScatteringCol_Extinction(float4 eyeVec)
{
    //Is this multiplication necessary...??
    float3 extinction = exp2(-gVC_LsBeta1PlusBeta2.xyz * eyeVec.w * gVC_LsLightDir.w * 2.08136892f);    //Note: gVC_LsLightDir.w is the distance multiplier
    return extinction;
}
/*-------------------------------------------------------------------*//*!
@brief Light scattering color
@param[in] Extinction
@return totalExtinction
*/

float3
CalcGetLightScatteringCol_TotalExtinction(float3 extinction)
{
    //value to multiply into pixel color
    float3 totalExtinction = extinction * gVC_LsTerrainReflectance.rgb;
    return totalExtinction;
}
/*-------------------------------------------------------------------*//*!
@brief Light scattering color
@param[in] Extinction
@return output color (xyz: light scattering color, w: BlendRate)
*/
float4
CalcGetLightScatteringCol_InScatColor(float4 eyeVec, float3 extinction)
{
    float dotEL = -dot(eyeVec.xyz, gVC_LsLightDir.xyz);    //dot product of eye vector and light vector
    float phase1 = dotEL * dotEL + 1.0f;

    //itoj: not sure, but since we convert the light vector direction to vertex->camera when computing dotEL, the minus sign is unnecessary? //original implementation had no minus sign, accounting for light vector inversion
    float tmp = gVC_LsHGg.z * dotEL + gVC_LsHGg.y;//minus sign is unnecessary //float tmp = -gVC_LsHGg.z * dotEL + gVC_LsHGg.y;
    float phase2 = rsqrt(tmp) * (1.0f/tmp) * gVC_LsHGg.x;

    float3 inscattering = (gVC_LsBetaDash1.xyz*phase1 + gVC_LsBetaDash2.xyz*phase2) * (1.0f - extinction) * gVC_LsOneOverBeta1PlusBeta2.xyz;

    //coefficient
    inscattering *= gVC_LsTerrainReflectance.w;    //Note: gVC_LsTerrainReflectance.w is the inscattering multiplier

    //color after scattering
    float4 scatCol;
    scatCol.rgb = gVC_LsSunColor.rgb*inscattering;
    scatCol.a = gVC_LsSunColor.a;

    return scatCol;
}
/*-------------------------------------------------------------------*//*!
@brief Multiply factor for light scattering color calculation on PS side
@param[in] Extinction
@return output color (xyz: light scattering color, w: BlendRate)
*/
float3
CalcGetLightScatteringMulFactor(float3 te, float4 scatCol)
{
    //PS side calculation is:
    // FScatC = FinalC*totalExtinction+scatCol.rgb
    // blend = scatCol.a
    // FinalC+ (FScatC-FinalC)* blend  -> Lerp(FinalC, FScatC, blend);
    // FinalC+ FScatC*blend-FinalC*blend
    // FinalC*(1-blend)+(FinalC*totalExtinction+scatCol.rgb)*blend
    // FinalC*(1-blend+blend*totalExtinction)+scatCol.rgb*A
    // Pass to PS: (1-blend+blend*totalExtinction)(multiply) and scatCol.rgb*blend(add)

    // 1+blend*totalExtinction-blend
    // 1+(totalExtinction-1)*blend
    float3 ret = (te-(1.f).xxx)*scatCol.a+(1.f).xxx;
    return ret;
}
/*-------------------------------------------------------------------*//*!
@brief Add factor for light scattering color calculation on PS side
@param[in] light scattering color
@return output color (xyz: light scattering color, w: BlendRate)
*/
float3
CalcGetLightScatteringAddFactor(float4 scatCol)
{
    //see above for explanation
    return scatCol.rgb*scatCol.a;
}


#endif // OLD_VERSION

/*-------------------------------------------------------------------*//*!
@brief Blend input color with light scattering color
@param[in] inCol input color
@param[in] totalExtinction
@param[in] scattering color
@return output color
*/
float4 CalcGetLightScatteringCol_Blend(float4 inCol, float3 LsMul, float3 LsAdd)
{
//  float3 fScatCol= inCol.rgb*totalExtinction+scatCol.rgb;
//  return float4(lerp(inCol.rgb, fScatCol, scatCol.a), inCol.a);    //Note: gVC_LsSunColor.a is the blend rate
//To reduce PS computation, the calculation is decomposed and the necessary values are passed from the vertex shader
    return float4( inCol.rgb*LsMul+LsAdd, inCol.a );
}

/*-------------------------------------------------------------------*//*!
@brief Calculate and get output color (ambient + diffuse + specular)
@param[in] colAmbLight ambient lighting color
@param[in] colDifLight diffuse lighting color
@param[in] colSpcLight specular lighting color
@param[in] colDifTex diffuse texture color
@param[in] colSpcTex specular texture color
@return output color
*/
float4
CalcGetMixCol_AmbDifSpc(float3 colAmbLight, float3 colDifLight, float3 colSpcLight, float4 colDifTex, float4 colSpcTex)
{
//  return float4(colDifTex.rgb*(colAmbLight.rgb+colDifLight.rgb) + colSpcTex.rgb*colSpcLight.rgb, colDifTex.a);
return float4(colDifTex.rgb*(colAmbLight.rgb+colDifLight.rgb) + colSpcTex.rgb*colSpcLight.rgb, colDifTex.a) * gFC_ModelMulCol;
}
/*-------------------------------------------------------------------*//*!
@brief Calculate and get output color (ambient + diffuse)
@param[in] colAmbLight ambient lighting color
@param[in] colDifLight diffuse lighting color
@param[in] colSpcLight specular lighting color
@param[in] colDifTex diffuse texture color
@param[in] colSpcTex specular texture color
@return output color
*/
float4
CalcGetMixCol_AmbDif(float3 colAmbLight, float3 colDifLight, float4 colDifTex)
{
//  return float4(colDifTex.rgb*(colAmbLight.rgb+colDifLight.rgb), colDifTex.a);
    return float4(colDifTex.rgb*(colAmbLight.rgb+colDifLight.rgb), colDifTex.a) * gFC_ModelMulCol;//output alpha support
}

/*-------------------------------------------------------------------*//*!
@brief Restore tonemapped frame color
@param[in] col input color
@return output color
*/
float3
DecodeToneMapColor(float3 col)
{
#if TONEMAP_LINEAR_VER
    col *= gFC_ToneMap.y;
#else
    col = col * gFC_ToneMap.y / (1.0f - col);
#endif
    col /= gFC_ToneMap.x;

    return col;
}

/*-------------------------------------------------------------------*//*!
@brief Ghost effect (translucency)
@param[in] inCol input color
@param[in] vecNrm normal (normalized)
@param[in] vecEye eye direction vector (normalized)
@param[in] targetCol target color
@return output color
*/
//float4
//CalcGetChost(float4 inCol, float3 vecNrm, float3 vecEye, float4 targetCol)
//{
//  float ghostPow = max(abs(dot(vecNrm.xyz, vecEye.xyz)), 0.0f);
//  ghostPow *= ghostPow;
//  return float4(lerp(targetCol.rgb, inCol.rgb*0.3f, ghostPow), inCol.a);
//}
float4
CalcGetGhost_Test(float4 inCol, float3 vecNrm, float3 vecEye, float4 targetCol)
{
/*1st version 60%/
    const float ghostPow = FRPG_CLAMP(abs(dot(vecNrm.xyz, vecEye.xyz)), 0.0f, 0.6f)*(1.0f/0.6f);
    return float4(lerp(targetCol.rgb, inCol.rgb, ghostPow), inCol.a);
/**/

/*2nd version*/
    const float ghostPow = (FRPG_CLAMP(abs(dot(vecNrm.xyz, vecEye.xyz)), 0.1f, 0.7f)-0.1f)*(1.0f/0.6f);
    return float4(lerp(targetCol.rgb, inCol.rgb, ghostPow), inCol.a);
/**/

/*3rd version inverse/
    const float ghostPow = 1.0f - (FRPG_CLAMP(abs(dot(vecNrm.xyz, vecEye.xyz)), 0.7f, 1.0f)-0.7f)*(1.0f/0.30f);
    return float4(lerp(targetCol.rgb, inCol.rgb, ghostPow), inCol.a);
/**/
}
/*-------------------------------------------------------------------*//*!
@brief Ghost effect (inverse)
@param[in] inCol input color
@param[in] vecNrm normal (normalized)
@param[in] vecEye eye direction vector (normalized)
@param[in] targetCol target color
@return output color
*/
//float4
//CalcGetChostInv(float4 inCol, float3 vecNrm, float3 vecEye, float4 targetCol)
//{
//  float ghostPow = min(max((dot(vecNrm.xyz, vecEye.xyz)-0.3f)*(1.3f/0.3f), 0.0f), 1.0f);
//  return lerp(targetCol.rgba, inCol.rgba, ghostPow);
//}

/*-------------------------------------------------------------------*//*!
@brief Ghost effect

@Ghost texture scroll texture removed version

@param[in] ghostTexSmp ghost texture sampler
@param[in] ghostTexSmp2 ghost texture sampler
@param[in] texUv texture UV x2
@param[in] inCol input color
@param[in] vecNrm normal (normalized)
@param[in] vecEye eye direction vector (normalized)
@param[in] ghostEdgeCol ghost edge color
@param[in] ghostTexCol ghost texture color
@param[in] ghostParam ghost parameters (x: blend rate (0.0~1.0), yzw: unused)
@return output color
*/
float4
CalcGetGhost(TEX2DSAMPLERDECL(ghostTexSmp), TEX2DSAMPLERDECL(ghostTexSmp2), float4 texUv, float4 inCol, float3 vecNrm, float3 vecEye, float4 ghostEdgeCol, float4 ghostTexCol, float4 ghostParam)
{
/*1st version/
    const float ghostPow = (FRPG_CLAMP(abs(dot(vecNrm.xyz, vecEye.xyz)), 0.1f, 0.7f)-0.1f)*(1.0f/0.6f);
    return float4(lerp(inCol.rgb, ghostEdgeCol.rgb, (1.0f-ghostPow)*ghostEdgeCol.a), inCol.a);
/**/

/*2nd version*/
    const float3 texCol = (tex2D(ghostTexSmp, texUv.xy).rgb + tex2D(ghostTexSmp2, texUv.zw).rgb) * 0.5f * ghostTexCol.rgb * ghostTexCol.a;
    const float3 edgeCol = ghostEdgeCol.rgb * ghostEdgeCol.a;
    const float ghostPow = (FRPG_CLAMP(abs(dot(vecNrm.xyz, vecEye.xyz)), 0.1f, 0.7f)-0.1f)*(1.0f/0.6f);
    const float3 ghostCol = lerp(edgeCol.rgb, texCol.rgb, ghostPow) * ghostParam.x;

    inCol.rgb += ghostCol.rgb;
    return inCol;

/**/
}
/*-------------------------------------------------------------------*//*!
@brief Ghost effect

@Ghost texture scroll texture removed version

@param[in] inCol input color
@param[in] vecNrm normal (normalized)
@param[in] vecEye eye direction vector (normalized)
@param[in] ghostEdgeCol ghost edge color
@param[in] ghostTexCol ghost texture color
@param[in] ghostParam ghost parameters (x: blend rate (0.0~1.0), yzw: unused)
@return output color
*/
float4
CalcGetGhost_NoTex(float4 inCol, float3 vecNrm, float3 vecEye, float4 ghostEdgeCol, float4 ghostTexCol, float4 ghostParam)
{
    //const float3 texCol = (tex2D(ghostTexSmp, texUv.xy).rgb + tex2D(ghostTexSmp2, texUv.zw).rgb) * 0.5f * ghostTexCol.rgb * ghostTexCol.a;
    const float3 texCol = ghostTexCol.rgb * ghostTexCol.a;
    const float3 edgeCol = ghostEdgeCol.rgb * ghostEdgeCol.a;
    const float ghostPow = (FRPG_CLAMP(abs(dot(vecNrm.xyz, vecEye.xyz)), 0.1f, 0.7f)-0.1f)*(1.0f/0.6f);
    const float3 ghostCol = lerp(edgeCol.rgb, texCol.rgb, ghostPow) * ghostParam.x;

    inCol.rgb += ghostCol.rgb;
    return inCol;
}

//shadow-related functions
#ifndef WITH_GBuffer
#include "FRPG_ShadowFunc.fxh"
#endif



//water surface height definitions

#define encode4ch


//#define chBit    (256.f)         //
#define chBit    (16.f)         //
#define chBitSq  (chBit*chBit)
#define EncodeScale (16.f)      //up to 16 overlapping layers OK



#ifdef encode4ch
#define fullbit (chBitSq*chBitSq-1.f)
#else
#define fullbit (chBitSq*chBit-1.f)
#endif

//4Bit 4Channel
float4 FloatTo16Bit(float f)
{
    float4 encode =  (f.xxxx*fullbit.xxxx)*float4( 1.f/(chBit*chBitSq), 1.f/(chBitSq), 1.f/(chBit), 1.f ) ;
    encode.yzw = fmod(encode.yzw, (chBit).xxx );
    encode = trunc(encode);
    return encode;
}

float4 EncodeWaterHeight(float fHeight)
{
    fHeight = min(fHeight, 1.f);
    float4 encode = FloatTo16Bit(fHeight);
    encode = encode / 255.f;
    return encode;
}

//terrain map model has height stacked 3 layers
float4 EncodeWaterHeight_Terrain(float fHeight)
{
    fHeight = min(fHeight/3.f, 1.f);
    float4 encode = FloatTo16Bit(fHeight);
    encode = encode*3.f / 255.f;
    return encode;
}

float DecodeWaterHeight(float4 color)
{
    float4 height = color;
    return dot(height, float4(chBitSq*chBit*255.f, chBitSq*255.f, chBit*255.f, 255.f )).x/fullbit;
}


float4 InverseEncodeWaterHeight_Terrain(float fHeight)
{
    fHeight = 1.f-(fHeight/3.f);    //Inverse
    float4 encode = FloatTo16Bit(fHeight);
    encode = encode*3.f / 255.f;
    return encode;
}

//terrain map model has height stacked 3 layers
float InverseDecodeWaterHeight(float4 color)
{
    // (45.f/255.f) = (15.f/255.f)*3.f
    color = (45.f/255.f).xxxx-color;    //restore inversed value
    return max(DecodeWaterHeight(color) ,0.f);
}

//dither
//float4 Dither(float4 outCol, float4 vtxScr)
//{
//  float2 scrPos = (vtxScr.xy/vtxScr.w) * float2(1280.f/4.f, 720/4.f) *(0.5f).xx;
//  float fDitherValue = tex2D( gSMP_DitherMatrix ,scrPos).x;
//  outCol.w *= (gFC_DitherParam.x > fDitherValue); //set alpha to 0 if below dither value
//  return outCol;
//}


float4 _TexDiff(TEX2DSAMPLERDECL(tex), float2 uv)
{
#if 1
    return tex2D(tex, uv);
#else //gamma correction
    float4 diff = tex2D(tex, uv);
    diff.rgb = pow(diff.rgb, gFC_ToneMap.w); //gFC_ToneMap.w is the texture gamma
    return diff;
#endif
}


float4 TexDiff(float2 uv)
{
    return _TexDiff(TEX2DSAMPLER(gSMP_DiffuseMap), uv);
}

float4 TexDiff2(float2 uv)
{
    return _TexDiff(TEX2DSAMPLER(gSMP_DiffuseMap2), uv);
}

float4 TexLightmap(float2 uv)
{
    float4 lightMapVal = tex2D(gSMP_LightMap, uv);
    lightMapVal.rgb = pow(abs(lightMapVal.rgb), gFC_DebugPointLightParams.z);
    //lightMapVal.rgb = pow(lightMapVal.rgb, gFC_DebugPointLightParams.z)*gFC_DebugPointLightParams.y;// (TODO: increase contrast between white and black (common value is 100 for lit areas and 25 for dark areas)
    return lightMapVal;
}

//screen space velocity calculation
float2 CalcScrSpaceVelocity(float4 vtxClip, float4 vtxClipPrev)
{
    return vtxClip.xy - vtxClipPrev.xy;
    /*
    vtxClip.xy /= abs(vtxClip.w);
    vtxClipPrev.xy /= abs(vtxClipPrev.w);
    float2 vel = vtxClip.xy-vtxClipPrev.xy;

//limit velocity to 2 (maximum screen space width)
#if 1
    float velLength = length(vel)+0.00001f; //avoid zero divide
    vel /= velLength;
    vel *= min(2.f, velLength);
#endif
    vel = vel*((0.5f).xx*float2(0.49804f,-0.49804f))+(0.49804f).xx; //-2 ~ 2 -> 0 ~ 1
    return vel;*/
}

float2 OctWrap(float2 v)
{
    return (1.0 - abs(v.yx)) * (v.xy >= 0.0 ? 1.0 : -1.0);
}

float2 OctEncode(float3 n)
{
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    n.xy = n.z >= 0.0 ? n.xy : OctWrap(n.xy);
    n.xy = n.xy * 0.5 + 0.5;
    return n.xy;
}
#endif //___FRPG_Flver_FRPG_Common_fxh___