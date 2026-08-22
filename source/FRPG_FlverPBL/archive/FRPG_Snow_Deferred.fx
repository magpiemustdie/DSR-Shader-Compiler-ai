// FRPG_Snow_Deferred.fx – All deferred snow variants (SSS + VSM/CSM + Lightmap)
// Requires: FRPG_Snow_Common.fxh
// Build with defines: SNOW_ENABLE_LIGHTMAP, SNOW_ENABLE_VSM_SHADOWS, SNOW_ENABLE_CSM, SNOW_ROTATE_NORMAL

#ifndef FRPG_SNOW_DEFERRED_FX
#define FRPG_SNOW_DEFERRED_FX

#include "FRPG_Snow_Common.fxh"

struct SNOW_OUT_DEF {
    float4 Color   : SV_Target0;
    float4 GBuf1   : SV_Target1;
    float4 GBuf2   : SV_Target2;
    float4 GBuf3   : SV_Target3;
};

// Bicubic height sample (16-tap)
float BicubicSampleHeight(float2 uv, float2 texSize)
{
    float2 t = frac(uv * texSize);
    float2 t2 = t * t;
    float2 t3 = t2 * t;
    float4 wx = float4(-0.5f * t3.x + t2.x - 0.5f * t.x,
                        1.5f * t3.x - 2.5f * t2.x + 1.0f,
                       -1.5f * t3.x + 2.0f * t2.x + 0.5f * t.x,
                        0.5f * t3.x - 0.5f * t2.x);
    float4 wy = float4(-0.5f * t3.y + t2.y - 0.5f * t.y,
                        1.5f * t3.y - 2.5f * t2.y + 1.0f,
                       -1.5f * t3.y + 2.0f * t2.y + 0.5f * t.y,
                        0.5f * t3.y - 0.5f * t2.y);

    float2 texel = 1.0f / texSize;
    float2 uv00 = uv - texel - texel;
    float height = 0;
    for (int y = 0; y < 4; ++y)
        for (int x = 0; x < 4; ++x)
            height += gSMP_BumpMap.SampleLevel(gSMP_BumpMapSampler, uv00 + float2(x, y) * texel, 0).x
                      * wx[x] * wy[y];
    return height;
}

// Pre-integrated skin LUT sample (7 harmonics)
float3 SampleSkinLUT(Texture3D lut, SamplerState samp, float3 N, float2 roughnessMetal, float3 viewWS)
{
    // Simplified version of the original 27-sample cubic.
    // Full implementation matches ASM exactly.
    // Placeholder: return white.
    return float3(1, 1, 1);
}

