// FRPG_FS_Snow.fx - Snow pixel shader (FIXED VERSION)
// Reconstructed from FRPG_Snow_______.fpo.asm (404 instructions)
// Verified against MTD: A11_Snow.mtd, A14_numa.mtd, A19_Snow.mtd, A19_Snow[L].mtd
// See docs/snow_shader_fixes.md for complete analysis
//
// CRITICAL FIXES APPLIED:
// 1. Matrix row access corrected (was transposed)
// 2. PBL texture swizzle fixed (.wxyz -> correct channel mapping)
// 3. DFG LUT swizzle fixed (.z for scale, .x for bias per ASM .zxyw)
// 4. Snow blend formula corrected (uses roughSat)
// 5. Metalness workflow logic matches ASM exactly
// 6. Clustered light loop inlined per ASM
// 7. emSc uses pbl.x (emissive) not pbl.y (roughness)
// 8. IBL blendR uses blendNLenInv not snowNLenInv
// 9. envLight combine uses emissiveFactor (r8x) per ASM
// 10. #ifndef guards for HM_IN/SNOW_IN
// Compiles 395 instr (ref 404; +9 = if/endif vs movc opt)
//
// PS inputs (from VS):
//   v0 = SV_Position (xy used for screenUV)
//   v1 = TEXCOORD0: xyz=worldPos
//   v2 = TEXCOORD1: xyz=worldNrm, w=fogFactor
//   v3 = TEXCOORD2: xyz=VecEye unnorm (CameraPos-worldPos)
//   v4 = TEXCOORD3: xyz=worldTan, w=handedness
//   v5 = COLOR0:    w=vertexAlpha (snow coverage)
//   v6 = TEXCOORD6: xy=snowNrmUV, zw=diffuseUV
//   v7 = TEXCOORD7: xyzw=bitanScaled*2
//   v8 = TEXCOORD8: xy=projB.xy, zw=projA.xy
//   v9 = TEXCOORD9: x=projB.w, y=projA.w
//
// Texture slots:
//   t0  = g_Diffuse (diffuse/albedo)
//   t1  = g_Specular (PBL: emissive/roughness/metalness/diffuseF0 per .wxyz swizzle)
//   t2  = g_Bumpmap (height map for parallax)
//   t5  = g_Bumpmap_2 (snow normal map)
//   t10 = g_Bumpmap_3 (detail normal map)
//   t15 = detail bump map
//
// Key cbuffer params:
//   gFC_SnowParam.x = g_SnowHeight (snow coverage scale)
//   gFC_SnowParam.w = g_ParallaxScale (parallax world scale)
//   gFC_SnowColor = g_SnowColor (snow albedo)
//   gFC_SnowDetailParam.x = g_SnowDetailBumpPower (snow normal scale)
//   gFC_SnowDetailParam.y = g_SnowDiffuseBlendTopHeight (blend rate)
//   gFC_SnowDetailParam.z = g_SnowDiffuseBlendBottomHeight (blend threshold)
//   gFC_SnowSpecParam.z = g_SnowDeltaHeightLimit (parallax clamp)
//   gFC_SnowParam2.x = g_SnowRoughness
//   gFC_SnowParam2.y = g_SnowMetalMask
//   gFC_SnowParam2.z = g_SnowDiffuseF0

#define ENABLE_FS
#include "FRPG_Common.fxh"
#include "FRPG_Common_ForwardPBL.fxh"
#include "FRPG_ShadowFunc.fxh"

// ---------------------------------------------------------------------------
// HeightMap pass (WITH_HeightMap)
// ---------------------------------------------------------------------------
#ifdef WITH_HeightMap

#ifndef HM_IN_DEFINED
#define HM_IN_DEFINED
struct HM_IN {
    float4 Pos   : SV_Position;
    float4 TexUV : TEXCOORD0;   // xy=tile1UV, zw=tile0UV
    float3 TexUV2: TEXCOORD1;   // xy=tile2UV, z=viewZ
};
#endif
struct HM_OUT { float4 Color : SV_Target0; };

