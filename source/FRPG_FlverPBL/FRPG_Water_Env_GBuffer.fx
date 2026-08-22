// FRPG_Water_Env_GBuffer.fx — Water environment GBuffer (PntSS/PntSSSS) path
// Reconstructed from FRPG_Water_Env____PntSS.fpo / PntSSSS.fpo via 3DMigoto HLSL
// Uses DL_FREG cbuffer layout (cb0[196])
// PntSS = 2 fog volumes; PntSSSS (WITH_GBUFFER_4LIGHTS) = 4 fog volumes

float4 FragmentMain(
    float4 v0 : SV_Position0,
    float4 v1 : TEXCOORD0,
    float4 v2 : TEXCOORD1,
    float4 v3 : TEXCOORD2,
    float4 v4 : TEXCOORD3,
    float4 v5 : COLOR0,
    float4 v6 : TEXCOORD5,
    float4 v7 : TEXCOORD6,
    float4 v8 : TEXCOORD7,
    float4 v9 : TEXCOORD8,
    float4 v10 : TEXCOORD9
) : SV_Target0
{
    float4 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12;
    precise float avgHeight = 0;
    float3 fogBase = float3(1, 1, 1);
    float _shadowPCF = 0;

    r0.yz = float2(0.5f, 0.5f);
    r1.xy = v9.xy / v9.ww;
    r2.xy = float2(0.5f, -0.5f) * r1.xy;
    r2.zw = r1.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r1.xy = r1.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r3.xy = v10.xy / v10.ww;
    r1.zw = r3.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r4 = DL_FREG_164.xyxy * r1.xyzw;
    r4 = frac(r4);
    r5 = (float4(0.5f, 0.5f, 0.5f, 0.5f) < r4) ? float4(1,1,1,1) : float4(-1,-1,-1,-1);
    r4 = r4 + float4(-0.5f, -0.5f, -0.5f, -0.5f);
    r6 = DL_FREG_164.zzww * r5.zxyw;
    r0.xw = r6.yz;
    r0 = r2.zyxw + r0;
    r2 = t2.Sample(s2, r0.zw);
    r0 = t2.Sample(s2, r0.xy);
    r7 = r5 * DL_FREG_164.zwzw + r1;
    r4 = r5 * r4;
    r5 = t2.Sample(s2, r7.xy);
    r7 = t2.Sample(s2, r7.zw);
    r5 = r5 + -r2;
    r2 = r4.xxxx * r5 + r2;
    r5 = t2.Sample(s2, r1.xy);
    r0 = -r5 + r0;
    r0 = r4.xxxx * r0 + r5;
    r2 = r2 + -r0;
    r0 = r4.yyyy * r2 + r0;
    r0.x = dot(r0, float4(1044480, 65280, 4080, 255));
    avgHeight = r0.x * (1.0f / 65535.0f);
    r2.yz = float2(0, 0);
    r0.yz = v6.xy / v6.ww;
    r0.yz = r0.yz * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r5 = r0.yzyz * float4(2, 2, 2, 2) + -r1;
    r1 = t2.Sample(s2, r1.zw);
    r8 = DL_FREG_164.xyxy * r5;
    r8 = frac(r8);
    r9 = (float4(0.5f,0.5f,0.5f,0.5f) < r8) ? float4(1,1,1,1) : float4(-1,-1,-1,-1);
    r8 = r8 + float4(-0.5f,-0.5f,-0.5f,-0.5f);
    r10 = DL_FREG_164.zzww * r9.zxyw;
    r2.xw = r10.yz;
    r2 = r5.xyxy + r2;
    r11 = t2.Sample(s2, r2.zw);
    r2 = t2.Sample(s2, r2.xy);
    r12 = r9 * DL_FREG_164.zwzw + r5;
    r8 = r9 * r8;
    r9 = t2.Sample(s2, r12.xy);
    r12 = t2.Sample(s2, r12.zw);
    r9 = r9 + -r11;
    r9 = r8.xxxx * r9 + r11;
    r11 = t2.Sample(s2, r5.xy);
    r2 = -r11 + r2;
    r2 = r8.xxxx * r2 + r11;
    r9 = r9 + -r2;
    r2 = r8.yyyy * r9 + r2;
    r0.w = dot(r2, float4(1044480, 65280, 4080, 255));
    avgHeight += r0.w * (1.0f / 65535.0f);
    r0.w = r0.w * (1.0f / 65535.0f);
    r0.x = r0.x * (1.0f / 65535.0f) + -r0.w;

    r0.w = v7.y + v7.y;
    r2.x = r0.x * DL_FREG_126 + r0.w;
    r2.yz = float2(2, 2) * v7.zx;
    r0.x = dot(r2.xyz, r2.xyz);
    r0.x = rsqrt(r0.x);
    r2.xyz = r2.xyz * r0.xxx;
    r9.xy = float2(0.5f, -0.5f) * r3.xy;
    r9.zw = r3.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r6.yz = float2(0.5f, 0.5f);
    r3 = r9.zyxw + r6;
    r6 = t2.Sample(s2, r3.xy);
    r3 = t2.Sample(s2, r3.zw);
    r6 = r6 + -r1;
    r1 = r4.zzzz * r6 + r1;
    r6 = r7 + -r3;
    r3 = r4.zzzz * r6 + r3;
    r3 = r3 + -r1;
    r1 = r4.wwww * r3 + r1;
    r0.x = dot(r1, float4(1044480, 65280, 4080, 255));
    avgHeight += r0.x;
    r10.yz = float2(0, 0);
    r1 = r10 + r5.zwzw;
    r3 = t2.Sample(s2, r5.zw);
    r4 = t2.Sample(s2, r1.zw);
    r1 = t2.Sample(s2, r1.xy);
    r1 = r1 + -r3;
    r1 = r8.zzzz * r1 + r3;
    r3 = r12 + -r4;
    r3 = r8.zzzz * r3 + r4;
    r3 = r3 + -r1;
    r1 = r8.wwww * r3 + r1;
    r0.w = dot(r1, float4(1044480, 65280, 4080, 255));
    avgHeight += r0.w;
    r0.w = r0.w * (1.0f / 65535.0f);
    r0.x = r0.x * (1.0f / 65535.0f) + -r0.w;

#if defined(WITH_ShadowMap)
    {
        avgHeight = avgHeight * DL_FREG_126;
        if (WITH_ShadowMap == 2)
            _shadowPCF = ComputeShadowPCF_Csd(v1.xyz, avgHeight, v1.w);
        else
            _shadowPCF = ComputeShadowPCF_Ncs(v1.xyz, avgHeight);
    }
#endif

    r0.w = v8.y + v8.y;
    r1.z = r0.x * DL_FREG_126 + r0.w;
    r1.xy = float2(2, 2) * v8.zx;
    r0.x = dot(r1.xyz, r1.xyz);
    r0.x = rsqrt(r0.x);
    r1.xyz = r1.xyz * r0.xxx;
    r3.xyz = r1.xyz * r2.xyz;
    r1.xyz = r1.zxy * r2.yzx + -r3.xyz;

    r2 = DL_FREG_125 * r1.xzxz;
    r0.xw = r2.zw * v5.ww + r0.yz;
    r2 = v5.wwww * r2;
    r2 = r2 * float4(1.03f, 1.03f, 1.06f, 1.06f) + r0.yzyz;

    r3.xyz = t1.Sample(s1, r0.yz).xyz;
    r0.xw = t1.Sample(s1, r0.xw).xw;
    r4.x = r0.w;
    r4.yz = t1.Sample(s1, r2.xy).wy;
    r0.zw = t1.Sample(s1, r2.zw).zw;
    r0.y = r4.z;
    r4.z = r0.w;
    r0.xyz = r0.xyz + -r3.xyz;
    r2.xyz = (r4.xyz == float3(1, 1, 1)) ? 0 : float3(1, 1, 1);
    r0.xyz = r2.xyz * r0.xyz + r3.xyz;

#if defined(WITH_ShadowMap)
    {
        float camDist = length(v3.xyz);
        fogBase = ApplyShadowPost(_shadowPCF, r1.xyz, camDist);
    }
#endif

    // Fog light volume 0
    r2.xyz = DL_FREG_112.xyz + -v1.xyz;
    r0.w = dot(r2.xyz, r2.xyz);
    r0.w = sqrt(r0.w);
    r2.xyz = r2.xyz / r0.www;
    r0.w = DL_FREG_116.w + -r0.w;
    r0.w = saturate(DL_FREG_112.w * r0.w);
    r3.xyz = DL_FREG_116.xyz * r0.www;
    r0.w = dot(r2.xyz, r1.xyz);
    r0.w = max(0, r0.w);
    r4.xyz = r3.xyz * r0.www + fogBase;

    // Fog light volume 1
    r5.xyz = DL_FREG_113.xyz + -v1.xyz;
    r0.w = dot(r5.xyz, r5.xyz);
    r0.w = sqrt(r0.w);
    r5.xyz = r5.xyz / r0.www;
    r0.w = DL_FREG_117.w + -r0.w;
    r0.w = saturate(DL_FREG_113.w * r0.w);
    r6.xyz = DL_FREG_117.xyz * r0.www;
    r0.w = dot(r5.xyz, r1.xyz);
    r0.w = max(0, r0.w);
    r4.xyz = r6.xyz * r0.www + r4.xyz;

#if defined(WITH_GBUFFER_4LIGHTS)
    // Fog light volume 2 (SSSS only)
    r7.xyz = DL_FREG_114.xyz + -v1.xyz;
    r0.w = dot(r7.xyz, r7.xyz);
    r0.w = sqrt(r0.w);
    r7.xyz = r7.xyz / r0.www;
    r0.w = DL_FREG_118.w + -r0.w;
    r0.w = saturate(DL_FREG_114.w * r0.w);
    r8.xyz = DL_FREG_118.xyz * r0.www;
    r0.w = dot(r7.xyz, r1.xyz);
    r0.w = max(0, r0.w);
    r4.xyz = r8.xyz * r0.www + r4.xyz;

    // Fog light volume 3 (SSSS only)
    r9.xyz = DL_FREG_115.xyz + -v1.xyz;
    r0.w = dot(r9.xyz, r9.xyz);
    r0.w = sqrt(r0.w);
    r9.xyz = r9.xyz / r0.www;
    r0.w = DL_FREG_119.w + -r0.w;
    r0.w = saturate(DL_FREG_115.w * r0.w);
    r10.xyz = DL_FREG_119.xyz * r0.www;
    r0.w = dot(r9.xyz, r1.xyz);
    r0.w = max(0, r0.w);
    r4.xyz = r10.xyz * r0.www + r4.xyz;
#endif

    r7.xyz = log2(DL_FREG_127.xyz);
    r7.xyz = float3(2.2f, 2.2f, 2.2f) * r7.xyz;
    r7.xyz = exp2(r7.xyz);
    r4.xyz = r7.xyz * r4.xyz + -r0.xyz;
    r0.w = DL_FREG_127.w * v5.w;
    r0.xyz = r0.www * r4.xyz + r0.xyz;

    r0.w = length(v3.xyz);
    r4.xyz = v3.xyz / r0.www;
    r7.xyz = -DL_FREG_104.xyz * r0.www;
    r7.xyz = DL_FREG_111.www * r7.xyz;
    r7.xyz = float3(2.081369f, 2.081369f, 2.081369f) * r7.xyz;
    r7.xyz = exp2(r7.xyz);
    r0.w = dot(r1.xyz, r4.xyz);
    r1.w = r0.w + r0.w;
    r0.w = max(0, r0.w);
    r0.w = 1 + -r0.w;
    r0.w = max(0, r0.w);
    r0.w = log2(r0.w);
    r0.w = DL_FREG_129 * r0.w;
    r0.w = exp2(r0.w);
    r1.xyz = r1.www * r1.xyz + -r4.xyz;
    r1.w = dot(r4.xyz, DL_FREG_111.xyz);

    // Accumulate specular from fog volumes + directional light
    r2.x = dot(r1.xyz, r2.xyz);
    r2.x = max(0, r2.x);
    r2.x = log2(r2.x);
    r2.x = DL_FREG_102.x * r2.x;
    r2.x = exp2(r2.x);
    r2.xyz = r3.xyz * r2.xxx;

    r2.w = dot(r1.xyz, DL_FREG_088.xyz);
    r2.w = max(0, -r2.w);
    r2.w = log2(r2.w);
    r2.w = DL_FREG_102.x * r2.w;
    r2.w = exp2(r2.w);
    r2.xyz = DL_FREG_089.xyz * r2.www + r2.xyz;

    r2.w = dot(r1.xyz, r5.xyz);
    r1.xyz = t12.Sample(s12, r1.xyz).xyz;
    r2.w = max(0, r2.w);
    r2.w = log2(r2.w);
    r2.w = DL_FREG_102.x * r2.w;
    r2.w = exp2(r2.w);
    r2.xyz = r6.xyz * r2.www + r2.xyz;

#if defined(WITH_GBUFFER_4LIGHTS)
    r2.w = dot(r1.xyz, r7.xyz);
    r2.w = max(0, r2.w);
    r2.w = log2(r2.w);
    r2.w = DL_FREG_102.x * r2.w;
    r2.w = exp2(r2.w);
    r2.xyz = r8.xyz * r2.www + r2.xyz;

    r2.w = dot(r1.xyz, r9.xyz);
    r2.w = max(0, r2.w);
    r2.w = log2(r2.w);
    r2.w = DL_FREG_102.x * r2.w;
    r2.w = exp2(r2.w);
    r2.xyz = r10.xyz * r2.www + r2.xyz;
#endif

    r3.xyz = log2(DL_FREG_132.xyz);
    r3.xyz = float3(2.2f, 2.2f, 2.2f) * r3.xyz;
    r3.xyz = exp2(r3.xyz);
    r1.xyz = r1.xyz * r3.xyz + r2.xyz;
    r1.xyz = r1.xyz + -r0.xyz;
    r2.x = 1 + -r0.w;
    r0.w = DL_FREG_130 * r2.x + r0.w;
    r0.w = DL_FREG_131 * r0.w;
    r1.xyz = r0.www * r1.xyz + r0.xyz;
    r2.xyz = v5.xyz * r1.xyz;
    r1.xyz = -r1.xyz * v5.xyz + DL_FREG_103.xyz;
    r0.w = saturate(v2.w);
    r0.w = saturate(DL_FREG_103.w * r0.w);
    r1.xyz = r0.www * r1.xyz + r2.xyz;
    r2.xyz = log2(abs(r1.xyz));
    r2.xyz = float3(5.0f / 11.0f, 5.0f / 11.0f, 5.0f / 11.0f) * r2.xyz;
    r2.xyz = exp2(r2.xyz);
    r0.w = (0.5f < DL_FREG_195.x) ? 1 : 0;
    r1.xyz = r0.www ? r2.xyz : r1.xyz;
    r2.x = DL_FREG_107.z * -r1.w + DL_FREG_107.y;
    r1.w = r1.w * r1.w + 1;
    r2.y = rsqrt(r2.x);
    r2.x = 1 / r2.x;
    r2.x = r2.y * r2.x;
    r2.x = DL_FREG_107.x * r2.x;
    r2.xyz = DL_FREG_109.xyz * r2.xxx;
    r2.xyz = DL_FREG_108.xyz * r1.www + r2.xyz;
    r3.xyz = float3(1, 1, 1) + -r7.xyz;
    r4.xyz = DL_FREG_105.xyz * r7.xyz;
    r2.xyz = r3.xyz * r2.xyz;
    r2.xyz = DL_FREG_106.xyz * r2.xyz;
    r2.xyz = DL_FREG_105.www * r2.xyz;
    r2.xyz = DL_FREG_110.xyz * r2.xyz;
    r2.xyz = r1.xyz * r4.xyz + r2.xyz;
    r2.xyz = r2.xyz + -r1.xyz;
    r1.xyz = DL_FREG_110.www * r2.xyz + r1.xyz;
    r2.xyz = log2(abs(r1.xyz));
    r2.xyz = float3(2.2f, 2.2f, 2.2f) * r2.xyz;
    r2.xyz = exp2(r2.xyz);
    r1.xyz = r0.www ? r2.xyz : r1.xyz;
    r1.xyz = r1.xyz + -r0.xyz;
    r0.w = min(DL_FREG_128.x, v5.w);
    r0.w = DL_FREG_128.y * r0.w;
    r0.xyz = r0.www * r1.xyz + r0.xyz;
    return float4(r0.xyz, 1.0f);
}
