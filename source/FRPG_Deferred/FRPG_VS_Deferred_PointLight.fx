cbuffer Globals : register(b0)
{
    float4x4 gVC_WorldViewClipMtx;
}

void VSMain(float3 pos : POSITION0, out float4 o0 : SV_Position)
{
    o0 = mul(float4(pos, 1.0f), gVC_WorldViewClipMtx);
}