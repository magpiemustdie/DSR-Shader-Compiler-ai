// FRPG_Fil_Quad.fx
// Standard fullscreen quad vertex shader used by most filter passes.
// Generates a fullscreen triangle from SV_VertexID.
// Output: SV_Position + TEXCOORD0 (UV)
//
// Target ASM (FRPG_Fil_Bilateral.vpo original):
//   ushr r0.x, v0.x, l(1)
//   utof r0.y, r0.x
//   utof o1.y, r0.x        ← direct output write
//   add r0.y, -r0.y, l(1)
//   and r0.z, v0.x, l(1)
//   utof r0.x, r0.z
//   utof o1.x, r0.z        ← direct output write
//   mad o0.xy, r0.xyxx, l(2,2,0,0), l(-1,-1,0,0)
//   mov o0.zw, l(0,0,0,1)

struct VS_OUT
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD0;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;
    uint  yBit = vertexID >> 1u;
    float fy   = (float)yBit;
    float posY = 1.0f - fy;
    uint  xBit = vertexID & 1u;
    float fx   = (float)xBit;
    Out.UV   = float2(fx, fy);
    Out.Pos  = float4(float2(fx, posY) * 2.0f - 1.0f, 0.0f, 1.0f);
    return Out;
}
