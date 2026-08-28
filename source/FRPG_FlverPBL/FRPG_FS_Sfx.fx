#define ENABLE_VS
#define ENABLE_FS
#define OLD_VERSION 1
// Feature defines: match Makefile вЂ” either set to 1 or undefined.
// Do NOT define defaults (VTX_OUT struct uses #ifdef checks).
// For numeric #if checks, guard with #ifdef for defined-and-nonzero.
static const uint4 gFC_DebugDraw = 0;
#include "FRPG_Common.fxh"

// ref Sfx base RDEF carries a [unused] float4[6] @c249 named VR_249A
// (clip-plane array; FromSoft VC header declared the raw VR_ name);
// declare to match metadata.
uniform float4 VR_249A[6]; // [unused]

float3 srgb_encode(float3 c) { return pow(abs(c), 1.0f / 2.2f); }
float3 srgb_decode(float3 c) { return pow(abs(c), 2.2f); }

#if defined(WITH_MultiTexture) && !defined(WITH_SpecularMap)
// ===== Mul-base mini shader (dead code: no MTD uses Mul base variants) =====
// Reference: ReverseToneMap-only shader, t6 lum sample at (0.5,0.5), o0+o1,
// cb0[205-208] params, cb0[35] GlowColor. Identical for all 12 Mul/BmpMul base
// variants (Sdw/Csd/Lit defines do not change the code).
GBUFFER_OUT FragmentMain(VTX_OUT In)
{
    float3 tcCol = float3(1.0f, 0.0f, 1.0f) * gFC_ToneCorrectParams.x;
    if (asint(gFC_PostEffectScale.x) != 0)
    {
        // Exact transcription of ref ReverseToneMap (Sfx base asm, if_nz cb0[208].x block).
        // C = gFC_AdaptParam (cb206), M = gFC_fMiddleGray (cb207).
        float Cy = gFC_AdaptParam.y, Cz = gFC_AdaptParam.z, Cw = gFC_AdaptParam.w;
        float Mx = gFC_fMiddleGray.x, My = gFC_fMiddleGray.y,
              Mz = gFC_fMiddleGray.z, Mw = gFC_fMiddleGray.w;

        float3 colLin = saturate(tcCol);

        float r1z = Cw * Cw;
        float r1w = Cz * My;
        float r3x = My * Mz;
        float r3y = My * Mw;
        float r3z = Mx * Mz;

        // k = [Cy*(Mx*Cy + My*Mz) + Cz*Mw] / [Cy*(Mx*Cy + My) + Cw^2] - Cz/Cw
        float kk = Cy * (Mx * Cy + r3x) + Cz * Mw;
        float den = Cy * (Mx * Cy + My) + r1z;
        kk = kk / den - Cz / Cw;

        float3 r4 = kk * colLin;
        float3 r5 = r4 * r4 - r4;
        r5 *= Mx * Mw;
        r5 *= Cw * Cw;
        r5 *= Cw;

        float E = r3y * Mz;
        float3 r6 = r3y * r4;
        float3 r7 = (E - r6) * Cz;
        float discX = r5.x - 2.0f * r7.x * Cw;   // ref dp2 doubles the product
        float twoE = E + E;
        float3 r8a = r4 * twoE;
        r8a = E * Mz - r8a;
        float F = r3z * Cz * 4.0f;
        r8a = -F * r4 + r8a;
        r6 = r6 * r4 + r8a;
        float czw = Cz / Cw;
        float numX = czw * r6.x + discX;
        bool geX = numX >= 0.0f;

        float tA = r3x - My * r4.x;
        float Ax = -tA * Cw + r1w;
        float tAw = r3x - My * r4.z;
        float Aw = -tAw * Cw + r1w;

        float sqX = sqrt(numX);
        float dX = Cw * Mx, Dy = Cz * Mx;
        float3 r8s = colLin * kk - 1.0f;
        float divX = dX * r8s.x + Dy;
        float root1X = -0.5f * (sqX + Ax);
        float root2X = -0.5f * (-sqX + Ax);
        float oX = max(max(root1X / divX, root2X / divX), 0.0f);
        oX = geX ? oX : 0.0f;

        float discY = r5.y - 2.0f * r7.y * Cw;
        float numY = czw * r6.y + discY;
        bool geY = numY >= 0.0f;
        float sqY = sqrt(numY);
        float divY = dX * r8s.y + Dy;
        float root1Y = -0.5f * (sqY + Ax);
        float root2Y = -0.5f * (-sqY + Ax);
        float oY = max(max(root1Y / divY, root2Y / divY), 0.0f);
        oY = geY ? oY : 0.0f;

        float discZ = r5.z - 2.0f * r7.z * Cw;
        float numZ = czw * r6.z + discZ;
        bool geZ = numZ >= 0.0f;
        float sqZ = sqrt(numZ);
        float divZ = dX * r8s.z + Dy;
        float root1Z = -0.5f * (sqZ + Aw);
        float root2Z = -0.5f * (-sqZ + Aw);
        float oZ = max(max(root1Z / divZ, root2Z / divZ), 0.0f);
        oZ = geZ ? oZ : 0.0f;

        float3 r8final = float3(oX, oY, oZ);
        float lumSample = tex2D(gSMP_LumTex, float2(0.5f, 0.5f)).r;
        float expScale = clamp(lumSample, gFC_PostEffectScale.z, gFC_PostEffectScale.w);
        expScale = expScale + 0.0001f;
        tcCol = expScale * r8final / gFC_AdaptParam.x;
    }

    GBUFFER_OUT Out;
    Out.GBuffer0 = float4(tcCol, 1.0f);
    Out.GBuffer1 = float4(1.0f, 0.0f, 1.0f, 1.0f) * gFC_GlowColor * min(1.0f, gFC_ToneCorrectParams.x);
    return Out;
}
#else
GBUFFER_OUT FragmentMain(VTX_OUT In)
{
    // ref front block (Sfx base asm 0-2): dist = length(VecEye.xyz),
    // V = VecEye.xyz / dist — TEXCOORD3.w is never read
    float3 eyeVec = In.VecEye.xyz;
    float  dist   = length(eyeVec);
    float3 V      = eyeVec / dist;
    float3 worldPos = In.VtxWld.xyz;

#if defined(WITH_MultiTexture)
    float4 difTexUV = In.TexDifDif;
#elif defined(WITH_LightMap)
    float2 difTexUV = In.TexDifLit.xy;
#else
    float2 difTexUV = In.TexDif.xy;
#endif

    float3 wN = In.isFrontFace ? In.VecNrm.xyz : -In.VecNrm.xyz;
    wN = normalize(wN);

#if WITH_BumpMap
    float3 T = normalize(In.VecTan.xyz);
    float3 B = cross(wN, T) * In.VecTan.w;
    if (gFC_ParallaxParams.x > 0.0f)
    {
        difTexUV.xy = ParallaxOcclusionMappingSingle(difTexUV.xy, gFC_ParallaxParams.x, V, T, B, wN);
    }
#   if defined(WITH_MultiTexture)
    float3 vecTan = normalize(In.VecTan.yzx);
    float3 vecBin1 = normalize(In.VecBin.xyz);
    float3 vecBin2 = normalize(In.VecBin2.xyz);
    float3 vecTex1 = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap), difTexUV.xy);
    float3 vecTex2 = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap2), difTexUV.zw);
    vecTex1 = gFC_NormalScale * (vecTex1 - float3(0, 0, 1)) + float3(0, 0, 1);
    vecTex2 = gFC_NormalScale * (vecTex2 - float3(0, 0, 1)) + float3(0, 0, 1);
    float3 pixNrm1 = normalize(vecBin1 * vecTex1.x + vecTan.zxy * vecTex1.y + wN * vecTex1.z);
    float3 pixNrm2 = normalize(vecBin2 * vecTex2.x + vecTan.zxy * vecTex2.y + wN * vecTex2.z);
    float3 pixNrm = normalize(pixNrm1 + In.ColVtx.w * (pixNrm2 - pixNrm1));
