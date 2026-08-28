Texture2D<float4> t1 : register(t1);
Texture2D<float4> t2 : register(t2);
Texture2D<float4> t3 : register(t3);
Texture2D<float4> t4 : register(t4);
Texture2D<float4> t6 : register(t6);
TextureCubeArray<float4> t7 : register(t7);
TextureCubeArray<float4> t8 : register(t8);
Texture2D<float4> t9 : register(t9);

SamplerState s1 : register(s1);
SamplerState s2 : register(s2);
SamplerState s3 : register(s3);
SamplerState s4 : register(s4);
SamplerState s6 : register(s6);
SamplerState s7 : register(s7);
SamplerState s8 : register(s8);
SamplerState s9 : register(s9);

cbuffer Globals : register(b0)
{
    float4x4 gFC_InvViewClipMtx;
    float4 gFC_CameraPosition;
    float4 gFC_ScreenSize;
    float4 gFC_DebugMaterialParams1;
    uint4 gFC_LightFalloff;
    float4 gFC_ShadowMapParam;
    float4 gFC_ShadowColor;
    float4 gFC_ShadowStartDist;
    float4x4 gFC_ShadowMapMtxArray[4];
    float4 gFC_ShadowMapClamp[4];
    float4 gFC_ShadowLightDir;
    float4 gFC_LightProbeParam;
    float4 gFC_HemAmbCol_u;
    float4 gFC_HemAmbCol_d;
    float4 gFC_LightPointPos0;
    float4 gFC_LightPointIntensity0;
    float4 gFC_LightPointAtt;
    float4 gFC_FogParam;
    float4 gFC_FogCol;
}

struct VS_OUTPUT
{
    float4 VecPos : SV_Position;
    float2 TexDif : TEXCOORD1;
};

float2 OctWrap(float2 encN)
{
    float2 s = (encN >= 0.0f) ? 1.0f : -1.0f;
    return s * (1.0f - abs(encN.xyx)).yz;
}

