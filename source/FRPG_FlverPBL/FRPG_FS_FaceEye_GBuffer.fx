/***************************************************************************//**

    @file       FRPG_FS_FaceEye_GBuffer.fx
    @brief      Face eye fragment shader - GBuffer pass (PntSS/PntSSSS)
    @par        Layout: OLD_VERSION (DL_FREG c84-c195 + VR c196+), 4 MRT
                Reference: ShaderCache\FRPG_Phn_FaceEye____PntSS.hlsl (471 op)
                          ShaderCache\FRPG_Gst_FaceEye_CsdPntSS.hlsl

*//****************************************************************************/

#define ENABLE_FS
#define ENABLE_VS

#include "FRPG_Common.fxh"

#if defined(WITH_GBuffer)
#include "FRPG_Common_ForwardPBL.fxh"
#include "FRPG_ShadowFunc.fxh"
#endif

struct GBUFFER_GB_OUT
{
    float4 Color    : SV_Target0;
    float4 Normal   : SV_Target1;
    float4 Albedo   : SV_Target2;
    float4 Material : SV_Target3;
};

// FaceEye GB ref clamps the GGX denominator with 1e-8 (ref 321/386), unlike
// the shared GBPointLightContribution used by HemEnv GB.
float3 FaceEyeGBPointLightContribution(float3 N, float3 L, float3 V,
    float3 diffColor, float3 specColor, float specF90,
    float roughness, float3 LampColor, float LampDist,
    float OneOverFalloffEndMinusStart, float LampFalloffEnd, uint falloffMode)
{
    float3 diffContrib = diffColor * M_INV_PI;
    float3 Hn = normalize(V + L);
    float vdh = saturate(dot(V, Hn));
    float ndh = saturate(dot(N, Hn));
    float ndl = saturate(dot(N, L));
    float ndv = saturate(dot(N, V));
    float alpha = roughness * roughness;
#ifdef FACEEYE_GB_DENOM_CLAMP
    float denom = max(1e-8f, ndh * ndh * (alpha * alpha - 1.0f) + 1.0f);
#else
    float denom = ndh * ndh * (alpha * alpha - 1.0f) + 1.0f;
#endif
    float D = alpha / denom;
    D *= D;
    D *= M_INV_PI;
    float k = 0.5f * alpha;
    float denomV = ndv * (1.0f - k) + k;
    float denomL = ndl * (1.0f - k) + k;
    float visibility = (1.0f / denomV) * (1.0f / denomL);
    float3 specContrib = fresnel(vdh, specColor, specF90) * (D * visibility * 0.25f);

    float lampAtt = GB_lampAttenuation(LampDist, LampFalloffEnd, OneOverFalloffEndMinusStart, falloffMode);

    return saturate(dot(N, L)) * ((diffContrib + specContrib) * LampColor * lampAtt * M_PI);
}

