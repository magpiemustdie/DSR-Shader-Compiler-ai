// FRPG_FS_NtoA.fx — Normal-to-Alpha shader
// Variants: Non (base), Sdw (shadow=1), Csd (shadow=2), DepAlp (discard only)

// Full standard cbuffer (c1..c102, dcl cb0[103]) + samplers + AlphaTestBuffer (b1) — matches original layout
#include "FRPG_Common_SMP.fxh"
#include "FRPG_Common_FC.fxh"

// --- Input structures ---

struct PS_IN_Non {
    float4 Pos     : SV_Position;
    float4 WorldPosZ : TEXCOORD0;
    float4 NrmFog  : TEXCOORD2;
    float4 WorldPos : TEXCOORD3;
    float4 Color   : COLOR0;
    float2 UV      : TEXCOORD6;
    float  ClipDist : SV_ClipDistance;
    uint  IsFront  : SV_IsFrontFace;
};

struct PS_IN_Sdw {
    float4 Pos     : SV_Position;
    float4 WorldPosZ : TEXCOORD0;
    float4 ShdProj : TEXCOORD1;
    float4 NrmFog  : TEXCOORD2;
    float4 WorldPos : TEXCOORD3;
    float4 Color   : COLOR0;
    float2 UV      : TEXCOORD6;
    float  ClipDist : SV_ClipDistance;
    uint   IsFront : SV_IsFrontFace;
};

struct PS_IN_Csd {
    float4 Pos     : SV_Position;
    float4 WorldPosZ : TEXCOORD0;
    float4 NrmFog  : TEXCOORD2;
    float4 WorldPos : TEXCOORD3;
    float4 Color   : COLOR0;
    float2 UV      : TEXCOORD6;
    float  ClipDist : SV_ClipDistance;
    uint   IsFront : SV_IsFrontFace;
};

struct PS_IN_DepAlp {
    float4 Pos       : SV_Position;
    float4 UVPacked  : TEXCOORD6;   // zw = UV (VS packs: o1.zw)
    float4 WorldNrm  : TEXCOORD2;
    float4 WorldPos  : TEXCOORD3;
    float4 Color     : COLOR0;
    float  ClipDist  : SV_ClipDistance;
};

struct PS_OUT {
    float4 Color0 : SV_Target0;
    float4 Color1 : SV_Target1;
};

// --- Shadow function ---

#ifdef WITH_ShadowMap
float3 CalcNtoAShadow(float4 posInLight, float4 clampRect, float eyeLen, float3 N)
{
    float2 posXY = posInLight.xy;
    posXY -= (posXY < clampRect.xy) * posInLight.w;
    posXY += (clampRect.zw < posXY) * posInLight.w;

    float NdotL = dot(gFC_ShadowLightDir.xyz, N);
    float bias = saturate((NdotL + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
    float slope = saturate((gFC_ShadowMapParam.y - eyeLen) * gFC_ShadowMapParam.z);

    float3 uvw = posInLight.xyz / posInLight.w;

    float4 s01 = float4(
        gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2(-1, -1)),
        gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 0, -1)),
        gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 1, -1)),
        gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2(-1,  0)));
    float4 s23 = float4(
        gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 0,  0)),
        gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 1,  0)),
        gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2(-1,  1)),
        gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 0,  1)));
    float s = dot(s01, 0.111111f) + dot(s23, 0.111111f)
            + 0.111111f * gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, int2( 1,  1));

    s += bias;
    s = min(s, 1.0f);
    float3 shadowColor = slope * gFC_ShadowColor.xyz;
    float3 s3 = 1.0f - shadowColor * s;
    return pow(abs(s3), gFC_DebugPointLightParams.zzz);
}
#endif

// --- DepAlp variant: simple discard ---

#ifdef WITH_DepAlp

void FragmentMain(PS_IN_DepAlp In)
{
    float3 N = normalize(In.WorldNrm.xyz);
    float3 V = In.WorldPos.xyz / length(In.WorldPos.xyz);

    float NdotV = abs(dot(N, V));
    float alpha = NdotV - gFC_NormalToAlphaParam.x;
    alpha = saturate(alpha * gFC_NormalToAlphaParam.y);
    float texAlpha = gSMP_0.Sample(gSMP_0Sampler, In.UVPacked.zw).w;
    alpha *= texAlpha;
    alpha *= In.Color.w;

    if (AlphaTest == 1 && AlphaTestRef.x >= alpha)
        discard;
}

#else

// --- Non/Sdw/Csd variants: full PBR forward ---

