// FRPG_Snow_GBuffer.fx — GBuffer snow pixel shader (PntSS variants)
// Reconstructed from FRPG_Snow_______PntSS.fpo.asm (DSR Windows, ~434 instructions)
// Can be included from FRPG_Snow_All.fx or compiled standalone.
#ifndef WITH_GBuffer
#define ENABLE_FS
#define WITH_GBuffer 1
#define USE_SH 1
#include "FRPG_Snow_Common.fxh"
#else
#ifndef ENABLE_FS
#define ENABLE_FS
#endif
#ifndef USE_SH
#define USE_SH 1
#endif
#include "FRPG_Snow_Common.fxh"
#endif



// Encoded shadow map texture (regular sampler, not comparison) for GBuffer Lit+Shadow variants
#if defined(WITH_LightMap) && defined(WITH_ShadowMap)
Texture2D<float4> gShadowEnc : register(t7);
SamplerState gShadowEncSamp : register(s7);
#endif

struct SNOW_OUT_GB {
    float4 Color    : SV_Target0;
    float4 GBufNorm : SV_Target1;
    float4 GBufAlb  : SV_Target2;
    float4 GBufMat  : SV_Target3;
};

struct SNOW_IN_GB {
    float4 Pos       : SV_Position;
    float4 WorldPos  : TEXCOORD0;
    float4 WorldNrm  : TEXCOORD1;
    float4 VecEye    : TEXCOORD2;
    float4 WorldTan  : TEXCOORD3;
    float4 Color     : COLOR0;
    float4 ScreenUV  : TEXCOORD5;
    float4 TexSnow   : TEXCOORD6;
    float4 TanFrame  : TEXCOORD7;
    float4 ProjPos   : TEXCOORD8;
    float4 ProjW     : TEXCOORD9;
};