GBUFFER_GB_OUT FragmentMain(VTX_OUT In)
{
    GBUFFER_GB_OUT GbOut;

    // ---------- material (ref 165-175) ----------
    float4 pbl = gSMP_1.Sample(gSMP_1Sampler, In.TexDif.xy);
    pbl.x = max(0.001f, pbl.x);
    float3 ovm1 = gFC_DebugMaterialParams.xyz + float3(-1.0f, -1.0f, -1.0f);
    float3 ovs = saturate(gFC_DebugMaterialParams.xyz);
    float rough = ovs.x * (ovm1.x - pbl.x) + pbl.x;
    float2 mtl = ovs.yz * (ovm1.yz - pbl.yz) + pbl.yz;
    float f0x02 = 0.2f * mtl.y;
    float emissive = (1.0f - pbl.w) * gFC_DebugMaterialParams.w;

    // ---------- color + alpha test (ref 176-186) ----------
    float4 sampledColor = gSMP_0.Sample(gSMP_0Sampler, In.TexDif.xy);
    sampledColor.xyz += gFC_FgSkinAddColor.xyz;
    float4 colorMul = gFC_ModelMulCol * In.ColVtx * lerp(gFC_DifMapMulCol, gFC_SpcMapMulCol, mtl.x);
    sampledColor *= colorMul;
    sampledColor = qlocDoAlphaTest(sampledColor);

    // ---------- albedo output + linearization (ref 187-190) ----------
    GbOut.Albedo.xyz = sampledColor.rgb * pbl.w;
    GbOut.Albedo.w = 1.0f;
    float3 albedoLin = pow(abs(sampledColor.rgb), 2.2f);

    // ---------- geometry (ref 191-200) ----------
    float3 N = normalize(In.VecNrm.xyz);
    In.VecEye = CalcGetVecEye_FS(In.VecEye);
    float NdotV = dot(In.VecEye.xyz, N);
    float rim2 = NdotV + NdotV;
    float3 R = rim2 * N - In.VecEye.xyz;
    float satNdotV = saturate(NdotV);

    // ---------- diffuse/specular colors (ref 201-206) ----------
    float3 diffCol = (1.0f - rough) * albedoLin;
    float3 specCol = rough * (albedoLin - 0.2f * mtl.x) + f0x02;
    float lum = saturate(50.0f * dot(specCol, 0.33f));

    // ---------- env diffuse (ref 207-216) ----------
    float3 envDif = 0.0f;
    if (gFC_SHEnabled < 0.5f) {
        envDif = gSMP_11_CUBE.SampleLevel(gSMP_11_CUBESampler, N, 0).xyz
               * (gFC_MagicLightParam.x * gFC_LightProbeParam.x)
               * gFC_EnvDifMapMulCol.xyz;
        envDif *= diffCol;
    }

    // ---------- env specular (ref 217-239) ----------
    float smoothness = saturate(1.0f - rough);
    float lerpFactor = smoothness * (sqrt(smoothness) + rough);
    float3 N2 = N + (R - N) * lerpFactor;
    float mip = linearRoughnessToMipLevel(rough, gFC_LightProbeParam.w);
    float3 envSpec = (gFC_MagicLightParam.y * gSMP_14_CUBE.SampleLevel(gSMP_14_CUBESampler, N2, mip).xyz
                     + gSMP_12_CUBE.SampleLevel(gSMP_12_CUBESampler, N2, mip).xyz)
                     * (gFC_LightProbeParam.y * gFC_EnvSpcMapMulCol.xyz);
    float fade = max(9.99999994e-009f, abs(dot(In.VecNrm.xyz, R)));
    float2 lut = gSMP_9.SampleLevel(gSMP_9Sampler, float2(rough, satNdotV), 0).xy;
    float3 envAccum = (envSpec * fade * (specCol * lut.x + lum * lut.y) + envDif) * pbl.w;

    // ---------- shadow (ref 242-322 Csd / Sdw) ----------
    float shadow16 = 0.0f;
#if defined(WITH_ShadowMap)
    {
        float4 position_in_light;
#if WITH_ShadowMap == CalcLispPos_VS
        float4 clampRect = gFC_ShadowMapClamp0 * In.VtxLit.w;
        position_in_light = In.VtxLit;
        position_in_light.xy -= (position_in_light.xy < clampRect.xy) * position_in_light.w;
        position_in_light.xy += (position_in_light.xy > clampRect.zw) * position_in_light.w;
#else
        float4 fEndDist = float4(gFC_ShadowStartDist.yzw, 65535.0f);
        float4 zGreater = (gFC_ShadowStartDist < In.VtxWld.w);
        float4 zLess = (fEndDist >= In.VtxWld.w);
        float4 fWeight = zGreater * zLess;
        float4x4 shadowMtx = gFC_ShadowMapMtxArray0 * fWeight.x;
        shadowMtx += gFC_ShadowMapMtxArray1 * fWeight.y;
        shadowMtx += gFC_ShadowMapMtxArray2 * fWeight.z;
        shadowMtx += gFC_ShadowMapMtxArray3 * fWeight.w;
        float4 clampRect = gFC_ShadowMapClamp1 * fWeight.y;
        clampRect += gFC_ShadowMapClamp0 * fWeight.x;
        clampRect += gFC_ShadowMapClamp2 * fWeight.z;
        clampRect += gFC_ShadowMapClamp3 * fWeight.w;
        float4 worldPos = float4(In.VtxWld.xyz, 1.0f);
        position_in_light = mul(worldPos, shadowMtx);
        clampRect *= position_in_light.w;
        position_in_light.xy -= (position_in_light.xy < clampRect.xy) * position_in_light.w;
        position_in_light.xy += (position_in_light.xy > clampRect.zw) * position_in_light.w;
#endif
        shadow16 = __GetShadowRate_GB16(position_in_light);
    }
    float shadowBias = saturate((dot(gFC_ShadowLightDir.xyz, N) + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
    float shadowWithBias = min(shadow16 + shadowBias, 1.0f);
    float shadowDist = saturate((gFC_ShadowMapParam.y - In.VecEye.w) * gFC_ShadowMapParam.z);
    float3 shadowRate = 1.0f - (float3)shadowDist * gFC_ShadowColor.rgb * shadowWithBias;
    envAccum *= exp2(gFC_DebugPointLightParams.z * log2(shadowRate));
#endif

    // ---------- SH / hemi (ref 240-290) ----------
    if (0.5f < gFC_SHEnabled) {
        float3 shPos = mul(float4(In.VtxWld.xyz, 1.0f), gFC_IVMtx).xyz;
        shPos = 0.5f + shPos.xzy;
        float sliceF = saturate(shPos.z);
        float4 sh0 = gSMP_13_3D.SampleLevel(gSMP_13_3DSampler, float3(shPos.xy, 0.142857149f * sliceF), 0).wxyz;
        float4 sh1 = gSMP_13_3D.SampleLevel(gSMP_13_3DSampler, float3(shPos.xy, 0.142857149f * (sliceF + 1.0f)), 0);
        float4 sh2 = gSMP_13_3D.SampleLevel(gSMP_13_3DSampler, float3(shPos.xy, 0.142857149f * (sliceF + 2.0f)), 0);
        float4 sh3 = gSMP_13_3D.SampleLevel(gSMP_13_3DSampler, float3(shPos.xy, 0.142857149f * (sliceF + 3.0f)), 0);
        float4 sh4 = gSMP_13_3D.SampleLevel(gSMP_13_3DSampler, float3(shPos.xy, 0.142857149f * (sliceF + 4.0f)), 0);
        float4 sh5 = gSMP_13_3D.SampleLevel(gSMP_13_3DSampler, float3(shPos.xy, 0.142857149f * (sliceF + 5.0f)), 0);
        float3 sh6 = gSMP_13_3D.SampleLevel(gSMP_13_3DSampler, float3(shPos.xy, 0.142857149f * (sliceF + 6.0f)), 0).xyz;
        float3 shW = 0.429042995f * float3(sh3.w, sh4.w, sh5.w);
        float basisY = N.z * N.z * 0.743125021f - 0.247707993f;
        float3 sh = basisY * sh6 + shW * (N.x * N.x - N.y * N.y) + 0.886227012f * sh0.xyz;
        float3 c1 = 0.85808599f * ((N.x * N.z) * float3(sh0.w, sh1.w, sh2.w) + (N.x * N.y) * sh4.xyz + (N.y * N.z) * sh5.xyz);
        float3 c2 = 1.02332795f * (sh1.xyz * N.y + sh3.xyz * N.x + sh2.xyz * N.z);
        envAccum += diffCol * max(0.0f, c2 + c1 + sh);
    } else {
        float hemiBlend = N.y * 0.5f + 0.5f;
        envAccum += diffCol * lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, hemiBlend);
    }

    // ---------- SAO (ref 291-297) ----------
    if (0.0f < gFC_SAOEnabled) {
        envAccum *= gSMP_8.Load(int3((int2)In.VtxClp.xy, 0)).x;
    }

    // ---------- point lights (ref 298-425 PntSS; PntSSSS: 4 lights, c112-115/c116-119) ----------
    float3 pointLight = 0.0f;
    {
        // light 0 (ref: assign + else 0)
        float3 L = gFC_PntLightPos[0].xyz - In.VtxWld.xyz;
        float distL = length(L);
        if (distL < gFC_PntLightCol[0].w) {
            L *= 1.0f / distL;
            pointLight = FaceEyeGBPointLightContribution(N, L, In.VecEye.xyz, diffCol, specCol, lum, rough,
                                                         gFC_PntLightCol[0].xyz, distL,
                                                         gFC_PntLightPos[0].w, gFC_PntLightCol[0].w,
                                                         (uint)gFC_DebugPointLightParams.x);
        } else {
            pointLight = 0.0f;
        }
        // light 1 (ref: += only)
        L = gFC_PntLightPos[1].xyz - In.VtxWld.xyz;
        distL = length(L);
        if (distL < gFC_PntLightCol[1].w) {
            L *= 1.0f / distL;
            pointLight += FaceEyeGBPointLightContribution(N, L, In.VecEye.xyz, diffCol, specCol, lum, rough,
                                                          gFC_PntLightCol[1].xyz, distL,
                                                          gFC_PntLightPos[1].w, gFC_PntLightCol[1].w,
                                                          (uint)gFC_DebugPointLightParams.x);
        }
#if defined(WITH_GBUFFER_4LIGHTS)
        // lights 2-3 (PntSSSS only)
        L = gFC_PntLightPos[2].xyz - In.VtxWld.xyz;
        distL = length(L);
        if (distL < gFC_PntLightCol[2].w) {
            L *= 1.0f / distL;
            pointLight += FaceEyeGBPointLightContribution(N, L, In.VecEye.xyz, diffCol, specCol, lum, rough,
                                                          gFC_PntLightCol[2].xyz, distL,
                                                          gFC_PntLightPos[2].w, gFC_PntLightCol[2].w,
                                                          (uint)gFC_DebugPointLightParams.x);
        }
        L = gFC_PntLightPos[3].xyz - In.VtxWld.xyz;
        distL = length(L);
        if (distL < gFC_PntLightCol[3].w) {
            L *= 1.0f / distL;
            pointLight += FaceEyeGBPointLightContribution(N, L, In.VecEye.xyz, diffCol, specCol, lum, rough,
                                                          gFC_PntLightCol[3].xyz, distL,
                                                          gFC_PntLightPos[3].w, gFC_PntLightCol[3].w,
                                                          (uint)gFC_DebugPointLightParams.x);
        }
#endif
    }

#if defined(WITH_GhostMap)
    // ---------- ghost light (ref Gst 534-549) ----------
    {
        float3 Lg = gFC_GhostLightPos.xyz - In.VtxWld.xyz;
        float distG = length(Lg);
        Lg /= distG;
        float distFade = saturate((gFC_GhostLightCol.w - distG) * gFC_GhostLightPos.w);
        float3 ghostLight = distFade * gFC_GhostLightCol.xyz;
        float ndlG = max(0.0f, dot(Lg, N));
        pointLight += ghostLight * ndlG;
        pointLight += ghostLight * pow(ndlG, gFC_DebugDraw.x);
    }
#endif

    pointLight += envAccum;
    float3 lit = emissive * albedoLin + pointLight;

#if defined(WITH_GhostMap)
    // ---------- ghosting (ref Gst 551-558) ----------
    {
        float3 edgeCol = gFC_GhostEdgeColor.xyz * gFC_GhostEdgeColor.w;
        float rimF = max(min(abs(rim2), 0.7f), 0.1f) - 0.1f;
        rimF *= 1.66666663f;
        float3 texCol = gFC_GhostTexColor.xyz * gFC_GhostTexColor.w;
        lit += lerp(edgeCol, texCol, rimF) * gFC_GhostParam.x;
    }
#endif

    // ---------- fog (ref 428-431) ----------
    float fog = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w);
    lit = lerp(lit, gFC_FogCol.xyz, fog);

    // ---------- gamma round-trip + scattering (ref 432-461) ----------
    if (gFC_GammaFlag.x > 0.5f) {
        lit = Linear2srgb(lit);
    }
    lit = CalcGetLightScatteringCol(float4(lit, 1.0f), In.VecEye).rgb;
    if (gFC_GammaFlag.x > 0.5f) {
        lit = Srgb2linear(lit);
    }

    // ---------- outputs (ref 462-469) ----------
    GbOut.Color.xyz = lit;
    GbOut.Color.w = 1.0f;
    GbOut.Normal.xyz = N * 0.5f + 0.5f;
    GbOut.Normal.w = 0.0f;
    GbOut.Albedo.xyz = sampledColor.rgb * pbl.w;
    GbOut.Albedo.w = 1.0f;
    GbOut.Material.x = rough;
#if defined(WITH_GhostMap)
    GbOut.Material.yz = float2(1.0f, 1.0f) * mtl;
#else
    GbOut.Material.yz = mtl;
#endif
    GbOut.Material.w = 1.0f;

    return GbOut;
}
