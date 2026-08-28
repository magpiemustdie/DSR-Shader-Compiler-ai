// FRPG_Fil_Quad_Unfocus3x3.fx
// Reconstructed from DSR DXBC (FRPG_Fil_Dof_Unfocus3x3.vpo).
// BYTE-REPRO NOTES:
// 1. Lane-mapped temp (r.xz/r.w/r.y) reproduces the ref allocation where raw UV
//    lives in SEPARATE conversions from the Pos math (retail fxc cannot emit the
//    second utof - FromSoft's compiler converts per-use-site without CSE - so
//    the floor here is ~-3.4% SHEX, scheduler-only).
// 2. The +-offsets must be written as TWO float2 statements (xy positive,
//    zw as raw - cb*vec) so fxc emits four 2-lane mads with negate ON THE CBUFFER
//    operand, matching ref; a single float4 constructor folds signs into the
//    literal instead.

#include "FRPG_Fil_Common.fxh"

struct VS_OUT
{
    float4 Pos : SV_Position;
    float4 UV1 : TEXCOORD0;
    float4 UV2 : TEXCOORD1;
    float2 UV3 : TEXCOORD2;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;

    Out.Pos.zw = float2(0.0f, 1.0f);

    uint yBit = vertexID >> 1u;
    uint xBit = vertexID & 1u;

    float4 r;
    r.w  = yBit;
    r.y  = 1.0f - (float)yBit;
    r.xz = xBit;

    Out.Pos.xy = r.xy * 2.0f - 1.0f;

    float2 s = gFC_ScreenSize.zw;
    Out.UV1.xy = s * float2(1.0f, 0.28f)  + r.zw;
    Out.UV1.zw = r.zw - s * float2(1.0f, 0.28f);
    Out.UV2.xy = s * float2(0.28f, -1.0f) + r.zw;
    Out.UV2.zw = r.zw - s * float2(0.28f, -1.0f);
    Out.UV3    = r.zw;
    return Out;
}
