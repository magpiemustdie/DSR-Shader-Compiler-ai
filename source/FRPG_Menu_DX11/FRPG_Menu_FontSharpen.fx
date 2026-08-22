Texture2D<float4> g_Texture : register(t0);
SamplerState g_TextureSampler : register(s0);

float4 gFC_FontSharpParam;
float4x4 gVC_WorldViewClipMtx;
float4 gVC_FontSharpParam;

struct VS_OUTPUT
{
    float4 VecPos : SV_Position;
    float4 Color : COLOR0;
    float2 Tex : TEXCOORD0;
    float4 TexOff1 : TEXCOORD1;
    float4 TexOff2 : TEXCOORD2;
};

float4 FragmentMain(VS_OUTPUT In) : SV_Target0
{
    float4 n = g_Texture.Sample(g_TextureSampler, In.TexOff1.xy);
    float4 c = g_Texture.Sample(g_TextureSampler, In.Tex);
    n = c * 5.0f - n;
    c = c * gFC_FontSharpParam.y;
    n -= g_Texture.Sample(g_TextureSampler, In.TexOff1.zw);
    n -= g_Texture.Sample(g_TextureSampler, In.TexOff2.xy);
    n -= g_Texture.Sample(g_TextureSampler, In.TexOff2.zw);
    n = n * gFC_FontSharpParam.x + c;
    return n * In.Color;
}
