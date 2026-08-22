// FRPG_Fil_DepthCopy_MSAA_VS.fx
// Vertex shader for DepthCopy_MSAA.
// Original ASM:
//   mov o0.zw, l(0,0,0,1)
//   ushr r0.x, v0.x, l(1)
//   utof r0.y, r0.x
//   utof o1.yw, r0.xxxx    <- y and w from yBit
//   add r0.y, -r0.y, l(1)
//   and r0.w, v0.x, l(1)
//   utof r0.xz, r0.wwww    <- x and z from xBit
//   mad o0.xy, r0.xyxx, l(2,2,0,0), l(-1,-1,0,0)
//   mad o1.z, cb0[12].z, l(-1), r0.z
//   mov o1.x, r0.z

#include "FRPG_Fil_Common.fxh"

struct VS_OUT
{
    float4 Pos : SV_Position;
    float4 UV  : TEXCOORD0;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;
    Out.Pos.zw = float2(0.0f, 1.0f);

    uint yBit = vertexID >> 1u;
    float fy  = (float)yBit;
    // utof o1.yw, r0.xxxx -> UV.y = UV.w = fy
    Out.UV.y  = fy;
    Out.UV.w  = fy;
    float posY = 1.0f - fy;

    uint xBit = vertexID & 1u;
    // utof r0.xz, r0.wwww -> both x and z get the same float value from xBit
    float2 fxz2 = (float2)xBit;  // convert uint to float2 (both components same)
    float fx  = fxz2.x;
    float fxz = fxz2.y;  // same value
    Out.Pos.xy = float2(fx, posY) * 2.0f - 1.0f;

    // mad o1.z, cb0[12].z, l(-1), r0.z  -> o1.z = -cb0[12].z + fxz
// CLASS B (08/17): fxc 6.3.9600 folds ANY form (mul sep, mad(), [precise], -1.0f*1.0f)
// into `add r, fx, -cb0[12].z` — the l(-1) literal is never emitted (ref 3 vs our 2).
// Semantics identical, invisible in game. Do not chase.
    Out.UV.z = -gFC_ScreenSize.z + fxz;
    // mov o1.x, r0.z
    Out.UV.x = fxz;

    return Out;
}
