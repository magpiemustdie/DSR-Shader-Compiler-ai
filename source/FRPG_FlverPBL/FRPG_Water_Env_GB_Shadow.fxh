// FRPG_Water_Env_GB_Shadow.fxh — Shadow map sampling for Water GBuffer path
// Pre-phase: projection + PCF (before tangent frame, no normal available)
// Post-phase: NdotL bias + color modulation (after tangent frame)

#ifndef WATER_ENV_GB_SHADOW_INCLUDED
#define WATER_ENV_GB_SHADOW_INCLUDED

static const float3 SHADOW_DECODE = float3(0.99609375f, 0.00389099121f, 1.51991844e-005f);

float SampleShadowPCF_4x4(float2 uv, float depth)
{
    float4 row0, row1, row2, row3;

    float2 r00 = uv + float2(-0.000732421875f, -0.000732421875f);
    float2 r01 = uv + float2(-0.000244140625f, -0.000732421875f);
    row0.x = dot(t7.Sample(s7, r00).xyz, SHADOW_DECODE);
    row0.y = dot(t7.Sample(s7, r01).xyz, SHADOW_DECODE);
    float2 r02 = uv + float2(0.000244140625f, -0.000732421875f);
    float2 r03 = uv + float2(0.000732421875f, -0.000732421875f);
    row0.z = dot(t7.Sample(s7, r02).xyz, SHADOW_DECODE);
    row0.w = dot(t7.Sample(s7, r03).xyz, SHADOW_DECODE);

    float2 r10 = uv + float2(-0.000732421875f, -0.000244140625f);
    float2 r11 = uv + float2(-0.000244140625f, -0.000244140625f);
    row1.x = dot(t7.Sample(s7, r10).xyz, SHADOW_DECODE);
    row1.y = dot(t7.Sample(s7, r11).xyz, SHADOW_DECODE);
    float2 r12 = uv + float2(0.000244140625f, -0.000244140625f);
    float2 r13 = uv + float2(0.000732421875f, -0.000244140625f);
    row1.z = dot(t7.Sample(s7, r12).xyz, SHADOW_DECODE);
    row1.w = dot(t7.Sample(s7, r13).xyz, SHADOW_DECODE);

    float2 r20 = uv + float2(-0.000732421875f, 0.000244140625f);
    float2 r21 = uv + float2(-0.000244140625f, 0.000244140625f);
    row2.x = dot(t7.Sample(s7, r20).xyz, SHADOW_DECODE);
    row2.y = dot(t7.Sample(s7, r21).xyz, SHADOW_DECODE);
    float2 r22 = uv + float2(0.000244140625f, 0.000244140625f);
    float2 r23 = uv + float2(0.000732421875f, 0.000244140625f);
    row2.z = dot(t7.Sample(s7, r22).xyz, SHADOW_DECODE);
    row2.w = dot(t7.Sample(s7, r23).xyz, SHADOW_DECODE);

    float2 r30 = uv + float2(-0.000732421875f, 0.000732421875f);
    float2 r31 = uv + float2(-0.000244140625f, 0.000732421875f);
    row3.x = dot(t7.Sample(s7, r30).xyz, SHADOW_DECODE);
    row3.y = dot(t7.Sample(s7, r31).xyz, SHADOW_DECODE);
    float2 r32 = uv + float2(0.000244140625f, 0.000732421875f);
    float2 r33 = uv + float2(0.000732421875f, 0.000732421875f);
    row3.z = dot(t7.Sample(s7, r32).xyz, SHADOW_DECODE);
    row3.w = dot(t7.Sample(s7, r33).xyz, SHADOW_DECODE);

    row0 = (row0 < depth) ? 1.0f : 0.0f;
    row1 = (row1 < depth) ? 1.0f : 0.0f;
    row2 = (row2 < depth) ? 1.0f : 0.0f;
    row3 = (row3 < depth) ? 1.0f : 0.0f;

    return dot(row0 + row1 + row2 + row3, float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));
}