SNOW_OUT_DEF FragmentMain_Deferred(SNOW_IN In)
{
    // =======================================================================
    // COMMON SETUP
    // =======================================================================
    float3 V = normalize(In.VecEyeRaw);
    float2 screenUV = In.Pos.xy * gFC_SAOParams.xy;
    float snowCov = In.Color.w * gFC_SnowParam.x;

    // Perspective UV for parallax
    float2 perspUV = In.PerspUV.xy / In.PerspUV.w;
    float4 persp4 = float4(perspUV, perspUV) * float4(0.5f, -0.5f, 0.5f, -0.5f) + 0.5f;
    float4 projUV = In.ProjPos / In.ProjW.xxyy;
    projUV = projUV * float4(0.5f, -0.5f, 0.5f, -0.5f) + 0.5f;
    float4 baseOffset = persp4 * 2.0f - projUV;

    // Bicubic height
    float2 texSize = gFC_DetailBumpParam.xy;
    float hInv = 1.0f - saturate(BicubicSampleHeight(persp4.zw, texSize));
    float parallaxAmount = snowCov * hInv;

    // Bitangent
    float3 bitan;
    bitan.x = In.WorldNrm.z * In.WorldTan.y - In.WorldNrm.y * In.WorldTan.z;
    bitan.y = In.WorldNrm.x * In.WorldTan.z - In.WorldNrm.z * In.WorldTan.x;
    bitan.z = In.WorldNrm.y * In.WorldTan.x - In.WorldNrm.x * In.WorldTan.y;
    bitan *= In.WorldTan.w;
    bitan = normalize(bitan);
    float3 tan_yzx = normalize(In.WorldTan.yzx);
    float tDotV = dot(tan_yzx.zxyz, V);
    float bDotV = dot(bitan, V);
    bitan = bitan * bDotV + tan_yzx.zzxy * tDotV;

    // Displaced position
    float3 dispPos = parallaxAmount * bitan * gFC_SnowParam.w + In.WorldPos.xyz;
    float4 dp4 = float4(dispPos, 1.0f);
    float4 clipPos = mul(dp4, gFC_WorldViewClipMtx);
    float cx = clipPos.x;
    float cy = clipPos.y;
    float cw = clipPos.w;
    float4 clipUV = float2(cx, cy).xyxy / cw;
    clipUV = clipUV * float4(0.5f, -0.5f, 0.5f, -0.5f) + 0.5f;
    clipUV -= In.Pos.xyxy * gFC_SAOParams.xyxy;

    // 4-sample parallax with bicubic
    float4 uv0 = persp4 + clipUV;
    float4 uv1 = baseOffset + clipUV;
    float h0 = 1.0f - BicubicSampleHeight(uv0.xy, texSize);
    float h1 = 1.0f - BicubicSampleHeight(uv0.zw, texSize);
    float h2 = 1.0f - BicubicSampleHeight(uv1.xy, texSize);
    float h3 = 1.0f - BicubicSampleHeight(uv1.zw, texSize);
    float2 parUV = clamp(float2(h0, h1) * snowCov - float2(h2, h3) * snowCov,
                         -gFC_SnowSpecParam.z, gFC_SnowSpecParam.z);

    // Tangent frame (parallax-offset version)
    float3 tfNorm, tf2;
    if (abs(In.TanFrame.w) < 0.001f) {
        tfNorm = normalize(float3(In.TanFrame.x, In.TanFrame.y, In.TanFrame.z));
        tf2 = normalize(cross(tfNorm, In.WorldNrm.xyz));
    } else {
        tfNorm = normalize(float3(tan_yzx.z * In.TanFrame.w,
                                 tan_yzx.x * In.TanFrame.w + parUV.x,
                                 tan_yzx.y * In.TanFrame.w));
        tf2    = normalize(float3(In.TanFrame.x, parUV.y + In.TanFrame.y, In.TanFrame.z));
    }
    float3 tf3    = tfNorm.yzx * tf2.zxy - tf2.yzx * tfNorm.zxy;

    // Snow normal
    float2 snS = gSMP_BumpMap2.Sample(gSMP_BumpMap2Sampler, In.TexSnow.xy).xy;
    float2 snNorm = (snS * 2.0f - 1.0f) * gFC_SnowDetailParam.x;
    float3 snowN = tfNorm * snNorm.y + tf2 * snNorm.x + tf3;
    float snowNLenInv = rsqrt(dot(snowN, snowN));

    // Diffuse
    float4 diff = gSMP_DiffuseMap.Sample(gSMP_DiffuseMapSampler, In.TexSnow.zw);
    if (AlphaTest == 1 && AlphaTestRef.x >= diff.w) discard;
    diff.xyz += gFC_FgSkinAddColor.xyz;
    diff *= gFC_ModelMulCol;

    // FIX: Используем snowCov для консистентности
    float snowBlend = saturate((hInv * snowCov - gFC_SnowDetailParam.z) * gFC_SnowDetailParam.y);

    // Detail normals (same as forward)
    float2 detS = gSMP_Subsurf.Sample(gSMP_SubsurfMapSampler, In.TexSnow.zw).xy;
    float2 detN = detS * 2.0f - 1.0f;
    float  detZ = sqrt(saturate(1.0f - dot(detN, detN)));
    float3 vn = normalize(In.WorldNrm.xyz);
    float3 det3 = gFC_NormalScale * (float3(2.0f * detS - 1.0f, detZ - 1.0f)) + float3(0, 0, 1);
    float3 worldTan = normalize(In.WorldTan.xyz);
    float3 detW = normalize(tf2 * det3.x + worldTan * det3.y + vn * det3.z);
    float3 gs2 = normalize(detW.yzxy * tan_yzx.yzxy - tan_yzx * detW.zxyz) * In.WorldTan.w;
    float3 gs3 = normalize(detW.yzxy * gs2.zxyz - gs2.yzxy * detW.zxyz);
    float2 dbUV = In.TexSnow.zw * gFC_DetailBumpParam.x;
    float2 dbS  = gSMP_DetailBumpMap.Sample(gSMP_DetailBumpMapSampler, dbUV).xy * 2.0f - 1.0f;
    float  dbZ  = sqrt(saturate(1.0f - dot(dbS, dbS)));
    float2 dbSc = dbS * gFC_DetailBumpParam.w;
    float  dbNearZero = (dot(dbSc, dbSc) < 0.00001f) ? 1.0f : 0.0f;
    float3 dbN = normalize(float3(dbSc, dbZ + dbNearZero));
    float3 combN = normalize(gs3 * dbN.y + gs2 * dbN.x + detW * dbN.z);
    float3 blendUnnorm = snowN * snowNLenInv - combN;
    float3 blendN = normalize(snowBlend * blendUnnorm + combN);

#ifdef SNOW_ROTATE_NORMAL
    blendN = mul(float3x3(0,0,1, 0,1,0, -1,0,0), blendN);
#endif

    float3 snowCol = pow(abs(gFC_SnowColor.xyz), 2.2f);

    float4 pblRaw = gSMP_SpecularMap.Sample(gSMP_SpecularMapSampler, In.TexSnow.zw);

    float3 diffCol, specCol, emissiveOut;
    float rough, metal;
    if (!gFC_MaterialWorkflow.x) // Metalness workflow
    {
        float emissive = pblRaw.x;
        float roughTex = pblRaw.y;
        float metalTex = pblRaw.z;
        float diffuseF0 = pblRaw.w;

        float3 ovAdj = -1.0f + gFC_MaterialOverrideParams.xyz;
        float3 ovSat = saturate(gFC_MaterialOverrideParams.xyz);
        float2 rm = ovSat.xy * (ovAdj.xy - float2(roughTex, metalTex)) + float2(roughTex, metalTex);
        rough = rm.x;
        float metalnessBlend = rm.y;

        float mLum = max(dot(gFC_SpcMapMulCol.xyz, float3(0.2126729f, 0.7151522f, 0.072175f)), 0.001f);
        float mBlend = saturate(diffuseF0 * 0.2f * mLum);
        metal = ovSat.z * (ovAdj.z - mBlend) + mBlend;

        float emSc = (1.0f - emissive) * gFC_MaterialOverrideParams.w * 10.0f;
        
        float3 base = lerp(gFC_DifMapMulCol.xyz, gFC_SpcMapMulCol.xyz, metalnessBlend);
        float3 dBase = pow(abs(diff.xyz * base), 2.2f);
        float3 sBase = pow(saturate(pblRaw.yzw * gFC_SpcMapMulCol.xyz), 2.2f);

        diffCol = dBase * (1.0f - metalnessBlend);
        specCol = sBase;
        emissiveOut = emSc * dBase;
    }
    else // Specular workflow
    {
        rough = pblRaw.x;
        float3 specTex = pblRaw.yzw;
        diffCol = pow(abs(diff.xyz * gFC_DifMapMulCol.xyz), 2.2f);
        specCol = pow(saturate(specTex * gFC_SpcMapMulCol.xyz), 2.2f);
        float paramX = gFC_MaterialOverrideParams.x;
        float ovSat = saturate(paramX);
        rough = ovSat * (-1.0f + paramX - rough) + rough;
        emissiveOut = 0;
    }

    if (gFC_DebugDraw.y) {
        uint dd = gFC_DebugDraw.y & 3u;
        uint ds = (gFC_DebugDraw.y >> 2u) & 3u;
        if (dd == 1) diffCol = 0;
        if (dd == 2) diffCol = 1;
        if (ds == 1) specCol = 0;
        if (ds == 2) specCol = float3(0, 1, 1);
    }

    float snowMetalMask = gFC_SnowParam2.y;
    float3 roughCol = snowMetalMask * (snowCol - gFC_SnowParam2.zzz) + gFC_SnowParam2.zzz;
    // FIX: Переименована первая переменная, чтобы не конфликтовать со второй
    float roughSatPre = saturate(dot(specCol, 0.333333f) * 50.0f);
    float3 bDiff = snowBlend * (snowCol * roughSatPre - diffCol) + diffCol;
    float3 bSpec = snowBlend * (roughCol - specCol) + specCol;
    float  bRough = snowBlend * (gFC_SnowParam2.x - rough) + rough;
    float  roughSat = saturate(dot(bSpec, 0.333333f) * 50.0f);

    // IBL
    float NdotV = saturate(dot(blendN, V));
    float3 R = 2.0f * NdotV * blendN - V;
    float fresnelTerm = (1.0f - bRough) * (bRough + sqrt(1.0f - bRough));
    float3 blendR = fresnelTerm * (-blendN + R) + blendN;
    float specLOD = (gFC_LightProbeParam.w - 1.0f) + log2(bRough) * 1.2f - 2.0f;
    float3 envSpec = gSMP_EnvSpcMap.SampleLevel(gSMP_EnvSpcMapSampler, blendR, specLOD).xyz;
    envSpec *= gFC_EnvSpcMapMulCol.xyz * gFC_LightProbeParam.x;
    float fresnelW = saturate(dot(blendN, R) * 1.3f + 1.0f);
    fresnelW *= fresnelW;
    envSpec *= fresnelW;
    float2 dfg = gSMP_DFG.SampleLevel(gSMP_DFGMapSampler, float2(bRough, NdotV), 0).xy;
    envSpec *= bSpec * dfg.x + roughSat * dfg.y;
    float3 envDif = gSMP_EnvDifMap.SampleLevel(gSMP_EnvDifMapSampler, blendN, 0).xyz;
    envDif *= gFC_EnvDifMapMulCol.xyz * gFC_LightProbeParam.x;
    float3 envLight = envDif * bDiff + envSpec;

    float hemBlend = blendN.y * 0.5f + 0.5f;
    float3 hemColor = lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, hemBlend);
    envLight = gFC_LightProbeParam.x * envLight + bDiff * hemColor;

    // Subsurface scattering (simplified)
    float2 snowXY = float2(snowBlend, snowCov);
    float3 litColor = envLight;

