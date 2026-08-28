// FRPG_Water_Forward_new.fx — unified forward water body (Env / Reflect × base / Ncs / Csd).
// Ported 1:1 from reference 3DMigoto decompiles (AGENTS.md п.19).
// Define contract (same as old FRPG_Water_All.fx):
//   WATER_ENV | WATER_REFLECT          reflection source (t12 CUBE | t0 screen)
//   WITH_ShadowMap=1|2                 Ncs / Csd — single-cascade 9-tap SampleCmp (identical code)

#include "FRPG_Water_Common_new.fxh"

// resources are declared in FRPG_Water_Common_new.fxh (variant-guarded there)

// ---------------------------------------------------------------- shared tail
// scattering/fog/gamma tail shared by every forward variant.
// r1 = lit color, r0.xyw(w-slot)=scene/refraction base, v5 = vertex color,
// fade = min(FadeBegin.x, v5.w) * FadeBegin.y
void WaterTail(inout float4 r0, inout float4 r1, float fogW, float alphaFade)
{
    r1.w = min(gFC_WaterFadeBegin.x, alphaFade);
    r1.w = gFC_WaterFadeBegin.y * r1.w;
    r1.xyz = log2(abs(r1.xyz));
    r1.xyz = float3(0.454545468f, 0.454545468f, 0.454545468f) * r1.xyz;
    r1.xyz = exp2(r1.xyz);
    float f = saturate(fogW);
    f = saturate(gFC_FogCol.w * f);
    float3 fogd = gFC_FogCol.xyz + -r1.xyz;
    r1.xyz = f * fogd + r1.xyz;
}

