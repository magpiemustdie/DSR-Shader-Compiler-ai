// FRPG_Snow_Forward.fx – Forward snow pixel shader
// Reconstructed from FRPG_Snow_______.fpo.asm (DSR Windows, ~404 instructions)
//
// cbuffer register → named constant mapping (from FRPG_Common_FC.fxh):
//   cb0[3]  = gFC_EnvDifMapMulCol      cb0[4]  = gFC_EnvSpcMapMulCol
//   cb0[7]  = gFC_HemAmbCol_u          cb0[8]  = gFC_HemAmbCol_d
//   cb0[9]  = gFC_DifMapMulCol         cb0[10] = gFC_SpcMapMulCol
//   cb0[12] = gFC_FogCol               cb0[39] = gFC_ModelMulCol
//   cb0[60] = gFC_FgSkinAddColor       cb0[63-66] = gFC_WorldViewClipMtx rows
//   cb0[67] = gFC_SnowParam            cb0[68] = gFC_SnowColor
//   cb0[69] = gFC_SnowTileBlend        cb0[70] = gFC_SnowDetailParam
//   cb0[71] = gFC_SnowSpecParam        cb0[75] = gFC_SnowParam2
//   cb0[78] = gFC_DetailBumpParam      cb0[79] = gFC_LightProbeParam
//   cb0[81] = gFC_PntLightCount        cb0[85] = gFC_MaterialWorkflow
//   cb0[86] = gFC_ClipInfo             cb0[87] = gFC_ClusterParam
//   cb0[90] = gFC_SAOParams            cb0[100]= gFC_MaterialOverrideParams
//   cb0[102]= gFC_DebugDraw

#ifndef FRPG_SNOW_FORWARD_FX
#define FRPG_SNOW_FORWARD_FX

#include "FRPG_Snow_Common.fxh"

struct SNOW_OUT_FWD {
    float4 Color : SV_Target0;
    float4 GBuf1 : SV_Target1;
};

