Texture2D<float4> g_Texture : register(t0);
SamplerState g_TextureSampler : register(s0);

struct VS_OUTPUT
{
    float4 VecPos : SV_Position;
    float4 Color : COLOR0;
    float3 TexDif : TEXCOORD0;
};

float4 FragmentMain(VS_OUTPUT In) : SV_Target0
{
    return g_Texture.Sample(g_TextureSampler, In.TexDif.xy) * In.Color;
}
