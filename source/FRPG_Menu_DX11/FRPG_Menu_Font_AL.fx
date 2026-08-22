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
    float4 TexOff1 : TEXCOORD1;
    float4 TexOff2 : TEXCOORD2;
};

VS_OUTPUT VSMain(VS_INPUT In)
{
    VS_OUTPUT Out;
    float2 p = floor(In.pos);
    Out.VecPos = mul(float4(p, 0.0f, 1.0f), gVC_WorldViewClipMtx);
    Out.Color = In.color;
    Out.Tex = In.uv - 0.0009765625f;
    float4 r1 = float4(-0.001953125f * gVC_FontSharpParam.z, -0.0009765625f, 0.001953125f * gVC_FontSharpParam.z, -0.0009765625f);
    float4 c4 = In.uv.xyxy + float4(0.0f, -0.0009765625f, 0.0f, -0.0009765625f);
    Out.TexOff1 = c4 + r1.wxwz;
    float4 c4b = In.uv.xyxy + float4(-0.0009765625f, 0.0f, -0.0009765625f, 0.0f);
    Out.TexOff2 = c4b + r1;
    return Out;
}
