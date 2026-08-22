/***************************************************************************//**

	@file		FRPG_FS_HemEnv.fx
	@brief		<ファイルの説明>
	@par 		<ファイルの詳細な説明>
	@author		itoj
	@version	v1.0

	@note		//<ポート元情報>

	@note		//<ポート元著作権表記>

	@note		//<フロム・ソフトウエア著作権表記>

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
/*!
	@par
*/
#ifdef _PS3
	#define ENABLE_FS	//フラグメントシェーダ
#else //define展開の時にFRPG_Commonで定義されている関数で使われるコンスタントの宣言が必要
	#define ENABLE_VS	//バーテックスシェーダ
	#define ENABLE_FS	//フラグメントシェーダ
#endif

#include "FRPG_Common.fxh"

/*-------------------------------------------------------------------*//*!
@brief フラグメントシェーダ

*/
//
//#define WITH_BumpMap	//!<バンプマップあり
//#define WITH_LightMap	//!<ライトマップあり
//#define WITH_ShadowMap	//!<シャドウマップあり
//#define WITH_EnvLerp	//!<環境光源の補間あり


//#define dbgShadow

/*-------------------------------------------------------------------*//*!
@brief フラグメントシェーダ
@par ディフューズ
*/

struct GBUFFER_GB_OUT
{
    float4 Color    : SV_Target0;
    float4 Normal   : SV_Target1;
    float4 Albedo   : SV_Target2;
    float4 Material : SV_Target3;
};

#ifdef WITH_HemDir3

#ifdef WITH_ShadowMap
#include "FRPG_ShadowFunc.fxh"
#endif

struct HEMDIR3_OUT
{
    float4 Color : SV_Target0;
};

