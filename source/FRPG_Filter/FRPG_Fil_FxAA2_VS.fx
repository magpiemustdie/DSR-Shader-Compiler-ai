// FRPG_Fil_FxAA2_VS.fx
// Vertex shader for FxAA2 and FxAA2_High.
// Target ASM (dcl_temps 1):
//   mov o0.zw, l(0,0,0,1)
//   ushr r0.x, v0.x, l(1)
//   utof r0.y, r0.x
//   utof o1.yw, r0.xxxx      <- writes directly to output from uint r0.x
//   add r0.y, -r0.y, l(1)
//   and r0.w, v0.x, l(1)
//   utof r0.xz, r0.wwww
//   mad o0.xy, r0.xyxx, l(2,2,0,0), l(-1,-1,0,0)
//   mov r0.x, cb0[12].z
//   add o1.z, r0.x, r0.z
//   mov o1.x, r0.z

#include "FRPG_Fil_Common.fxh"

struct VS_OUT
{
    float4 Pos : SV_Position;
    float4 UV  : TEXCOORD1;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;
    float4 r0;

    Out.Pos.zw = float2(0.0f, 1.0f);

    uint yBit = vertexID >> 1u;
    r0.y = (float)yBit;
    // Write o1.y and o1.w directly from the uint (same as utof o1.yw, r0.xxxx)
    Out.UV.yw = (float2)yBit;
    r0.y = 1.0f - r0.y;

    uint xBit = vertexID & 1u;
    r0.xz = (float2)xBit;

    Out.Pos.xy = r0.xy * 2.0f - 1.0f;

    r0.x = gFC_ScreenSize.z;
    Out.UV.z = r0.x + r0.z;
    Out.UV.x = r0.z;

    return Out;
}
