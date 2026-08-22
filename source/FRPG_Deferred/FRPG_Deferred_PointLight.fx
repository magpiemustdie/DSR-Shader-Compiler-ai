Texture2D<float4> t1 : register(t1);
Texture2D<float4> t2 : register(t2);
Texture2D<float4> t3 : register(t3);
Texture2D<float4> t4 : register(t4);

SamplerState s1 : register(s1);
SamplerState s2 : register(s2);
SamplerState s3 : register(s3);
SamplerState s4 : register(s4);

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
}

struct VS_OUTPUT
{
    float4 VecPos : SV_Position;
};

float3 Srgb2linear(float3 c)
{
    return exp(log(c) * 2.200000047683716f);
}

float calcSpecularF90(float3 specColor)
{
    return min(dot(specColor, 0.330000013113022f) * 50.0f, 1.0f);
}

void QlocAttenuation(float dist, float rangeRcp, float range, out float atten)
{
    float d = dist / range;
    float d2 = d * d;
    float denom = saturate(1.0f - d2 * d2);
    float denom2 = denom * denom;
    float expTerm = exp(log(dist) * rangeRcp);
    atten = denom2 / (expTerm + 1.0f);
}

void UnrealOffsetAttenuation(float dist, float rangeRcp, float range, out float atten)
{
    float falloffStart = range - rangeRcp;
    float distance = max(dist - falloffStart, 0.0f);
    float lightRadius = max(range - falloffStart, 0.0f);
    float d = distance / lightRadius;
    float d2 = d * d;
    float denom = saturate(1.0f - d2 * d2);
    float denom2 = denom * denom;
    float dist2 = distance * distance + 1.0f;
    atten = denom2 / dist2;
}

void PerceivedLinearAttenuation(float dist, float range, float rangeRcp, out float atten)
{
    float d = range - dist;
    float d_scaled = d * rangeRcp;
    atten = saturate(d_scaled * d_scaled * d_scaled);
}

void LinearAttenuation(float dist, float range, float rangeRcp, out float atten)
{
    float d = range - dist;
    atten = saturate(d * rangeRcp);
}

void BuggedLinearAttenuation(float dist, float start, float end, out float atten)
{
    float d = dist - start;
    float range = end - start;
    atten = saturate(1.0f - d / range);
}

float2 OctWrap(float2 encN)
{
    float2 s = (encN >= 0.0f) ? 1.0f : -1.0f;
    return s * (1.0f - abs(encN.xyx)).yz;
}