// HemDir3: single-target forward shader (ref FRPG_*_*HemDir3*.fpo, non-OLD layout).
// dir lights c92-99, point lights c112-119 (linear atten, no range check), ghost c180/181,
// slope ghost c136-138 (WITH_GhostMap), spec pow exponent c102.x, scattering c104-111, tonemap c135.
// Shadow: 16-tap PCF (__GetShadowRate_GB16) without pow/c186; slope bias added after normal.
HEMDIR3_OUT FragmentMain(VTX_OUT In)
{
    HEMDIR3_OUT Out;
    Out.Color = float4(0, 0, 0, 0);

    float2 difTexUV = 0;
    float2 lightmapUV = 0;
#ifdef WITH_MultiTexture
    difTexUV = In.TexDifDif.xy;
    #ifdef WITH_LightMap
        lightmapUV = In.TexLit.xy;
    #endif
#else
    #ifdef WITH_LightMap
        difTexUV = In.TexDifLit.xy;
        lightmapUV = In.TexDifLit.zw;
    #else
        difTexUV = In.TexDif.xy;
    #endif
#endif

    In.VecEye = CalcGetVecEye_FS(In.VecEye);

#ifdef WITH_MultiTexture
    // Mul: alpha chain = DifMapMulCol.a * ModelMulCol.a (no texture sample), test + o0.w in head (ref)
    float alpha = gFC_DifMapMulCol.a * gFC_ModelMulCol.a;
    Out.Color.a = alpha;
    if (AlphaTest == 1 && AlphaTestRef.x >= alpha) discard;
#endif

// ---------- normal ----------
    float3 N = normalize(In.VecNrm.xyz);
#ifdef WITH_BumpMap
    float3 vTan = normalize(In.VecTan.xyz);
    float3 vBin = normalize(cross(In.VecNrm.xyz, vTan) * In.VecTan.w);
    float2 bumpT = tex2D(gSMP_BumpMap, difTexUV).rg * 2.0f - 1.0f;
    float bumpZ = sqrt(1.0f - min(dot(bumpT, bumpT), 1.0f));
    N = normalize(N * bumpZ + vBin * bumpT.x + vTan * bumpT.y);
#ifdef WITH_MultiTexture
    float3 vTan2 = normalize(In.VecTan2.xyz);
    float3 vBin2 = normalize(cross(In.VecNrm.xyz, vTan2) * In.VecTan2.w);
    float2 bumpT2 = tex2D(gSMP_BumpMap2, In.TexDifDif.zw).rg * 2.0f - 1.0f;
    float bumpZ2 = sqrt(1.0f - min(dot(bumpT2, bumpT2), 1.0f));
    float3 N2 = normalize(N * bumpZ2 + vBin2 * bumpT2.x + vTan2 * bumpT2.y);
    N = normalize(N + In.ColVtx.a * (N2 - N));
#endif
    vBin = normalize(cross(N, vTan)) * In.VecTan.w;
    vTan = normalize(cross(vBin, N));
#endif

    // light-space normal (t15): |xy|^2 before scale, z = sqrt(1-min(|xy|^2,1)) + (|lt*w|^2 < 1e-5)
    float2 lt = tex2D(gSMP_DetailBumpMap, difTexUV * gFC_DetailBumpParam.x).rg * 2.0f - 1.0f;
    float llen2 = dot(lt, lt);
    lt *= gFC_DetailBumpParam.w;
    float3 ltxyz = float3(lt, sqrt(1.0f - min(llen2, 1.0f)) + (dot(lt, lt) < 0.00001f));
    ltxyz = normalize(ltxyz);
#ifdef WITH_BumpMap
    N = normalize(N * ltxyz.z + vBin * ltxyz.x + vTan * ltxyz.y);
#else
    // no TBN inputs: ref = N.xyz*lt.x + N.zyx*lt.y + N.xzy*lt.z (r2=r1.xzy*r0.z; +=r1.zyx*r0.y; +=r1.xyz*r0.w)
    N = normalize(N * ltxyz.x + N.zyx * ltxyz.y + N.xzy * ltxyz.z);
#endif

#if defined(WITH_GBUFFER_4LIGHTS)
    const uint HD3_LIGHT_COUNT = 4;
#elif defined(WITH_GBuffer)
    const uint HD3_LIGHT_COUNT = 2;
#elif defined(WITH_PntS)
    const uint HD3_LIGHT_COUNT = 1;
#else
    const uint HD3_LIGHT_COUNT = 0;
#endif

// ---------- diffuse light: dir (B,A,C) (ref order) ----------
    float3 difLight = CalcGetDirDifLightCol(N, gFC_DirLightVec[1].xyz, gFC_DirLightVec[0].xyz, gFC_DirLightVec[2].xyz,
                                               gFC_DirLightCol[1].rgb, gFC_DirLightCol[0].rgb, gFC_DirLightCol[2].rgb);

    // ---------- shadow: cascade split (Csd) / VtxLit (Sdw) + 16-tap PCF (ref: after dir lights) ----------
    float shadow16 = 0.0f;
#ifdef WITH_ShadowMap
    {
        float4 position_in_light;
#if WITH_ShadowMap == CalcLispPos_PS
        float4 fEndDist = float4(gFC_ShadowStartDist.yzw, 65535.0f);
        float4 zGreater = (gFC_ShadowStartDist < In.VtxWld.w);
        float4 zLess = (fEndDist >= In.VtxWld.w);
        float4 fWeight = zGreater * zLess;
        float4x4 shadowMtx = gFC_ShadowMapMtxArray0 * fWeight.x;
        shadowMtx += gFC_ShadowMapMtxArray1 * fWeight.y;
        shadowMtx += gFC_ShadowMapMtxArray2 * fWeight.z;
        shadowMtx += gFC_ShadowMapMtxArray3 * fWeight.w;
        float4 clampRect = gFC_ShadowMapClamp0 * fWeight.x;
        clampRect += gFC_ShadowMapClamp1 * fWeight.y;
        clampRect += gFC_ShadowMapClamp2 * fWeight.z;
        clampRect += gFC_ShadowMapClamp3 * fWeight.w;
        float4 worldPos = float4(In.VtxWld.xyz, 1.0f);
        position_in_light = mul(worldPos, shadowMtx);
        clampRect *= position_in_light.w;
        position_in_light.xy -= (position_in_light.xy < clampRect.xy) * position_in_light.w;
        position_in_light.xy += (position_in_light.xy > clampRect.zw) * position_in_light.w;
#else
        float4 clampRect = gFC_ShadowMapClamp0 * In.VtxLit.w;
        position_in_light = In.VtxLit;
        position_in_light.xy -= (position_in_light.xy < clampRect.xy) * position_in_light.w;
        position_in_light.xy += (position_in_light.xy > clampRect.zw) * position_in_light.w;
#endif
        shadow16 = __GetShadowRate_GB16(position_in_light);
    }
#endif

    // ---------- shadow rate: slope bias + distance fade (ref) ----------
    float3 lightmapColor = 1.0f;
#ifdef WITH_ShadowMap
    float shadowBias = saturate((dot(gFC_ShadowLightDir.xyz, N) + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
    float shadowWithBias = min(shadow16 + shadowBias, 1.0f);
    float shadowDist = saturate((gFC_ShadowMapParam.y - In.VecEye.w) * gFC_ShadowMapParam.z);
    float3 shadowRate = 1.0f - (float3)shadowDist * gFC_ShadowColor.rgb * shadowWithBias;
#ifdef WITH_LightMap
    lightmapColor = min(shadowRate, tex2D(gSMP_LightMap, lightmapUV).rgb);
#else
    lightmapColor = shadowRate;
#endif
#else
#ifdef WITH_LightMap
    lightmapColor = tex2D(gSMP_LightMap, lightmapUV).rgb;
#endif
#endif
difLight *= lightmapColor;
    if (HD3_LIGHT_COUNT > 0)
    {
        [unroll]
        for (uint i = 0; i < HD3_LIGHT_COUNT; ++i)
        {
            float4 vp = CalcGetVecPnt(In.VtxWld.xyz, gFC_PntLightPos[i], gFC_PntLightCol[i]);
            difLight += CalcGetPntDifLightCol(N, vp.xyz, gFC_PntLightCol[i].rgb * vp.w);
        }
    }
#ifdef WITH_GhostMap
    {
        float4 vg = CalcGetVecPnt(In.VtxWld.xyz, gFC_GhostLightPos, gFC_GhostLightCol);
        difLight += CalcGetPntDifLightCol(N, vg.xyz, gFC_GhostLightCol.rgb * vg.w);
    }
#endif
    difLight += CalcGetHemLightCol(gFC_HemAmbCol_u.rgb, gFC_HemAmbCol_d.rgb, N.y * 0.5f + 0.5f);

    // ---------- specular: dir (B,A,C) x lightmap + points + ghost (ref order) ----------
    float3 specLightSum = 0.0f;
#ifdef WITH_SpecularMap
    float3 R = CalcGetDirSpcLightCol(N, In.VecEye.xyz);
    specLightSum = CalcGetDirSpcLightCol(R, gFC_SpcParam, gFC_DirLightVec[1].xyz, gFC_DirLightVec[0].xyz, gFC_DirLightVec[2].xyz,
                                                          gFC_DirLightCol[1].rgb, gFC_DirLightCol[0].rgb, gFC_DirLightCol[2].rgb);
specLightSum *= lightmapColor;
    if (HD3_LIGHT_COUNT > 0)
    {
        [unroll]
        for (uint j = 0; j < HD3_LIGHT_COUNT; ++j)
        {
            float4 vp = CalcGetVecPnt(In.VtxWld.xyz, gFC_PntLightPos[j], gFC_PntLightCol[j]);
            specLightSum += CalcGetPntSpcLightCol(R, gFC_SpcParam, vp.xyz, gFC_PntLightCol[j].rgb * vp.w);
        }
    }
#ifdef WITH_GhostMap
    {
        float4 vg = CalcGetVecPnt(In.VtxWld.xyz, gFC_GhostLightPos, gFC_GhostLightCol);
        specLightSum += CalcGetPntSpcLightCol(R, gFC_SpcParam, vg.xyz, gFC_GhostLightCol.rgb * vg.w);
    }
#endif
#endif

// ---------- final color ----------
    float3 specLight = 0.0f;
    float3 albedo;
#ifdef WITH_MultiTexture
    float3 dif1 = tex2D(gSMP_DiffuseMap, difTexUV).rgb;
    float3 dif2 = tex2D(gSMP_DiffuseMap2, In.TexDifDif.zw).rgb + gFC_FgSkinAddColor.rgb;
    albedo = lerp(dif1, dif2, In.ColVtx.a) * gFC_DifMapMulCol.rgb * In.ColVtx.rgb;
#ifdef WITH_SpecularMap
    float3 spc1 = tex2D(gSMP_SpecularMap, difTexUV).rgb;
    float3 spc2 = tex2D(gSMP_SpecularMap2, In.TexDifDif.zw).rgb;
    specLight = specLightSum * (lerp(spc1, spc2, In.ColVtx.a) * gFC_SpcMapMulCol.rgb * In.ColVtx.rgb);
#endif
#else
    float alpha = 1.0f;
    float4 alb4 = (In.ColVtx * gFC_DifMapMulCol) * (tex2D(gSMP_DiffuseMap, difTexUV) + float4(gFC_FgSkinAddColor.rgb, 0.0f));
    albedo = alb4.rgb;
#ifdef WITH_SpecularMap
    float3 specMap = tex2D(gSMP_SpecularMap, difTexUV).rgb * gFC_SpcMapMulCol.rgb * In.ColVtx.rgb;
    specLight = specLightSum * specMap;
#endif
    alpha = alb4.a * gFC_ModelMulCol.a;
    if (AlphaTest == 1 && AlphaTestRef.x >= alpha) discard;
#endif
    float3 litColor = albedo * difLight + specLight;
    litColor *= gFC_ModelMulCol.rgb;
#ifndef WITH_MultiTexture
    Out.Color.a = alpha;
#endif

#ifdef WITH_GhostMap
    litColor = CalcGetGhost_NoTex(float4(litColor, 0.0f), N, In.VecEye.xyz, gFC_GhostEdgeColor, gFC_GhostTexColor, gFC_GhostParam).rgb;
#endif

    float fogCoef = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w);
    litColor = lerp(litColor, gFC_FogCol.rgb, fogCoef);

    float4 scatCol = CalcGetLightScatteringCol(float4(litColor, 0.0f), In.VecEye);
    Out.Color.rgb = saturate(scatCol.rgb * gFC_ToneMap.x / gFC_ToneMap.y);
    return Out;
}

#else

#if defined(WITH_MultiTexture) && !defined(WITH_SpecularMap)

// Mul + !Spc variants. Ref = 484 B mini shader (2 targets, switch cb0[102].x = gFC_DebugDraw)
// with constant inputs of a Mul material (LitColor=(1,0,1), Diffuse=Specular=Emissive=0,
// Normal=0 -> case5 = 0.49804, Roughness=1 -> case6 = (1,0,0))
#if defined(WITH_GBuffer)
// Mul + !Spc + GBuffer: ref = 192 B 4-target stub, no cb0 access
GBUFFER_GB_OUT FragmentMain(VTX_OUT In)
{
    GBUFFER_GB_OUT GbOut;
    GbOut.Color = float4(1, 0, 1, 1);
    GbOut.Normal = float4(0.5f, 0.5f, 0.5f, 0.0f);
    GbOut.Albedo = float4(0, 0, 0, 1);
    GbOut.Material = float4(1, 0, 0, 1);
    return GbOut;
}
#else
GBUFFER_OUT FragmentMain(VTX_OUT In)
{
    GBUFFER_OUT Out;
    float3 s;
    switch (gFC_DebugDraw.x)
    {
        case 1:  s = float3(1, 0, 1); break;
        case 2:  s = float3(0, 0, 0); break;
        case 3:  s = float3(0, 0, 0); break;
        case 4:  s = float3(0, 0, 0); break;
        case 5:  s = float3(0.49804f, 0.49804f, 0.49804f); break;
        case 6:  s = float3(1, 0, 0); break;
        default: s = float3(0, 0, 0); break;
    }
    Out.GBuffer0 = float4(1, 0, 1, 1);
    Out.GBuffer1 = float4(s, 0);
    return Out;
}
#endif

#else

#ifdef WITH_GBuffer
#include "FRPG_Common_ForwardPBL.fxh"
#include "FRPG_ShadowFunc.fxh"

GBUFFER_GB_OUT FragmentMain(VTX_OUT In)
{
    GBUFFER_GB_OUT GbOut;

#else

GBUFFER_OUT FragmentMain(VTX_OUT In)
{
    GBUFFER_OUT Out;

#endif
#if defined(WITH_MultiTexture)
    float4 difTexUV = In.TexDifDif;
#elif defined(WITH_LightMap)
    float2 difTexUV = In.TexDifLit.xy;
#else
    float2 difTexUV = In.TexDif.xy;
#endif

    {//xyz - view vector, w - camera distance
        In.VecEye = CalcGetVecEye_FS(In.VecEye);
    }

#if defined(WITH_BumpMap) && defined(WITH_Parallax)
    if (gFC_ParallaxParams.x > 0.0f) {
        #ifdef CALC_VS_BINORMAL
            float3 vBin = In.VecBin.xyz;
        #else
            float3 vBin = cross(In.VecNrm.xyz, In.VecTan.xyz) * In.VecTan.w;
        #endif
        difTexUV.xy = ParallaxOcclusionMappingSingle(difTexUV.xy, gFC_ParallaxParams.x, In.VecEye.xyz, In.VecTan.xyz, vBin, In.VecNrm.xyz);
    }
#endif

#ifdef WITH_MultiTexture
    float4 sampledColor = TexDiff(difTexUV.xy);
    float4 sampledColor2 = TexDiff2(In.TexDifDif.zw);
    sampledColor2.rgb += gFC_FgSkinAddColor.rgb;
    sampledColor = float4(lerp(sampledColor.rgb, sampledColor2.rgb, In.ColVtx.a), 1.0)*float4(In.ColVtx.rgb, 1.0) * gFC_ModelMulCol;
    sampledColor = qlocDoAlphaTest(sampledColor);
#else
    float4 sampledColor = TexDiff(difTexUV);
    sampledColor.rgb += gFC_FgSkinAddColor.rgb;
    sampledColor *= In.ColVtx;
    sampledColor = qlocDoAlphaTest(sampledColor);
#endif

    float alpha = saturate(sampledColor.a);

    //qloc: face is backwards, invert normal (forward only — ref GBuffer path has no FFACE)
#ifndef WITH_GBuffer
    if (!In.isFrontFace) {
        In.VecNrm.xyz = -In.VecNrm.xyz;
    }
#endif
    float3 vertexNormal = In.VecNrm.xyz;

    {//Normal
    #if WITH_ShadowMap == 2
        // Csd — uses original VS layout (same TEXCOORD as non-Csd)
        // No VecTan2/VecBin2 — use inline TBN for MultiTexture
        #ifdef WITH_BumpMap
            float3 vNrm = normalize(In.VecNrm.xyz);
            float3 vTan = normalize(In.VecTan.xyz);
            #ifdef CALC_VS_BINORMAL
                float3 vBin = normalize(In.VecBin.xyz);
            #else
                float3 vBin = normalize(cross(vNrm, vTan) * In.VecTan.w);
            #endif
            #ifdef WITH_MultiTexture
                float3 bump1 = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap), difTexUV.xy);
                float3 bump2 = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap2), difTexUV.zw);
                #ifndef WITH_GBuffer
                // GB ref does NOT apply normalScale (no c194.z in ref PntSS asm)
                bump1 = lerp(float3(0,0,1), bump1, gFC_NormalScale);
                bump2 = lerp(float3(0,0,1), bump2, gFC_NormalScale);
                #endif
                float3 nrmA = normalize(vBin*bump1.x + vTan*bump1.y + vNrm*bump1.z);
                float3 nrmB = normalize(vBin*bump2.x + vTan*bump2.y + vNrm*bump2.z);
                In.VecNrm.xyz = normalize(lerp(nrmA, nrmB, In.ColVtx.a));
                APPLY_DETAIL_BUMP_TAN(In.VecNrm.xyz, In.VecTan, difTexUV.xy);
            #else
                In.VecNrm.xyz = CalcGetNormal_FromNormalTex_Bin(TEX2DSAMPLER(gSMP_BumpMap), difTexUV, In.VecNrm.xyz, In.VecTan, vBin);
            #endif
        #else
            In.VecNrm.xyz = normalize(In.VecNrm.xyz);
            APPLY_DETAIL_BUMP(In.VecNrm.xyz, difTexUV.xy);
        #endif
    #else
        #ifdef WITH_BumpMap
            #ifdef WITH_MultiTexture
                #ifdef CALC_VS_BINORMAL
                    In.VecNrm.xyz = CalcGetNormal_FromNormalTex_Mul_Bin(TEX2DSAMPLER(gSMP_BumpMap), TEX2DSAMPLER(gSMP_BumpMap2), difTexUV,  In.VecNrm.xyz, In.VecTan, In.VecTan2, In.VecBin, In.VecBin2, In.ColVtx.a);
                #else
                    const float3 localVecBin = cross(In.VecNrm.xyz, In.VecTan.xyz)*In.VecTan.w;
                    const float3 localVecBin2 = cross(In.VecNrm.xyz, In.VecTan2.xyz)*In.VecTan2.w;
                    In.VecNrm.xyz = CalcGetNormal_FromNormalTex_Mul_Bin(TEX2DSAMPLER(gSMP_BumpMap), TEX2DSAMPLER(gSMP_BumpMap2), difTexUV,  In.VecNrm.xyz, In.VecTan, In.VecTan2, localVecBin, localVecBin2, In.ColVtx.a);
                #endif
            #else
                #ifdef CALC_VS_BINORMAL
                    In.VecNrm.xyz = CalcGetNormal_FromNormalTex_Bin(TEX2DSAMPLER(gSMP_BumpMap), difTexUV, In.VecNrm.xyz, In.VecTan, In.VecBin);
                #else
                    const float3 localVecBin = cross(In.VecNrm.xyz, In.VecTan.xyz)*In.VecTan.w;
                    In.VecNrm.xyz = CalcGetNormal_FromNormalTex_Bin(TEX2DSAMPLER(gSMP_BumpMap), difTexUV, In.VecNrm.xyz, In.VecTan, localVecBin);
                #endif
            #endif
        #else
            In.VecNrm.xyz = normalize(In.VecNrm.xyz);
            APPLY_DETAIL_BUMP(In.VecNrm.xyz, difTexUV.xy);
        #endif
    #endif
    }