float4 FragmentMain(VS_OUTPUT In) : SV_Target0
{
    float4 gBuf1 = t1.SampleLevel(s1, In.TexDif, 0.0f);
    float smoothness = gBuf1.z;

    float2 encN = mad(gBuf1.xy, 2.0f, -1.0f);

    float nz = (1.0f - abs(encN.x)) - abs(encN.y);
    float nzPos = (nz >= 0.0f);
    float2 n = nzPos ? encN.xy : OctWrap(encN);
    float3 normal = normalize(float3(n, nz));
    float nDotN = dot(normal, normal);

    float encodedDepth = t4.SampleLevel(s4, In.TexDif, 0.0f).x;

    float2 posNdcd = mad(In.TexDif, float2(2.0f, -2.0f), float2(-1.0f, 1.0f));
    float4 posC = mul(float4(posNdcd, encodedDepth, 1.0f), gFC_InvViewClipMtx);
    float4 pos = float4(posC.xyz, 1.0f) / posC.w;

    float3 V = gFC_CameraPosition.xyz - pos.xyz;
    float camDist = sqrt(dot(V, V));
    V = V / camDist;

    float4 zGreater = (gFC_ShadowStartDist < pos.w);
    // ref emits ftoi for the cascade slice (signed conversion)
    int slice = (int)(dot(zGreater, 1.0f) - 1.0f);

    // Whole vector-matrix mul: fxc folds this into 4x dp4 with direct dynamic
    // cbuffer operands (cb0[matIdx+11..14]); per-component dots materialize
    // each row via 4x mov first (+16 instr).
    float4 posLS = mul(float4(pos.xyz, 1.0f), gFC_ShadowMapMtxArray[slice]);

    float4 clamped = posLS.w * gFC_ShadowMapClamp[slice];
    float2 posClamped = posLS.xy;
    float2 under = (posClamped < clamped.xy);
    posClamped -= under * posLS.w;
    float2 over = (clamped.zw < posClamped);
    posClamped += over * posLS.w;

    float3 shadowUV = float3(posClamped, posLS.z) / posLS.w;

    float step = 0.000244140625f;
    float2 baseUV = shadowUV.xy;
    float shadDepth = shadowUV.z;

    float4 row1 = float4(
        t9.Sample(s9, baseUV + float2(-3.0f * step, -3.0f * step)).x,
        t9.Sample(s9, baseUV + float2(-1.0f * step, -3.0f * step)).x,
        t9.Sample(s9, baseUV + float2( 1.0f * step, -3.0f * step)).x,
        t9.Sample(s9, baseUV + float2( 3.0f * step, -3.0f * step)).x);

    float4 row2 = float4(
        t9.Sample(s9, baseUV + float2(-3.0f * step, -1.0f * step)).x,
        t9.Sample(s9, baseUV + float2(-1.0f * step, -1.0f * step)).x,
        t9.Sample(s9, baseUV + float2( 1.0f * step, -1.0f * step)).x,
        t9.Sample(s9, baseUV + float2( 3.0f * step, -1.0f * step)).x);

    float4 row3 = float4(
        t9.Sample(s9, baseUV + float2(-3.0f * step,  1.0f * step)).x,
        t9.Sample(s9, baseUV + float2(-1.0f * step,  1.0f * step)).x,
        t9.Sample(s9, baseUV + float2( 1.0f * step,  1.0f * step)).x,
        t9.Sample(s9, baseUV + float2( 3.0f * step,  1.0f * step)).x);

    float4 row4 = float4(
        t9.Sample(s9, baseUV + float2(-3.0f * step,  3.0f * step)).x,
        t9.Sample(s9, baseUV + float2(-1.0f * step,  3.0f * step)).x,
        t9.Sample(s9, baseUV + float2( 1.0f * step,  3.0f * step)).x,
        t9.Sample(s9, baseUV + float2( 3.0f * step,  3.0f * step)).x);

    if (nDotN == 0.0f)
    {
        float3 specDir = -V;
        float arrayIdx = gFC_LightProbeParam.z;
        float3 specLD = t8.SampleLevel(s8, float4(specDir, arrayIdx), -1e39f).xyz * gFC_LightProbeParam.y;
        return float4(exp(log(specLD) * 0.454499989748001f), 1.0f);
    }

    float3 albedo = t2.SampleLevel(s2, In.TexDif, 0.0f).xyz;
    float3 specColor = t3.SampleLevel(s3, In.TexDif, 0.0f).xyz;

    albedo = exp(log(albedo) * 2.200000047683716f);
    specColor = exp(log(specColor) * 2.200000047683716f);

    float NdotV_raw = dot(V, normal);
    float3 R = mad(2.0f * NdotV_raw, normal, -V);
    float NdotV = saturate(NdotV_raw);

    float F90 = min(dot(specColor, 0.330000013113022f) * 50.0f, 1.0f);

    float arrayIdx = gFC_LightProbeParam.z;
    float3 diffuseLD = t7.SampleLevel(s7, float4(normal, arrayIdx), 0.0f).xyz;

    float hemLerp = normal.y * 0.5f + 0.5f;
    float3 hemAmb = lerp(gFC_HemAmbCol_d.xyz, gFC_HemAmbCol_u.xyz, hemLerp);

    float3 diffuseLighting = gFC_LightProbeParam.x * diffuseLD + hemAmb;

    float roughness = saturate(1.0f - smoothness);
    float lerpFactor = roughness * (smoothness + sqrt(roughness));
    float3 specDir = lerp(normal, R, lerpFactor);

    NdotV = max(NdotV, 0.00390625f);
    float lastMip = gFC_LightProbeParam.w - 1.0f;
    float mip = 1.200000047683716f * log2(smoothness) + lastMip - 2.0f;

    float3 specLD = t8.SampleLevel(s8, float4(specDir, arrayIdx), mip).xyz * gFC_LightProbeParam.y;

    float2 dfg = t6.SampleLevel(s6, float2(smoothness, NdotV), 0.0f).xy;

    float3 specularIBL = (specColor * dfg.x + F90 * dfg.y) * specLD;

    float pcf = dot((float4)(row1 < shadDepth), 0.0625f)
              + dot((float4)(row2 < shadDepth), 0.0625f)
              + dot((float4)(row3 < shadDepth), 0.0625f)
              + dot((float4)(row4 < shadDepth), 0.0625f);

    float shadowDist = saturate(gFC_ShadowMapParam.z * gFC_ShadowMapParam.y);
    float3 shadowMul = shadowDist * gFC_ShadowColor.xyz;
    float3 radiosity = min(1.0f - shadowMul * pcf, 0.0f);

    float3 lighting = mad(albedo, diffuseLighting, specularIBL);
    float3 litColor = radiosity * lighting;

    float fogDist = pos.w - gFC_FogParam.x;
    float fog = saturate(fogDist * gFC_FogParam.y);
    fog = saturate(fog * gFC_FogCol.w);

    float3 fogBlend = gFC_FogCol.xyz - lighting * radiosity;
    float3 finalColor = mad(fog, fogBlend, litColor);

    return float4(finalColor, 1.0f);
}