// ---------------------------------------------------------------- main bodies
#if defined(WATER_ENV) || defined(WATER_REFLECT)
WATER_OUT FragmentMain_WaterBody(WATER_IN_BASE In)
{
    WATER_OUT oout;
    float4 o0;
    float4 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9;

    // ---- screen parallax UVs ----
    r0.xy = gFC_SAOParams.xy * In.VtxClp.xy;
    r0.zw = In.TexUV_A.xy / In.TexUV_A.ww;
    r1.xy = r0.zw * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r0.zw = In.TexUV_B.xy / In.TexUV_B.ww;
    r1.zw = r0.zw * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r2.xyzw = r0.xyxy * float4(2, 2, 2, 2) + -r1.xyzw;

    // ---- wave heights: 4 taps of t2 ----
    r0.z = gSMP_2.Sample(gSMP_2Sampler, r1.xy).x;
    r0.w = gSMP_2.Sample(gSMP_2Sampler, r1.zw).x;
    r1.x = gSMP_2.Sample(gSMP_2Sampler, r2.xy).x;
    r1.y = gSMP_2.Sample(gSMP_2Sampler, r2.zw).x;
    float hSum = r0.z + r0.w + r1.x + r1.y;   // shadow height displacement source

    // ---- tangent frame from the two wave normals ----
    r1.z = In.WldNrm_0.y + In.WldNrm_0.y;
    r0.zw = -r1.xy + r0.zw;
    r2.x = r0.z * gFC_WaterWaveHeight + r1.z;
    r0.z = In.WldNrm_1.y + In.WldNrm_1.y;
    r1.z = r0.w * gFC_WaterWaveHeight + r0.z;
    r2.yz = float2(2, 2) * In.WldNrm_0.zx;
    r0.z = dot(r2.xyz, r2.xyz);
    r0.z = rsqrt(r0.z);
    r2.xyz = r2.xyz * r0.zzz;
    float3 nA = r2.xyz;
    r1.xy = float2(2, 2) * In.WldNrm_1.zx;
    r0.z = dot(r1.xyz, r1.xyz);
    r0.z = rsqrt(r0.z);
    r1.xyz = r1.xyz * r0.zzz;

    // ---- pseudo-binormal + fresnel against world normal ----
    r3.xyz = r1.xyz * r2.xyz;
    r1.xyz = r1.zxy * r2.yzx + -r3.xyz;
    r0.z = dot(In.VecNrmW.xyz, In.VecNrmW.xyz);
    r0.z = sqrt(r0.z);
    r2.xyz = In.VecNrmW.xyz / r0.zzz;
    r0.w = dot(r1.xyz, r2.xyz);
    r1.w = max(0, r0.w);
    r1.w = 1 + -r1.w;
    r1.w = max(0, r1.w);
    r1.w = log2(r1.w);
    r1.w = gFC_WaterFresnelPow * r1.w;
    r1.w = exp2(r1.w);
    r2.w = 1 + -r1.w;
    r1.w = gFC_WaterFresnelBias * r2.w + r1.w;
    r1.w = gFC_WaterFresnelScale * r1.w;
    r0.w = r0.w + r0.w;
    r3.xyz = r0.www * r1.xyz + -r2.xyz;

    // ---- refraction band UVs ----
    r4.xyzw = gFC_WaterRefractBand * r1.xzxz;
    r4.xyzw = In.ColVtx.wwww * r4.xyzw;

#ifdef WATER_ENV
    // ---- CUBE environment reflection ----
    r1.xyz = gSMP_12_CUBE.Sample(gSMP_12_CUBESampler, r3.xyz).xyz;
#else
    // ---- screen-space reflection through t0 ----
    r1.xy = r3.xz * gFC_WaterReflectBand + r0.xz;
    r1.xyz = gSMP_0.Sample(gSMP_0Sampler, r1.xy).xyz;
#endif

    // ---- 3-band refraction + mask ----
    r5.xy = In.VtxClp.xy * gFC_SAOParams.xy + r4.zw;
    r6.x = gSMP_1.Sample(gSMP_1Sampler, r5.xy).x;
    r4.xyzw = r4.xyzw * float4(1.02999997f, 1.02999997f, 1.05999994f, 1.05999994f) + r0.xyxy;
    r6.y = gSMP_1.Sample(gSMP_1Sampler, r4.xy).y;
    r6.z = gSMP_1.Sample(gSMP_1Sampler, r4.zw).z;
    r5.x = gSMP_3.Sample(gSMP_3Sampler, r5.xy).w;
    r5.y = gSMP_3.Sample(gSMP_3Sampler, r4.xy).w;
    r5.z = gSMP_3.Sample(gSMP_3Sampler, r4.zw).w;
    r4.xyz = (r5.xyz == float3(1, 1, 1)) ? float3(1, 1, 1) : float3(0, 0, 0);
    r0.xyw = gSMP_1.Sample(gSMP_1Sampler, r0.xy).xyz;
    r5.xyz = r6.xyz + -r0.xyw;
    r0.xyw = r4.xyz * r5.xyz + r0.xyw;

    // ---- Fresnel color linearization + specular ----
    r4.xyz = log2(abs(gFC_WaterFresnelColor.xyz));
    r4.xyz = float3(2.20000005f, 2.20000005f, 2.20000005f) * r4.xyz;
    r4.xyz = exp2(r4.xyz);

    r2.w = dot(r3.xyz, gFC_SpcLightVec.xyz);
    r2.w = max(0, -r2.w);
    r2.w = log2(r2.w);
    r2.w = gFC_SpcParam.x * r2.w;
    r2.w = exp2(r2.w);

    float shadowR = 0.0f, shadowG = 0.0f, shadowB = 0.0f;
    float3 sceneBase = r0.xyw;

#ifdef WITH_ShadowMap
    // ---- single-cascade shadow (Ncs == Csd): 9-tap SampleCmp on t7 ----
    // lookup position displaced by wave height; ALL locals fresh — must not
    // clobber r0/r1/r2 lanes carrying fresnel/spec/normals.
    float hW = hSum * gFC_WaterWaveHeight;
    float shPosY = hW * 0.25f + In.VecPos.y;
    float4 shPos = float4(In.VecPos.x, shPosY, In.VecPos.z, 1);
#if WITH_ShadowMap == 2
    // cascade select: index = count(ShadowStartDist < posW) - 1
    float4 ltMask = (gFC_ShadowStartDist.xyzw < In.VecPos.wwww) ? float4(1, 1, 1, 1) : float4(0, 0, 0, 0);
    int cascadeIdx = (int)(dot(ltMask, float4(1, 1, 1, 1)) + -1);
#else
    const int cascadeIdx = 0;
#endif
    float4 mtx0 = gFC_ShadowMapMtxArray[cascadeIdx]._m00_m10_m20_m30;
    float4 mtx1 = gFC_ShadowMapMtxArray[cascadeIdx]._m01_m11_m21_m31;
    float4 mtx2 = gFC_ShadowMapMtxArray[cascadeIdx]._m02_m12_m22_m32;
    float4 mtx3 = gFC_ShadowMapMtxArray[cascadeIdx]._m03_m13_m23_m33;
    float su = dot(shPos, mtx0);
    float sv = dot(shPos, mtx1);
    float sd = dot(shPos, mtx2);
    float sw = dot(shPos, mtx3);
    float4 cl = gFC_ShadowMapClamp[cascadeIdx].xyzw * sw;
    float2 lo = (su < cl.x && sv < cl.y) ? float2(1, 1) : float2(0, 0);
    float2 uva = -lo * sw + float2(su, sv);
    float2 hiM = (cl.z < uva.x && cl.w < uva.y) ? float2(1, 1) : float2(0, 0);
    float2 uvb = hiM * sw + uva;
    float ndl = dot(gFC_ShadowLightDir.xyz, nA);
    float biasTerm = gFC_ShadowMapParam.x + ndl;
    float depthTerm = gFC_ShadowMapParam.y + -sd;
    float2 bz = saturate(gFC_ShadowMapParam.wz * float2(biasTerm, depthTerm));
    float3 suvd = float3(uvb, sw) / sw;
    float t0c = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(-1, -1)).x;
    float t1c = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(0, -1)).x;
    float t2c = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(1, -1)).x;
    float t3c = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(-1, 0)).x;
    float sumA = dot(float4(t0c, t1c, t2c, t3c), float4(0.111111112f, 0.111111112f, 0.111111112f, 0.111111112f));
    t0c = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(0, 0)).x;
    t1c = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(1, 0)).x;
    t2c = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(-1, 1)).x;
    t3c = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(0, 1)).x;
    float sumB = dot(float4(t0c, t1c, t2c, t3c), float4(0.111111112f, 0.111111112f, 0.111111112f, 0.111111112f));
    float tap9 = gSMP_7.SampleCmp(gSMP_7Sampler, suvd.xy, suvd.z, int2(1, 1)).x;
    float shAvg = tap9 * 0.111111112f + sumA;
    shAvg = sumB + shAvg;
    shAvg = shAvg + bz.x;
    shAvg = min(1, shAvg);
    float3 tint = gFC_ShadowColor.xyz * bz.y;
    float3 shTint = -tint * shAvg + float3(1, 1, 1);
    shTint = log2(abs(shTint));
    shTint = gFC_DebugPointLightParams.zzz * shTint;
    shTint = exp2(shTint);
    shadowR = shTint.x; shadowG = shTint.y; shadowB = shTint.z;