#ifdef WITH_GBuffer
    // ===== GBUFFER PATH (full forward lighting, 4 RT output) =====

    float4 lightmapColor = 1.0f;
    {//lightmap and shadowmap
    #ifdef WITH_LightMap
        #ifdef WITH_MultiTexture
            const float2 lightmapUV = In.TexLit.xy;
        #else
            const float2 lightmapUV = In.TexDifLit.zw;
        #endif
        #ifdef WITH_ShadowMap
            float4 lightMapVal = TexLightmap(lightmapUV);
            // ref GB lightmap luminance remap (ref 346-353): lum = max(0.001, dots); rgb *= pow(lum, c186.z)/lum
            float lightMapLum = CalcLuminance(lightMapVal.rgb);
            lightMapVal.rgb *= pow(abs(lightMapLum), gFC_DebugPointLightParams.z) / lightMapLum;
            #if WITH_ShadowMap == CalcLispPos_VS
                const float3 shadowMapVal = CalcGetShadowRateLitSpace(In.VtxLit, In.VecNrm.xyz, In.VecEye).rgb;
            #else
                const float3 shadowMapVal = CalcGetShadowRateWorldSpaceBlend(In.VtxWld, In.VecNrm.xyz, In.VecEye).rgb;
            #endif
            lightmapColor.rgb = min(shadowMapVal.rgb, lightMapVal.rgb)*gFC_DebugPointLightParams.y;
            lightmapColor.a = lightMapVal.a*shadowMapVal.r;
        #else
            // ref GB lightmap no-shadow (ref 401-409): lum=max(lum,0.001); rgb *= pow(lum,c186.z)/lum; x c186.y, no min
            float4 lightMapVal = TexLightmap(lightmapUV);
            float lightMapLum = max(CalcLuminance(lightMapVal.rgb), 0.001f);
            lightMapVal.rgb *= pow(lightMapLum, gFC_DebugPointLightParams.z) / lightMapLum;
            lightmapColor = lightMapVal * float4(gFC_DebugPointLightParams.y, gFC_DebugPointLightParams.y, gFC_DebugPointLightParams.y, 1);
        #endif
    #else
        #ifdef WITH_ShadowMap
            #if WITH_ShadowMap == CalcLispPos_VS
                const float3 shadowMapVal = CalcGetShadowRateLitSpace(In.VtxLit, In.VecNrm.xyz, In.VecEye).rgb;
            #else
                const float3 shadowMapVal = CalcGetShadowRateWorldSpaceBlend(In.VtxWld, In.VecNrm.xyz, In.VecEye).rgb;
            #endif
            lightmapColor.rgb = shadowMapVal.rgb;
        #endif
    #endif
    }

    #if defined(WITH_MultiTexture) && defined(WITH_SpecularMap)
        float4 pblTexData = tex2D(gSMP_PBLMap, difTexUV.xy).rgba;
        float4 pblTexData2 = tex2D(gSMP_PBLMap2, In.TexDifDif.zw).rgba;
        pblTexData = lerp(pblTexData.rgba, pblTexData2.rgba, In.ColVtx.a);
    #elif defined(WITH_SpecularMap)
        float4 pblTexData = tex2D(gSMP_PBLMap, difTexUV).rgba;
    #else
        float4 pblTexData = float4(1.0f, 0.0f, 0.0f, 1.0f);
    #endif

    // GB ref PackMaterial (ref 175-192, 258-266): no CalcLuminance-based F0, no FitRoughness,
    // roughness clamped to 0.001 BEFORE the c185 remap,
    // specColor = Metal*(albedo - 0.2*F0) + 0.2*F0, emissive = (1-pbl.a)*c185.w (no EMISSIVE_STRENGTH)
