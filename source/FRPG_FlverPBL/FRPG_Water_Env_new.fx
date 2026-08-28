// FRPG_Water_Env.fx — Water environment path (t12 CUBE reflections).
// Ported 1:1 from reference decompile FRPG_Water_Env____.hlsl (see AGENTS.md п.19).
// Operation shapes kept literal (log2/exp2 pairs, max(0,...), while-loop) so that
// fxc reproduces the reference instruction stream.

#include "FRPG_Water_Common_new.fxh"

WATER_OUT FragmentMain_WaterEnv(WATER_IN_BASE In)
{
    float4 o0;
    float4 r0, r1, r2, r3, r4, r5, r6, r7, r8;

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

    // ---- tangent frame from the two wave normals ----
    r0.zw = -r1.xy + r0.zw;
    r2.x = r0.z * gFC_WaterWaveHeight + (In.WldNrm_0.y + In.WldNrm_0.y);
    r1.z = r0.w * gFC_WaterWaveHeight + (In.WldNrm_1.y + In.WldNrm_1.y);
    r2.yz = float2(2, 2) * In.WldNrm_0.zx;
    r0.z = dot(r2.xyz, r2.xyz);
    r0.z = rsqrt(r0.z);
    r2.xyz = r2.xyz * r0.zzz;
    r1.xy = float2(2, 2) * In.WldNrm_1.zx;
    r0.z = dot(r1.xyz, r1.xyz);
    r0.z = rsqrt(r0.z);
    r1.xyz = r1.xyz * r0.zzz;

    // ---- pseudo-binormal + fresnel against world normal ----
    r3.xyz = r2.xyz * r1.xyz;
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

    // ---- reflection (CUBE) + 3-band refraction (t1) masked by t3.w ----
    r4.xyzw = gFC_WaterRefractBand * r1.xzxz;
    r4.xyzw = In.ColVtx.wwww * r4.xyzw;
    r1.xyz = gSMP_12_CUBE.Sample(gSMP_12_CUBESampler, r3.xyz).xyz;
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

    // ---- clustered point lights (cell lookup identical to other PBL families) ----
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
    r5.xy = (uint2)r5.xy;
    r3.w = r5.z * gFC_ClipInfo.z + gFC_ClipInfo.y;
    r3.w = gFC_ClipInfo.w / r3.w;
    r3.w = r3.w / gFC_ClipInfo.x;
    r3.w = log2(r3.w);
    r3.w = gFC_ClusterParam.x * r3.w;
    r3.w = min(23, r3.w);
    uint cellZ = (uint)r3.w;
    uint cellY = cellZ * 8u + (uint)r5.y;
    uint cellX = cellY * 16u + (uint)r5.x;
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

    // ---- water body color blend ----
    r5.xyz = log2(abs(gFC_WaterColor.xyz));
    r5.xyz = float3(2.20000005f, 2.20000005f, 2.20000005f) * r5.xyz;
    r5.xyz = exp2(r5.xyz);
    r2.w = gFC_WaterColor.w * In.ColVtx.w;
    r5.xyz = r5.xyz + -r0.xyw;
    r0.xyw = r2.www * r5.xyz + r0.xyw;
    r1.xyz = r1.xyz * r4.xyz + r3.xyz;
    r1.xyz = r1.xyz + -r0.xyw;
    r1.xyz = r1.www * r1.xyz + r0.xyw;
    r1.xyz = In.ColVtx.xyz * r1.xyz;
    r1.w = min(gFC_WaterFadeBegin.x, In.ColVtx.w);
    r1.w = gFC_WaterFadeBegin.y * r1.w;

    // ---- gamma round trip + fog ----
    r1.xyz = log2(abs(r1.xyz));
    r1.xyz = float3(0.454545468f, 0.454545468f, 0.454545468f) * r1.xyz;
    r1.xyz = exp2(r1.xyz);
    r2.w = saturate(In.VtxFog.w);
    r2.w = saturate(gFC_FogCol.w * r2.w);
    r3.xyz = gFC_FogCol.xyz + -r1.xyz;
    r1.xyz = r2.www * r3.xyz + r1.xyz;

    // ---- aerial-perspective scattering (Ls block) ----
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

    WATER_OUT Out;
    Out.Color = o0;
    return Out;
}
