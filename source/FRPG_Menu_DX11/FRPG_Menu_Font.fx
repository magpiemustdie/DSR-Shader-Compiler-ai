float4x4 gVC_WorldViewClipMtx;
float4 gVC_FontSharpParam;
float4 gFC_FontSharpParam;

struct VS_INPUT
{
    float2 pos : POSITION0;
    float4 color : COLOR0;
    float2 uv : TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 VecPos : SV_Position;
    float4 Color : COLOR0;
    float2 Tex : TEXCOORD0;
};

VS_OUTPUT VSMain(VS_INPUT In)
{
    VS_OUTPUT Out;
    float2 p = In.pos - 0.5f;
    Out.VecPos = mul(float4(p, 0.0f, 1.0f), gVC_WorldViewClipMtx);
    Out.Color = In.color;
    Out.Tex = In.uv - 0.0009765625f;
    return Out;
}