MATERIAL Mtl;
    float4 pblGB = pblTexData;
    pblGB.r = max(pblGB.r, 0.001f);
#ifdef WITH_SpecularMap
    Mtl.Roughness = lerp(pblGB.r, gFC_MaterialOverrideParams.x - 1.0f, saturate(gFC_MaterialOverrideParams.x));
    float MetalMaskGB = lerp(pblGB.g, gFC_MaterialOverrideParams.y - 1.0f, saturate(gFC_MaterialOverrideParams.y));
    float DiffuseF0GB = lerp(pblGB.b, gFC_MaterialOverrideParams.z - 1.0f, saturate(gFC_MaterialOverrideParams.z));
#else
    Mtl.Roughness = pblGB.r;
    float MetalMaskGB = pblGB.g;
    float DiffuseF0GB = pblGB.b;
#endif
    Mtl.LightPower = pblTexData.a;
    float3 linearSampledGB = Srgb2linear(sampledColor.rgb) * lerp(gFC_DifMapMulCol.rgb, gFC_SpcMapMulCol.rgb, MetalMaskGB);
    Mtl.DiffuseColor = (1.0f - MetalMaskGB) * linearSampledGB;
    // ref 183/263-264: specColor = Metal*(albedo - 0.2*F0) + 0.2*F0 (0.2 as float3 mad literal + scalar mul)
    Mtl.SpecularColor = DiffuseF0GB * linearSampledGB - float3(0.2f, 0.2f, 0.2f) * (DiffuseF0GB * MetalMaskGB) + 0.2f * MetalMaskGB;
