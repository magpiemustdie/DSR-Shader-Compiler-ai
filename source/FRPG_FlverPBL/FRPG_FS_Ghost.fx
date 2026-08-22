// FRPG_FS_Ghost.fx - Ghost shader (FRPG_Ghost.fpo)

#define FC_REG(x) register(x)

Texture2D    gSMP_2        : register(t2);
SamplerState gSMP_2Sampler : register(s2);
Texture2D    gSMP_6        : register(t6);
SamplerState gSMP_6Sampler : register(s6);
Texture2D    gSMP_15       : register(t15);
SamplerState gSMP_15Sampler : register(s15);

float4 gFC_FogCol                : FC_REG(c12);
float4 gFC_LsBeta1PlusBeta2      : FC_REG(c13);
float4 gFC_LsTerrainReflectance  : FC_REG(c14);
float4 gFC_LsOneOverBeta1PlusBeta2 : FC_REG(c15);
float4 gFC_LsHGg                 : FC_REG(c16);
float4 gFC_LsBetaDash1           : FC_REG(c17);
float4 gFC_LsBetaDash2           : FC_REG(c18);
float4 gFC_LsSunColor            : FC_REG(c19);
float4 gFC_LsLightDir            : FC_REG(c20);
float4 gFC_GhostEdgeColor        : FC_REG(c36);
float4 gFC_GhostTexColor         : FC_REG(c37);
float4 gFC_ModelMulCol           : FC_REG(c39);
float4 gFC_DetailBumpParam       : FC_REG(c78);
float4 gFC_ToneCorrectParams     : FC_REG(c88);
float4 gFC_AdaptParam            : FC_REG(c89);
float4 gFC_InverseToneMapEnable  : FC_REG(c91);

struct PS_IN {
    float4 VtxClp  : SV_Position;
    float4 VtxWld  : TEXCOORD0;
    float4 VecNrm  : TEXCOORD2;   // xyz=normal, w=fog coefficient
    float4 VecEye  : TEXCOORD3;   // xyz=eye vector
    float4 VecTan  : TEXCOORD4;   // xyz=tangent, w=sign
    float4 ColVtx  : COLOR0;      // w=intensity
    float2 TexDif  : TEXCOORD6;   // diffuse UV
};

struct PS_OUT {
    float4 Color : SV_Target0;
};

PS_OUT FragmentMain(PS_IN In)
{
    float3 bump;
    bump.xy = gSMP_2.Sample(gSMP_2Sampler, In.TexDif).xy * 2.0f - 1.0f;
    bump.z = sqrt(1.0f - min(dot(bump.xy, bump.xy), 1.0f));

    float3 N = normalize(In.VecNrm.xyz);
    float3 T = normalize(In.VecTan.xyz);
    float3 B = normalize(cross(N, T) * In.VecTan.w);
    float3 worldNrm = normalize(N * bump.z + B * bump.x + T * bump.y);

    float3 B2 = normalize(cross(worldNrm, T) * In.VecTan.w);
    float3 T2 = normalize(cross(B2, worldNrm));

    float3 detail;
    detail.xy = gSMP_15.Sample(gSMP_15Sampler, In.TexDif * gFC_DetailBumpParam.xx).xy * 2.0f - 1.0f;
    float lenSq = dot(detail.xy, detail.xy);
    detail.xy *= gFC_DetailBumpParam.ww;
    float eps = (lenSq < 0.00001f) ? 1.0f : 0.0f;
    detail.z = sqrt(1.0f - min(lenSq, 1.0f)) + eps;
    detail = normalize(detail);

    float3 combinedNrm = normalize(worldNrm * detail.z + B2 * detail.x + T2 * detail.y);

    float3 V = normalize(In.VecEye.xyz);
    float viewLen = length(In.VecEye.xyz);

    float3 ghostColor = gFC_GhostTexColor.xyz * gFC_GhostTexColor.w;
    ghostColor *= gFC_ModelMulCol.xyz;
    float3 edgeColor = gFC_GhostEdgeColor.xyz * gFC_GhostEdgeColor.w;

    float NdotV = dot(combinedNrm, V);
    NdotV = clamp(abs(NdotV), 0.1f, 0.7f);
    float alphaBlend = (NdotV - 0.1f) * 1.666667f;
    float3 color = lerp(edgeColor, ghostColor * 2.0f, alphaBlend);

    float fogF = saturate(In.VecNrm.w);
    fogF = saturate(fogF * gFC_FogCol.w);
    color = lerp(color, gFC_FogCol.xyz, fogF);

    float3 fresnelSpec = exp2(viewLen * -gFC_LsBeta1PlusBeta2.xyz * gFC_LsLightDir.w * 2.081369f);
    float3 specFresnelColor = fresnelSpec * gFC_LsTerrainReflectance.xyz;

    float VdotFF = dot(V, gFC_LsLightDir.xyz);
    float G_denom = gFC_LsHGg.z * -VdotFF + gFC_LsHGg.y;
    float G_rsqrt = rsqrt(G_denom);
    float G = 1.0f / G_denom * G_rsqrt * gFC_LsHGg.x;
    float VdotFF_sq1 = VdotFF * VdotFF + 1.0f;

    float3 ggxTerm = G * gFC_LsBetaDash2.xyz + gFC_LsBetaDash1.xyz * VdotFF_sq1;
    ggxTerm *= (1.0f - fresnelSpec) * gFC_LsOneOverBeta1PlusBeta2.xyz * gFC_LsTerrainReflectance.w * gFC_LsSunColor.xyz;

    float3 specFinal = color * specFresnelColor + ggxTerm;
    color = lerp(color, specFinal, gFC_LsSunColor.w);

    float3 outCol = color * gFC_ToneCorrectParams.x;
    float outAlpha = In.ColVtx.w * gFC_ModelMulCol.w;
    float4 output = float4(outCol, outAlpha);

    if (gFC_InverseToneMapEnable.x != 0.0f) {
        float toneSample = gSMP_6.Sample(gSMP_6Sampler, float2(0.5f, 0.5f)).x;
        toneSample = max(toneSample, gFC_AdaptParam.z);
        toneSample = min(toneSample, gFC_AdaptParam.w);
        output.xyz = (output.xyz * gFC_AdaptParam.y) * (toneSample + 0.0001f) / gFC_AdaptParam.x;
    }

    PS_OUT Out;
    Out.Color = output;
    return Out;
}