#endif

    // ---- clustered point lights ----
    r5.xyz = In.VecPos.xyz;
    r5.w = 1;
    r6.x = dot(r5.xyzw, gFC_WorldViewClipMtx._m00_m10_m20_m30);
    r6.y = dot(r5.xyzw, gFC_WorldViewClipMtx._m01_m11_m21_m31);
    r6.z = dot(r5.xyzw, gFC_WorldViewClipMtx._m02_m12_m22_m32);
    r3.w = dot(r5.xyzw, gFC_WorldViewClipMtx._m03_m13_m23_m33);
    r5.xyz = r6.xyz / r3.www;
    r5.xy = r5.xy * float2(0.5f, 0.5f) + float2(0.5f, 0.5f);
    r5.xy = float2(16, 8) * r5.xy;
    r5.xy = floor(r5.xy);
    r5.xy = min(float2(15, 7), r5.xy);
    uint2 cellXY = (uint2)r5.xy;
    float zSlice = r5.z;
    r3.w = zSlice * gFC_ClipInfo.z + gFC_ClipInfo.y;
    r3.w = gFC_ClipInfo.w / r3.w;
    r3.w = r3.w / gFC_ClipInfo.x;
    r3.w = log2(r3.w);
    r3.w = gFC_ClusterParam.x * r3.w;
    r3.w = min(23, r3.w);
    uint cellZ = (uint)r3.w;
    uint cellY = cellZ * 8u + cellXY.y;
    uint cellX = cellY * 16u + cellXY.x;
    uint offsetNum = numLightsBuffer[cellX].offsetNum;
    uint lLocal = offsetNum & 63u;
    lLocal = min((uint)gFC_PntLightCount.x, lLocal);
    uint lBase = offsetNum >> 12;
    uint lCount = lLocal + lBase;
    r5.xyz = float3(0, 0, 0);
    [loop]
    for (uint li = lBase; li < lCount; li++)
    {
        uint lid = lightIDBuffer[li].id & 511u;
        r7 = lightParamBuffer[lid].position;
        r6 = lightParamBuffer[lid].color;
        r7.xyz = -In.VecPos.xyz + r7.xyz;
        r8.x = dot(r7.xyz, r7.xyz);
        r8.x = sqrt(r8.x);
        r8.y = (r8.x < r6.w) ? 1.0f : 0.0f;
        r7.xyz = r7.xyz / r8.xxx;
        r6.w = -r8.x + r6.w;
        r6.w = saturate(r7.w * r6.w);
        r6.xyz = r6.xyz * r6.www;
        r6.w = dot(r3.xyz, r7.xyz);
        r6.w = max(0, r6.w);
        r6.w = log2(r6.w);
        r6.w = gFC_SpcParam.x * r6.w;
        r6.w = exp2(r6.w);
        r6.xyz = r6.www * r6.xyz + r5.xyz;
        r5.xyz = r8.yyy ? r6.xyz : r5.xyz;
    }
    r3.xyz = gFC_SpcLightCol.xyz * r2.www + r5.xyz;

    // ---- water body blend (shadowed path mixes toward pre-blend scene color) ----
