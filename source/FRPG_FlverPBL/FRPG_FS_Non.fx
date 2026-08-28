/***************************************************************************//**

	@file		FRPG_FS_Non.fx
	@brief		Non-environment fragment shader (forward, diffuse-only)
	@par		No env IBL, no point lights, no specular PBR.
				Diffuse + detail-bump + shadowmap/lightmap + fog + scattering only.
				WITH_BumpMap is a DETAIL/HEIGHT bump (pow + min modulation), NOT a
				tangent-space normal map — matches reference Non ASM.

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
#ifdef _PS3
	#define ENABLE_FS
#else
	#define ENABLE_VS
	#define ENABLE_FS
#endif

#include "FRPG_Common.fxh"

// Single-target output: ref _Non OSGN has only SV_Target0
struct NON_OUT {
	float4 Color : SV_Target0;
};

NON_OUT FragmentMain(VTX_OUT In)
{
	NON_OUT Out = (NON_OUT)0;

	// ref v7: .xy = diffuse UV, .zw = secondary UV (lightmap / layer2 / bump)
#if defined(WITH_MultiTexture)
	float4 difTexUV = In.TexDifDif;
#elif defined(WITH_LightMap)
	float4 difTexUV = In.TexDifLit;
#else
	float2 difTexUV = In.TexDif.xy;
#endif

	{
		In.VecEye = CalcGetVecEye_FS(In.VecEye);
	}

	// Diffuse color
#ifdef WITH_MultiTexture
	float4 c1 = TexDiff(difTexUV.xy);
	float4 c2 = TexDiff2(In.TexDifDif.zw);
	c2.rgb += gFC_FgSkinAddColor.rgb;
	float3 mulRGB = lerp(c1.rgb, c2.rgb, In.ColVtx.a) * In.ColVtx.rgb * gFC_DifMapMulCol.rgb;
	float4 sampledColor = float4(mulRGB, gFC_DifMapMulCol.a);
#else
	float4 sampledColor = TexDiff(difTexUV.xy);
	sampledColor.rgb += gFC_FgSkinAddColor.rgb;
	sampledColor *= In.ColVtx * gFC_DifMapMulCol;
#endif
	sampledColor = qlocDoAlphaTest(sampledColor);

	// Lightmap (WITH_LightMap): ref does NOT multiply the raw lightmap into the
	// diffuse. It runs the sample through pow(|lm|, gFC_DebugPointLightParams.z)
	// and min()s it into the bump/shadow modulation inside the sRGB round-trip
	// (see bumpMod below). The sample is kept here for that use.
#if defined(WITH_LightMap)
	#if defined(WITH_MultiTexture)
		float3 lmTex = tex2D(gSMP_6, In.TexLit).xyz;
	#else
		float3 lmTex = tex2D(gSMP_6, In.TexDifLit.zw).xyz;
	#endif
#else
	float3 lmTex = float3(0.0f, 0.0f, 0.0f);
#endif

	Out.Color.a = sampledColor.a;

	float3 N = normalize(In.VecNrm.xyz);

	// --- Shadow / lightmap factor (computed before lighting, like ref) ---
	float3 bumpMod = float3(1.0f, 1.0f, 1.0f);
#if defined(WITH_ShadowMap)
	float shadowFactor = 1.0f;
	#if WITH_ShadowMap == CalcLispPos_VS
		shadowFactor = CalcGetShadowRate(In.VtxLit, N, In.VecEye).r;
	#else
		shadowFactor = CalcGetShadowRateWorldSpaceNon(In.VtxWld, N, In.VecEye).r;
	#endif
	bumpMod = pow(abs(float3(1.0f, 1.0f, 1.0f) - gFC_ShadowColor.xyz * shadowFactor), gFC_DebugPointLightParams.z);
#endif

	// --- Lightmap modulation: pow(|lm|, z), min'd with the shadow term ---
	// (ref Lit asm: log/×cb101.z/exp on the t6 sample, then mul into linearized
	// diffuse; WITH_BumpMap adds nothing by itself in the Non family — ref Bmp
	// variants declare no bump texture.)
#if defined(WITH_LightMap)
	bumpMod = min(pow(abs(lmTex), gFC_DebugPointLightParams.z), bumpMod);
#endif

	// --- PBL specular (WITH_SpecularMap) ---
	float3 pbl = 0.0f;
#ifdef WITH_SpecularMap
	#if defined(WITH_MultiTexture)
		float4 pblTex = tex2D(gSMP_PBLMap, difTexUV.xy);
		float4 pblTex2 = tex2D(gSMP_PBLMap2, In.TexDifDif.zw);
		pblTex = lerp(pblTex, pblTex2, In.ColVtx.a);
	#else
		float4 pblTex = tex2D(gSMP_PBLMap, difTexUV.xy);
	#endif
	pbl = pblTex.rgb * gFC_SpcMapMulCol.rgb * In.ColVtx.rgb * bumpMod;
#endif

	// --- Final lit color ---
	// ref applies the sRGB round-trip (pow(2.2)*bumpMod + pbl, then pow(5/11))
	// ONLY when bumpMod is active (WITH_BumpMap / WITH_ShadowMap); otherwise it
	// skips straight to scatter + final gamma to avoid an identity transform.
#if defined(WITH_LightMap) || defined(WITH_ShadowMap) || defined(WITH_SpecularMap)
	float3 litColor = pow(abs(sampledColor.rgb), 2.2f) * bumpMod + pbl;
	litColor = pow(abs(litColor), 5.0f / 11.0f);
#else
	float3 litColor = sampledColor.rgb + pbl;
#endif
	{
		float fog = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w);
		litColor = lerp(litColor, gFC_FogCol.xyz, fog);
	}
#ifdef VSLS
	litColor = CalcGetLightScatteringCol_Blend(float4(litColor, 1.0f), In.LsMul, In.LsAdd).rgb;
#else
	litColor = CalcGetLightScatteringCol(float4(litColor, 1.0f), In.VecEye).rgb;
#endif
#ifdef WITH_Glow
	litColor = ReverseToneMap(litColor);
#endif
	litColor = pow(abs(litColor), 2.2f);
	Out.Color.rgb = litColor;
	return Out;
}