PS_OUT FragmentMain(
#if defined(WITH_ShadowMap) && WITH_ShadowMap == 2
    PS_IN_Csd In
#elif defined(WITH_ShadowMap)
    PS_IN_Sdw In
#else
    PS_IN_Non In
#endif
)
{
    float3 N = normalize(In.NrmFog.xyz);
    float fogFactor = In.NrmFog.w;

    float3 V = In.WorldPos.xyz / length(In.WorldPos.xyz);
    float eyeLen = length(In.WorldPos.xyz);

    // Hemi sky/ground blend from N.y
    float hemiBlend = N.y * 0.5f + 0.5f;
    float3 hemiColor = lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, hemiBlend);

    // Environment map
    float3 envColor = gSMP_11_CUBE.Sample(gSMP_11_CUBESampler, N).xyz * gFC_EnvDifMapMulCol.xyz;

    // Shadow
    float3 shadowFactor = float3(1, 1, 1);
#if defined(WITH_ShadowMap)
    float3 shadowPos = In.WorldPos.xyz;
    float shadowViewZ = 0;
#if defined(WITH_ShadowMap) && WITH_ShadowMap == 2
    shadowPos = In.WorldPosZ.xyz;
    shadowViewZ = In.WorldPosZ.w;
    float4 zCmp = gFC_ShadowStartDist < shadowViewZ;
    int cascadeIndex = (int)(dot(zCmp, float4(1, 1, 1, 1)) - 1.0f);
    float4 posInLight = mul(float4(shadowPos, 1), gFC_ShadowMapMtxArray[cascadeIndex]);
    float4 clampRect = posInLight.w * gFC_ShadowMapClamp[cascadeIndex];
    shadowFactor = CalcNtoAShadow(posInLight, clampRect, eyeLen, N);
#else
    shadowFactor = CalcNtoAShadow(In.ShdProj, In.ShdProj.w * gFC_ShadowMapClamp0, eyeLen, N);
#endif
#endif

    // Diffuse texture
    float4 diffuse = gSMP_0.Sample(gSMP_0Sampler, In.UV) * In.Color * gFC_DifMapMulCol;

    // SRGB decode
    float3 diffLin = pow(abs(diffuse.xyz), 2.2f);

    // Combine env + hemi (+ shadow on env only)
    float3 combined = envColor * shadowFactor + hemiColor;
    combined *= diffLin;

    // Gamma encode
    float3 gammaCol = pow(abs(combined), 1.0f / 2.2f);

    // Fog
    float fogF = saturate(fogFactor);
    fogF = saturate(fogF * gFC_FogCol.w);
    float3 fogged = lerp(gammaCol, gFC_FogCol.xyz, fogF);

    // Specular (GGX BRDF using light scattering slots c13-c20)
    float3 fresnelSpec = exp2(eyeLen * -gFC_LsBeta1PlusBeta2.xyz * gFC_LsLightDir.w * 2.081369f);
    float3 specFresnelColor = fresnelSpec * gFC_LsTerrainReflectance.xyz;

    float VdotFF = dot(V, gFC_LsLightDir.xyz);
    float VdotFF_sq1 = VdotFF * VdotFF + 1.0f;

    float G_denom = gFC_LsHGg.z * -VdotFF + gFC_LsHGg.y;
    float G_rsqrt = rsqrt(G_denom);
    float G = 1.0f / G_denom * G_rsqrt * gFC_LsHGg.x;

    float3 ggxTerm = G * gFC_LsBetaDash2.xyz + gFC_LsBetaDash1.xyz * VdotFF_sq1;
    ggxTerm *= (1.0f - fresnelSpec) * gFC_LsOneOverBeta1PlusBeta2.xyz * gFC_LsTerrainReflectance.w * gFC_LsSunColor.xyz;

    float3 specFinal = fogged * specFresnelColor + ggxTerm;
    specFinal = lerp(fogged, specFinal, gFC_LsSunColor.w);
    float3 outCol = pow(abs(specFinal), 2.2f);

    // Normal-to-Alpha
    float NdotV = abs(dot(V, N));
    float ntoa = NdotV - gFC_NormalToAlphaParam.x;
    ntoa = saturate(ntoa * gFC_NormalToAlphaParam.y);
    float outAlpha = ntoa * diffuse.w;

    // Alpha test
    if (AlphaTest == 1 && AlphaTestRef.x >= outAlpha)
        discard;

    // Debug visualization
    float3 debugColor = 0;
    uint debugMode = gFC_DebugDraw.x;
    switch (debugMode) {
    case 1:
        debugColor = outCol;
        break;
    case 2:
        debugColor = exp2(diffuse.xyz);
        break;
    case 3:
        debugColor = 0;
        break;
    case 4:
        debugColor = 0;
        break;
    case 5:
        debugColor = N * 0.49804f + 0.49804f;
        break;
    case 6:
        debugColor = float3(1, 0, 0);
        break;
    default:
        debugColor = 0;
        break;
    }

    PS_OUT Out;
    Out.Color0 = float4(outCol, outAlpha);
    Out.Color1 = float4(debugColor, 0);
    return Out;
}

#endif
