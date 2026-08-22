float4x4 gVC_WorldViewClipMtx : register(c0);
row_major float3x4 gVC_LocalWorldMtx : register(c8);

struct VS_INPUT
{
    float3 VecPos : POSITION0;
    float2 TexDif : TEXCOORD0;
    float4 Color : COLOR0;
};

struct VS_OUTPUT
{
    float4 VecPos : SV_Position;
    float2 TexDif : TEXCOORD0;
    float4 Color : COLOR0;
};

VS_OUTPUT VSMain(VS_INPUT In)
{
    VS_OUTPUT Out;
    float4 pos = float4(In.VecPos, 1.0f);
    float4 worldPos = float4(
        dot(gVC_LocalWorldMtx[0], pos),
        dot(gVC_LocalWorldMtx[1], pos),
        dot(gVC_LocalWorldMtx[2], pos),
        1.0f);
    Out.VecPos = mul(worldPos, gVC_WorldViewClipMtx);
    Out.TexDif = In.TexDif;
    Out.Color = In.Color;
    return Out;
}