/***************************************************************************//**

	@file		FRPG_FS_Non.fx
	@brief		Non-environment fragment shader (forward, diffuse-only)
	@par		No env IBL, no point lights, no specular PBR.
				Diffuse + bump + lightmap + shadowmap + fog + scattering only.

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
#ifdef _PS3
	#define ENABLE_FS
#else
	#define ENABLE_VS
	#define ENABLE_FS
#endif

#include "FRPG_Common.fxh"

GBUFFER_OUT FragmentMain(VTX_OUT In)
{
	GBUFFER_OUT Out = (GBUFFER_OUT)0;

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
		difTexUV.xy = ParallaxOcclusionMapping(difTexUV.xy, gFC_ParallaxParams.x, In.VecEye.xyz, In.VecTan.xyz, In.VecBin, In.VecNrm.xyz);
	}
#endif

#ifdef WITH_MultiTexture
	float4 sampledColor = TexDiff(difTexUV.xy);
	float4 sampledColor2 = TexDiff2(In.TexDifDif.zw);
	sampledColor2.rgb += gFC_FgSkinAddColor.rgb;
	sampledColor = float4(lerp(sampledColor.rgb, sampledColor2.rgb, In.ColVtx.a), 1.0)*float4(In.ColVtx.rgb, 1.0) * gFC_DifMapMulCol;
	sampledColor = qlocDoAlphaTest(sampledColor);
#else
	float4 sampledColor = TexDiff(difTexUV);
	sampledColor.rgb += gFC_FgSkinAddColor.rgb;
	sampledColor *= In.ColVtx * gFC_DifMapMulCol;
	sampledColor = qlocDoAlphaTest(sampledColor);
#endif

	Out.GBuffer0.a = saturate(sampledColor.a);

	//qloc: face is backwards, invert normal
	if (!In.isFrontFace) {
		In.VecNrm.xyz = -In.VecNrm.xyz;
	}

{//Normal
    #if WITH_ShadowMap == 2
        #ifdef WITH_BumpMap
            float3 vNrm = normalize(In.VecNrm.xyz);
            float3 vTan = normalize(In.VecTan.xyz);
            #ifdef WITH_MultiTexture
                float3 bump1 = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap), difTexUV.xy);
                float3 bump2 = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap2), difTexUV.zw);
                bump1 = lerp(float3(0,0,1), bump1, gFC_NormalScale);
                bump2 = lerp(float3(0,0,1), bump2, gFC_NormalScale);
                float3 vBin = normalize(In.VecBin.xyz);
                float3 nrmA = normalize(vBin*bump1.x + vTan*bump1.y + vNrm*bump1.z);
                float3 nrmB = normalize(vBin*bump2.x + vTan*bump2.y + vNrm*bump2.z);
                In.VecNrm.xyz = normalize(lerp(nrmA, nrmB, In.ColVtx.a));
            #else
                In.VecNrm.xyz = CalcGetNormal_FromNormalTex_Bin(TEX2DSAMPLER(gSMP_BumpMap), difTexUV, In.VecNrm.xyz, In.VecTan, In.VecBin.xyz);
            #endif
        #else
            In.VecNrm.xyz = normalize(In.VecNrm.xyz);
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
		#endif
	#endif
	}

	float3 baseColor = sampledColor.rgb;
	float4 lightmapColor = 1.0f;
	{//lightmap and shadowmap
	#ifdef WITH_LightMap
		#ifdef WITH_MultiTexture
			const float2 lightmapUV = In.TexLit.xy;
		#else
			const float2 lightmapUV = In.TexDifLit.zw;
		#endif
		#ifdef WITH_ShadowMap
			const float4 lightMapVal = TexLightmap(lightmapUV);
			#if WITH_ShadowMap == CalcLispPos_VS
				const float3 shadowMapVal = CalcGetShadowRateLitSpace(In.VtxLit, In.VecNrm.xyz, In.VecEye).rgb;
			#else
				const float3 shadowMapVal = CalcGetShadowRateWorldSpace(In.VtxWld, In.VecNrm.xyz, In.VecEye).rgb;
			#endif
			lightmapColor.rgb = min(shadowMapVal.rgb, lightMapVal.rgb)*gFC_DebugPointLightParams.y;
		#else
			lightmapColor = TexLightmap(lightmapUV) * float4(gFC_DebugPointLightParams.y, gFC_DebugPointLightParams.y, gFC_DebugPointLightParams.y, 1);
		#endif
	#else
		#ifdef WITH_ShadowMap
			#if WITH_ShadowMap == CalcLispPos_VS
				const float3 shadowMapVal = CalcGetShadowRateLitSpace(In.VtxLit, In.VecNrm.xyz, In.VecEye).rgb;
			#else
				const float3 shadowMapVal = CalcGetShadowRateWorldSpace(In.VtxWld, In.VecNrm.xyz, In.VecEye).rgb;
			#endif
			lightmapColor.rgb = shadowMapVal.rgb;
		#endif
	#endif
	}

	// Diffuse-only forward lighting: base color * lightmap/shadow
	float3 litColor = baseColor;

#if defined(WITH_LightMap) || defined(WITH_SpecularMap) || defined(WITH_ShadowMap)
	// sRGB round-trip: scattering → sRGB encode → lighting factor → sRGB decode → fog → scattering blend → gamma
	litColor = CalcGetLightScatteringCol(float4(litColor, 1), In.VecEye).rgb;
	litColor = pow(abs(litColor), 2.2f);
	{//lighting factor in sRGB space (prevents pow fusion)
		#if defined(WITH_LightMap)
			litColor *= lightmapColor.rgb;
		#elif defined(WITH_ShadowMap)
			litColor *= lightmapColor.rgb;
		#endif
	}
	#ifdef WITH_SpecularMap
	{
		float4 pblTex = tex2D(gSMP_PBLMap, difTexUV.xy);
		litColor.rgb = mad(pblTex.rgb * gFC_SpcMapMulCol.rgb, In.ColVtx.xyz, litColor.rgb);
	}
	#endif
	litColor = pow(abs(litColor), 5.0f / 11.0f);
	{ float fog = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w); litColor.rgb = lerp(litColor.rgb, gFC_FogCol.xyz, fog); }
#ifdef VSLS
	float4 scatteredColor = CalcGetLightScatteringCol_Blend(float4(litColor, 1), In.LsMul, In.LsAdd);
#else
	float4 scatteredColor = CalcGetLightScatteringCol(float4(litColor, 1), In.VecEye);
#endif
	litColor = scatteredColor.rgb;
#else
	// Simple path: fog → scattering → gamma (no texture lighting factor)
	{ float fog = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w); litColor.rgb = lerp(litColor.rgb, gFC_FogCol.xyz, fog); }
#ifdef VSLS
	float4 scatteredColor = CalcGetLightScatteringCol_Blend(float4(litColor, 1), In.LsMul, In.LsAdd);
#else
	float4 scatteredColor = CalcGetLightScatteringCol(float4(litColor, 1), In.VecEye);
#endif
	litColor = scatteredColor.rgb;
#endif

#ifdef WITH_Glow
	litColor.rgb = ReverseToneMap(litColor.rgb);
#endif

	litColor = pow(abs(litColor), 2.2f);
	Out.GBuffer0.rgb = litColor;
	return Out;
}