#ifdef WITH_SpecularMap
    Mtl.EmissiveColor = (1.0f - pblTexData.a) * gFC_MaterialOverrideParams.w * linearSampledGB;
#else
    Mtl.EmissiveColor = float3(0, 0, 0);
#endif
    Mtl.LitColor = float4(0, 0, 0, 0);
    Mtl.Normal = In.VecNrm.xyz;
    #ifdef FS_SUBSURF
    #ifdef WITH_SpecularMap
        float2 subsurfData = tex2D(gSMP_Subsurf, difTexUV.xy).rg;
        Mtl.SubsurfStrength = subsurfData.r * gFC_SubsurfaceParam.x;
        Mtl.SubsurfOpacity = TranslucencyScaled(subsurfData.g, gFC_SubsurfaceParam.y);
    #else
        Mtl.SubsurfStrength = 0.0f;
        Mtl.SubsurfOpacity = 1.0f;
    #endif
    #endif

    // GBuffer path: ref only computes specularF90 when WITH_SpecularMap is set
    #ifdef WITH_SpecularMap
    float specularF90 = calcSpecularF90(Mtl.SpecularColor);
    #else
    float specularF90 = 0.0f;
    #endif

    float3 emissiveComponent = CalcEmissive(Mtl);

    #ifdef WITH_HemDir3
        float3 dirLight =
            max(-dot(Mtl.Normal, gFC_PntLightPos[0].xyz), 0) * gFC_PntLightPos[3].xyz +
            max(-dot(Mtl.Normal, gFC_PntLightPos[1].xyz), 0) * gFC_PntLightCol[0].rgb +
            max(-dot(Mtl.Normal, gFC_PntLightPos[2].xyz), 0) * gFC_PntLightCol[1].rgb;
        float hemiBlendGB = Mtl.Normal.y * 0.5f + 0.5f;
        float3 ambLightGB = lerp(gFC_PntLightCol[3].rgb, gFC_PntLightCol[2].rgb, hemiBlendGB);
        Mtl.LitColor.rgb = (dirLight + ambLightGB) * Mtl.DiffuseColor * lightmapColor.rgb;
    #else
        // GBuffer IBL: ref uses diffuse-only IBL when !WITH_SpecularMap, full IBL with Spc
        float3 envLightComponent;
        #ifdef WITH_SpecularMap
            envLightComponent = CalcEnvIBL(Mtl, vertexNormal, In.VecEye.xyz, In.VtxWld.xyz, specularF90) * lightmapColor.rgb;
        #else
            // Diffuse-only IBL (no evaluateIBLSpecular → no 1.3/0.014/-5.55/-6.98/pi/1pi)
            float NdotV = saturate(dot(Mtl.Normal, In.VecEye.xyz));
            float3 diffuseIBL = evaluateIBLDiffuse(Mtl.Normal, In.VecEye.xyz, NdotV, Mtl.Roughness);
            #ifdef USE_SH
            if (gFC_SHEnabled >= 0.5f) { // ref: lt cb0[187].x, l(0.5)
                diffuseIBL += CalcSH(Mtl.Normal, float4(In.VtxWld.xyz, 1.0f));
            }
            #endif
            diffuseIBL *= Mtl.DiffuseColor;
            envLightComponent = Mtl.LightPower * diffuseIBL * lightmapColor.rgb;
        #endif

        envLightComponent += Mtl.DiffuseColor * CalcHemAmbient(Mtl.Normal);