#   else
    float3 vecTan = normalize(In.VecTan.yzx);
    float3 vecBin = normalize(In.VecBin.xyz);
    float3 vecTex = DecodeNormalMap(TEX2DSAMPLER(gSMP_BumpMap), difTexUV.xy);
    vecTex = gFC_NormalScale * (vecTex - float3(0, 0, 1)) + float3(0, 0, 1);
    float3 pixNrm = normalize(vecBin * vecTex.x + vecTan.zxy * vecTex.y + wN * vecTex.z);
#   endif
    float3 bin = normalize(cross(pixNrm, vecTan.zxy)) * In.VecTan.w;
    float3 tan = normalize(cross(bin, pixNrm));
    float3 N = _ApplyDetailBump(difTexUV.xy, pixNrm, tan, bin);
#else
    float3 N = ApplyDetailBump(difTexUV.xy, wN);
#endif

#if defined(WITH_MultiTexture)
    // ref FRPG_FS_HemEnv_Base.fxh L814: second diffuse layer t3 (DiffuseMap2,
    // UV = TEXCOORD6.zw); FgSkinAddColor goes on the SECOND sample BEFORE the
    // lerp (first sample stays raw); rgb lerped by COLOR0.a, then x COLOR0.rgb,
    // alpha forced to 1 before ModelMulCol
    float4 sampledColor  = TexDiff(difTexUV.xy);
    float4 sampledColor2 = TexDiff2(difTexUV.zw);
    sampledColor2.rgb += gFC_FgSkinAddColor.rgb;
    sampledColor.rgb = In.ColVtx.a * (sampledColor2.rgb - sampledColor.rgb) + sampledColor.rgb;
    sampledColor.rgb *= In.ColVtx.rgb;
    sampledColor.a = 1.0f;
    sampledColor *= gFC_ModelMulCol;