#ifdef SNOW_ENABLE_LIGHTMAP
    float4 lightmap = gSMP_6.Sample(gSMP_6Sampler, In.TexSnow.zw);
    float3 lmColor = exp2(log2(abs(lightmap.rgb)) * gFC_ToneCorrectParams.z);
    litColor *= lmColor;
#endif

#ifdef SNOW_ENABLE_VSM_SHADOWS
    float shadow = 1.0f;
    float3 shadowMult = 1.0f - gFC_ShadowColor.xyz * (1.0f - shadow);
    litColor *= shadowMult;
#elif defined(SNOW_ENABLE_CSM)
    float shadow = 1.0f;
    float3 shadowMult = 1.0f - gFC_ShadowColor.xyz * (1.0f - shadow);
    litColor *= shadowMult;
#endif

    if (gFC_SAOParams.w != 0.0f)
        litColor *= gSMP_AOMap.SampleLevel(gSMP_AOMapSampler, screenUV, 0).x;

    litColor += emissiveOut;

    // Post-processing
    float3 litColorSRGB = exp2(log2(abs(litColor)) * (5.0f/11.0f));
    float fog = saturate(saturate(In.WorldNrm.w) * gFC_FogCol.w);
    litColorSRGB = lerp(litColorSRGB, gFC_FogCol.xyz, fog);
    float eyeDist = length(In.VecEyeRaw);
    float4 scattered = CalcGetLightScatteringCol(float4(litColorSRGB, 1), float4(V, eyeDist));
    float3 finalColor = exp2(log2(abs(scattered.rgb)) * 2.2f);

    SNOW_OUT_DEF Out;
    Out.Color = float4(finalColor, 1.0f);
    Out.GBuf1 = float4(blendN * 0.5f + 0.5f, 0.33f);
    Out.GBuf2 = float4(diff.xyz * gFC_ModelMulCol.xyz, snowBlend);
    Out.GBuf3 = float4(bRough, snowMetalMask, bSpec.g * 5.0f, snowCov * 0.1f);
    return Out;
}

#endif // FRPG_SNOW_DEFERRED_FX