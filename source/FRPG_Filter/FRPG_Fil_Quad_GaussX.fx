// FRPG_Fil_Quad_GaussX.fx
// Reconstructed from DSR DXBC (FRPG_Fil_Dof_GaussX.vpo).
// Vertex shader for horizontal Gauss blur — outputs 4 pairs of UV offsets.
// Offsets: ±1.5, ±3.5, ±5.5, ±7.5 pixels horizontally.
// cb0[12].x = screen width in pixels

#include "FRPG_Fil_Common.fxh"

struct VS_OUT
{
    float4 Pos : SV_Position;
    float4 UV1 : TEXCOORD1;  // xy=center UV, zw=0
    float4 UV2 : TEXCOORD2;  // xy=UV+(-1.5/W,0), zw=UV+(1.5/W,0)
    float4 UV3 : TEXCOORD3;  // xy=UV+(-3.5/W,0), zw=UV+(3.5/W,0)
    float4 UV4 : TEXCOORD4;  // xy=UV+(-5.5/W,0), zw=UV+(5.5/W,0)
    float4 UV5 : TEXCOORD5;  // xy=UV+(-7.5/W,0), zw=UV+(7.5/W,0)
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;

    float2 uv;
    uv.x = (float)(vertexID & 1u);
    uv.y = (float)(vertexID >> 1u);

    Out.Pos = float4(uv * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), 0.0f, 1.0f);
    Out.UV1 = float4(uv.x, uv.y, 0.0f, 0.0f);

    // div by screenWidth (matches ASM: div r0, l(-1.5,0,1.5,0), cb0[12].x)
    float4 off15 = float4(-1.5f, 0.0f,  1.5f, 0.0f) / gFC_ScreenSize.x;
    float4 off35 = float4(-3.5f, 0.0f,  3.5f, 0.0f) / gFC_ScreenSize.x;
    float4 off55 = float4(-5.5f, 0.0f,  5.5f, 0.0f) / gFC_ScreenSize.x;
    float4 off75 = float4(-7.5f, 0.0f,  7.5f, 0.0f) / gFC_ScreenSize.x;

    Out.UV2 = off15 + uv.xyxy;
    Out.UV3 = off35 + uv.xyxy;
    Out.UV4 = off55 + uv.xyxy;
    Out.UV5 = off75 + uv.xyxy;

    return Out;
}