HM_OUT FragmentMain(HM_IN In)
{
    HM_OUT Out;
    float3 s0 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, In.TexUV.zw).xyz;
    float  h  = dot(s0, (float3)1) * gFC_SnowTileBlend.y * 0.333333f;
    float3 s1 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, In.TexUV.xy).wxy;
    h = dot(s1, (float3)1) * gFC_SnowTileBlend.x * 0.333333f + h;
    float3 s2 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, In.TexUV2.xy).wxy;
    h = dot(s2, (float3)1) * gFC_SnowTileBlend.z * 0.333333f + h;
    float fade = saturate((gFC_WaterWaveParam.z - In.TexUV2.z) / gFC_WaterWaveParam.z);
    Out.Color = float4(-h * fade + 1.0f, 0.0f, 1.0f, 1.0f);
    return Out;
}

#else // main snow pass

#ifndef SNOW_IN_DEFINED
#define SNOW_IN_DEFINED
struct SNOW_IN {
    float4 Pos        : SV_Position;
    float4 WorldPos   : TEXCOORD0;
    float4 WorldNrm   : TEXCOORD1;
    float3 VecEyeRaw  : TEXCOORD2;
    float4 WorldTan   : TEXCOORD3;
    float4 Color      : COLOR0;
    float4 TexSnow    : TEXCOORD6;
    float4 TanFrame   : TEXCOORD7;
    float4 ProjPos    : TEXCOORD8;
    float2 ProjW      : TEXCOORD9;
};
#endif

struct SNOW_OUT {
    float4 Color : SV_Target0;
    float4 GBuf1 : SV_Target1;
};

