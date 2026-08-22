float4x4 gVC_WorldViewClipMtx;
float4 gVC_FontSharpParam;
float4 gFC_FontSharpParam;

struct VS_INPUT
{
    int2 pos : POSITION0;
    float4 color : COLOR0;
    int2 uv : TEXCOORD0;
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
    float2 p = float2(In.pos) * 0.125f;
    Out.VecPos = mul(float4(p, 0.0f, 1.0f), gVC_WorldViewClipMtx);
    Out.Color = In.color;
    Out.Tex = float2(In.uv) * 0.000244140625f;
    return Out;
}