#else
    float4 sampledColor = TexDiff(difTexUV.xy);
    sampledColor.rgb += gFC_FgSkinAddColor.rgb;
    sampledColor *= In.ColVtx * gFC_ModelMulCol;
#endif
    sampledColor = qlocDoAlphaTest(sampledColor);

    float3 diffCol;
    float3 specCol;
    float specInt;
    float MtlLightPower = 1.0f;
    float3 MtlEmissive = float3(0, 0, 0);

#if WITH_SpecularMap
    float4 pblTexData;
#   if defined(WITH_MultiTexture)
    pblTexData = tex2D(gSMP_PBLMap, difTexUV.xy).rgba;
    float4 pblTexData2 = tex2D(gSMP_PBLMap2, In.TexDifDif.zw).rgba;
    pblTexData = lerp(pblTexData.rgba, pblTexData2.rgba, In.ColVtx.a);
#   else
    pblTexData = tex2D(gSMP_PBLMap, difTexUV).rgba;
#   endif
    if (gFC_MaterialWorkflow.x == 0)
    {
        specInt = lerp(pblTexData.r, gFC_MaterialOverrideParams.x - 1.0f, saturate(gFC_MaterialOverrideParams.x));
        float metalMask = lerp(pblTexData.g, gFC_MaterialOverrideParams.y - 1.0f, saturate(gFC_MaterialOverrideParams.y));
        float diffuseF0 = lerp(saturate(UnpackDiffuseF0(pblTexData.b) * CalcLuminance(gFC_SpcMapMulCol.xyz)), gFC_MaterialOverrideParams.z - 1.0f, saturate(gFC_MaterialOverrideParams.z));
        MtlLightPower = pblTexData.a;
        float emissivePower = (1.0f - pblTexData.a) * gFC_MaterialOverrideParams.w * EMISSIVE_STRENGTH;
        float3 linearSampledColor = pow(saturate(sampledColor.rgb * lerp(gFC_DifMapMulCol.rgb, gFC_SpcMapMulCol.rgb, metalMask)), 2.2f);
        diffCol = MtlLightPower * linearSampledColor * (1.0f - metalMask);
        specCol = MtlLightPower * lerp(diffuseF0, linearSampledColor, metalMask);
        MtlEmissive = emissivePower * linearSampledColor;
    }
    else
    {
        diffCol = pow(abs(sampledColor.rgb * gFC_DifMapMulCol.rgb), 2.2f);
        specCol = pow(saturate(pblTexData.rgb * gFC_SpcMapMulCol.rgb), 2.2f);
        specInt = lerp(pblTexData.a, gFC_MaterialOverrideParams.x - 1.0f, saturate(gFC_MaterialOverrideParams.x));
    }
