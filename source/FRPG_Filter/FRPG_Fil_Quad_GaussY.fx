// FRPG_Fil_Quad_GaussY.fx
// Reconstructed from DSR DXBC (FRPG_Fil_Dof_GaussY.vpo).
// Vertex shader for vertical Gauss blur — outputs 4 pairs of UV offsets.
// Offsets: ±1.5, ±3.5, ±5.5, ±7.5 pixels vertically.
// cb0[12].y = screen height in pixels

#include "FRPG_Fil_Common.fxh"

struct VS_OUT
{
    float4 Pos : SV_Position;
    float4 UV1 : TEXCOORD1;  // xy=center UV, zw=0
    float4 UV2 : TEXCOORD2;  // xy=UV+(0,-1.5/H), zw=UV+(0,1.5/H)
    float4 UV3 : TEXCOORD3;  // xy=UV+(0,-3.5/H), zw=UV+(0,3.5/H)
    float4 UV4 : TEXCOORD4;  // xy=UV+(0,-5.5/H), zw=UV+(0,5.5/H)
    float4 UV5 : TEXCOORD5;  // xy=UV+(0,-7.5/H), zw=UV+(0,7.5/H)
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;

    float2 uv;
    uv.x = (float)(vertexID & 1u);
    uv.y = (float)(vertexID >> 1u);

    Out.Pos = float4(uv * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), 0.0f, 1.0f);
    Out.UV1 = float4(uv.x, uv.y, 0.0f, 0.0f);

    // div by screenHeight (matches ASM: div r0, l(0,-1.5,0,1.5), cb0[12].y)
    float4 off15 = float4(0.0f, -1.5f, 0.0f,  1.5f) / gFC_ScreenSize.y;
    float4 off35 = float4(0.0f, -3.5f, 0.0f,  3.5f) / gFC_ScreenSize.y;
    float4 off55 = float4(0.0f, -5.5f, 0.0f,  5.5f) / gFC_ScreenSize.y;
    float4 off75 = float4(0.0f, -7.5f, 0.0f,  7.5f) / gFC_ScreenSize.y;

    Out.UV2 = off15 + uv.xyxy;
    Out.UV3 = off35 + uv.xyxy;
    Out.UV4 = off55 + uv.xyxy;
    Out.UV5 = off75 + uv.xyxy;

    return Out;
}
