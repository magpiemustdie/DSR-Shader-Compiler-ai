struct VS_OUTPUT
{
    float4 VecPos : SV_Position;
    float4 Color : COLOR0;
    float2 Tex : TEXCOORD0;
};

float4 FragmentMain(VS_OUTPUT In) : SV_Target0
{
    return In.Color;
}