float4 FragmentMain(VS_OUTPUT In) : SV_Target0
{
    float2 screenUV = In.VecPos.xy * gFC_ScreenSize.xy;

    float4 gBuf1 = t1.SampleLevel(s1, screenUV, 0.0f);
    if (gBuf1.z == 0.0f) discard;

    float2 encN = mad(gBuf1.xy, 2.0f, -1.0f);

    float nz = (1.0f - abs(encN.x)) - abs(encN.y);
    float nzPos = (nz >= 0.0f);
    float2 n = nzPos ? encN.xy : OctWrap(encN);
    float3 normal = normalize(float3(n, nz));

    if (dot(normal, normal) == 0.0f)
        return float4(0.0f, 0.0f, 0.0f, 1.0f);

    float encodedDepth = t4.SampleLevel(s4, screenUV, 0.0f).x;

    float2 posNdcd = mad(screenUV, float2(2.0f, -2.0f), float2(-1.0f, 1.0f));
    float4 posC = mul(float4(posNdcd, encodedDepth, 1.0f), gFC_InvViewClipMtx);
    float3 pos = posC.xyz / posC.w;

    float3 L = gFC_LightPointPos0.xyz - pos;
    float distL = sqrt(dot(L, L));

    if (gFC_LightPointIntensity0.w < distL)
        return float4(0.0f, 0.0f, 0.0f, 1.0f);

    float4 gBuf2_samp = t2.SampleLevel(s2, screenUV, 0.0f).xywz;
    float3 albedo = Srgb2linear(gBuf2_samp.xyw);
    float4 gBuf3_samp = t3.SampleLevel(s3, screenUV, 0.0f).wxyz;
    float3 specColor = Srgb2linear(gBuf3_samp.yzw);
    float subsurfStrengthRaw = gBuf3_samp.x;

    uint isSubsurf = gBuf1.w > 0.0f;
    float3 sssParams = isSubsurf ? float3(1.0f, subsurfStrengthRaw * 10.0f, gBuf2_samp.z)
                                 : float3(subsurfStrengthRaw, 0.0f, 1.0f);
    float ao = sssParams.x;
    float subsurfStrength = sssParams.y;
    float subsurfOpacity = sssParams.z;

    float3 V = gFC_CameraPosition.xyz - pos;
    float invVLen = rsqrt(dot(V, V));
    float3 Vn = V * invVLen;

    float F90 = calcSpecularF90(specColor);

    float lampAtt;
    switch (gFC_LightFalloff.x)
    {
        case 1:
            QlocAttenuation(distL, gFC_LightPointPos0.w, gFC_LightPointIntensity0.w, lampAtt);
            break;
        case 2:
        {
            float rangeRcp = 1.0f / gFC_LightPointPos0.w;
            UnrealOffsetAttenuation(distL, rangeRcp, gFC_LightPointIntensity0.w, lampAtt);
            break;
        }
        case 3:
            PerceivedLinearAttenuation(distL, gFC_LightPointIntensity0.w, gFC_LightPointPos0.w, lampAtt);
            break;
        case 4:
            LinearAttenuation(distL, gFC_LightPointIntensity0.w, gFC_LightPointPos0.w, lampAtt);
            break;
        default:
            BuggedLinearAttenuation(distL, gFC_LightPointPos0.w, gFC_LightPointIntensity0.w, lampAtt);
            break;
    }

    float aoAdj = lerp(ao, 1.0f, gFC_LightPointAtt.w);
    lampAtt *= aoAdj;

    float invDistL = 1.0f / distL;
    float3 Ln = L * invDistL;

    float r = max(gBuf1.z, 0.014000000432134f);

    float3 Hn = normalize(Vn + Ln);
    float vdh = saturate(dot(Vn, Hn));
    float ndh = saturate(dot(normal, Hn));
    float ndl = saturate(dot(normal, Ln));
    float ndv = saturate(dot(normal, Vn));

    float sphg = exp2(vdh * mad(vdh, -5.554729938507080f, -6.983160018920898f));
    float3 F = mad(sphg, mad(-F90, specColor, F90), specColor);

    float alpha = r * r;
    float ndh2 = ndh * ndh;
    float denom = mad(ndh2, mad(alpha, alpha, -1.0f), 1.0f);
    float D = alpha / denom;
    D = D * D * 0.318309873342514f;

    float k = alpha * 0.5f;
    float G1_ndl = 1.0f / mad(ndl, 1.0f - k, k);
    float G1_ndv = 1.0f / mad(ndv, 1.0f - k, k);
    float Vis = G1_ndl * G1_ndv;

    float dv = D * Vis * 0.250000000000000f;
    float3 BRDF = F * dv;

    float3 contrib = mad(albedo.xyz, 0.318309873342514f, BRDF);
    contrib *= gFC_LightPointIntensity0.xyz;
    contrib *= lampAtt;
    contrib *= ndl;
    contrib *= 3.141592741012573f;

    if (subsurfStrength > 0.0f && isSubsurf)
    {
        float3 sssColor = albedo * gFC_LightPointIntensity0.xyz;
        sssColor *= lampAtt;

        float scale = 8.250000000000000f / (subsurfStrength * 0.012000000104308f);
        float d = scale * subsurfOpacity * subsurfOpacity;

        float dd = -d * d;
        float4 gauss = exp2(dd * float4(225.421096801757812f, 29.807748794555664f, 7.714946269989014f, 2.544435739517212f));

        float3 profile = gauss.y * float3(0.100000001490116f, 0.335999995470047f, 0.344000011682510f)
                       + gauss.x * float3(0.232999995350838f, 0.455000013113022f, 0.648999989032745f)
                       + gauss.z * float3(0.118000000715256f, 0.197999998927116f, 0.0f)
                       + gauss.w * float3(0.112999998033047f, 0.007000000216067f, 0.007000000216067f);

        float2 extra = exp2(dd * float2(0.724972426891327f, 0.194695696234703f));
        profile += extra.x * float3(0.358000010251999f, 0.004000000189990f, 0.0f);
        profile += extra.y * float3(0.078000001609325f, 0.0f, 0.0f);

        sssColor *= profile;

        float nlWrap = saturate(dot(Ln, -normal) + 0.300000011920929f);
        contrib += sssColor * nlWrap;
    }

    return float4(contrib, 1.0f);
}
