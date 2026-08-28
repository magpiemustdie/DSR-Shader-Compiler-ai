float4x4 gVC_WorldViewClipMtx       : register(c0);
float4x4 gFC_InvViewClipMtx         : register(c4);  // [unused]
float4   gFC_CameraPosition         : register(c8);  // [unused]
float4   gFC_ScreenSize             : register(c9);  // [unused]
float4   gFC_DebugMaterialParams1   : register(c10); // [unused]
uint4    gFC_LightFalloff           : register(c11); // [unused]
float4   gFC_FogParam               : register(c12); // [unused]
float4   gFC_FogCol                 : register(c13); // [unused]
float4   gFC_LightPointPos0         : register(c14); // [unused]
float4   gFC_LightPointIntensity0   : register(c15); // [unused]
float4   gFC_LightPointAtt          : register(c16); // [unused]

void VSMain(float3 pos : POSITION0, out float4 o0 : SV_Position)
{
    o0 = mul(float4(pos, 1.0f), gVC_WorldViewClipMtx);
}