SNOW_OUT_GB FragmentMain(SNOW_IN_GB In)
{
    float eyeDist = length(In.VecEye.xyz);
    float3 V = In.VecEye.xyz / eyeDist;

    // === PBL map (t1) at diffuse UV ===
    float4 pbl = gSMP_SpecularMap.Sample(gSMP_SpecularMapSampler, In.TexSnow.zw);
    float  emissive = max(0.001f, pbl.x);
    float3 ovAdj = DL_FREG_185.xyz + float3(-1, -1, -1);
    float3 ovSat = saturate(DL_FREG_185.xyz);
    emissive = ovSat.x * (ovAdj.x - emissive) + emissive;
    float roughness = ovSat.y * (ovAdj.y - pbl.y) + pbl.y;
    float metalness = ovSat.z * (ovAdj.z - pbl.z) + pbl.z;
    float subsurfBlend = 0.2f * metalness;
    float emissiveScale = (1.0f - pbl.w) * DL_FREG_185.w;

    // === Albedo (t0) at diffuse UV ===
    float4 albedoRaw = gSMP_DiffuseMap.Sample(gSMP_DiffuseMapSampler, In.TexSnow.zw);
    if (AlphaTest == 1 && AlphaTestRef.x >= albedoRaw.w) discard;
    albedoRaw.xyz += DL_FREG_156.xyz;

    float3 baseLerp = lerp(DL_FREG_100.xyz, DL_FREG_101.xyz, emissive);
    float3 baseCol = baseLerp * DL_FREG_139.xyz;
    float3 baseMixed = baseCol * albedoRaw.xyz;

    // === Screen UV for jittered sampling ===
    float2 screenPos = In.ScreenUV.xy / In.ScreenUV.ww;
    float4 screenUV = float4(screenPos, screenPos) * float4(0.5, -0.5, 0.5, -0.5) + float4(0.5, 0.5, 0.5, 0.5);
    float snowCov = DL_FREG_169.x * In.Color.w;

    float4 projDiv = In.ProjPos / In.ProjW.xxyy;
    float4 projUV = projDiv * float4(0.5, -0.5, 0.5, -0.5) + float4(0.5, 0.5, 0.5, 0.5);
    float4 jitterOffset = screenUV.zwzw * float4(2, 2, 2, 2) - projUV;

    float2 uvN = screenPos * float2(0.5, -0.5) + float2(0.5, 0.5);

    // === Block 1: jittered 2x2 height sampling ===
    float2 jitFrac = frac(uvN * DL_FREG_164.xy);
    float2 jitSign = (jitFrac > 0.5f) ? 1.0f : -1.0f;
    float2 jitOff = (jitFrac - 0.5f) * jitSign;
    float2 jitDelta = DL_FREG_164.zw * jitSign;

    float4 hA = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uvN);
    float4 hB = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uvN + float2(jitDelta.x, 0));
    float4 hC = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uvN + float2(0, jitDelta.y));
    float4 hD = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, uvN + jitDelta);
    float4 valid1 = (float4(hA.w, hB.w, hC.w, hD.w) > 0.00390625f) ? 1.0f : 0.0f;
    float4 h1b = lerp(hB, hA, valid1.x);
    h1b = lerp(hC, h1b, valid1.x);
    h1b = lerp(hD, h1b, valid1.x);
    float4 h1bw = (hB - h1b) * valid1.y;
    float4 h1cw = lerp(h1b, hC, valid1.z);
    float4 h1dw = lerp(h1b, hD, valid1.w);
    h1bw = h1b + jitOff.x * h1bw;
    h1cw = lerp(h1cw, h1dw, jitOff.x);
    h1b = lerp(h1cw, h1bw, jitOff.y);

    float4 heightDecode = float4(1044480, 65280, 4080, 255);
    float hVal = max(0, dot(float4(3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f) - h1b, heightDecode) * 1.52590219e-5f);

    // === Parallax offset (bitangent + normal view-space projection) ===
    float3 bitan;
    bitan.x = In.WorldNrm.y * In.WorldTan.z - In.WorldNrm.z * In.WorldTan.y;
    bitan.y = In.WorldNrm.z * In.WorldTan.x - In.WorldNrm.x * In.WorldTan.z;
    bitan.z = In.WorldNrm.x * In.WorldTan.y - In.WorldNrm.y * In.WorldTan.x;
    bitan *= In.WorldTan.w;
    bitan = normalize(bitan);
    float3 worldNrm = normalize(In.WorldNrm.xyz);
    float bDotV = dot(bitan, V);
    float nDotV = dot(worldNrm, V);
    float3 parPos = (bitan * bDotV + worldNrm * nDotV) * (hVal * snowCov) * DL_FREG_169.w + In.WorldPos.xyz;
    float4 parPosW = float4(parPos, 1.0f);
    float projX = dot(parPosW, DL_FREG_165[0]);
    float projY = dot(parPosW, DL_FREG_165[1]);
    float projW = dot(parPosW, DL_FREG_165[3]);
    float2 projOff = float2(projX, projY) / projW;
    projOff = projOff * float2(0.5, -0.5) + float2(0.5, 0.5);
    projOff -= screenUV.zw;

    // === Blocks 2-5: bilinear height at parallax-shifted centers ===
    float2 c2 = projUV.xy + projOff;
    float2 c3 = projUV.zw + projOff;
    float2 c4 = jitterOffset.xy + projOff;
    float2 c5 = jitterOffset.zw + projOff;

    float4 fr2 = frac(float4(c2, c3) * DL_FREG_164.xyxy);
    float4 fr3 = frac(float4(c4, c5) * DL_FREG_164.xyxy);
    float4 sg2 = (fr2 > 0.5f) ? 1.0f : -1.0f;
    float4 sg3 = (fr3 > 0.5f) ? 1.0f : -1.0f;
    float4 of2 = (fr2 - 0.5f) * sg2;
    float4 of3 = (fr3 - 0.5f) * sg3;
    float4 dl23 = DL_FREG_164.zwzw * sg2.xxyy;
    float4 dl45 = DL_FREG_164.zwzw * sg3.xxyy;

    float4 b2 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c2);
    float4 b2B = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c2 + float2(dl23.x, 0));
    float4 b2C = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c2 + float2(0, dl23.y));
    float4 b2D = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c2 + dl23.xy);
    float4 b2b = lerp(lerp(b2, b2B, of2.x), lerp(b2C, b2D, of2.x), of2.y);
    float h2 = max(0, dot(float4(3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f) - b2b, heightDecode) * 1.52590219e-5f);
    float v2 = (b2b.w > 0.00390625f) ? 1.0f : 0.0f;
    float H2 = v2 * (h2 - hVal) + hVal;

    float4 b3 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c3);
    float4 b3B = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c3 + float2(dl23.z, 0));
    float4 b3C = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c3 + float2(0, dl23.w));
    float4 b3D = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c3 + dl23.zw);
    float4 b3b = lerp(lerp(b3, b3B, of2.z), lerp(b3C, b3D, of2.z), of2.w);
    float h3 = max(0, dot(float4(3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f) - b3b, heightDecode) * 1.52590219e-5f);
    float v3 = (b3b.w > 0.00390625f) ? 1.0f : 0.0f;
    float H3 = v3 * (h3 - hVal) + hVal;

    float4 b4 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c4);
    float4 b4B = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c4 + float2(dl45.x, 0));
    float4 b4C = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c4 + float2(0, dl45.y));
    float4 b4D = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c4 + dl45.xy);
    float4 b4b = lerp(lerp(b4, b4B, of3.x), lerp(b4C, b4D, of3.x), of3.y);
    float h4 = max(0, dot(float4(3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f) - b4b, heightDecode) * 1.52590219e-5f);
    float v4 = (b4b.w > 0.00390625f) ? 1.0f : 0.0f;
    float H4 = v4 * (h4 - hVal) + hVal;

    float4 b5 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c5);
    float4 b5B = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c5 + float2(dl45.z, 0));
    float4 b5C = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c5 + float2(0, dl45.w));
    float4 b5D = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, c5 + dl45.zw);
    float4 b5b = lerp(lerp(b5, b5B, of3.z), lerp(b5C, b5D, of3.z), of3.w);
    float h5 = max(0, dot(float4(3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f, 3.0f/17.0f) - b5b, heightDecode) * 1.52590219e-5f);
    float v5 = (b5b.w > 0.00390625f) ? 1.0f : 0.0f;
    float H5 = v5 * (h5 - hVal) + hVal;

    float2 parUV;
    parUV.x = snowCov * H2 - snowCov * H4;
    parUV.y = snowCov * H3 - snowCov * H5;
    parUV = clamp(parUV, -DL_FREG_173.z, DL_FREG_173.z);

    // === Tangent frame ===
    float3 tf1 = float3(worldNrm.x * In.TanFrame.w,
                        worldNrm.y * In.TanFrame.w + parUV.x,
                        worldNrm.z * In.TanFrame.w);
    tf1 = normalize(tf1);
    float3 tf2 = float3(In.TanFrame.x, parUV.y + In.TanFrame.y, In.TanFrame.z);
    tf2 = normalize(tf2);
    float3 tf3;
    tf3.x = tf2.y * tf1.z - tf1.y * tf2.z;
    tf3.y = tf2.z * tf1.x - tf1.z * tf2.x;
    tf3.z = tf2.x * tf1.y - tf1.x * tf2.y;

    // === Normal from t5 (gSMP_BumpMap2) at detail UV ===
    float2 bumpS = gSMP_BumpMap2.Sample(gSMP_BumpMap2Sampler, In.TexSnow.xy).xy;
    float2 bumpN = (bumpS * 2.0f - 1.0f) * DL_FREG_172.x;
    float3 snowN = tf1 * bumpN.y + tf2 * bumpN.x + tf3;
    float snowNLenInv = rsqrt(dot(snowN, snowN));

    // === Snow blend ===
    float snowBlend = saturate((hVal * In.Color.w - DL_FREG_172.z) * DL_FREG_172.y);

    // === Final normal (PntSS: no secondary detail frame) ===
    float3 blendN = snowN * snowNLenInv;

    // === NdotV / R ===
    float NdotV = dot(blendN, V);
    float3 R = 2.0f * NdotV * blendN - V;
    float NdotV_sat = saturate(NdotV);

    // === Snow color ===
    float3 snowCol = exp2(log2(abs(gFC_SnowColor.xyz)) * 2.2f);

    // === Material blend with snow ===
    float3 baseColor = -baseMixed + DL_FREG_170.xyz;
    float3 albedo = snowBlend * baseColor + baseMixed;

    // === Rough / AO / Spec ===  
    float omRough = DL_FREG_177.x - roughness;
    float rough = snowBlend * omRough + roughness;
    float roughAO = DL_FREG_177.y - emissive;
    float ao = snowBlend * roughAO + emissive;
    float roughSSS = -subsurfBlend + DL_FREG_177.z;
    float subsurface = snowBlend * roughSSS + subsurfBlend;
    float2 specParams = DL_FREG_169.zy * snowBlend;

    // === Gamma correct base ===
    float3 baseGamma = exp2(log2(abs(albedo)) * 2.2f);
    float omR = 1.0f - rough;
    float3 roughCol = baseGamma * omR;
    float3 specCol = rough * (baseGamma - subsurface) + subsurface;
    float roughSat = saturate(dot(specCol, float3(0.33f, 0.33f, 0.33f)) * 50.0f);

    // === Light probe ===
    float3 envAccum = 0;
    float probeType = DL_FREG_187;

    if (probeType < 0.5f) {
        float probeScale = DL_FREG_194.x * DL_FREG_184.x;
        float3 probeMul = DL_FREG_086.xyz * probeScale;
        float3 envDif = gSMP_EnvDifMap.SampleLevel(gSMP_EnvDifMapSampler, blendN, 0).xyz;
        float3 envLight = envDif * probeMul * roughCol;

        if (snowBlend < 1.0f && specParams.x > 0) {
            float3 negN = -blendN;
            float3 envNeg = gSMP_EnvDifMap.SampleLevel(gSMP_EnvDifMapSampler, negN, 0).xyz;
            float3 negLight = envNeg * probeMul * roughCol;
            float specK = 8.25f / (0.012f * specParams.x);
            float roughSq = snowBlend * snowBlend;
            float sssT = -(specK * roughSq) * (specK * roughSq);
            float4 sss4 = exp2(float4(225.421097f, 29.807749f, 7.71494627f, 2.54443574f) * sssT);
            float2 sss2 = exp2(float2(0.72497243f, 0.19469570f) * sssT);
            float3 sssWeight = sss4.y * float3(0.100f, 0.336f, 0.344f)
                             + sss4.x * float3(0.233f, 0.455f, 0.649f)
                             + sss4.z * float3(0.118f, 0.198f, 0.0f)
                             + sss4.w * float3(0.113f, 0.007f, 0.007f)
                             + sss2.x * float3(0.358f, 0.004f, 0.0f)
                             + sss2.y * float3(0.078f, 0.0f, 0.0f);
            envLight += negLight * sssWeight;
        }
        envAccum = envLight;
    }

    // === Fresnel env map ===
    float omRoughSat = saturate(1.0f - rough);
    float sqrtOmR = sqrt(omRoughSat);
    float fresnelFactor = omRoughSat * (rough + sqrtOmR);
    float3 blendR = fresnelFactor * (-blendN * 1.0f + R) + blendN;
    float specLOD = (DL_FREG_184.w - 1.0f) + log2(rough) * 1.2f - 2.0f;

    float3 envSpc = gSMP_EnvSpcMap.SampleLevel(gSMP_EnvSpcMapSampler, blendR, specLOD).xyz;
    float3 envSpc2 = gSMP_EnvSpcMap2.SampleLevel(gSMP_EnvSpcMap2Sampler, blendR, specLOD).xyz;
    envSpc = lerp(envSpc, envSpc2, DL_FREG_194.y);
    envSpc *= DL_FREG_087.xyz * DL_FREG_184.y;

    float NdotR = max(abs(dot(In.WorldNrm.xyz, R)), 1e-8f);
    envSpc *= NdotR;

    float2 dfg = gSMP_DFG.SampleLevel(gSMP_DFGMapSampler, float2(rough, NdotV_sat), 0).zx;
    envAccum += envSpc * (specCol * dfg.x + roughSat * dfg.y);
    envAccum *= snowBlend;

    // === Shadow PCF for GBuffer Ncs/Csd (and lightmap blend for Lit+shadow) variants ===
