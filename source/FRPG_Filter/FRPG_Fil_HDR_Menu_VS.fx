// FRPG_Fil_HDR_Menu_VS.fx
// Vertex shader for HDR_Menu only (simple quad, no cbuffer reads).
// o1.xy = (fx, fy) with raw fy (no 1-fy inversion in UV).
// BYTE-REPRO NOTE (same as FRPG_Fil_Quad.fx): UV store goes AFTER Pos with
// IMPLICIT uint->float conversion -> direct `utof o1` output writes.

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

    Out.Pos = float4(float2((float)xBit, 1.0f - fy) * 2.0f - 1.0f, 0.0f, 1.0f);
    Out.UV  = float2(xBit, yBit);

    return Out;
}
