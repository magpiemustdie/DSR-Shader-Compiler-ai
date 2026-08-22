#include "FRPG_Water_Common.fxh"

WATER_OUT FragmentMain_WaterEnv(WATER_IN_BASE In)
{
    float2 screenUV = In.Pos.xy * gFC_SAOParams.xy;

    float2 uvA_proj = In.ProjUV_A.xy / In.ProjUV_A.w;
    float2 uvB_proj = In.ProjUV_B.xy / In.ProjUV_B.w;

    float4 r1;
    r1.xy = uvA_proj * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r1.zw = uvB_proj * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    float4 r2 = screenUV.xyxy * 2.0f - r1;

    float h0 = gSMP_NormalMap.Sample(gSMP_NormalMapSampler, r1.xy);
    float h1 = gSMP_NormalMap.Sample(gSMP_NormalMapSampler, r1.zw);
    float h2 = gSMP_NormalMap.Sample(gSMP_NormalMapSampler, r2.xy);
    float h3 = gSMP_NormalMap.Sample(gSMP_NormalMapSampler, r2.zw);

    r1.z = In.TanFrameA.y + In.TanFrameA.y;
    float hDelta0 = h0 - h2;
    float hDelta1 = h1 - h3;

    float3 n1;
    n1.x = hDelta0 * gFC_WaterWaveHeight + r1.z;
    n1.y = In.TanFrameA.z + In.TanFrameA.z;
    n1.z = In.TanFrameA.x + In.TanFrameA.x;
    n1 = normalize(n1);

    float3 n2;
    n2.x = In.TanFrameB.z + In.TanFrameB.z;
    n2.y = In.TanFrameB.x + In.TanFrameB.x;
    n2.z = hDelta1 * gFC_WaterWaveHeight + In.TanFrameB.y + In.TanFrameB.y;
    n2 = normalize(n2);

    float3 N_wave = n2.zxy * n1.yzx - n1 * n2;

    float worldNrmLen = length(In.WorldNrm.xyz);
    float3 V = In.WorldNrm.xyz / worldNrmLen;

    float NdotV = dot(N_wave, V);
    float omNdotV = max(1.0f - max(NdotV, 0.0f), 0.0f);
    float fresnel = pow(omNdotV, gFC_WaterFresnelPow);
    fresnel = gFC_WaterFresnelBias * (1.0f - fresnel) + fresnel;
    fresnel *= gFC_WaterFresnelScale;

    float3 R = NdotV * 2.0f * N_wave - V;

    float4 refractUV = N_wave.xzxz * gFC_WaterRefractBand;
    refractUV *= In.Color.wwww;

    float3 diffRipple;
    diffRipple.x = gSMP_DiffuseMap.Sample(gSMP_DiffuseMapSampler, screenUV + refractUV.zw);
    diffRipple.y = gSMP_DiffuseMap.Sample(gSMP_DiffuseMapSampler, screenUV + refractUV.xy * 1.03f);
    diffRipple.z = gSMP_DiffuseMap.Sample(gSMP_DiffuseMapSampler, screenUV + refractUV.xy * 1.06f);

    float3 maskVals;
    maskVals.x = gSMP_MaskMap.Sample(gSMP_MaskMapSampler, screenUV + refractUV.zw);
    maskVals.y = gSMP_MaskMap.Sample(gSMP_MaskMapSampler, screenUV + refractUV.xy * 1.03f);
    maskVals.z = gSMP_MaskMap.Sample(gSMP_MaskMapSampler, screenUV + refractUV.xy * 1.06f);

    float3 maskFactor = (maskVals == 1.0f) ? 1.0f : 0.0f;

    float3 diffBase = gSMP_DiffuseMap.Sample(gSMP_DiffuseMapSampler, screenUV);
    float3 diffBlend = lerp(diffBase, diffRipple, maskFactor);

    float3 envColorLin = exp2(log2(abs(gFC_WaterFresnelColor.xyz)) * 2.2f);
    float3 envSample = gSMP_EnvMap.Sample(gSMP_EnvMapSampler, R);

    float NdotL_dir = max(-dot(R, gFC_SpcLightVec.xyz), 0.0f);
    float specDir = pow(NdotL_dir, gFC_SpcParam.x);

#ifndef WITH_GBuffer
    float3 specAccum = AccumulateClusteredLights(In.WorldPos, R, gFC_SpcParam.x);
#else
    float3 specAccum = 0.0f;
#endif

    float3 specCombined = gFC_SpcLightCol.xyz * specDir + specAccum;

    float waveHeightAvg = (h0 + h1 + h2 + h3) * gFC_WaterWaveHeight * 0.25f;

#ifdef WITH_ShadowMap
    float3 shadowFactor = CalcWaterShadow(In.WorldPos, waveHeightAvg, N_wave, V, In.WorldPos.w);
#else
    float3 shadowFactor = 1.0f;
#endif

    float3 waterColorLin = exp2(log2(abs(gFC_WaterColor.xyz)) * 2.2f);
    float  waterBlend = In.Color.w * gFC_WaterColor.w;

    float3 waterColorShadowed = waterColorLin * shadowFactor;
    diffBlend = lerp(diffBlend, waterColorShadowed, waterBlend);

    float3 lit = envSample * envColorLin + specCombined;
    float3 final = lerp(diffBlend, lit, fresnel);
    final *= In.Color.xyz;

    float fade = min(In.Color.w, gFC_WaterFadeBegin.x) * gFC_WaterFadeBegin.y;

    float3 linCol = exp2(log2(abs(final)) * (5.0f/11.0f));

    float fogFactor = saturate(In.Fog.w);
    fogFactor = saturate(fogFactor * gFC_FogCol.w);
    linCol = lerp(linCol, gFC_FogCol.xyz, fogFactor);

    float VdotFF = dot(V, gFC_WaterFresnelFactors.xyz);
    float VdotFF_sq1 = VdotFF * VdotFF + 1.0f;

    float3 fresnelSpec = exp2(worldNrmLen * -gFC_WaterFresnelAttn.xyz * gFC_WaterFresnelFactors.w * 2.081369f);
    float3 specFresnelColor = fresnelSpec * gFC_WaterSpecColor.xyz;

    float G_denom = gFC_WaterGGXInner.z * -VdotFF + gFC_WaterGGXInner.y;
    float G_rsqrt = rsqrt(G_denom);
    float G = 1.0f / G_denom * G_rsqrt * gFC_WaterGGXInner.x;

    float3 ggxTerm = G * gFC_WaterGGXB.xyz;
    ggxTerm = gFC_WaterGGXA.xyz * VdotFF_sq1 + ggxTerm;
    ggxTerm *= (1.0f - fresnelSpec) * gFC_WaterRoughness.xyz * gFC_WaterSpecColor.w * gFC_WaterSpecTint.xyz;

    float3 specFinal = linCol * specFresnelColor + ggxTerm;
    specFinal = lerp(linCol, specFinal, gFC_WaterSpecTint.w);

    float3 gammaCol = exp2(log2(abs(specFinal)) * 2.2f);

    WATER_OUT Out;
    Out.Color.xyz = fade * (gammaCol - diffBlend) + diffBlend;
    Out.Color.w = 1.0f;
    return Out;
}