// Pre-phase: projection + PCF (before tangent frame)
// avgHeight is already scaled by (1/65535) but NOT by DL_FREG_126
float ComputeShadowPCF_Ncs(float3 worldPos, float avgHeight)
{
    float3 r1;
    r1.y = avgHeight * DL_FREG_126 * 0.25f + worldPos.y;
    r1.xz = worldPos.xz;
    float4 hpos = float4(r1.xyz, 1);

    float2 uv = float2(
        dot(hpos, DL_FREG_140._m00_m10_m20_m30),
        dot(hpos, DL_FREG_140._m01_m11_m21_m31)
    );
    float w = dot(hpos, DL_FREG_140._m03_m13_m23_m33);
    float depth = dot(hpos, DL_FREG_140._m02_m12_m22_m32);

    float4 clamp4 = DL_FREG_157.xyzw * w;
    float2 lowMask = (uv < clamp4.xy) ? 1.0f : 0.0f;
    uv -= lowMask * w;
    float2 highMask = (clamp4.zw < uv) ? 1.0f : 0.0f;
    uv += highMask * w;

    uv /= w;
    depth /= w;

    return SampleShadowPCF_4x4(uv, depth);
}

float ComputeShadowPCF_Csd(float3 worldPos, float avgHeight, float vertexDist)
{
    float4 r2, r4;

    r2.xyz = DL_FREG_123.yzw;
    r2.w = 65535.0f;
    r2 = (r2 >= vertexDist) ? 1.0f : 0.0f;
    r4 = (DL_FREG_123.xyzw < vertexDist) ? 1.0f : 0.0f;
    r2 = r4 * r2;

    float4 row3 = DL_FREG_144._m03_m13_m23_m33 * r2.yyyy;
    row3 = DL_FREG_140._m03_m13_m23_m33 * r2.xxxx + row3;
    row3 = DL_FREG_148._m03_m13_m23_m33 * r2.zzzz + row3;
    row3 = DL_FREG_152._m03_m13_m23_m33 * r2.wwww + row3;

    float4 row0 = DL_FREG_144._m00_m10_m20_m30 * r2.yyyy;
    row0 = DL_FREG_140._m00_m10_m20_m30 * r2.xxxx + row0;
    row0 = DL_FREG_148._m00_m10_m20_m30 * r2.zzzz + row0;
    row0 = DL_FREG_152._m00_m10_m20_m30 * r2.wwww + row0;

    float4 row1 = DL_FREG_144._m01_m11_m21_m31 * r2.yyyy;
    row1 = DL_FREG_140._m01_m11_m21_m31 * r2.xxxx + row1;
    row1 = DL_FREG_148._m01_m11_m21_m31 * r2.zzzz + row1;
    row1 = DL_FREG_152._m01_m11_m21_m31 * r2.wwww + row1;

    float4 row2 = DL_FREG_144._m02_m12_m22_m32 * r2.yyyy;
    row2 = DL_FREG_140._m02_m12_m22_m32 * r2.xxxx + row2;
    row2 = DL_FREG_148._m02_m12_m22_m32 * r2.zzzz + row2;
    row2 = DL_FREG_152._m02_m12_m22_m32 * r2.wwww + row2;

    float4 clampBlend = DL_FREG_158.xyzw * r2.yyyy;
    clampBlend = DL_FREG_157.xyzw * r2.xxxx + clampBlend;
    clampBlend = DL_FREG_159.xyzw * r2.zzzz + clampBlend;
    clampBlend = DL_FREG_160.xyzw * r2.wwww + clampBlend;

    float3 r1;
    r1.y = avgHeight * DL_FREG_126 * 0.25f + worldPos.y;
    r1.xz = worldPos.xz;
    float4 hpos = float4(r1.xyz, 1);

    float w = dot(hpos, row3);
    float2 uv = float2(dot(hpos, row0), dot(hpos, row1));
    float depth = dot(hpos, row2);

    float4 clamp4 = clampBlend * w;
    float2 lowMask = (uv < clamp4.xy) ? 1.0f : 0.0f;
    uv -= lowMask * w;
    float2 highMask = (clamp4.zw < uv) ? 1.0f : 0.0f;
    uv += highMask * w;

    uv /= w;
    depth /= w;

    return SampleShadowPCF_4x4(uv, depth);
}

// Post-phase: apply NdotL bias + shadow color modulation (after tangent frame)
float3 ApplyShadowPost(float rawShadowFactor, float3 normal, float distToCamera)
{
    float ndotl = dot(DL_FREG_175.xyz, normal);
    float bias = saturate(DL_FREG_121.w * (DL_FREG_121.x + ndotl));
    float shadowFactor = min(1, rawShadowFactor + bias);

    float fade = saturate(DL_FREG_121.z * (DL_FREG_121.y - distToCamera));
    float3 att = 1.0f - DL_FREG_122.xyz * fade * shadowFactor;
    att = pow(abs(att), DL_FREG_186.zzz);
    return att;
}

#endif
