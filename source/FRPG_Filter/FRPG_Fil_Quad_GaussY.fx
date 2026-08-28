// FRPG_Fil_Quad_GaussY.fx
// Reconstructed from DSR DXBC (FRPG_Fil_Dof_GaussY.vpo / StretchAlphaY.vpo).
// Vertical 4-pair UV offsets: +/-1.5, +/-3.5, +/-5.5, +/-7.5 pixels.
// cb0[12].y = screen height.
// BYTE-REPRO NOTE: lane-mapped temp (see FRPG_Fil_Quad_Unfocus3x3.fx).

#include "FRPG_Fil_Common.fxh"

struct VS_OUT
{
    float4 Pos : SV_Position;
    float4 UV1 : TEXCOORD1;
    float4 UV2 : TEXCOORD2;
    float4 UV3 : TEXCOORD3;
    float4 UV4 : TEXCOORD4;
    float4 UV5 : TEXCOORD5;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;

    uint yBit = vertexID >> 1u;
    uint xBit = vertexID & 1u;

    float4 r;
    r.w  = yBit;
    r.y  = 1.0f - (float)yBit;
    r.xz = xBit;

    Out.Pos.zw = float2(0.0f, 1.0f);
    Out.Pos.xy = r.xy * 2.0f - 1.0f;
    Out.UV1    = float4(r.zw, 0.0f, 0.0f);

    float4 off15 = float4(0.0f, -1.5f, 0.0f,  1.5f) / gFC_ScreenSize.y;
    float4 off35 = float4(0.0f, -3.5f, 0.0f,  3.5f) / gFC_ScreenSize.y;
    float4 off55 = float4(0.0f, -5.5f, 0.0f,  5.5f) / gFC_ScreenSize.y;
    float4 off75 = float4(0.0f, -7.5f, 0.0f,  7.5f) / gFC_ScreenSize.y;

    Out.UV2 = off15 + r.zwzw;
    Out.UV3 = off35 + r.zwzw;
    Out.UV4 = off55 + r.zwzw;
    Out.UV5 = off75 + r.zwzw;
    return Out;
}