#else
    [branch] if (gFC_MaterialWorkflow.x == 0)
    {
        float3 matP = saturate(gFC_MaterialOverrideParams.xyz);
        float3 matO = gFC_MaterialOverrideParams.xyz - float3(2.0f, 1.0f, 1.0f);
        specInt = matP.x * matO.x + 1.0f;
        float blend = matP.y * matO.y;
        float blendZ = matP.z * matO.z;
        float3 color = pow(saturate(sampledColor.rgb * lerp(gFC_DifMapMulCol.rgb, gFC_SpcMapMulCol.rgb, blend)), 2.2f);
        diffCol = (1.0f - blend) * color;
        specCol = lerp(blendZ, color, blend);
    }
    else
    {
        diffCol = pow(abs(sampledColor.rgb * gFC_DifMapMulCol.rgb), 2.2f);
        specCol = pow(saturate(gFC_SpcMapMulCol.rgb * float3(1.0f, 0.0f, 0.0f)), 2.2f);
        specInt = (gFC_MaterialOverrideParams.x - 2.0f) * saturate(gFC_MaterialOverrideParams.x) + 1.0f;
    }
#endif

    float specF90 = saturate(50.0f * dot(specCol, 0.33f));
    float NdotV = saturate(dot(N, V));

    // Environment IBL: 4-cube blend
    float3 envDif0 = texCUBElod(gSMP_EnvDifMap, float4(N, 0)).rgb;
    float3 envDif1 = texCUBElod(gSMP_13_CUBE, float4(N, 0)).rgb;
    float3 envDif = (gFC_LightProbeParam.x * envDif0 + gFC_MagicLightParam.x * envDif1) * gFC_EnvDifMapMulCol.rgb;

    float3 R = 2.0f * NdotV * N - V;
    float smoothness = 1.0f - specInt;
    float lerpFactor = smoothness * (sqrt(smoothness) + specInt);
    float3 domR = lerp(N, R, lerpFactor);
    float mipBase = gFC_LightProbeParam.w - 1.0f;
    float mip = log2(specInt) * 1.2f + mipBase - 2.0f;

    float3 envSpc0 = texCUBElod(gSMP_EnvSpcMap, float4(domR, mip)).rgb;
    float3 envSpc1 = texCUBElod(gSMP_14_CUBE, float4(domR, mip)).rgb;
    float3 envSpc = (gFC_LightProbeParam.y * envSpc0 + gFC_MagicLightParam.y * envSpc1) * gFC_EnvSpcMapMulCol.rgb;

    float horiz = saturate(1.0f + 1.3f * dot(wN, R));
    horiz *= horiz;

    float2 dfgVal = tex2Dlod(gSMP_DFG, float4(specInt, NdotV, 0, 0)).xy;
    float3 envSpecFactor = specCol * dfgVal.x + dfgVal.y * specF90;
    float3 envLighting = envDif * diffCol + envSpc * envSpecFactor * horiz;
#if WITH_SpecularMap
    envLighting *= MtlLightPower;