#ifndef WITH_ShadowMap
    r5.xyz = log2(abs(gFC_WaterColor.xyz));
    r5.xyz = float3(2.20000005f, 2.20000005f, 2.20000005f) * r5.xyz;
    r5.xyz = exp2(r5.xyz);
    r2.w = gFC_WaterColor.w * In.ColVtx.w;
    r5.xyz = r5.xyz + -r0.xyw;
    r0.xyw = r2.www * r5.xyz + r0.xyw;
    r1.xyz = r1.xyz * r4.xyz + r3.xyz;
#else
    float3 wcLin = log2(abs(gFC_WaterColor.xyz));
    wcLin = float3(2.20000005f, 2.20000005f, 2.20000005f) * wcLin;
    wcLin = exp2(wcLin);
    float wA = gFC_WaterColor.w * In.ColVtx.w;
    float3 wcTint = wcLin * float3(shadowR, shadowG, shadowB) + -sceneBase;
    r0.xyz = wA * wcTint + sceneBase;
    r1.xyz = r1.xyz * r4.xyz + r3.xyz;
#endif
    r1.xyz = r1.xyz + -r0.xyw;
    r1.xyz = r1.www * r1.xyz + r0.xyw;
    r1.xyz = In.ColVtx.xyz * r1.xyz;

    // ---- shared tail: fade / gamma / fog / scatter ----
    WaterTail(r0, r1, In.VtxFog.w, In.ColVtx.w);

    r2.x = dot(r2.xyz, gFC_LsLightDir.xyz);
    r2.y = r2.x * r2.x + 1;
    r3.xyz = -gFC_LsBeta1PlusBeta2.xyz * r0.zzz;
    r3.xyz = gFC_LsLightDir.www * r3.xyz;
    r3.xyz = float3(2.08136892f, 2.08136892f, 2.08136892f) * r3.xyz;
    r3.xyz = exp2(r3.xyz);
    r4.xyz = gFC_LsTerrainReflectance.xyz * r3.xyz;
    r0.z = gFC_LsHGg.z * -r2.x + gFC_LsHGg.y;
    r2.x = rsqrt(r0.z);
    r0.z = 1 / r0.z;
    r0.z = r2.x * r0.z;
    r0.z = gFC_LsHGg.x * r0.z;
    r2.xzw = gFC_LsBetaDash2.xyz * r0.zzz;
    r2.xyz = gFC_LsBetaDash1.xyz * r2.yyy + r2.xzw;
    r3.xyz = float3(1, 1, 1) + -r3.xyz;
    r2.xyz = r3.xyz * r2.xyz;
    r2.xyz = gFC_LsOneOverBeta1PlusBeta2.xyz * r2.xyz;
    r2.xyz = gFC_LsTerrainReflectance.www * r2.xyz;
    r2.xyz = gFC_LsSunColor.xyz * r2.xyz;
    r2.xyz = r1.xyz * r4.xyz + r2.xyz;
    r2.xyz = r2.xyz + -r1.xyz;
    r1.xyz = gFC_LsSunColor.www * r2.xyz + r1.xyz;
    r1.xyz = log2(abs(r1.xyz));
    r1.xyz = float3(2.20000005f, 2.20000005f, 2.20000005f) * r1.xyz;
    r1.xyz = exp2(r1.xyz);
    r1.xyz = r1.xyz + -r0.xyw;
    o0.xyz = r1.www * r1.xyz + r0.xyw;
    o0.w = 1;

    oout.Color = o0;
    return oout;
}
#endif