if (gFC_SAOEnabled > 0.0f) { // ref: lt r1.w, l(0.0), cb0[193].x
            float aoMapVal = gSMP_AOMap.Load(int3((int2)In.VtxClp.xy, 0)).x;
            envLightComponent *= aoMapVal;
        }

        Mtl.LitColor.rgb = emissiveComponent + envLightComponent;

        // GBuffer path: ref uses legacy point light loop UNROLLED to exactly 2 lights (PntSS)
        // or 4 lights (PntSSSS: 1/pi 16, pi 12, 0.25 4 — ref c112-115/c116-119, no count clamp, no loop)
        float3 pointLightComponent = float3(0.0f, 0.0f, 0.0f);
    #if defined(WITH_GBUFFER_4LIGHTS)
        const uint GB_LIGHT_COUNT = 4;
    #else
        const uint GB_LIGHT_COUNT = 2;
    #endif
        [unroll]
        for (uint i = 0; i < GB_LIGHT_COUNT; ++i) {
            float3 L = gFC_PntLightPos[i].xyz - In.VtxWld.xyz;
            float distL = length(L);
            if (distL < gFC_PntLightCol[i].w) {
                L *= 1.0 / distL;
                #ifdef WITH_SpecularMap
                pointLightComponent += GBPointLightContribution(
                    Mtl.Normal, L, In.VecEye.xyz,
                    Mtl.DiffuseColor, Mtl.SpecularColor, specularF90,
                    Mtl.Roughness, gFC_PntLightCol[i].xyz, distL,
                    gFC_PntLightPos[i].w, gFC_PntLightCol[i].w, (uint)gFC_DebugPointLightParams.x);
                #else
                // ref GB !Spc light loop: diffuse-only, no 1/pi, no GGX D-term (ref 493-505)
                float attenGB = GB_lampAttenuation(distL, gFC_PntLightCol[i].w, gFC_PntLightPos[i].w, (uint)gFC_DebugPointLightParams.x);
                pointLightComponent += saturate(dot(Mtl.Normal, L)) * (Mtl.DiffuseColor * gFC_PntLightCol[i].xyz * attenGB);
                #endif
            }
        }

        {//Ghost lights — ref GB (666-679): no D/Fresnel cycle, simple falloff + NdotL + pow(ndl, c102.x)
        #ifdef WITH_GhostMap
            float3 L = gFC_GhostLightPos.xyz - In.VtxWld.xyz;
            float distL = length(L);
            L /= distL;
            float distFade = saturate((gFC_GhostLightCol.w - distL) * gFC_GhostLightPos.w);
            float3 ghostLight = distFade * gFC_GhostLightCol.rgb;
            float ndl = max(dot(L, Mtl.Normal), 0.0f);
            pointLightComponent += ghostLight * ndl;
            pointLightComponent += ghostLight * pow(ndl, gFC_DebugDraw.x);
        #endif
        }

        Mtl.LitColor.rgb += pointLightComponent;
    #endif

    {//Ghosting
    #ifdef WITH_GhostMap
        Mtl.LitColor = CalcGetGhost_NoTex(Mtl.LitColor, Mtl.Normal, In.VecEye.xyz, gFC_GhostEdgeColor, gFC_GhostTexColor, gFC_GhostParam);
    #endif
    }

    #ifndef WITH_HemDir3
        if (gFC_GammaFlag.x > 0.5f) {
            Mtl.LitColor = Linear2srgb(Mtl.LitColor);
        }
    #endif
    { float fog = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w); Mtl.LitColor.rgb = lerp(Mtl.LitColor.rgb, gFC_FogCol.xyz, fog); }

    #ifdef VSLS
        float4 scatteredColor = CalcGetLightScatteringCol_Blend(Mtl.LitColor, In.LsMul, In.LsAdd);
    #else
        float4 scatteredColor = CalcGetLightScatteringCol(Mtl.LitColor, In.VecEye);
    #endif
    Mtl.LitColor = scatteredColor;
    #ifndef WITH_HemDir3
        if (gFC_GammaFlag.x > 0.5f) {
            Mtl.LitColor = Srgb2linear(Mtl.LitColor);
        }
    #endif

    #if defined(WITH_HemDir3)
        Mtl.LitColor.rgb *= gFC_ToneMap.x;
    #endif

    // GBuffer outputs — Spc ref (asm 257, 729-731):
    //   o2.xyz = pbl.a x (TexDiff+skin) x ColVtx x Model x lerp(c100,c101,MetalMask)  [written pre-2.2]
    //   o2.w   = 1 (non-Mul) / 0 (Mul)
    //   o3.x   = roughness remapped (clamped max(0.001) FIRST, then lerp)
    //   o3.yz  = (MetalMask, pbl.b remapped); o3.w not written
    // !Spc ref (asm 608-610): Albedo = x Model x DifMapMul.xyz (no SpcMap lerp, no Metal); Material = (1,0,0)
