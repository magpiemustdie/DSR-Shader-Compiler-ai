TextureCube<float4> g_CubeTexture : register(t0);
SamplerState g_CubeTextureSampler : register(s0);

struct VS_OUTPUT
{
    float4 VecPos : SV_Position;
    float4 Color : COLOR0;
    float3 TexDif : TEXCOORD0;
};

float4 FragmentMain(VS_OUTPUT In) : SV_Target0
{
    return g_CubeTexture.Sample(g_CubeTextureSampler, In.TexDif) * In.Color;
}
