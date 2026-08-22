/***************************************************************************//**

	@file		FRPG_FS_HemEnv_Alpha.fx
	@brief		Alpha blend fragment shader (OLD_VERSION, 4 MRT)
	@par

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
#ifdef _PS3
	#define ENABLE_FS
#else
	#define ENABLE_VS
	#define ENABLE_FS
#endif

#define OLD_VERSION 1
#define USE_SH 1
#define WITH_Parallax 1

// Stub definitions for non-OLD registers used in ForwardPBL/Tonemap functions not called by AlphaBlend
static const uint4 gFC_DebugDraw = 0;

#include "FRPG_Common.fxh"

// FS-local normal helpers: reference Alp shaders do NOT apply gFC_NormalScale (cb0[194].z).
// Also expose the raw (pre-normalize) normal and the normalized detail normal for the
// |dot(In.VecNrm, detailNrm)| factor used in envR/specular IBL.
HALF3
_ApplyDetailBump_FS(float2 texUv, HALF3 vecNrm, HALF3 vecTan, HALF3 vecBin, out HALF3 outRaw, out HALF3 outDetail)
{
	HALF3 detailBump = DecodeNormalMap(TEX2DSAMPLER(gSMP_DetailBumpMap), (texUv*gFC_DetailBumpParam.xx));
	detailBump.xy *= gFC_DetailBumpParam.w;
	detailBump.z += (dot(detailBump.xy,detailBump.xy) < 0.00001f); //avoid zero divide; detailBump.z will not go negative
	detailBump = normalize(detailBump); //normalize
	outDetail = detailBump;

	HALF3 raw = vecBin*detailBump.x + vecTan*detailBump.y + vecNrm*detailBump.z;
	outRaw = raw;
	return normalize(raw);
}

HALF3
CalcGetNormal_FromNormalTex_Bin_FS(TEX2DSAMPLERDECL(normalTexSmp), float2 texUv, HALF3 vecNrm, HALF4 vecTan, HALF3 vecBin, out HALF3 outRaw, out HALF3 outDetail)
{
	HALF3 vecTex = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp), texUv);

	//decode primary normal, tangent, binormal
	vecNrm = normalize(vecNrm);         //normal normalize
	vecTan.xyz = normalize(vecTan.xyz); //tangent normalize
	vecBin = normalize(vecBin); //normalize

	//calculate final normal from texture normal, primary normal, tangent, and binormal
	HALF3 pixNrm = normalize(vecBin*vecTex.x + vecTan.xyz*vecTex.y + vecNrm*vecTex.z);

	HALF3 vecBin2 = normalize(cross(pixNrm, vecTan.xyz))*vecTan.w;
	HALF3 vecTan2 = normalize(cross(vecBin2, pixNrm));
	return _ApplyDetailBump_FS(texUv, pixNrm, vecTan2, vecBin2, outRaw, outDetail);
}

HALF3
CalcGetNormal_FromNormalTex_Mul_Bin_FS(TEX2DSAMPLERDECL(normalTexSmp), TEX2DSAMPLERDECL(normalTexSmp2), float4 texUv, HALF3 vecNrm, HALF4 vecTan, HALF4 vecTan2, HALF3 vecBin, HALF3 vecBin2, HALF blendRate, out HALF3 outRaw, out HALF3 outDetail)
{
	HALF3 vecTex = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp), texUv.xy);
	HALF3 vecTex2 = DecodeNormalMap(TEX2DSAMPLER(normalTexSmp2), texUv.zw);

	//decode primary normal, tangent, binormal
	vecNrm = normalize(vecNrm);             //normal normalize
	vecTan.xyz = normalize(vecTan.xyz);     //tangent normalize
	vecTan2.xyz = normalize(vecTan2.xyz);   //tangent normalize

	vecBin = normalize(vecBin);   //normalize
	vecBin2 = normalize(vecBin2); //normalize

	//calculate final normal from texture normal, primary normal, tangent, and binormal
	HALF3 vecNrmA = normalize(vecBin*vecTex.x + vecTan.xyz*vecTex.y + vecNrm*vecTex.z);
	HALF3 vecNrmB = normalize(vecBin2*vecTex2.x + vecTan.xyz*vecTex2.y + vecNrm*vecTex2.z);

	HALF3 pixNrm = normalize(lerp(vecNrmA, vecNrmB, blendRate));    //blend normals

	HALF3 vecBin3 = normalize(cross(pixNrm, vecTan.xyz))*vecTan.w;
	HALF3 vecTan3 = normalize(cross(vecBin3, pixNrm));
	return _ApplyDetailBump_FS(texUv.xy, pixNrm, vecTan3, vecBin3, outRaw, outDetail);
}

cbuffer AlphaTestBuffer : register(b1)
{
	int g_AlphaTest : packoffset(c0.x);
	float g_AlphaTestRef : packoffset(c0.y);
};

struct ALPHA_OUT
{
	float4 Color : SV_Target0;
	float4 Normal : SV_Target1;
	float4 Albedo : SV_Target2;
	float4 Dummy : SV_Target3;
};

#if defined(WITH_MultiTexture) && !defined(WITH_SpecularMap)
ALPHA_OUT FragmentMain(VTX_OUT In)
{
	// Mul + !Spc: ref = 192 B 4-target stub, no cb0 access
	ALPHA_OUT Out;
	Out.Color = float4(1, 0, 1, 1);
	Out.Normal = float4(0.5f, 0.5f, 0.5f, 1.0f);
	Out.Albedo = float4(0, 0, 0, 1);
	Out.Dummy = float4(1, 0, 0, 1);
	return Out;
}
#else
ALPHA_OUT FragmentMain(VTX_OUT In)
{
	ALPHA_OUT Out;

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

#if defined(WITH_BumpMap)
	if (gFC_ParallaxParams.x > 0.0f) {
		difTexUV.xy = ParallaxOcclusionMapping(difTexUV.xy, gFC_ParallaxParams.x, In.VecEye.xyz, In.VecTan.xyz, In.VecBin, In.VecNrm.xyz);
	}
#endif

	float4 dif0;
#ifdef WITH_SpecularMap
#ifdef WITH_MultiTexture
	float4 pblTexData = tex2D(gSMP_PBLMap, difTexUV.xy);
	float4 pblTexData2 = tex2D(gSMP_PBLMap2, difTexUV.zw);
	pblTexData = lerp(pblTexData, pblTexData2, In.ColVtx.a);
#else
	float4 pblTexData = tex2D(gSMP_PBLMap, difTexUV);
#endif
	float4 overrideParams = gFC_DebugMaterialParams;
	float3 overrideRange = overrideParams.xyz - 1.0f;
	float3 overrideFlags = saturate(overrideParams.xyz);
	float3 pblParams = lerp(pblTexData.rgb, overrideRange, overrideFlags);
	float specIntensity = pblParams.z * 0.2f;
	float emissiveFactor = (1.0f - pblTexData.a) * overrideParams.w;
	float roughness = pblParams.x;
	float metalness = pblParams.y;
	float specLevel = pblParams.z;

#ifdef WITH_MultiTexture
	{
		float4 difSample1 = TexDiff(difTexUV.xy);
		float4 difSample2 = TexDiff2(difTexUV.zw);
		difSample2.rgb += gFC_FgSkinAddColor.rgb;
		dif0.rgb = lerp(difSample1.rgb, difSample2.rgb, In.ColVtx.a);
		dif0.w = 1.0f;
		dif0.xyz *= In.ColVtx.xyz;
	}
#else
	dif0 = TexDiff(difTexUV);
	dif0.rgb += gFC_FgSkinAddColor.rgb;
	dif0 *= In.ColVtx * gFC_ModelMulCol * lerp(gFC_DifMapMulCol, gFC_SpcMapMulCol, metalness);
#endif
#else
#ifdef WITH_MultiTexture
	{
		float4 difSample1 = TexDiff(difTexUV.xy);
		float4 difSample2 = TexDiff2(difTexUV.zw);
		difSample2.rgb += gFC_FgSkinAddColor.rgb;
		dif0.rgb = lerp(difSample1.rgb, difSample2.rgb, In.ColVtx.a);
		dif0.w = 1.0f;
		dif0.xyz *= In.ColVtx.xyz;
	}
#else
	dif0 = TexDiff(difTexUV);
	dif0.rgb += gFC_FgSkinAddColor.rgb;
	dif0 *= In.ColVtx;
#endif
	dif0 *= gFC_ModelMulCol;
	dif0 *= gFC_DifMapMulCol;
#endif

#ifndef WITH_MultiTexture
	if (g_AlphaTest == 1 && g_AlphaTestRef >= dif0.w)
		discard;
#endif

#ifdef WITH_SpecularMap
#ifndef WITH_MultiTexture
	Out.Albedo = float4(pblTexData.a * dif0.rgb, dif0.w);
#endif
#endif

	float3 albedo = Srgb2linear(dif0.rgb);
	float alpha = dif0.w;

	float3 nRaw;
	float3 detailNrm = 0.0f;

	float3 vNrm = In.VecNrm.xyz;

{//normal
    #if WITH_ShadowMap == 2
        #ifdef WITH_BumpMap
            float3 vTan = normalize(In.VecTan.xyz);
            #ifdef WITH_MultiTexture
                float3 bump1 = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap), difTexUV.xy);
                float3 bump2 = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap2), difTexUV.zw);
                float3 vBin = normalize(In.VecBin.xyz);
                float3 nrmA = normalize(vBin*bump1.x + vTan*bump1.y + vNrm*bump1.z);
                float3 nrmB = normalize(vBin*bump2.x + vTan*bump2.y + vNrm*bump2.z);
                vNrm = normalize(lerp(nrmA, nrmB, In.ColVtx.a));
                APPLY_DETAIL_BUMP_TAN(vNrm, In.VecTan, difTexUV.xy);
                nRaw = vNrm;
            #else
                vNrm = CalcGetNormal_FromNormalTex_Bin_FS(TEX2DSAMPLER(gSMP_BumpMap), difTexUV, vNrm, In.VecTan, In.VecBin.xyz, nRaw, detailNrm);
            #endif
        #else
            vNrm = normalize(vNrm);
            APPLY_DETAIL_BUMP(vNrm, difTexUV.xy);
            nRaw = vNrm;
        #endif
    #else
	#ifdef WITH_BumpMap
		#ifdef WITH_MultiTexture
			#ifdef CALC_VS_BINORMAL
				vNrm = CalcGetNormal_FromNormalTex_Mul_Bin_FS(TEX2DSAMPLER(gSMP_BumpMap), TEX2DSAMPLER(gSMP_BumpMap2), difTexUV, vNrm, In.VecTan, In.VecTan2, In.VecBin, In.VecBin2, In.ColVtx.a, nRaw, detailNrm);
			#else
				float3 localVecBin = cross(vNrm, In.VecTan.xyz) * In.VecTan.w;
				float3 localVecBin2 = cross(vNrm, In.VecTan2.xyz) * In.VecTan2.w;
				vNrm = CalcGetNormal_FromNormalTex_Mul_Bin_FS(TEX2DSAMPLER(gSMP_BumpMap), TEX2DSAMPLER(gSMP_BumpMap2), difTexUV, vNrm, In.VecTan, In.VecTan2, localVecBin, localVecBin2, In.ColVtx.a, nRaw, detailNrm);
			#endif
		#else
			#ifdef CALC_VS_BINORMAL
				vNrm = CalcGetNormal_FromNormalTex_Bin_FS(TEX2DSAMPLER(gSMP_BumpMap), difTexUV, vNrm, In.VecTan, In.VecBin, nRaw, detailNrm);
			#else
				float3 localVecBin = cross(vNrm, In.VecTan.xyz) * In.VecTan.w;
				vNrm = CalcGetNormal_FromNormalTex_Bin_FS(TEX2DSAMPLER(gSMP_BumpMap), difTexUV, vNrm, In.VecTan, localVecBin, nRaw, detailNrm);
			#endif
		#endif
	#else
		vNrm = normalize(vNrm);
		APPLY_DETAIL_BUMP(vNrm, difTexUV.xy);
		nRaw = vNrm;
	#endif
    #endif
	}

	float3 N = vNrm;
	float3 V = In.VecEye.xyz;

#ifdef WITH_SpecularMap
	float ndotv = dot(V, N);
	float3 R = 2.0f * ndotv * N - V;
	float ndotvS = saturate(ndotv);

#ifdef WITH_MultiTexture
	float3 difColor = albedo - metalness * albedo;
#else
	float3 difColor = albedo * (1.0f - metalness);
#endif

	float3 specColor = metalness * (albedo - specLevel * float4(0.2f, 0.2f, 0.2f, 0.0f).xyz) + specIntensity;
	float specLum = dot(specColor, 0.33f);
	specLum = saturate(specLum * 50.0f);
#endif

	float3 envLight = 0;
	if (gFC_SHEnabled < 0.5f) {
		float probeScale = gFC_LightProbeParam.x * gFC_MagicLightParam.x;
		float3 envMul = gFC_EnvDifMapMulCol.xyz * probeScale;
		float3 envSample = texCUBElod(gSMP_11_CUBE, float4(N, 0)).xyz;
#ifdef WITH_SpecularMap
		envLight = envMul * envSample * difColor;
#else
		envLight = envMul * envSample * albedo;
#endif
	} else {
		float3 shLight = CalcSH(N, float4(In.VtxWld.xyz, 1.0f));
		float probeScale = gFC_LightProbeParam.x * gFC_MagicLightParam.x;
		float3 envMul = gFC_EnvDifMapMulCol.xyz * probeScale;
		float3 envSample = texCUBElod(gSMP_11_CUBE, float4(N, 0)).xyz;
#ifdef WITH_SpecularMap
		envLight = (shLight + envMul * envSample) * difColor;
#else
		envLight = (shLight + envMul * envSample) * albedo;
#endif
	}

#ifdef WITH_SpecularMap
	{//specular IBL
		float smoothness = saturate(1.0f - roughness);
		float sqSmooth = sqrt(smoothness);
		float envFresnel = smoothness * (sqSmooth + roughness);
		float3 envR = N + envFresnel * (R - normalize(nRaw));
		float envMip = linearRoughnessToMipLevel(roughness, gFC_LightProbeParam.w);
		float3 spcEnvMul = gFC_EnvSpcMapMulCol.xyz * gFC_LightProbeParam.y;
		float3 spcEnv0 = texCUBElod(gSMP_12_CUBE, float4(envR, envMip)).xyz;
		float3 spcEnv1 = texCUBElod(gSMP_14_CUBE, float4(envR, envMip)).xyz;
		float3 spcEnv = spcEnv0 + gFC_MagicLightParam.y * spcEnv1;
		spcEnv = spcEnvMul * spcEnv;
		float envNV = max(abs(dot(In.VecNrm.xyz, R)), 1e-8f);
		spcEnv *= envNV;

		float2 dfgLut = tex2Dlod(gSMP_9, float4(roughness, ndotvS, 0, 0)).xy;
		float3 dfgFactor = specColor * dfgLut.x + specLum * dfgLut.y;
		envLight += spcEnv * dfgFactor;
#ifndef WITH_MultiTexture
		envLight *= pblTexData.a;
#endif
	}
#endif

	float3 dirLight = envLight;
	{
		uint dirCount = min(3u, gFC_DirLightCount.x);
#ifdef WITH_SpecularMap
		float r = max(roughness, 0.014f);
		float3 fresnelBase = specLum - specLum * specColor;
		float a = r * r;
		float aSq = a * a - 1.0f;
		float k = a * 0.5f;
		float oneMinusK = 1.0f - k;
		float g1v = 1.0f / (ndotvS * oneMinusK + k);
		for (uint i = 0; i < dirCount; i++) {
			float3 L = -gFC_DirLightVec[i].xyz;
			float dotLR = dot(L, R);
			float3 L_bent = R - dotLR * L;
			bool bentValid = dotLR < 0.9999619126f;
			L_bent = L * 0.9999619126f + normalize(L_bent) * 0.0087265354f;
			L_bent = bentValid ? normalize(L_bent) : R;
			float ndotl = saturate(dot(N, L));
			float3 H = normalize(V + L_bent);
			float vdoth = saturate(dot(V, H));
			float ndoth = saturate(dot(N, H));
			float ndotlb = saturate(dot(N, L_bent));

			float ndfExp = exp2(vdoth * (-5.554730f * vdoth - 6.983160f));
			float3 F = fresnelBase * ndfExp + specColor;

			float ndothSq = ndoth * ndoth;
			float d = a / (1.0f + ndothSq * aSq);
			d = d * d * 0.318309873f;

			float g1l = 1.0f / (ndotlb * oneMinusK + k);
			float g = g1v * g1l;

			float spec = d * g * 0.25f;
			float3 result = difColor * 0.318309873f + F * spec;
			result *= gFC_DirLightCol[i].xyz;
			result *= ndotl;
			result *= 3.14159274f;
			dirLight += result;
		}
#else
		float invPi = 0.318309873f;
		float3 diffuseFactor = albedo * invPi;
		for (uint i = 0; i < dirCount; i++) {
			float ndotl = saturate(dot(N, -gFC_DirLightVec[i].xyz));
			dirLight += diffuseFactor * gFC_DirLightCol[i].xyz * ndotl * 3.14159274f;
		}
#endif
	}

	float3 litColor = dirLight;

#if defined(WITH_LightMap) || defined(WITH_ShadowMap)
	float3 lightMapColor = 1.0f;
#endif

#ifdef WITH_LightMap
	{
#if defined(WITH_MultiTexture)
		float2 lightMapUV = In.TexLit.xy;
	#else
		float2 lightMapUV = In.TexDifLit.zw;
	#endif
		float4 lightMapSample = tex2D(gSMP_LightMap, lightMapUV);
		float lum = dot(lightMapSample.rgb, float3(0.2126729f, 0.7151522f, 0.0721750f));
		lum = max(lum, 0.001f);
		float scale = pow(lum, gFC_DebugPointLightParams.z) / lum;
		lightMapColor = lightMapSample.rgb * scale;
	}
#endif

#if defined(WITH_ShadowMap) && (WITH_ShadowMap == CalcLispPos_VS)
	{
		float4 posInLight = In.VtxLit;
		float4 clampRect = gFC_ShadowMapClamp0 * posInLight.w;
		posInLight.xy -= (posInLight.xy < clampRect.xy) * posInLight.w;
		posInLight.xy += (posInLight.xy > clampRect.zw) * posInLight.w;

		float ndotl = dot(gFC_ShadowLightDir.xyz, N);
		float fShadowBias = saturate((ndotl + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);

		float fade = saturate((gFC_ShadowMapParam.y - In.VecEye.w) * gFC_ShadowMapParam.z);

		float2 shadowUV = posInLight.xy / posInLight.w;
		float shadowDepth = posInLight.z / posInLight.w;

		float pcf = 0;
		const float w = 1.0f / 9.0f;
		// ref packs 9 taps as 2x dot4 + mad (9 literal copies of 1/9)
		pcf += dot(float4(
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2(-1, -1)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 0, -1)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 1, -1)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2(-1,  0))), float4(w, w, w, w));
		pcf += dot(float4(
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 0,  0)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 1,  0)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2(-1,  1)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 0,  1))), float4(w, w, w, w));
		pcf += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 1,  1)) * w;

		float atten = min(fShadowBias + pcf, 1.0f);
		float3 shadowFactor = 1.0f - fade * gFC_ShadowColor.xyz * atten;
		shadowFactor = pow(abs(shadowFactor), gFC_DebugPointLightParams.z);

	#ifdef WITH_LightMap
		lightMapColor = min(lightMapColor, shadowFactor);
		lightMapColor *= gFC_DebugPointLightParams.y;
	#else
		lightMapColor = shadowFactor;
	#endif
	}
#elif defined(WITH_ShadowMap) && (WITH_ShadowMap == 2)
	{
		// Per-pixel cascade shadow selection and PCF (Csd)
		float4 zGreater = (gFC_ShadowStartDist < In.VtxWld.wwww);
		int cascadeIdx = (int)(dot(zGreater, 1.0f) - 1.0f);

		float4 worldPos = float4(In.VtxWld.xyz, 1.0f);
		float4 posInLight = mul(worldPos, gFC_ShadowMapMtxArray[cascadeIdx]);

		float4 clampRect = gFC_ShadowMapClamp[cascadeIdx] * posInLight.w;
		posInLight.xy -= (posInLight.xy < clampRect.xy) * posInLight.w;
		posInLight.xy += (posInLight.xy > clampRect.zw) * posInLight.w;

		float ndotl = dot(gFC_ShadowLightDir.xyz, N);
		float bias = saturate((ndotl + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);

		float fade = saturate((gFC_ShadowMapParam.y - In.VecEye.w) * gFC_ShadowMapParam.z);

		float2 shadowUV = posInLight.xy / posInLight.w;
		float shadowDepth = posInLight.z / posInLight.w;

		float pcf = 0;
		const float w = 1.0f / 9.0f;
		// ref packs 9 taps as 2x dot4 + mad (9 literal copies of 1/9)
		pcf += dot(float4(
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2(-1, -1)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 0, -1)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 1, -1)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2(-1,  0))), float4(w, w, w, w));
		pcf += dot(float4(
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 0,  0)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 1,  0)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2(-1,  1)),
			gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 0,  1))), float4(w, w, w, w));
		pcf += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, shadowUV, shadowDepth, int2( 1,  1)) * w;

		float atten = min(bias + pcf, 1.0f);
		float3 shadowFactor = 1.0f - fade * gFC_ShadowColor.xyz * atten;
		shadowFactor = pow(abs(shadowFactor), gFC_DebugPointLightParams.z);

	#ifdef WITH_LightMap
		lightMapColor = min(lightMapColor, shadowFactor);
		lightMapColor *= gFC_DebugPointLightParams.y;
	#else
		lightMapColor = shadowFactor;
	#endif
	}
#endif

#if defined(WITH_LightMap) || defined(WITH_ShadowMap)
	litColor = envLight + dirLight * lightMapColor;
#endif

	{//hemisphere ambient
		float hemiBlend = N.x * 0.5f + 0.5f;
#ifdef WITH_SpecularMap
		litColor += difColor * lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, hemiBlend);
#else
		litColor += albedo * lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, hemiBlend);
#endif
	}

#ifdef WITH_SpecularMap
#ifndef WITH_MultiTexture
	litColor += emissiveFactor * albedo;
#endif
#endif

#ifdef WITH_GhostMap
	litColor = CalcGetGhost_NoTex(float4(litColor, alpha), N, V, gFC_GhostEdgeColor, gFC_GhostTexColor, gFC_GhostParam).rgb;
#endif

	{//fog
		float fog = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w);
		litColor = lerp(litColor, gFC_FogCol.xyz, fog);
	}

	if (gFC_GammaFlag.x > 0.5f) {
		litColor = Linear2srgb(litColor);
	}

	{//light scattering
		float4 scattered = CalcGetLightScatteringCol(float4(litColor, 1), In.VecEye);
		litColor = scattered.rgb;
	}

	if (gFC_GammaFlag.x > 0.5f) {
		litColor = Srgb2linear(litColor);
	}

	N = N * 0.5f + 0.5f;

	Out.Color = float4(litColor, alpha);
	Out.Normal = float4(N, alpha);
#ifdef WITH_SpecularMap
#ifdef WITH_MultiTexture
	Out.Albedo = float4(dif0.rgb * gFC_ModelMulCol * lerp(gFC_DifMapMulCol, gFC_SpcMapMulCol, metalness), dif0.w);
#else
	Out.Albedo = float4(pblTexData.a * dif0.rgb, dif0.w);
#endif
#else
	Out.Albedo = float4(dif0.rgb, alpha);
#endif
#ifdef WITH_SpecularMap
#ifdef WITH_MultiTexture
	Out.Dummy = float4(pblTexData.rgb, alpha);
#else
	Out.Dummy = float4(pblParams.rgb, alpha);
#endif
#else
	Out.Dummy = float4(1, 0, 0, alpha);
#endif

	return Out;
}

#endif // WITH_MultiTexture && !WITH_SpecularMap stub