#if defined(WITH_SpecularMap)
    float clampedRough = max(pblTexData.r, 0.001f);
    float remappedRoughness = lerp(clampedRough, gFC_MaterialOverrideParams.x - 1.0f, saturate(gFC_MaterialOverrideParams.x));
    float MetalMask = lerp(pblTexData.g, gFC_MaterialOverrideParams.y - 1.0f, saturate(gFC_MaterialOverrideParams.y));
    float remappedF0 = lerp(pblTexData.b, gFC_MaterialOverrideParams.z - 1.0f, saturate(gFC_MaterialOverrideParams.z));
#else
    float remappedRoughness = 1.0f;
    float MetalMask = 0.0f;
    float remappedF0 = 0.0f;
#endif

    float3 albedoChain = sampledColor.rgb;
    #ifndef WITH_MultiTexture
    albedoChain *= gFC_ModelMulCol.rgb;
    #endif
#if defined(WITH_SpecularMap)
    albedoChain *= lerp(gFC_DifMapMulCol.rgb, gFC_SpcMapMulCol.rgb, MetalMask) * Mtl.LightPower;
#else
    albedoChain *= gFC_DifMapMulCol.rgb;
#endif

    GbOut.Color = float4(Mtl.LitColor.rgb, 1.0f);
    // ref GB: normal*0.5+0.5 with y,z,x swizzle (ref 524: mad r9.xyzw, r4.yxyz, l(0.5), l(0.5); o1.xyz = r9.yzw)
    GbOut.Normal = float4(Mtl.Normal.y, Mtl.Normal.z, Mtl.Normal.x, 0.0f) * 0.5f + 0.5f;
    GbOut.Normal.w = 0;
    GbOut.Albedo.xyz = albedoChain;
#ifdef WITH_MultiTexture
    GbOut.Albedo.w = 0.0f;
#else
    GbOut.Albedo.w = 1.0f;
#endif
#if defined(WITH_SpecularMap)
    GbOut.Material = float4(remappedRoughness, MetalMask, remappedF0, 0.0f);
#else
    GbOut.Material = float4(1.0f, 0.0f, 0.0f, 0.0f);
#endif
    return GbOut;

