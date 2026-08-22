// FRPG_Deferred_DebugGBuffer — debug GBuffer viewer

cbuffer Globals : register(b0) {
    uint4 gFC_DebugShowGBuffer : packoffset(c80);
}

Texture2D g_tAlbedoRT  : register(t0);
SamplerState g_sAlbedo  : register(s0);
Texture2D g_tNormalRT  : register(t1);
SamplerState g_sNormal  : register(s1);
Texture2D g_tDepthRT   : register(t2);
SamplerState g_sDepth   : register(s2);

struct PS_INPUT {
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD1;
};

float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    float4 outColor;
    switch (gFC_DebugShowGBuffer.x) {
        case 1:
            outColor = g_tAlbedoRT.SampleLevel(g_sAlbedo, In.UV, 0);
            break;
        case 8: {
            float r = g_tDepthRT.SampleLevel(g_sDepth, In.UV, 0).r;
            outColor = float4(r, r, r, 1.0);
            break;
        }
        default:
            outColor = g_tNormalRT.SampleLevel(g_sNormal, In.UV, 0);
            break;
    }
    return outColor;
}