#if defined(WITH_ShadowMap)
#if defined(WITH_LightMap)
    // Lightmap sampling at lightmap UV (In.ProjW.zw) — ref GB: only Lit+shadow variants sample t6
    float3 lightMap = gSMP_LightMap.Sample(gSMP_LightMapSampler, In.ProjW.zw).xyz;
    float lightLum = max(dot(lightMap, float3(0.2126729f, 0.7151522f, 0.0721750f)), 0.001f);
    float lightLumLog = log2(lightLum);
    float lightLumPow = exp2(gFC_DebugPointLightParams.z * lightLumLog);
    float lightLumNorm = lightLumPow / lightLum;
    float3 lightAdj = lightMap * lightLumNorm;
#endif

    // Shadow cascade (ref GB: Ncs = single cascade c140-143+c157, no 65535; Csd = 4 cascades c140-155+c157-160+c123+65535)
    float4 wPos4 = float4(In.WorldPos.xyz, 1);
    float4 shPos;
#if WITH_ShadowMap == 2
    float4 zCmp = (gFC_ShadowStartDist < eyeDist) ? 1 : 0;
    float4 endDist = float4(gFC_ShadowStartDist.yzw, 65535.0f);
    float4 zRev = (eyeDist <= endDist) ? 1 : 0;
    float4 weight = zCmp * zRev;

    float4 shRow0 = gFC_ShadowMapMtxArray0._m00_m10_m20_m30 * weight.x
                  + gFC_ShadowMapMtxArray1._m00_m10_m20_m30 * weight.y
                  + gFC_ShadowMapMtxArray2._m00_m10_m20_m30 * weight.z
                  + gFC_ShadowMapMtxArray3._m00_m10_m20_m30 * weight.w;
    float4 shRow1 = gFC_ShadowMapMtxArray0._m01_m11_m21_m31 * weight.x
                  + gFC_ShadowMapMtxArray1._m01_m11_m21_m31 * weight.y
                  + gFC_ShadowMapMtxArray2._m01_m11_m21_m31 * weight.z
                  + gFC_ShadowMapMtxArray3._m01_m11_m21_m31 * weight.w;
    float4 shRow2 = gFC_ShadowMapMtxArray0._m02_m12_m22_m32 * weight.x
                  + gFC_ShadowMapMtxArray1._m02_m12_m22_m32 * weight.y
                  + gFC_ShadowMapMtxArray2._m02_m12_m22_m32 * weight.z
                  + gFC_ShadowMapMtxArray3._m02_m12_m22_m32 * weight.w;
    float4 shRow3 = gFC_ShadowMapMtxArray0._m03_m13_m23_m33 * weight.x
                  + gFC_ShadowMapMtxArray1._m03_m13_m23_m33 * weight.y
                  + gFC_ShadowMapMtxArray2._m03_m13_m23_m33 * weight.z
                  + gFC_ShadowMapMtxArray3._m03_m13_m23_m33 * weight.w;

    shPos.x = dot(wPos4, shRow0);
    shPos.y = dot(wPos4, shRow1);
    shPos.z = dot(wPos4, shRow2);
    shPos.w = dot(wPos4, shRow3);

    // Cascade clamp (blended clamp rect)
    float4 clampRect = gFC_ShadowMapClamp0 * weight.x
                     + gFC_ShadowMapClamp1 * weight.y
                     + gFC_ShadowMapClamp2 * weight.z
                     + gFC_ShadowMapClamp3 * weight.w;
    clampRect *= shPos.w;
    float2 outLow = (shPos.xy < clampRect.xy) ? 1 : 0;
    shPos.xy -= outLow * shPos.w;
    float2 outHigh = (clampRect.zw < shPos.xy) ? 1 : 0;
    shPos.xy += outHigh * shPos.w;