SNOW_OUT_FWD FragmentMain_Forward(SNOW_IN In)
{
    // -----------------------------------------------------------------------
    // Eye vector: r0.x = length(v3), r0.yzw = v3/r0.x
    // -----------------------------------------------------------------------
    float eyeDist = length(In.VecEye.xyz);
    float3 V = In.VecEye.xyz / eyeDist;

    // -----------------------------------------------------------------------
    // Screen UV for SAO: r1.xy = v0.xy * gFC_SAOParams.xy
    // Snow coverage:     r1.z  = v5.w * gFC_SnowParam.x
    // -----------------------------------------------------------------------
    float2 screenUV = In.Pos.xy * gFC_SAOParams.xy;
    float  snowCov  = In.Color.w * gFC_SnowParam.x;

    // -----------------------------------------------------------------------
    // Perspective UV: r2.xyzw = v8/v9.xxyy * (0.5,-0.5,0.5,-0.5) + 0.5
    // -----------------------------------------------------------------------
    float4 r2;
    r2.x = In.ProjPos.x / In.ProjW.x;
    r2.y = In.ProjPos.y / In.ProjW.x;
    r2.z = In.ProjPos.z / In.ProjW.y;
    r2.w = In.ProjPos.w / In.ProjW.y;
    r2 = r2 * float4(0.5f,-0.5f,0.5f,-0.5f) + float4(0.5f,0.5f,0.5f,0.5f);

    // r3.xyzw = screenUV.xyxy * 2 - r2.xyzw
    float4 r3;
    r3.x = screenUV.x * 2.0f - r2.x;
    r3.y = screenUV.y * 2.0f - r2.y;
    r3.z = screenUV.x * 2.0f - r2.z;
    r3.w = screenUV.y * 2.0f - r2.w;

    // Initial height sample at screen UV (t2)
    // ASM: sample t2.yzwx → r1.w gets t2.y channel
    // t2 here is the HeightMap RT (output of HeightMap pass): float4(height, 0, 1, 1)
    // .yzwx swizzle: r1.w = t2.y = 0.0 always? No — t2 is the bump texture, not RT.
    // The .yzwx swizzle is a compiler artifact; the scalar result r1.w = first component.
    float hInv  = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, screenUV).x;
    float r4x   = snowCov * hInv;

    // -----------------------------------------------------------------------
    // Bitangent: cross(v2.xyz, v4.xyz) * v4.w, normalized
    // r4.yzw = cross(WorldNrm, WorldTan) * handedness
    // -----------------------------------------------------------------------
    float3 bitan;
    bitan.x = In.WorldNrm.y * In.WorldTan.z - In.WorldNrm.z * In.WorldTan.y;
    bitan.y = In.WorldNrm.z * In.WorldTan.x - In.WorldNrm.x * In.WorldTan.z;
    bitan.z = In.WorldNrm.x * In.WorldTan.y - In.WorldNrm.y * In.WorldTan.x;
    bitan *= In.WorldTan.w;
    bitan = normalize(bitan);

    // r5.xyz = normalize(v4.yzx)  [tangent permuted yzx]
    // ASM: dp3 r5.x, v4.xyzx, v4.xyzx; rsq r5.x; mul r5.xyz, r5.xxxx, v4.yzxy
    // Compute length from v4.xyz (same as v4.yzx), multiply v4.yzx by 1/len
    float tanLenSq = dot(In.WorldTan.xyz, In.WorldTan.xyz);
    float tanLenInv = rsqrt(tanLenSq);
    // Explicit yzx permutation: (v4.y, v4.z, v4.x)
    float3 tanYZX = float3(In.WorldTan.y * tanLenInv,
                           In.WorldTan.z * tanLenInv,
                           In.WorldTan.x * tanLenInv);

    // -----------------------------------------------------------------------
    // Parallax displacement
    // ASM:
    //   dp3 r5.w, r5.zxyz, r0.yzwy  → tDotV = dot(r5.zxy, V) = dot(WorldTan.xyz, V)
    //   dp3 r6.x, r4.yzwy, r0.yzwy  → bDotV = dot(bitan, V)
    //   mul r4.yzw, r4.yyzw, r6.xxxx → bitan * bDotV
    //   mad r4.yzw, r5.wwww, r5.zzxy, r4.yyzw → += tDotV * r5.zzxy
    //   r5.zzxy.yzw = (r5.z, r5.x, r5.y) = (v4.x, v4.y, v4.z) = WorldTan.xyz
    // So dispDir = bitan*bDotV + WorldTan.xyz * tDotV
    // -----------------------------------------------------------------------
    float3 tanOrig = float3(In.WorldTan.x * tanLenInv,
                            In.WorldTan.y * tanLenInv,
                            In.WorldTan.z * tanLenInv);
    float  tDotV   = dot(tanOrig, V);
    float  bDotV   = dot(bitan, V);
    float3 dispDir = bitan * bDotV + tanOrig * tDotV;
    float3 dispPos = r4x * dispDir * gFC_SnowParam.w + In.WorldPos.xyz;

    // -----------------------------------------------------------------------
    // Project displaced position → parallax UV offset
    // ASM: dp4 r6.x, r4.xyzw, cb0[63]; dp4 r6.y, r4.xyzw, cb0[64]; dp4 r4.x, r4.xyzw, cb0[66]
    // cb0[63..66] = columns of gFC_WorldViewClipMtx (column-major in DXBC memory)
    // mul(pos4, M) = dot(pos4, col0), dot(pos4, col1), ... = dot(pos4, cb0[63]), ...
    // -----------------------------------------------------------------------
    float4 dp4 = float4(dispPos, 1.0f);
    float4 col0 = gFC_WorldViewClipMtx._m00_m10_m20_m30;
    float4 col1 = gFC_WorldViewClipMtx._m01_m11_m21_m31;
    float4 col3 = gFC_WorldViewClipMtx._m03_m13_m23_m33;
    float clipX = dot(dp4, col0);
    float clipY = dot(dp4, col1);
    float clipW = dot(dp4, col3);
    float4 r4clip;
    r4clip.x = clipX / clipW;
    r4clip.y = clipY / clipW;
    r4clip.z = clipX / clipW;
    r4clip.w = clipY / clipW;
    r4clip = r4clip * float4(0.5f,-0.5f,0.5f,-0.5f) + float4(0.5f,0.5f,0.5f,0.5f);
    r4clip -= float4(In.Pos.x, In.Pos.y, In.Pos.x, In.Pos.y) * gFC_SAOParams.xyxy;

    // -----------------------------------------------------------------------
    // 4-sample parallax height lookup
    // uvA = r2 + r4clip,  uvB = r3 + r4clip
    // h0..h3 = 1 - t2.Sample(uv).x
    // parUV = clamp(snowCov*h0 - snowCov*h2, snowCov*h1 - snowCov*h3,
    //              -gFC_SnowSpecParam.z, gFC_SnowSpecParam.z)
    // -----------------------------------------------------------------------
    float4 uvA = r2 + r4clip;
    float4 uvB = r3 + r4clip;
    float h0 = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uvA.xy).x;
    float h1 = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uvA.zw).x;
    float h2 = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uvB.xy).x;
    float h3 = 1.0f - gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uvB.zw).x;
    float2 parUV;
    parUV.x = snowCov * h0 - snowCov * h2;
    parUV.y = snowCov * h1 - snowCov * h3;
    parUV   = clamp(parUV, -gFC_SnowSpecParam.z, gFC_SnowSpecParam.z);

    // -----------------------------------------------------------------------
    // Tangent frame for snow normal (v7 = TanFrame = bitanScaled*2)
    // ASM:
    //   r3.xz = r5.zy * v7.w  (tanYZX.z, tanYZX.y)
    //   r3.w  = r5.x * v7.w + parUV.x  (tanYZX.x * v7.w + parUV.x)
    //   r2.y  = parUV.y + v7.y
    //   tf1 = normalize(r3.x, r3.w, r3.z) = (tanYZX.z*v7.w, tanYZX.x*v7.w+parUV.x, tanYZX.y*v7.w)
    //   tf2 = normalize(v7.x, r2.y, v7.z) = (v7.x, parUV.y+v7.y, v7.z)
    //   tf3 = cross(tf1.yzx, tf2.zxy) - cross(tf2.yzx, tf1.zxy)
    // -----------------------------------------------------------------------
    float3 tf1 = float3(tanYZX.z * In.TanFrame.w,
                        tanYZX.x * In.TanFrame.w + parUV.x,
                        tanYZX.y * In.TanFrame.w);
    tf1 = normalize(tf1);

    float3 tf2 = float3(In.TanFrame.x, parUV.y + In.TanFrame.y, In.TanFrame.z);
    tf2 = normalize(tf2);

    // tf3 = cross(tf2, tf1)  — ASM: r4 = r2.yzx*r3.zxy - r3.yzx*r2.zxy = cross(tf2, tf1)
    float3 tf3;
    tf3.x = tf2.y * tf1.z - tf1.y * tf2.z;
    tf3.y = tf2.z * tf1.x - tf1.z * tf2.x;
    tf3.z = tf2.x * tf1.y - tf1.x * tf2.y;

    // -----------------------------------------------------------------------
    // Snow normal from t5 (gSMP_BumpMap2), UV = v6.xy
    // r6.xy = t5.Sample(v6.xy).xy * 2 - 1
    // r6.xy *= gFC_SnowDetailParam.x
    // snowN = tf1*r6.y + tf2*r6.x + tf3
    // snowNLenInv = rsqrt(dot(snowN,snowN))
    // -----------------------------------------------------------------------
    float2 snS      = gSMP_BumpMap2.Sample(gSMP_BumpMap2Sampler, In.TexSnow.xy).xy;
    float2 snNorm   = (snS * 2.0f - 1.0f) * gFC_SnowDetailParam.x;
    float3 snowN    = tf1 * snNorm.y + tf2 * snNorm.x + tf3;
    float  snowNLenInv = rsqrt(dot(snowN, snowN));

    // -----------------------------------------------------------------------
    // Diffuse sample t0, UV = v6.zw
    // Alpha test, add gFC_FgSkinAddColor, multiply gFC_ModelMulCol
    // -----------------------------------------------------------------------
    float4 diff = gSMP_DiffuseMap.Sample(gSMP_DiffuseMapSampler, In.TexSnow.zw);
    if (AlphaTest == 1 && AlphaTestRef.x >= diff.w) discard;
    diff.xyz += gFC_FgSkinAddColor.xyz;
    diff     *= gFC_ModelMulCol;

    // -----------------------------------------------------------------------
    // Snow blend: saturate((hInv * v5.w - gFC_SnowDetailParam.z) * gFC_SnowDetailParam.y)
    // -----------------------------------------------------------------------
    float snowBlend = saturate((hInv * In.Color.w - gFC_SnowDetailParam.z) * gFC_SnowDetailParam.y);

    // -----------------------------------------------------------------------
    // Detail normal from t10 (gSMP_Subsurf), UV = v6.zw
    // r6.xy = t10.Sample(v6.zw).xy
    // r7.xy = r6.xy + r6.xy  (2*detS, kept for NormalScale blend)
    // r6.xy = r6.xy*2-1  (decode to [-1,1])
    // r7.z  = sqrt(1 - min(dot(r6.xy,r6.xy), 1))
    // normalize v2.xyz → wNrm
    // r7.xyz += (-1,-1,-1); r7.xyz = gFC_NormalScale * r7 + (0,0,1)
    // detWorld = normalize(tanYZX.zxy*r7.y + wNrm*r7.x + wNrm*r7.z)
    // -----------------------------------------------------------------------
    float2 detS   = gSMP_Subsurf.Sample(gSMP_SubsurfMapSampler, In.TexSnow.zw).xy;
    float2 r7xy   = detS + detS;
    float2 detN   = detS * 2.0f - 1.0f;
    float  detZ   = sqrt(1.0f - min(dot(detN, detN), 1.0f));
    float3 r7xyz  = float3(r7xy, detZ);
    float3 wNrm   = normalize(In.WorldNrm.xyz);
    r7xyz = r7xyz + float3(-1.0f, -1.0f, -1.0f);
    r7xyz = gFC_NormalScale * r7xyz + float3(0.0f, 0.0f, 1.0f);
    float3 detWorld = wNrm * r7xyz.x + float3(tanYZX.z, tanYZX.x, tanYZX.y) * r7xyz.y;
    detWorld = wNrm * r7xyz.z + detWorld;
    detWorld = normalize(detWorld);

    // -----------------------------------------------------------------------
    // Build detail tangent frame (gs2, gs3)
    // r6.xyz = tanYZX * detWorld.zxy
    // gs2_raw = detWorld.yzx * tanYZX.yzx - r6.xyz  → normalize → * v4.w
    // gs3 = normalize(detWorld.yzx * gs2.zxy - gs2.yzx * detWorld.zxy)
    // -----------------------------------------------------------------------
    float3 r6xyz   = tanYZX * float3(detWorld.z, detWorld.x, detWorld.y);
    float3 gs2_raw = detWorld.yzx * tanYZX.yzx - r6xyz;
    float3 gs2     = normalize(gs2_raw) * In.WorldTan.w;
    float3 gs3_raw = gs2.yzx * detWorld.zxy - detWorld.yzx * gs2.zxy;
    float3 gs3     = normalize(gs3_raw);

    // -----------------------------------------------------------------------
    // Detail bump from t15 (gSMP_DetailBumpMap), UV = v6.zw * gFC_DetailBumpParam.x
    // r7.xy = t15.Sample(uv).xy * 2 - 1
    // r7.z  = sqrt(1 - min(dot(r7.xy,r7.xy),1))
    // r7.xy *= gFC_DetailBumpParam.w
    // if dot(r7.xy,r7.xy) < 0.00001 → r7.z += 1
    // dbN = normalize(r7.xyz)
    // -----------------------------------------------------------------------
    float2 dbUV    = In.TexSnow.zw * gFC_DetailBumpParam.x;
    float2 dbS     = gSMP_DetailBumpMap.Sample(gSMP_DetailBumpMapSampler, dbUV).xy * 2.0f - 1.0f;
    float  dbZ     = sqrt(1.0f - min(dot(dbS, dbS), 1.0f));
    float2 dbSc    = dbS * gFC_DetailBumpParam.w;
    float  dbNZ    = (dot(dbSc, dbSc) < 0.000010f) ? 1.0f : 0.0f;
    float3 dbN     = normalize(float3(dbSc, dbZ + dbNZ));

    // -----------------------------------------------------------------------
    // Combine normals
    // combN = normalize(gs3*dbN.y + gs2*dbN.x + detWorld*dbN.z)
    // blendUnnorm = snowN * snowNLenInv - combN
    // blendN = normalize(snowBlend * blendUnnorm + combN)
    // -----------------------------------------------------------------------
    float3 combN    = normalize(gs3 * dbN.y + gs2 * dbN.x + detWorld * dbN.z);
    float3 blendN_u = snowN * snowNLenInv - combN;
    float3 blendN_r = snowBlend * blendN_u + combN;
    float  blendNLenInv = rsqrt(dot(blendN_r, blendN_r));
    float3 blendN   = blendNLenInv * blendN_r;

    // -----------------------------------------------------------------------
    // Lightmap + Shadow map (WITH_LightMap / WITH_ShadowMap)
    // Ref UV sources:
    //   WITH_LightMap && WITH_ShadowMap: lightmap UV = ProjW.zw (v9.zw)
    //   WITH_LightMap && !WITH_ShadowMap (no PntS): lightmap UV = TexSnow.zw (v6.zw)
    //   WITH_LightMap && WITH_PntS && !WITH_ShadowMap: NO lightmap (ref has no t6)
    // -----------------------------------------------------------------------
    float3 lightShdFactor = 1.0f;