#endif

    float3 envLightComponent = envLighting;
    float3 dirSpecular = float3(0, 0, 0);
    float3 f90Term = specF90 - specF90 * specCol;
    {
        uint dirCount = min(3, gFC_DirLightCount.x);
        float roughDir = max(specInt, 0.08f);
        float alphaDir = roughDir * roughDir;
        float kDir = alphaDir * 0.5f;
        float k1Dir = 1.0f - kDir;
        float g1v = 1.0f / (NdotV * k1Dir + kDir);
        for (uint di = 0; di < dirCount; di++)
        {
            float3 Ldir = gFC_DirLightVec[di].xyz;
            float DdotR = dot(-Ldir, R);
            float3 S = R - DdotR * (-Ldir);
            float3 L2 = (DdotR < 0.9999619126f) ? normalize(normalize(S) * 0.0087265354f + (-0.9999619126f) * Ldir) : R;
            float ndl = saturate(dot(N, -Ldir));
            float3 illuminance = ndl * gFC_DirLightCol[di].rgb;
            float3 diffContrib = diffCol * illuminance;
            float3 Hn = normalize(V + L2);
            float vdh = saturate(dot(V, Hn));
            float ndh = saturate(dot(N, Hn));
            float ndl2 = saturate(dot(N, L2));
            float sphg = exp2(vdh * (-5.55473f * vdh - 6.98316f));
            float3 F = f90Term * sphg + specCol;
            float D = normal_distrib(ndh, roughDir);
            float g1l = 1.0f / (ndl2 * k1Dir + kDir);
            float vis = g1v * g1l;
            float mf = D * vis * 0.25f;
            float3 spcContrib = mf * F * illuminance * gFC_DirLightParam.y;
            envLightComponent += diffContrib * gFC_DirLightParam.x;
            dirSpecular += spcContrib * M_PI;
        }
    }

    float3 shFade = float3(1, 1, 1);
    float fShadow = 1.0f;
#ifdef WITH_LightMap
#ifdef WITH_MultiTexture
    float4 lightMapVal = tex2D(gSMP_LightMap, In.TexLit);
#else
    float4 lightMapVal = tex2D(gSMP_LightMap, In.TexDifLit.zw);
#endif
    lightMapVal.rgb = pow(lightMapVal.rgb, gFC_DebugPointLightParams.z);