#else
    shPos = mul(wPos4, gFC_ShadowMapMtxArray0);
    float4 clampRect = gFC_ShadowMapClamp0 * shPos.w;
    float2 outLow = (shPos.xy < clampRect.xy) ? 1 : 0;
    shPos.xy -= outLow * shPos.w;
    float2 outHigh = (clampRect.zw < shPos.xy) ? 1 : 0;
    shPos.xy += outHigh * shPos.w;
#endif

    // Normal bias + distance fade
    float NdotL = dot(gFC_ShadowLightDir.xyz, blendN);
    float normBias = saturate((NdotL + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
    float distFade = saturate((gFC_ShadowMapParam.y - eyeDist) * gFC_ShadowMapParam.z);

    // 16-tap PCF, 4x4 binning by 0.0625, offsets 1.5/0.5 texel (ref GB 0.000732/0.000244)
    float shAvg = saturate(__GetShadowRate_GB16(shPos) + normBias);

    // Shadow attenuation: 1 - distFade * ShadowColor.xyz * fShadow, pow by DebugPointLightParams.z
    float3 shFade = 1.0f - distFade * gFC_ShadowColor.xyz * shAvg;
    shFade = exp2(log2(shFade) * gFC_DebugPointLightParams.z);
#if defined(WITH_LightMap)
    shFade = min(shFade, lightAdj.xyz);
    shFade *= gFC_DebugPointLightParams.y;
#endif

    envAccum *= shFade;
#endif

    // === High-quality probe: 3D SH volume ===
    if (probeType >= 0.5f) {
        float3 shUV = mul(float4x4(DL_FREG_188._m00_m10_m20_m30,
                                   DL_FREG_188._m01_m11_m21_m31,
                                   DL_FREG_188._m02_m12_m22_m32,
                                   DL_FREG_188._m03_m13_m23_m33), float4(In.WorldPos.xyz, 1)).xyz;
        shUV += 0.5f;
        float shLayer = saturate(shUV.z);

        float4 sh0 = gSMP_SHMap.SampleLevel(gSMP_SHMapSampler, float3(shUV.xy, shLayer * (1.0f / 7.0f)), 0);
        float4 sh1 = gSMP_SHMap.SampleLevel(gSMP_SHMapSampler, float3(shUV.xy, (shLayer + 1.0f) * (1.0f / 7.0f)), 0);
        float4 sh2 = gSMP_SHMap.SampleLevel(gSMP_SHMapSampler, float3(shUV.xy, (shLayer + 2.0f) * (1.0f / 7.0f)), 0);
        float4 sh3 = gSMP_SHMap.SampleLevel(gSMP_SHMapSampler, float3(shUV.xy, (shLayer + 3.0f) * (1.0f / 7.0f)), 0);
        float4 sh4 = gSMP_SHMap.SampleLevel(gSMP_SHMapSampler, float3(shUV.xy, (shLayer + 4.0f) * (1.0f / 7.0f)), 0);
        float4 sh5 = gSMP_SHMap.SampleLevel(gSMP_SHMapSampler, float3(shUV.xy, (shLayer + 5.0f) * (1.0f / 7.0f)), 0);
        float3 sh6 = gSMP_SHMap.SampleLevel(gSMP_SHMapSampler, float3(shUV.xy, (shLayer + 6.0f) * (1.0f / 7.0f)), 0).xyz;

        float3 shW = float3(sh4.w, sh3.w, sh5.w) * 0.429043f;
        float3 shBasis;
        shBasis.x = blendN.x * blendN.x - blendN.y * blendN.y;
        shBasis.y = blendN.z * blendN.z * 0.743125f - 0.247708f;
        float3 shLight = shW * shBasis.x
                       + sh6.xyz * shBasis.y
                       + sh0.xyz * 0.886227f;

        float3 shNXY = (blendN.x * blendN.z) * float3(sh0.w, sh1.w, sh2.w);
        shNXY += (blendN.x * blendN.y) * sh3.xyz;
        shNXY += (blendN.z * blendN.y) * sh5.xyz;
        shLight += shNXY * 0.858086f;

        float3 shDir = blendN.y * sh1.xyz + blendN.x * sh4.xyz + blendN.z * sh2.xyz;
        shLight += shDir * 1.023328f;
        shLight = max(shLight, 0);

        float3 shResult = roughCol * shLight + envAccum;

        if (snowBlend < 1.0f && specParams.x > 0) {
            float3 shNeg = -blendN.y * sh1.xyz - blendN.x * sh4.xyz - blendN.z * sh2.xyz;
            shNeg = max(shNeg * 1.023328f, 0);
            float3 shNegResult = roughCol * shNeg;

            float specK = 8.25f / (0.012f * specParams.x);
            float roughSq = snowBlend * snowBlend;
            float sssT = -(specK * roughSq) * (specK * roughSq);
            float4 sss4 = exp2(float4(225.421097f, 29.807749f, 7.71494627f, 2.54443574f) * sssT);
            float2 sss2 = exp2(float2(0.72497243f, 0.19469570f) * sssT);
            float3 sssWeight = sss4.y * float3(0.100f, 0.336f, 0.344f)
                             + sss4.x * float3(0.233f, 0.455f, 0.649f)
                             + sss4.z * float3(0.118f, 0.198f, 0.0f)
                             + sss4.w * float3(0.113f, 0.007f, 0.007f)
                             + sss2.x * float3(0.358f, 0.004f, 0.0f)
                             + sss2.y * float3(0.078f, 0.0f, 0.0f);
            shResult += shNegResult * sssWeight;
        }
        envAccum = shResult;
    }

    // === Hemisphere fallback (when no probe) ===
    if (probeType < 0.5f) {
        float hemBlend = blendN.y * 0.5f + 0.5f;
        float3 hemCol = lerp(DL_FREG_099.xyz, DL_FREG_098.xyz, hemBlend);
        envAccum = roughCol * hemCol + envAccum;
    }

    // === Screen-space AO ===
    if (DL_FREG_193 > 0) {
        uint2 aoUV = (uint2)In.Pos.xy;
        float aoSample = gSMP_AOMap.Load(int3(aoUV, 0)).x;
        envAccum *= aoSample;
    }

    // === Final composite ===
    float3 litColor = envAccum + emissiveScale * baseGamma;

    // === Fog ===
    float fogFactor = saturate(saturate(In.WorldNrm.w) * DL_FREG_103.w);
    float3 fogged = fogFactor * (DL_FREG_103.xyz - litColor) + litColor;

    // === Gamma / tone map ===
    float3 finalSRGB = fogged;
    if (DL_FREG_195.x > 0.5f) {
        finalSRGB = exp2(log2(abs(fogged)) * (5.0f / 11.0f));
    }

    float4 scattered = CalcGetLightScatteringCol(float4(finalSRGB, 1), float4(V, eyeDist));
    float3 scatteredSRGB = scattered.xyz;
    if (DL_FREG_195.x > 0.5f) {
        scatteredSRGB = exp2(log2(abs(scattered.xyz)) * 2.2f);
    }

    // === Output encode ===
    SNOW_OUT_GB Out;
    Out.Color = float4(scatteredSRGB, 1.0f);
    Out.GBufNorm = float4(blendN * 0.5f + 0.5f, 0.33f);
    Out.GBufAlb = float4(albedo, hVal);
    Out.GBufMat = float4(roughness, metalness, subsurface * 5.0f, ao * 0.1f);
    return Out;
}