#else
    // ===== FORWARD PATH =====

    float4 lightmapColor = 1.0f; // used for shadowing static map point lights
    {//lightmap and shadowmap
    #ifdef WITH_LightMap
        #ifdef WITH_MultiTexture
            const float2 lightmapUV = In.TexLit.xy;
        #else
            const float2 lightmapUV = In.TexDifLit.zw;
        #endif
        #ifdef WITH_ShadowMap
            //light map + shadow map
            const float4 lightMapVal = TexLightmap(lightmapUV);
            #if WITH_ShadowMap == CalcLispPos_VS
                const float3 shadowMapVal = CalcGetShadowRateLitSpace(In.VtxLit, In.VecNrm.xyz, In.VecEye).rgb;
            #else //WITH_ShadowMap == CalcLispPos_PS
                const float3 shadowMapVal = CalcGetShadowRateWorldSpace(In.VtxWld, In.VecNrm.xyz, In.VecEye).rgb;
            #endif
            lightmapColor.rgb = min(shadowMapVal.rgb, lightMapVal.rgb)*gFC_DebugPointLightParams.y;
            lightmapColor.a = lightMapVal.a*shadowMapVal.r; //QLOC: store shadowing from shadow map too
        #else
            //light map only
            lightmapColor = TexLightmap(lightmapUV) * float4(gFC_DebugPointLightParams.y, gFC_DebugPointLightParams.y, gFC_DebugPointLightParams.y, 1);
        #endif
    #else
        #ifdef WITH_ShadowMap
            //shadow map only
            #if WITH_ShadowMap == CalcLispPos_VS
                const float3 shadowMapVal = CalcGetShadowRateLitSpace(In.VtxLit, In.VecNrm.xyz, In.VecEye).rgb;
            #else //WITH_ShadowMap == CalcLispPos_PS
                const float3 shadowMapVal = CalcGetShadowRateWorldSpace(In.VtxWld, In.VecNrm.xyz, In.VecEye).rgb;
            #endif
            lightmapColor.rgb = shadowMapVal.rgb;
        #endif
    #endif
    }

    #if defined(WITH_MultiTexture) && defined(WITH_SpecularMap)
        float4 pblTexData = tex2D(gSMP_PBLMap, difTexUV.xy).rgba;
        float4 pblTexData2 = tex2D(gSMP_PBLMap2, In.TexDifDif.zw).rgba;
        pblTexData = lerp(pblTexData.rgba, pblTexData2.rgba, In.ColVtx.a);
    #elif defined(WITH_SpecularMap)
        float4 pblTexData = tex2D(gSMP_PBLMap, difTexUV).rgba;
    #else
        float4 pblTexData = float4(1.0f, 0.0f, 0.0f, 1.0f);
    #endif

    MATERIAL Mtl = PackMaterial(sampledColor, pblTexData, In.VecNrm.xyz);
    #ifdef FS_SUBSURF
    #ifdef WITH_SpecularMap
        float2 subsurfData = tex2D(gSMP_Subsurf, difTexUV.xy).rg;
        Mtl.SubsurfStrength = subsurfData.r * gFC_SubsurfaceParam.x;
        Mtl.SubsurfOpacity = TranslucencyScaled(subsurfData.g, gFC_SubsurfaceParam.y);
    #else //WITH_SpecularMap
        Mtl.SubsurfStrength = 0.0f;
        Mtl.SubsurfOpacity = 1.0f;
    #endif //WITH_SpecularMap
    #endif //FS_SUBSURF

    float specularF90 = calcSpecularF90(Mtl.SpecularColor);

    //emissive
    float3 emissiveComponent = CalcEmissive(Mtl);

    #ifdef WITH_HemDir3
        // 3 directional lights + hemisphere ambient (non-OLD_VERSION: c92-99 = gFC_PntLightPos/Col)
        float3 dirLight =
            max(-dot(Mtl.Normal, gFC_PntLightPos[0].xyz), 0) * gFC_PntLightPos[3].xyz +
            max(-dot(Mtl.Normal, gFC_PntLightPos[1].xyz), 0) * gFC_PntLightCol[0].rgb +
            max(-dot(Mtl.Normal, gFC_PntLightPos[2].xyz), 0) * gFC_PntLightCol[1].rgb;
        float hemiBlend = Mtl.Normal.y * 0.5 + 0.5;
        float3 ambLight = lerp(gFC_PntLightCol[3].rgb, gFC_PntLightCol[2].rgb, hemiBlend);
        Mtl.LitColor.rgb = (dirLight + ambLight) * Mtl.DiffuseColor * lightmapColor.rgb;
    #else
        //image-based lighting
        float3 envLightComponent = CalcEnvIBL(Mtl, vertexNormal, In.VecEye.xyz, In.VtxWld.xyz, specularF90) * lightmapColor.rgb;

        //ambient light
        envLightComponent += Mtl.DiffuseColor * CalcHemAmbient(Mtl.Normal);

        if (gFC_SAOEnabled != 0.0f) {
            const float aoMapVal = tex2Dlod(gSMP_AOMap, float4(In.VtxClp.xy * gFC_SAOParams.xy, 0, 0)).r;
            envLightComponent *= aoMapVal;
        }

        Mtl.LitColor.rgb = emissiveComponent + envLightComponent;

    #if(POINT_LIGHT_0 >POINT_LIGHT_TYPE_None)
        float3 pointLightComponent = CalcPointLightsLegacy(Mtl, In.VecEye.xyz, In.VtxWld.xyz, specularF90, lightmapColor.a);
    #else
        float3 pointLightComponent = CalcPointLightsClustered(Mtl, In.VecEye.xyz, In.VtxWld.xyz, specularF90, lightmapColor.a);
    #endif

        {//Ghost lights
        #ifdef WITH_GhostMap
            float3 L = gFC_GhostLightPos.xyz - In.VtxWld.xyz;
            float distL = length(L);
            pointLightComponent += PointLightContribution(
                Mtl.Normal, L / distL, In.VecEye.xyz,
                Mtl.DiffuseColor, Mtl.SpecularColor, specularF90,
                Mtl.Roughness, gFC_GhostLightCol.rgb, distL,
                gFC_GhostLightPos.w, gFC_GhostLightCol.w, 0);
        #endif
        }

        Mtl.LitColor.rgb += pointLightComponent;
    #endif

    {//Ghosting
    #ifdef WITH_GhostMap
        // Ref (Gst/Sfx base forward ONLY): ghost color goes through Srgb2linear-sign round-trip,
        //   then the SUM gets Linear2srgb'd before fog (ref: mad r2 -> lt/iadd/itof sign,
        //   mad add, then max/log*0.454545/exp of the sum).
        //   ghostCol = pow(|x|, 2.2) * sign(x), x = lerp(edgeCol, texCol, ghostPow) * ghostParam.x
        //   (Alp/GB/HemDir3 refs have NO such round-trip -> keep CalcGetGhost_NoTex there)
        float3 texCol = gFC_GhostTexColor.rgb * gFC_GhostTexColor.a;
        float3 edgeCol = gFC_GhostEdgeColor.rgb * gFC_GhostEdgeColor.a;
        float ghostPow = (FRPG_CLAMP(abs(dot(Mtl.Normal, In.VecEye.xyz)), 0.1f, 0.7f) - 0.1f) * (1.0f / 0.6f);
        float3 ghostCol = lerp(edgeCol, texCol, ghostPow) * gFC_GhostParam.x;
        ghostCol = pow(abs(ghostCol), 2.2f) * sign(ghostCol);
        Mtl.LitColor.rgb += ghostCol;
    #endif
    }

    #ifndef WITH_HemDir3
        Mtl.LitColor = Linear2srgb(Mtl.LitColor); // sRGB conversion for fog + scattering
    #endif
    { float fog = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w); Mtl.LitColor.rgb = lerp(Mtl.LitColor.rgb, gFC_FogCol.xyz, fog); }

    #ifdef VSLS
        float4 scatteredColor = CalcGetLightScatteringCol_Blend(Mtl.LitColor, In.LsMul, In.LsAdd);
    #else
        float4 scatteredColor = CalcGetLightScatteringCol(Mtl.LitColor, In.VecEye);
    #endif
    Mtl.LitColor = scatteredColor;
    #ifndef WITH_HemDir3
        Mtl.LitColor = Srgb2linear(Mtl.LitColor);
    #endif

    #if defined(WITH_GhostMap) || defined(WITH_Glow)
        // Ref: tone-map block emitted unconditionally for Gst (WITH_GhostMap) and Sfx (WITH_Glow)
        // forward paths, but NOT for Phn. Ref structure: mul by gFC_ToneCorrectParams.x OUTSIDE
        // the if, then ne/if_nz cb0[91].x -> sample t6 (0.5,0.5), clamp z/w, mul y, add 1e-4, mul, div x.
        Mtl.LitColor.rgb *= gFC_ToneCorrectParams.x;
        if (gFC_InverseToneMapEnable.x != 0.0f)
        {
            float expScale = clamp(tex2D(gSMP_LumTex, float2(0.5f, 0.5f)).r,
                                   gFC_AdaptParam.z, gFC_AdaptParam.w);
            Mtl.LitColor.rgb = gFC_AdaptParam.y * Mtl.LitColor.rgb
                             * (expScale + 0.0001f) / gFC_AdaptParam.x;
        }
    #endif

    #if defined(WITH_HemDir3)
        Mtl.LitColor.rgb *= gFC_ToneMap.x;
        Out.GBuffer0.rgb = saturate(Mtl.LitColor.rgb / gFC_ToneMap.y);
        Out.GBuffer0.a = alpha;
        return Out;
    #else
        Out.GBuffer0.a = alpha;
        return PackGBuffer(Out, Mtl);
    #endif
#endif
}
#endif


#endif // WITH_HemDir3
