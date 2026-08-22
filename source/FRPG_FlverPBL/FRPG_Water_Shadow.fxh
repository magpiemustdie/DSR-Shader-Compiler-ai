#ifndef FRPG_WATER_SHADOW_FXH
#define FRPG_WATER_SHADOW_FXH

Texture2D    gSMP_ShadowMap         : register(t7);
SamplerComparisonState gSMP_ShadowMapSampler : register(s7);

// Shadow constants (from FRPG_Common_FC.fxh, non-OLD_VERSION layout)
float4x4 gFC_ShadowMapMtxArray[4] : register(c40);
float4   gFC_ShadowMapClamp[4]    : register(c56);
float4   gFC_ShadowMapParam       : register(c21);
float4   gFC_ShadowColor          : register(c22);
float4   gFC_ShadowStartDist      : register(c23);
float4   gFC_ShadowLightDir       : register(c73);
float4   gFC_DebugPointLightParams : register(c101);

#define gFC_ShadowMapMtxArray0 gFC_ShadowMapMtxArray[0]
#define gFC_ShadowMapMtxArray1 gFC_ShadowMapMtxArray[1]
#define gFC_ShadowMapMtxArray2 gFC_ShadowMapMtxArray[2]
#define gFC_ShadowMapMtxArray3 gFC_ShadowMapMtxArray[3]
#define gFC_ShadowMapClamp0 gFC_ShadowMapClamp[0]
#define gFC_ShadowMapClamp1 gFC_ShadowMapClamp[1]
#define gFC_ShadowMapClamp2 gFC_ShadowMapClamp[2]
#define gFC_ShadowMapClamp3 gFC_ShadowMapClamp[3]

float3 CalcWaterShadow(float3 worldPos, float waveHeightAvg, float3 N, float3 V, float viewZ)
{
    float3 wavePos = worldPos;
    wavePos.y += waveHeightAvg;

    float4 worldPos4 = float4(wavePos, 1.0f);
    float4 posInLight;
    float4 clampRect;

#if WITH_ShadowMap == 2
    int cascade = (int)(dot(step(gFC_ShadowStartDist, viewZ), 1.0f) - 1.0f);
    posInLight = mul(worldPos4, gFC_ShadowMapMtxArray[cascade]);
    clampRect = gFC_ShadowMapClamp[cascade];
#else
    posInLight = mul(worldPos4, gFC_ShadowMapMtxArray0);
    clampRect = gFC_ShadowMapClamp0;
#endif

    clampRect *= posInLight.w;
    posInLight.xy -= (posInLight.xy < clampRect.xy) * posInLight.w;
    posInLight.xy += (posInLight.xy > clampRect.zw) * posInLight.w;

    float3 uvw = posInLight.xyz / posInLight.w;

    float NdotL = dot(gFC_ShadowLightDir.xyz, N);
    float bias = saturate((NdotL + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
    uvw.z += bias;

    float s = 0;
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2(-1, -1));
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 0, -1));
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 1, -1));
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2(-1,  0));
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 0,  0));
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 1,  0));
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2(-1,  1));
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 0,  1));
    s += gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 1,  1));
    s *= 1.0f / 9.0f;

    s = min(s, 1.0f);
    float shadowDarkness = gFC_ShadowColor.w;
    float3 shadowColor = gFC_ShadowColor.xyz * shadowDarkness;
    s = 1.0f - shadowColor * s;
    return pow(abs(s), gFC_DebugPointLightParams.zzz);
}

#endif
