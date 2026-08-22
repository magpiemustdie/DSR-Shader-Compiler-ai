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
    float2 n = g_Texture.Sample(g_TextureSampler, In.TexDif.xy).xy * 2.0f - 1.0f;
    float d = 1.0f - dot(n, n);
    float3 nz = (d < 0.0f) ? float3(1.0f, 0.0f, 0.0f) : sqrt(d).xxx;
    return float4(nz, 1.0f);
}