#if defined(WITH_LightMap) && defined(WITH_ShadowMap)
    {
        float4 lightMapVal = gSMP_LightMap.Sample(gSMP_LightMapSampler, In.ProjW.zw);
        lightMapVal.rgb = pow(abs(lightMapVal.rgb), gFC_DebugPointLightParams.z);
        float3 shadowRate = CalcGetShadowRateWorldSpace(
            float4(In.WorldPos.xyz, In.WorldPos.w), blendN).rgb;
        lightShdFactor = min(shadowRate.rgb, lightMapVal.rgb) * gFC_DebugPointLightParams.y;
    }
#elif defined(WITH_LightMap) && !defined(WITH_PntS)
    {
        float4 lightMapVal = gSMP_LightMap.Sample(gSMP_LightMapSampler, In.TexSnow.zw);
        lightMapVal.rgb = pow(abs(lightMapVal.rgb), gFC_DebugPointLightParams.z);
        lightShdFactor = lightMapVal.rgb * gFC_DebugPointLightParams.y;
    }
#elif defined(WITH_ShadowMap)
    {
        float3 shadowRate = CalcGetShadowRateWorldSpace(
            float4(In.WorldPos.xyz, In.WorldPos.w), blendN).rgb;
        lightShdFactor = shadowRate.rgb;
    }
