// FRPG_Fil_DepthCopy_Fragment_VS.fx
// Vertex shader for DepthCopy_Fragment0 and Fragment1.
// Uses ICB with 6 positions, indexed by SV_VertexID.
// Original ASM:
//   dcl_immediateConstantBuffer { {1,1,0,0},{1,-1,0,0},{-1,-1,0,0},{-1,-1,0,0},{-1,1,0,0},{1,1,0,0} }
//   mov r0.x, v0.x
//   mov o0.xy, icb[r0.x+0].xyxx
//   mov o0.zw, l(0,0,0,1)

static const float2 kPositions[6] =
{
    float2( 1.0f,  1.0f),
    float2( 1.0f, -1.0f),
    float2(-1.0f, -1.0f),
    float2(-1.0f, -1.0f),
    float2(-1.0f,  1.0f),
    float2( 1.0f,  1.0f),
};

struct VS_OUT { float4 Pos : SV_Position; };

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;
    Out.Pos = float4(kPositions[vertexID], 0.0f, 1.0f);
    return Out;
}
