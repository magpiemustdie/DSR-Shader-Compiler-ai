// FRPG_Deferred_DebugGBuffer — debug GBuffer viewer

float4x4 gFC_InvViewClipMtx       : register(c0);  // [unused]
float4   gFC_CameraPosition        : register(c4);  // [unused]
float4   gFC_ScreenSize            : register(c5);  // [unused]
float4   gFC_DebugMaterialParams1  : register(c6);  // [unused]
uint4    gFC_LightFalloff          : register(c7);  // [unused]
float4   gFC_FogParam              : register(c38); // [unused]
float4   gFC_FogCol                : register(c39); // [unused]
uint4    gFC_DebugShowGBuffer      : register(c80);
float4x4 gVC_WorldViewClipMtx      : register(c81); // [unused]

Texture2D    gSMP_0         : register(t0);
SamplerState gSMP_0Sampler  : register(s0);
Texture2D    gSMP_1         : register(t1);
SamplerState gSMP_1Sampler  : register(s1);
Texture2D    gSMP_2         : register(t2);
SamplerState gSMP_2Sampler  : register(s2);

struct PS_INPUT {
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD1;
};

float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    float4 outColor;
    switch (gFC_DebugShowGBuffer.x) {
        case 1:
            outColor = gSMP_0.SampleLevel(gSMP_0Sampler, In.UV, 0);
            break;
        case 8: {
            float r = gSMP_2.SampleLevel(gSMP_2Sampler, In.UV, 0).r;
            outColor = float4(r, r, r, 1.0);
            break;
        }
        default:
            outColor = gSMP_1.SampleLevel(gSMP_1Sampler, In.UV, 0);
            break;
    }
    return outColor;
}
