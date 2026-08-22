// FRPG_Fil_DepthCopy_SingleFragment_VS.fx
// Vertex shader for DepthCopy_SingleFragment.
// Uses ICB with 6 positions AND 6 UVs, indexed by SV_VertexID.
// Original ASM:
//   dcl_immediateConstantBuffer { {1,1,1,0},{1,-1,1,1},{-1,-1,0,1},{-1,-1,0,1},{-1,1,0,0},{1,1,1,0} }
//   mov o0.zw, l(0,0,0,1)
//   mov r0.x, v0.x
//   mov o0.xy, icb[r0.x+0].xyxx
//   mov o1.xy, icb[r0.x+0].zwzz

static const float4 kICB[6] =
{
    float4( 1.0f,  1.0f, 1.0f, 0.0f),
    float4( 1.0f, -1.0f, 1.0f, 1.0f),
    float4(-1.0f, -1.0f, 0.0f, 1.0f),
    float4(-1.0f, -1.0f, 0.0f, 1.0f),
    float4(-1.0f,  1.0f, 0.0f, 0.0f),
    float4( 1.0f,  1.0f, 1.0f, 0.0f),
};

struct VS_OUT
{
    float4 Pos : SV_Position;
    float2 UV  : Texcoord0;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;
    Out.Pos = float4(kICB[vertexID].xy, 0.0f, 1.0f);
    Out.UV  = kICB[vertexID].zw;
    return Out;
}