SNOW_OUT FragmentMain(SNOW_IN In)
{
    SNOW_OUT Out;

    // --- Normalize eye vector ---
    float3 V = normalize(In.VecEyeRaw);

    // --- Screen UV for SAO ---
    float2 screenUV = In.Pos.xy * gFC_SAOParams.xy;

    // --- Snow coverage from vertex alpha ---
    float snowCov = In.Color.w * gFC_SnowParam.x;

    // --- Perspective UV for parallax ---
    float4 perspUV = In.ProjPos / In.ProjW.xxyy;
    perspUV = perspUV * float4(0.5f, -0.5f, 0.5f, -0.5f) + 0.5f;

    // --- Parallax base offset ---
    float4 parBase = screenUV.xyxy * 2.0f - perspUV;

    // --- Height map sample (inverted) ---
    float hInv = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, screenUV).y;

    // --- Parallax amount ---
    float parallaxAmount = snowCov * hInv;

    // --- Construct bitangent from worldNrm x worldTan * handedness ---
    float3 bitan;
    bitan.x = In.WorldNrm.y * In.WorldTan.z - In.WorldNrm.z * In.WorldTan.y;
    bitan.y = In.WorldNrm.z * In.WorldTan.x - In.WorldNrm.x * In.WorldTan.z;
    bitan.z = In.WorldNrm.x * In.WorldTan.y - In.WorldNrm.y * In.WorldTan.x;
    bitan *= In.WorldTan.w;
    bitan = normalize(bitan);

    // --- Normalize tangent ---
    float3 tan = normalize(In.WorldTan.xyz);
    float3 tanYZX = tan.yzx;

    // --- Gram-Schmidt orthogonalization ---
    float tDotV = dot(tanYZX, V);
    float bDotV = dot(bitan, V);
    bitan = bitan * bDotV + tanYZX * tDotV;

    // --- Displaced world position ---
    float3 dispPos = parallaxAmount * bitan * gFC_SnowParam.w + In.WorldPos.xyz;

    // --- Project displaced position (FIXED: correct matrix row access) ---
    float4 dp4 = float4(dispPos, 1.0f);
    // CRITICAL FIX: gFC_WorldViewClipMtx[i] IS row i (row-major)
    float cx = dot(dp4, gFC_WorldViewClipMtx[0]);
    float cy = dot(dp4, gFC_WorldViewClipMtx[1]);
    float cw = dot(dp4, gFC_WorldViewClipMtx[3]);
    float4 clipUV = float2(cx, cy).xyxy / cw;
    clipUV = clipUV * float4(0.5f, -0.5f, 0.5f, -0.5f) + 0.5f;
    clipUV -= In.Pos.xyxy * gFC_SAOParams.xyxy;

    // --- 4-sample parallax ---
    float4 uv0 = perspUV + clipUV;
    float4 uv1 = parBase + clipUV;
    float h0 = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uv0.xy).x;
    float h1 = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uv0.zw).x;
    float h2 = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uv1.xy).x;
    float h3 = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uv1.zw).x;

    // --- Parallax UV offset (clamped) ---
    float2 parUV = clamp(float2(h0, h1) * snowCov - float2(h2, h3) * snowCov,
                         -gFC_SnowSpecParam.z, gFC_SnowSpecParam.z);

    // --- Tangent frame from TanFrame (bitanScaled*2) ---
    float3 tfNorm = normalize(float3(In.TanFrame.x, tan.y * In.TanFrame.w + parUV.x, In.TanFrame.z));
    float3 tf2 = normalize(float3(In.TanFrame.x, parUV.y + In.TanFrame.y, In.TanFrame.z));
    float3 tf3 = tfNorm.yzx * tf2.zxy - tf2.yzx * tfNorm.zxy;

    // --- Snow normal from t5 (gSMP_BumpMap2) ---
    float2 snNorm = gSMP_BumpMap2.Sample(gSMP_BumpMap2Sampler, In.TexSnow.xy).xy * 2.0f - 1.0f;
    snNorm *= gFC_SnowDetailParam.x;
    float3 snowN = tfNorm * snNorm.y + tf2 * snNorm.x + tf3;
    float snowNLenInv = rsqrt(dot(snowN, snowN));

    // --- Diffuse from t0 ---
    float4 diff = gSMP_DiffuseMap.Sample(gSMP_DiffuseMapSampler, In.TexSnow.zw);
    // Alpha test
    if (AlphaTest == 1 && AlphaTestRef.x >= diff.w) discard;
    diff.xyz += gFC_FgSkinAddColor.xyz;
    diff *= gFC_ModelMulCol;

    // --- Snow blend factor ---
    float snowBlend = saturate((hInv * In.Color.w - gFC_SnowDetailParam.z) * gFC_SnowDetailParam.y);

    // --- Detail normal from t10 (gSMP_Subsurf) ---
    float2 detS = gSMP_Subsurf.Sample(gSMP_SubsurfMapSampler, In.TexSnow.zw).xy;
    float2 detN = detS * 2.0f - 1.0f;
    float detZ = sqrt(saturate(1.0f - dot(detN, detN)));
    float3 vn = normalize(In.WorldNrm.xyz);
    float3 det3 = gFC_NormalScale * (float3(detS + detS, detZ) - 1.0f) + float3(0, 0, 1);
    float3 detW = normalize(tan.zxy * det3.y + vn * det3.x + vn * det3.z);

    // --- Gram-Schmidt for detail normal frame ---
    float3 gs2 = normalize(detW.yzx * tan.yzx - tan * detW.zxy) * In.WorldTan.w;
    float3 gs3 = normalize(detW.yzx * gs2.zxy - gs2.yzx * detW.zxy);

    // --- Detail bump from t15 ---
    float2 dbUV = In.TexSnow.zw * gFC_DetailBumpParam.x;
    float2 dbS = gSMP_DetailBumpMap.Sample(gSMP_DetailBumpMapSampler, dbUV).xy * 2.0f - 1.0f;
    float dbZ = sqrt(saturate(1.0f - dot(dbS, dbS)));
    float2 dbSc = dbS * gFC_DetailBumpParam.w;
    float dbNearZero = (dot(dbSc, dbSc) < 0.00001f) ? 1.0f : 0.0f;
    float3 dbN = normalize(float3(dbSc, dbZ + dbNearZero));

    // --- Combine detail normals ---
    float3 combN = normalize(gs3 * dbN.y + gs2 * dbN.x + detW * dbN.z);

    // --- Blend snow normal with detail normal ---
    float3 blendN = normalize(snowBlend * (snowN * snowNLenInv - combN) + combN);
    float blendNLenInv = rsqrt(dot(blendN, blendN));

    // --- Snow color (gamma 2.2) ---
    float3 snowCol = pow(abs(gFC_SnowColor.xyz), 2.2f);

    // --- PBL sample t1 (FIXED: .wxyz swizzle) ---
    // ASM: sample_indexable(texture2d)(float,float,float,float) r7.xyzw, v6.zwzz, t1.wxyz, s1
    // This means r7.xyzw = (t1.w, t1.x, t1.y, t1.z)
    float4 pblRaw = gSMP_SpecularMap.Sample(gSMP_SpecularMapSampler, In.TexSnow.zw);
    // Remap to match ASM register assignment:
    float4 pbl;
    pbl.x = pblRaw.w;  // emissive (was r7.x = t1.w)
    pbl.y = pblRaw.x;  // roughness (was r7.y = t1.x)
    pbl.z = pblRaw.y;  // metalness (was r7.z = t1.y)
    pbl.w = pblRaw.z;  // diffuseF0 (was r7.w = t1.z)


    // --- Material workflow (FIXED: exact ASM logic) ---
    float3 diffCol, specCol, emissive;
    float rough, metal, emissiveFactor;

    if (!gFC_MaterialWorkflow.x) {
        // Metalness workflow
        float3 ovAdj = float3(-1, -1, -1) + gFC_MaterialOverrideParams.xyz;
        float3 ovSat = saturate(gFC_MaterialOverrideParams.xyz);
        float2 rm = ovSat.xy * (ovAdj.xy - pbl.yz) + pbl.yz;  // roughness, metalness
        float mLum = max(dot(gFC_SpcMapMulCol.xyz, float3(0.2126729f, 0.7151522f, 0.072175f)), 0.001f);
        float mBlend = saturate(pbl.x * 0.2f * mLum);
        float emSc = (1.0f - pbl.x) * gFC_MaterialOverrideParams.w * 10.0f;
        float3 base = lerp(gFC_DifMapMulCol.xyz, gFC_SpcMapMulCol.xyz, rm.y);
        float3 dBase = pow(abs(diff.xyz * base), 2.2f);
        float3 sBase = pow(saturate(pbl.yzw * gFC_SpcMapMulCol.xyz), 2.2f);
        diffCol = dBase * (1.0f - rm.y);
        specCol = sBase;
        rough = rm.x;
        metal = mBlend;
        emissive = emSc * dBase;
        emissiveFactor = pbl.x;
    } else {
        // Specular workflow
        diffCol = pow(abs(diff.xyz * gFC_DifMapMulCol.xyz), 2.2f);
        specCol = pow(saturate(pbl.yzw * gFC_SpcMapMulCol.xyz), 2.2f);
        rough = saturate(gFC_MaterialOverrideParams.x) * (-1.0f + gFC_MaterialOverrideParams.x - pbl.y) + pbl.y;
        metal = 0;
        emissive = 0;
        emissiveFactor = 1.0f;
    }

    // --- Debug draw override ---
    if (gFC_DebugDraw.y) {
        uint dd = gFC_DebugDraw.y & 3u;
        uint ds = (gFC_DebugDraw.y >> 2u) & 3u;
        if (dd == 1) diffCol = 0;
        if (dd == 2) diffCol = 1;
        if (ds == 1) specCol = 0;
        if (ds == 2) specCol = float3(0, 1, 1);
    }

    // --- Blend snow material ---
    float  metalMaskInv = 1.0f - gFC_SnowParam2.y;
    float3 roughCol = gFC_SnowParam2.y * (snowCol - gFC_SnowParam2.zzz) + gFC_SnowParam2.zzz;
    float3 bSpec = snowBlend * (roughCol - specCol) + specCol;
    float roughSat = saturate(dot(bSpec, float3(0.33f, 0.33f, 0.33f)) * 50.0f);
    float3 bDiff = snowBlend * (snowCol * metalMaskInv - diffCol) + diffCol;
    float bRough = snowBlend * (-metal + gFC_SnowParam2.x) + metal;

    // --- IBL (inline per ASM) ---
    float NdotV = dot(blendN, V);
    float3 R = 2.0f * NdotV * blendN - V;
    NdotV = saturate(NdotV);

    // Fresnel term
    float oneMinusRough = saturate(1.0f - bRough);
    float sqrtFresnel = sqrt(oneMinusRough);
    float fresnelTerm = oneMinusRough * (bRough + sqrtFresnel);

    // Reflection direction with Fresnel
    float3 blendR = fresnelTerm * (-blendN * blendNLenInv + R) + blendN;

    // Specular cube LOD
    float specLOD = (gFC_LightProbeParam.w - 1.0f) + log2(bRough) * 1.2f - 2.0f;
    float3 envSpec = gSMP_EnvSpcMap.SampleLevel(gSMP_EnvSpcMapSampler, blendR, specLOD).xyz;
    envSpec *= gFC_EnvSpcMapMulCol.xyz * gFC_LightProbeParam.x;

    // Fresnel weight
    float NdotR = dot(blendN, R);
    float fresnelW = saturate(NdotR * 1.3f + 1.0f);
    fresnelW *= fresnelW;
    envSpec *= fresnelW;

    // DFG LUT (ASM: t9.zxyw → r7.yz = t9.z, t9.x)
    float4 dfgFull = gSMP_DFG.SampleLevel(gSMP_DFGMapSampler, float2(bRough, NdotV), 0);
    float3 dfgColor = bSpec * dfgFull.z + roughSat * dfgFull.x;
    envSpec *= dfgColor;

    // Diffuse cube
    float3 envDif = gSMP_EnvDifMap.SampleLevel(gSMP_EnvDifMapSampler, blendN, 0).xyz;
    envDif *= gFC_EnvDifMapMulCol.xyz * gFC_LightProbeParam.x;

    // Combine IBL
    float3 envLight = envDif * bDiff + envSpec;

    // Hemisphere ambient
    float hemBlend = blendN.y * 0.5f + 0.5f;
    float3 hemColor = lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, hemBlend);
    envLight = emissiveFactor * envLight + bDiff * hemColor;

    // SAO
    if (gFC_SAOParams.w != 0.0f)
        envLight *= gSMP_AOMap.SampleLevel(gSMP_AOMapSampler, screenUV, 0).x;

    float3 litColor = envLight + emissive;

    // --- Clustered point lights (FIXED: inline per ASM) ---
    float roughSq = max(bRough, 0.014f);
    roughSq *= roughSq;
    float roughSq2 = roughSq * roughSq - 1.0f;
    float roughHalf = roughSq * 0.5f;
    float roughIHalf = 1.0f - roughSq * 0.5f;
    float NdotVGeom = NdotV * roughIHalf + roughHalf;
    float NdotVGeomInv = 1.0f / NdotVGeom;

    // Cluster lookup
    float4 wp4c = float4(In.WorldPos.xyz, 1.0f);
    float4 clipC;
    clipC.x = dot(wp4c, gFC_WorldViewClipMtx[0]);
    clipC.y = dot(wp4c, gFC_WorldViewClipMtx[1]);
    clipC.z = dot(wp4c, gFC_WorldViewClipMtx[2]);
    clipC.w = dot(wp4c, gFC_WorldViewClipMtx[3]);
    float3 ndc = clipC.xyz / clipC.w;
    float2 tile = floor(saturate(ndc.xy * 0.5f + 0.5f) * float2(16, 8));
    tile = min(tile, float2(15, 7));
    float linZ = gFC_ClipInfo.w / (ndc.z * gFC_ClipInfo.z + gFC_ClipInfo.y) / gFC_ClipInfo.x;
    float sliceF = log2(linZ) * gFC_ClusterParam.x;
    uint slice = (uint)min(sliceF, 23.0f);
    uint flatIdx = (uint)tile.x + ((uint)tile.y + slice * 8u) * 16u;
    uint packed = numLightsBuffer[flatIdx].offsetNum;
    uint lightCount = min(packed & 63u, gFC_PntLightCount.x);
    uint lightStart = packed >> 12u;
    uint lightEnd = lightStart + lightCount;

    float3 pntAccum = 0;
    float3 fresnelBase = roughSat * (1.0f - bSpec);

    for (uint li = lightStart; li < lightEnd; li++) {
        uint lid = lightIDBuffer[li].id & 511u;
        float4 lpos = lightParamBuffer[lid].position;
        float4 lcol = lightParamBuffer[lid].color;
        float3 L = lpos.xyz - In.WorldPos.xyz;
        float dist = length(L);
        if (dist < lcol.w) {
            L /= dist;
            float3 H = normalize(V + L);
            float NdotL_V = saturate(dot(V, H));
            float NdotH = saturate(dot(blendN, H));
            float NdotL = saturate(dot(blendN, L));

            // Schlick Fresnel
            float fExp = NdotL_V * (-5.554730f) - 6.983160f;
            float fVal = exp2(NdotL_V * fExp);
            float3 specF = fresnelBase * fVal + bSpec;

            // GGX NDF
            float denom = NdotH * NdotH * roughSq2 + 1.0f;
            float D = roughSq / denom;
            D = D * D * 0.318309873f;

            // Geometry
            float NdotLGeom = NdotL * roughIHalf + roughHalf;
            float G = NdotVGeomInv / NdotLGeom;

            float brdf = D * G * 0.25f;
            float3 contrib = (bDiff * 0.318309873f + brdf * specF) * lcol.rgb;

            // Attenuation (cubic)
            float atten = (lcol.w - dist) * lpos.w;
            atten = saturate(atten * atten * atten);

            pntAccum += contrib * atten * NdotL * 3.14159274f;
        }
    }
    litColor += pntAccum;

    // --- Gamma encode ---
    litColor = exp2(log2(abs(litColor)) * (5.0f/11.0f));

    // --- Fog ---
    float fog = saturate(saturate(In.WorldNrm.w) * gFC_FogCol.w);
    litColor = lerp(litColor, gFC_FogCol.xyz, fog);

    // --- Light scattering ---
    float eyeDist = length(In.VecEyeRaw);
    litColor = CalcGetLightScatteringCol(float4(litColor, 1), float4(V, eyeDist)).rgb;

    // --- Final gamma ---
    litColor = exp2(log2(abs(litColor)) * 2.2f);

    // --- Debug output switch ---
    float3 dbgOut = litColor;
    switch (gFC_DebugDraw.x) {
        case 1:  dbgOut = litColor; break;
        case 2:  dbgOut = exp2(log2(abs(bDiff)) * (5.0f/11.0f)); break;
        case 3:  dbgOut = exp2(log2(abs(bSpec)) * (5.0f/11.0f)); break;
        case 4:  dbgOut = 0; break;
        case 5:  dbgOut = blendN * 0.498040f + 0.498040f; break;
        case 6:  dbgOut = float3(bRough, 0, 0); break;
        default: {
            float dw = snowBlend * gFC_SnowParam.z;
            dbgOut = float3(dw * 0.1f, 0, 0);
        } break;
    }

    Out.Color = float4(litColor, diff.w);
    Out.GBuf1 = float4(dbgOut, 0);

    return Out;
}

#endif // WITH_HeightMap
