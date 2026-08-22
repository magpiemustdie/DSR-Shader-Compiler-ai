// FRPG_Fil_HDR_Menu_VS.fx
// Vertex shader for HDR_Menu only (simple quad, no cbuffer reads).
// Original ASM (FRPG_Fil_HDR_Menu.vpo):
//   ushr r0.x, v0.x, l(1)
//   utof o1.y, r0.x          <- direct output write
//   and r0.z, v0.x, l(1)
//   utof o1.x, r0.z          <- direct output write
//   mad o0.xy, r0.xyxx, l(2,2,0,0), l(-1,-1,0,0)
//   mov o0.zw, l(0,0,0,1)
// o1.xy = (fx, fy) with raw fy (no 1-fy inversion in UV).

#include "FRPG_Fil_Common.fxh"

struct VS_OUT
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD1;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;

    uint  yBit = vertexID >> 1u;
    float fy   = (float)yBit;
    uint  xBit = vertexID & 1u;
    float fx   = (float)xBit;

    Out.Pos = float4(float2(fx, 1.0f - fy) * 2.0f - 1.0f, 0.0f, 1.0f);
    Out.UV  = float2(fx, fy);

    return Out;
}