#endif
#ifdef WITH_ShadowMap
    {
        float3 vShadowCoord;
        float4 positionInLight;
        float4 clampRect;
#if WITH_ShadowMap == CalcLispPos_VS
        positionInLight = In.VtxLit;
        clampRect = positionInLight.w * gFC_ShadowMapClamp0;
        float2 posLow = positionInLight.xy - positionInLight.w * (positionInLight.xy < clampRect.xy ? 1.0f : 0.0f);
        float2 posHigh = posLow + positionInLight.w * (clampRect.zw < posLow ? 1.0f : 0.0f);
        vShadowCoord = float3(posHigh.xy, positionInLight.z) / positionInLight.w;
#else
        float4 zGreater = (gFC_ShadowStartDist.xyzw < In.VtxWld.w) ? 1.0f : 0.0f;
        int slice = (int)(dot(zGreater, 1.0f) - 1.0f);
        positionInLight = mul(float4(In.VtxWld.xyz, 1.0f), gFC_ShadowMapMtxArray[slice]);
        clampRect = positionInLight.w * gFC_ShadowMapClamp[slice];
        float2 posLow = positionInLight.xy - positionInLight.w * (positionInLight.xy < clampRect.xy ? 1.0f : 0.0f);
        float2 posHigh = posLow + positionInLight.w * (clampRect.zw < posLow ? 1.0f : 0.0f);
        vShadowCoord = float3(posHigh.xy, positionInLight.z) / positionInLight.w;
#endif
        float NdotL = dot(gFC_ShadowLightDir.xyz, N);
        fShadow = saturate((NdotL + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
        float distF = saturate((gFC_ShadowMapParam.y - dist) * gFC_ShadowMapParam.z);
        float4 tapsA = float4(DecodeDepthCmp(vShadowCoord, int2(-1, -1)), DecodeDepthCmp(vShadowCoord, int2(0, -1)), DecodeDepthCmp(vShadowCoord, int2(1, -1)), DecodeDepthCmp(vShadowCoord, int2(-1, 0)));
        float4 tapsB = float4(DecodeDepthCmp(vShadowCoord, int2(0, 0)), DecodeDepthCmp(vShadowCoord, int2(1, 0)), DecodeDepthCmp(vShadowCoord, int2(-1, 1)), DecodeDepthCmp(vShadowCoord, int2(0, 1)));
        float pcf = dot(tapsA, 0.111111112f) + dot(tapsB, 0.111111112f);
        pcf = pcf + DecodeDepthCmp(vShadowCoord, int2(1, 1)) * 0.111111112f;
        fShadow = min(1.0f, fShadow + pcf);
        float3 rate = pow(1.0f - distF * gFC_ShadowColor.xyz * fShadow, gFC_DebugPointLightParams.z);
#ifdef WITH_LightMap
        shFade = min(lightMapVal.rgb, rate) * gFC_DebugPointLightParams.y;
#else
        shFade = rate;
#endif
    }
#else
#ifdef WITH_LightMap
    shFade = lightMapVal.rgb * gFC_DebugPointLightParams.y;
#endif
#endif

    float3 hemiAmb = lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, N.y * 0.5f + 0.5f);
    float3 accum = envLightComponent * shFade + hemiAmb * diffCol;

    // SAO (Screen-space ambient occlusion)
    if (gFC_SAOEnabled != 0.0f)
    {
        uint2 sp = (uint2)In.VtxClp.xy;
        float ao = gSMP_AOMap.Load(int3(sp, 0)).r;
        accum *= ao;
    }

    // Clustered point lights (SFX-specific cluster format: 8-bit count, offset >> 8)
    float3 pointAccum = float3(0, 0, 0);
    {
        uint3 clusterCoords = GetClusterCoords(worldPos);
        uint idx = (clusterCoords.z * CLUSTER_COUNT_Y + clusterCoords.y) * CLUSTER_COUNT_X + clusterCoords.x;
        uint offsetNum = numLightsBuffer[idx].offsetNum;
        if ((offsetNum & 0xff) != 0)
        {
            uint lightNum = min(offsetNum & 0xff, gFC_PntLightCount.x);
            uint offset = offsetNum >> 8;
            float pRoughness = max(specInt, 0.014f);
            float pAlpha = pRoughness * pRoughness;
            float pK = pAlpha * 0.5f;
            float pK1 = 1.0f - pK;
            float pInvDenV = 1.0f / (NdotV * pK1 + pK);
            for (uint li = offset; li < offset + lightNum; li++)
            {
                uint lID = lightIDBuffer[li].id;
                float4 lPos = lightParamBuffer[lID].position;
                float4 lCol = lightParamBuffer[lID].color;
                float atten = lightParamBuffer[lID].attenuation;
                uint fm = lightParamBuffer[lID].falloffMode;
                float3 delta = lPos.xyz - worldPos;
                float dL = length(delta);
                if (dL < lCol.w)
                {
                    float invD = 1.0f / dL;
                    float3 L = delta * invD;
                    float3 H = normalize(L + V);
                    float NdotL_d = saturate(dot(N, L));
                    float NdotH = saturate(dot(N, H));
                    float VdotH = saturate(dot(V, H));
                    float sphg = exp2(VdotH * (-5.55473f * VdotH - 6.98316f));
                    float3 F = f90Term * sphg + specCol;
                    float D = normal_distrib(NdotH, pRoughness);
                    float denL = NdotL_d * pK1 + pK;
                    float Vj = pInvDenV * (1.0f / denL);
                    float spcScale = D * Vj * 0.25f;
                    float3 spc = F * spcScale;
                    float3 difC = diffCol * M_INV_PI;

                    float la;
                    float lw = lCol.w;
                    float lmSh = 1.0f;
#ifdef WITH_LightMap
                    lmSh = lightMapVal.a * fShadow;
#endif
                    switch (fm)
                    {
                    case 1:
                    {
                        float t = dL / lw;
                        float t2 = t * t;
                        la = max(1.0f - t2 * t2, 0.0f);
                        la = la * la / (pow(dL, lPos.w) + 1.0f);
                        break;
                    }
                    case 2:
                    {
                        float iA = 1.0f / lPos.w;
                        float fS = lw - iA;
                        float distance = max(dL - fS, 0.0f);
                        float lightRadius = max(lw - fS, 0.0f);
                        float t = distance / lightRadius;
                        float t2 = t * t;
                        la = max(1.0f - t2 * t2, 0.0f);
                        la = la * la / (dL * dL + 1.0f);
                        break;
                    }
                    case 3:
                    {
                        la = (lw - dL) * lPos.w;
                        la = saturate(la * la * la);
                        break;
                    }
                    case 4:
                    {
                        la = saturate(lPos.w * (lw - dL));
                        break;
                    }
                    default:
                    {
                        la = saturate(1.0f - (dL - lPos.w) / (lw - lPos.w));
                        break;
                    }
                    }
                    float3 contribution = NdotL_d * ((difC + spc) * lCol.rgb * la * M_PI);
                    pointAccum += contribution * (atten * (1.0f - lmSh) + lmSh);
                }
            }
        }
    }
    accum += pointAccum;

    // Emissive glow (from material alpha Г— EMISSIVE_STRENGTH)
    float3 emissiveGlow = 0;
#if WITH_SpecularMap
    emissiveGlow = MtlEmissive;
#endif
    accum += emissiveGlow;
    accum += dirSpecular;

    // Linear -> srgb (gamma encode)
    float3 srgbCol = srgb_encode(accum);

    // Fog (in gamma space)
    float fogFactor = saturate(saturate(In.VecNrm.w) * gFC_FogCol.w);
    float3 fogged = lerp(srgbCol, gFC_FogCol.xyz, fogFactor);

    // Light scattering (atmospheric fog)
    float VdotL = dot(V, gFC_LsLightDir.xyz);
    float phase1 = VdotL * VdotL + 1.0f;
    float3 ext = exp2(-gFC_LsBeta1PlusBeta2.xyz * dist * gFC_LsLightDir.w * 2.081369f);
    float3 totExt = ext * gFC_LsTerrainReflectance.xyz;
    float hg = gFC_LsHGg.z * VdotL + gFC_LsHGg.y;
    float hgP = rsqrt(hg) * (1.0f / hg) * gFC_LsHGg.x;
    float3 inScat = (gFC_LsBetaDash1.xyz * phase1 + gFC_LsBetaDash2.xyz * hgP) * (1.0f - ext) * gFC_LsOneOverBeta1PlusBeta2.xyz;
    inScat *= gFC_LsTerrainReflectance.w;
    float3 scat = fogged * totExt + gFC_LsSunColor.rgb * inScat;
    float3 scatBlend = fogged + gFC_SfxLightScatteringParams.x * (scat - fogged) * gFC_LsSunColor.a;

    // Final output: gamma-encoded base + optional ReverseToneMap (OLD_VERSION)
    float3 gammaCol = pow(abs(scatBlend), 2.2f);
    float3 tcCol = gammaCol * gFC_ToneCorrectParams.x;

    if (asint(gFC_PostEffectScale.x) != 0)
    {
        float3 r1 = tcCol; // ref does NOT saturate before ReverseToneMap
        float3 r2 = float3(gFC_AdaptParam.z * gFC_fMiddleGray.w,
                           gFC_AdaptParam.w * gFC_fMiddleGray.w,
                           gFC_AdaptParam.z * gFC_fMiddleGray.y);
        float3 r3 = float3(gFC_fMiddleGray.y * gFC_fMiddleGray.z,
                           gFC_fMiddleGray.y * gFC_fMiddleGray.w,
                           gFC_fMiddleGray.x * gFC_fMiddleGray.y);
        float r2w1 = gFC_fMiddleGray.x * gFC_AdaptParam.y + r3.x;
        float r2x1 = gFC_AdaptParam.y * r2w1 + r2.x;
        float r2w2 = gFC_fMiddleGray.x * gFC_AdaptParam.y + gFC_fMiddleGray.y;
        float r2y1 = gFC_AdaptParam.y * r2w2 + r2.y;
        float r2x2 = r2x1 / r2y1;
        float r2y2 = gFC_AdaptParam.z / gFC_AdaptParam.w;
        float r2x3 = r2x2 - r2y2;
        float3 r4 = r2x3 * r1;
        float3 r5 = r4 * r4 - r4;
        r5 *= gFC_fMiddleGray.x * gFC_fMiddleGray.w;
        float r2y3 = gFC_AdaptParam.w * gFC_AdaptParam.w;
        r5 *= r2y3 * gFC_AdaptParam.w;
        float r2w4 = r3.y * (gFC_AdaptParam.z * gFC_AdaptParam.w);
        r5 = r5 * (-4.0f) + r2w4;
        float r2w5 = r3.y * gFC_fMiddleGray.z;
        float3 r6x = r3.y * r4;
        float3 r7x = r3.y * gFC_fMiddleGray.z - r6x;
        r7x *= gFC_AdaptParam.z;
        float dp2x = 2.0f * r7x.x * gFC_AdaptParam.w;
        float r3y1 = r5.x - dp2x;
        float r3w1 = r2w5 + r2w5;
        float3 r8x = r4 * r3w1;
        r8x = r2w5 * gFC_fMiddleGray.z - r8x;
        float r2w6 = r3.z * gFC_AdaptParam.z;
        r2w6 *= 4.0f;
        r8x = -r2w6 * r4 + r8x;
        r6x = r6x * r4 + r8x;
        float r2w7 = r2y3 * r6x.x + r3y1;
        float r2zInit = gFC_AdaptParam.z * gFC_fMiddleGray.y;
        float3 r3xzw = gFC_fMiddleGray.y * (gFC_fMiddleGray.z - r4);
        r3xzw = -r3xzw * gFC_AdaptParam.w + r2zInit;
        float sqrtX = sqrt(r2w7);
        float root1X = -0.5f * (sqrtX + r3xzw.x);
        float2 r4xy = float2(gFC_AdaptParam.w * gFC_fMiddleGray.x,
                              gFC_AdaptParam.z * gFC_fMiddleGray.x);
        float3 r8y = r1 * r2x3 + (-1.0f);
        float3 r4z = r4xy.x * r8y + r4xy.y;
        float root2X = -0.5f * (-sqrtX + r3xzw.x);
        float divX1 = root1X / r4z.x;
        float divX2 = root2X / r4z.x;
        float maxRootX = max(max(divX1, divX2), 0.0f);
        float r8rX = (r2w7 >= 0.0f) ? maxRootX : 0.0f;

        float dp2y = 2.0f * r7x.y * gFC_AdaptParam.w;
        float r2x4 = r5.y - dp2y;
        r2x4 = r2y3 * r6x.y + r2x4;
        float sqrtY = sqrt(r2x4);
        float root1Y = -0.5f * (sqrtY + r3xzw.y);
        float root2Y = -0.5f * (-sqrtY + r3xzw.y);
        float divY1 = root1Y / r4z.y;
        float divY2 = root2Y / r4z.y;
        float maxRootY = max(max(divY1, divY2), 0.0f);
        float r8rY = (r2x4 >= 0.0f) ? maxRootY : 0.0f;

        float dp2z = 2.0f * r7x.z * gFC_AdaptParam.w;
        float r2x5 = r5.z - dp2z;
        r2x5 = r2y3 * r6x.z + r2x5;
        float sqrtZ = sqrt(r2x5);
        float root1Z = -0.5f * (sqrtZ + r3xzw.z);
        float root2Z = -0.5f * (-sqrtZ + r3xzw.z);
        float divZ1 = root1Z / r4z.z;
        float divZ2 = root2Z / r4z.z;
        float maxRootZ = max(max(divZ1, divZ2), 0.0f);
        float r8rZ = (r2x5 >= 0.0f) ? maxRootZ : 0.0f;

        float3 r8final = float3(r8rX, r8rY, r8rZ);
        float lumSample = tex2D(gSMP_LumTex, float2(0.5f, 0.5f)).r;
        float expScale = clamp(lumSample, gFC_PostEffectScale.z, gFC_PostEffectScale.w);
        expScale = expScale + 0.0001f;
        tcCol = expScale * r8final / gFC_AdaptParam.x;
    }

    GBUFFER_OUT Out;
    Out.GBuffer0 = float4(tcCol, sampledColor.a);
    Out.GBuffer1 = float4(gammaCol * gFC_GlowColor.rgb, sampledColor.a * gFC_GlowColor.w) * min(1.0f, gFC_ToneCorrectParams.x);
    return Out;
}
#endif