#endif

    // -----------------------------------------------------------------------
    // Snow color: exp2(log2(|gFC_SnowColor.xyz|) * 2.2)
    // -----------------------------------------------------------------------
    float3 snowCol = exp2(log2(abs(gFC_SnowColor.xyz)) * 2.2f);

    // -----------------------------------------------------------------------
    // Snow roughness/metal params (gFC_SnowParam2)
    // roughCol = gFC_SnowParam2.y * (snowCol - gFC_SnowParam2.zzz) + gFC_SnowParam2.zzz
    // -----------------------------------------------------------------------
    float  snowMetalMask = gFC_SnowParam2.y;
    float3 roughCol = snowMetalMask * (snowCol - gFC_SnowParam2.zzz) + gFC_SnowParam2.zzz;

    // -----------------------------------------------------------------------
    // PBL sample t1 (gSMP_SpecularMap), UV = v6.zw
    // ASM: rX.xyzw = t1.Sample(s1, v6.zwzz) with .wxyz swizzle
    //   t1.w→emissive, t1.x→roughness, t1.y→metalness, t1.z→diffuseF0
    // The swizzle remap below triggers fxc to emit .wxyz on the texture
    // instruction; with .wxyz the remap becomes identity and is eliminated.
    // -----------------------------------------------------------------------
    float4 pblRaw = gSMP_SpecularMap.Sample(gSMP_SpecularMapSampler, In.TexSnow.zw);
    float4 pbl;
    pbl.x = pblRaw.w;  // emissive
    pbl.y = pblRaw.x;  // roughness
    pbl.z = pblRaw.y;  // metalness
    pbl.w = pblRaw.z;  // diffuseF0

    // -----------------------------------------------------------------------
    // Material workflow (gFC_MaterialWorkflow.x)
    // -----------------------------------------------------------------------
    float3 diffCol, specCol, emissiveOut;
    float  rough, r8x;

    if (!gFC_MaterialWorkflow.x) {
        // Metalness workflow
        float3 ovAdj = -1.0f + gFC_MaterialOverrideParams.xyz;
        float3 ovSat = saturate(gFC_MaterialOverrideParams.xyz);
        float2 rm;
        rm.x = ovSat.x * (ovAdj.x - pbl.y) + pbl.y;  // roughness
        rm.y = ovSat.y * (ovAdj.y - pbl.z) + pbl.z;  // metalness

        float mLum   = max(dot(gFC_SpcMapMulCol.xyz, float3(0.2126729f,0.7151522f,0.0721750f)), 0.001f);
        float mBlend = saturate(pbl.w * 0.2f * mLum);
        float metal  = ovSat.z * (-mBlend + ovAdj.z) + mBlend;

        float emSc   = (1.0f - pbl.x) * gFC_MaterialOverrideParams.w * 10.0f;

        float3 base  = lerp(gFC_DifMapMulCol.xyz, gFC_SpcMapMulCol.xyz, rm.y);
        float3 dBase = exp2(log2(abs(diff.xyz * base)) * 2.2f);

        float3 r10   = pbl.x * dBase;
        diffCol      = (1.0f - rm.y) * r10;
        float3 specBase = rm.y * (dBase - metal) + metal;
        specCol      = saturate(pbl.x * specBase);
        emissiveOut  = emSc * dBase;
        rough        = rm.x;
        r8x          = pbl.x;
    } else {
        // Specular workflow
        diffCol     = exp2(log2(abs(diff.xyz * gFC_DifMapMulCol.xyz)) * 2.2f);
        specCol     = exp2(log2(saturate(pbl.yzw * gFC_SpcMapMulCol.xyz)) * 2.2f);
        float paramX = gFC_MaterialOverrideParams.x;
        rough       = saturate(paramX) * (-1.0f + paramX - pbl.x) + pbl.x;
        emissiveOut = 0;
        r8x         = 1.0f;
    }

    // Debug draw override (gFC_DebugDraw.y)
    if (gFC_DebugDraw.y) {
        uint dd = gFC_DebugDraw.y & 3u;
        uint ds = (gFC_DebugDraw.y >> 2u) & 3u;
        switch (dd) {
            case 1: diffCol = 0;             break;
            case 2: diffCol = 1;             break;
        }
        switch (ds) {
            case 1: specCol = 0;             break;
            case 2: specCol = 1;             break;
        }
    }

    // -----------------------------------------------------------------------
    // Snow material blend
    // ASM:
    //   add r2.w, l(1.0), -cb0[75].y             ← metalMaskInv = 1 - snowMetalMask
    //   mad r4.xyz, r5.xyzx, r2.wwww, -r10.xyzx  ← snowCol * metalMaskInv - diffCol
    //   mad r4.xyz, r1.wwww, r4.xyzx, r10.xyzx   ← bDiff = snowBlend*(snowCol*metalMaskInv-diffCol)+diffCol
    //   add r5.xyz, r6.xyzx, -r8.yzwy             ← roughCol - specCol
    //   mad r5.xyz, r1.wwww, r5.xyzx, r8.yzwy    ← bSpec = snowBlend*(roughCol-specCol)+specCol
    //   add r2.w, -r8.x, cb0[75].x               ← gFC_SnowParam2.x - rough
    //   mad r6.x, r1.w, r2.w, r8.x               ← bRough = snowBlend*(SnowParam2.x-rough)+rough
    //   dp3 r2.w, r5.xyzx, 0.33 * 50 sat         ← roughSat = saturate(dot(bSpec,0.33)*50)
    // NOTE: roughSat is computed AFTER bDiff (metalMaskInv used there), used in IBL
    // -----------------------------------------------------------------------
    // First compute bSpec and bRough (don't need roughSat yet)
    float3 bSpec   = snowBlend * (roughCol - specCol) + specCol;
    float  bRough  = snowBlend * (gFC_SnowParam2.x - rough) + rough;
    // metalMaskInv used in bDiff (ASM: r2.w = 1 - gFC_SnowParam2.y set before material workflow)
    float  metalMaskInv = 1.0f - snowMetalMask;
    // roughSat from bSpec (ASM: dp3 r2.w, r5.xyzx, 0.33*50 sat, computed AFTER bDiff)
    float  roughSat = saturate(dot(bSpec, float3(0.33f,0.33f,0.33f)) * 50.0f);
    // bDiff uses metalMaskInv (ASM: mad r4.xyz, snowCol * metalMaskInv - diffCol)
    float3 bDiff   = snowBlend * (snowCol * metalMaskInv - diffCol) + diffCol;

    // -----------------------------------------------------------------------
    // IBL
    // NdotV = dot(blendN, V)
    // R = 2*NdotV*blendN - V
    // fresnelTerm = (1-bRough) * (bRough + sqrt(1-bRough))
    // blendR = fresnelTerm * (-blendN * blendNLenInv + R) + blendN
    // -----------------------------------------------------------------------
    float  NdotV     = dot(blendN, V);
    float3 R         = 2.0f * NdotV * blendN - V;
    float  NdotV_sat = saturate(NdotV);

    float  omR       = saturate(1.0f - bRough);
    float  fresnelT  = omR * (bRough + sqrt(omR));
    float3 blendR    = fresnelT * (-blendN * blendNLenInv + R) + blendN;

    // Specular LOD: log2(bRough)*1.2 + (gFC_LightProbeParam.w - 1) - 2
    // (mipCount-1) first — forces add l(-1) -> mad l(1.2) -> add l(-2) ref codegen
    float specLOD = (gFC_LightProbeParam.w - 1.0f) + log2(bRough) * 1.2f - 2.0f;

    // Sample t12 (gSMP_EnvSpcMap)
    float3 envSpec = gSMP_EnvSpcMap.SampleLevel(gSMP_EnvSpcMapSampler, blendR, specLOD).xyz;
    envSpec *= gFC_EnvSpcMapMulCol.xyz * gFC_LightProbeParam.x;

    // Fresnel weight: saturate(dot(blendN,R)*1.3+1)^2
    float fresnelW = saturate(dot(blendN, R) * 1.3f + 1.0f);
    fresnelW *= fresnelW;
    envSpec *= fresnelW;

    // DFG LUT: t9, UV=(bRough, NdotV_sat)
    // ASM swizzle t9.zxyw → r7.yz = (t9.z, t9.x)
    float4 dfgFull = gSMP_DFG.SampleLevel(gSMP_DFGMapSampler, float2(bRough, NdotV_sat), 0.0f);
    float  dfg_scale = dfgFull.z;  // r7.y
    float  dfg_bias  = dfgFull.x;  // r7.z
    envSpec *= bSpec * dfg_scale + roughSat * dfg_bias;

    // Diffuse env: t11 (gSMP_EnvDifMap)
    float3 envDif = gSMP_EnvDifMap.SampleLevel(gSMP_EnvDifMapSampler, blendN, 0.0f).xyz;
    envDif *= gFC_EnvDifMapMulCol.xyz * gFC_LightProbeParam.x;

    float3 envLight = envDif * bDiff + envSpec;

    // Hemisphere
    float  hemBlend = blendN.y * 0.5f + 0.5f;
    float3 hemColor = lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, hemBlend);
    // ASM: r7.yzw = bDiff * hemColor; r2.xyz = r7.x * envLight + r7.yzw
    // r7.x = 1.0 (specular workflow) or pbl.x (metalness emissive factor)
    // In specular workflow: mov r7.x, l(1.000000)
    // In metalness workflow: r7.x = pbl.x (t1.w = emissive channel)
    float3 hemTerm  = bDiff * hemColor;
    envLight = r8x * envLight * lightShdFactor + hemTerm;

    // SAO
    if (gFC_SAOParams.w != 0.0f) {
        float ao = gSMP_AOMap.SampleLevel(gSMP_AOMapSampler, screenUV, 0.0f).x;
        envLight *= ao;
    }

    float3 litColor = envLight + emissiveOut;

    // -----------------------------------------------------------------------
    // Clustered point lights
    // ASM: dp4 r2.x/y/z, r7.xyzw, cb0[63/64/65]; dp4 r3.w, r7.xyzw, cb0[66]
    // -----------------------------------------------------------------------
    float4 wp4 = float4(In.WorldPos.xyz, 1.0f);
    float4 c0 = gFC_WorldViewClipMtx._m00_m10_m20_m30;
    float4 c1 = gFC_WorldViewClipMtx._m01_m11_m21_m31;
    float4 c2 = gFC_WorldViewClipMtx._m02_m12_m22_m32;
    float4 c3 = gFC_WorldViewClipMtx._m03_m13_m23_m33;
    float4 clipWP;
    clipWP.x = dot(wp4, c0);
    clipWP.y = dot(wp4, c1);
    clipWP.z = dot(wp4, c2);
    clipWP.w = dot(wp4, c3);
    float  ndcX = clipWP.x;
    float  ndcY = clipWP.y;
    float  ndcZ = clipWP.z;
    float  ndcW = clipWP.w;
    float3 ndc  = float3(ndcX, ndcY, ndcZ) / ndcW;

    float2 tile = floor(saturate(ndc.xy * 0.5f + 0.5f) * float2(16.0f, 8.0f));
    tile = min(tile, float2(15.0f, 7.0f));

    // linZ = gFC_ClipInfo.w / (ndc.z * gFC_ClipInfo.z + gFC_ClipInfo.y) / gFC_ClipInfo.x
    float linZ   = gFC_ClipInfo.w / (ndc.z * gFC_ClipInfo.z + gFC_ClipInfo.y);
    linZ        /= gFC_ClipInfo.x;
    float sliceF = min(log2(linZ) * gFC_ClusterParam.x, 23.0f);

    uint tileX   = (uint)tile.x;
    uint tileY   = (uint)tile.y;
    uint slice   = (uint)sliceF;
    uint flatIdx = tileX + (tileY + slice * 8u) * 16u;
    uint packed  = numLightsBuffer[flatIdx].offsetNum;

    uint lightCount = min(packed & 63u, gFC_PntLightCount.x);
    uint lightStart = packed >> 12u;
    uint lightEnd   = lightStart + lightCount;

    // GGX precomputed terms
    float roughSq    = max(bRough, 0.014f);
    roughSq         *= roughSq;
    float roughSq2   = roughSq * roughSq - 1.0f;
    float roughHalf  = roughSq * 0.5f;
    float roughIHalf = 1.0f - roughHalf;
    float NdotVGeom  = NdotV_sat * roughIHalf + roughHalf;
    float NdotVGeomInv = 1.0f / NdotVGeom;
    float3 fresnelBase = roughSat * (1.0f - bSpec);

    float3 pntAccum = 0;

    [loop]
    while (lightStart < lightEnd) {
        uint lid = lightIDBuffer[lightStart].id & 511u;

        float4 lpos = lightParamBuffer[lid].position;
        float4 lcol = lightParamBuffer[lid].color;

        float3 L    = lpos.xyz - In.WorldPos.xyz;
        float  dist = sqrt(dot(L, L));

        if (dist < lcol.w) {
            L /= dist;
            float3 H      = normalize(V + L);
            float  NdotLV = saturate(dot(V, H));
            float  NdotH  = saturate(dot(blendN, H));
            float  NdotL  = saturate(dot(blendN, L));

            float  fExp   = NdotLV * (-5.554730f) + (-6.983160f);
            float3 specF  = fresnelBase * exp2(NdotLV * fExp) + bSpec;

            float  denom  = NdotH * NdotH * roughSq2 + 1.0f;
            float  D      = roughSq / denom;
            D = D * D * 0.318309873f;

            float  NdotLG = NdotL * roughIHalf + roughHalf;
            float  G      = NdotVGeomInv / NdotLG;
            float  brdf   = D * G * 0.25f;

            float3 contrib = (bDiff * 0.318309873f + brdf * specF) * lcol.rgb;

            float  atten  = (lcol.w - dist) * lpos.w;
            atten = saturate(atten * atten * atten);

            pntAccum += contrib * atten * NdotL * 3.14159274f;
        }
        lightStart++;
    }
    litColor += pntAccum;

    // -----------------------------------------------------------------------
    // Gamma + fog + light scattering
    // -----------------------------------------------------------------------
    float3 litSRGB = exp2(log2(abs(litColor)) * (5.0f/11.0f));

    float fogFactor = saturate(saturate(In.WorldNrm.w) * gFC_FogCol.w);
    litSRGB = fogFactor * (gFC_FogCol.xyz - litSRGB) + litSRGB;

    float4 scattered = CalcGetLightScatteringCol(float4(litSRGB, 1.0f), float4(V, eyeDist));
    float3 finalColor = exp2(log2(abs(scattered.rgb)) * 2.2f);

    // -----------------------------------------------------------------------
    // Debug output (gFC_DebugDraw.x)
    // -----------------------------------------------------------------------
    float3 dbgOut = finalColor;
    switch ((int)gFC_DebugDraw.x) {
        case 1: dbgOut = finalColor; break;
        case 2: dbgOut = exp2(log2(abs(diff.xyz)) * (5.0f/11.0f)); break;
        case 3: dbgOut = exp2(log2(abs(bSpec)) * (5.0f/11.0f)); break;
        case 4: break;
        case 5: dbgOut = blendN * 0.498040f + 0.498040f; break;
        case 6: dbgOut = float3(bRough, 0.0f, 0.0f); break;
        default:
            dbgOut = float3(snowBlend * gFC_SnowParam.z * 0.1f, 0.0f, 0.0f);
            break;
    }

    SNOW_OUT_FWD Out;
    Out.Color = float4(finalColor, diff.w);
    Out.GBuf1 = float4(dbgOut, 0.0f);
    return Out;
}

#endif // FRPG_SNOW_FORWARD_FX
