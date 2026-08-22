// FRPG_Fil_HDR_VS.fx
// Vertex shader for HDR, HDR_ColAdj, HDR_PBL, HDR_PBL_ColAdj.
// Outputs TEXCOORD1 xyzw where zw = mad(UV.zw, cb0[68].xy, cb0[68].zw)
// Original ASM (HDR_PBL.vpo):
//   mov o0.zw, l(0,0,0,1)
//   ushr r0.x, v0.x, l(1)
//   utof r0.y, r0.x
//   utof r1.w, r0.x
//   add r1.y, -r0.y, l(1)
//   and r0.x, v0.x, l(1)
//   utof r1.xz, r0.xxxx
//   mad o0.xy, r1.xyxx, l(2,2,0,0), l(-1,-1,0,0)
//   mad o1.zw, r1.zzzw, cb0[68].xxxy, cb0[68].zzzw
//   mov o1.xy, r1.zwzz
//
// Note: cb0[68] = gVC_NoiseParam (at offset 1088 = 68*16)
// o1.xy = UV.xy (from r1.zw = (UV.x, UV.y))
// o1.zw = UV.zw * cb0[68].xy + cb0[68].zw  (noise UV transform)
// But r1.zw = (UV.x, UV.y) so o1.xy = (UV.x, UV.y) and o1.zw = UV.xy * cb0[68].xy + cb0[68].zw

// The cbuffer layout for VS uses a different register mapping.
// gVC_NoiseParam is at offset 1088 = 68*16 bytes = cb0[68]
// But in VS, the cbuffer is declared as CB0[69] (immediateIndexed)

cbuffer Globals : register(b0)
{
    float4x4 gVC_WorldViewClipMtx : packoffset(c0);   // offset 0
    float4   gVC_ScreenSize       : packoffset(c12);  // offset 192
    float4   gVC_NoiseParam       : packoffset(c68);  // offset 1088
};

struct VS_OUT
{
    float4 Pos : SV_Position;
    float4 UV  : TEXCOORD1;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;
    Out.Pos.zw = float2(0.0f, 1.0f);

    uint yBit = vertexID >> 1u;
    float fy  = (float)yBit;
    float r1w = fy;  // r1.w = utof(yBit)
    float posY = 1.0f - fy;

    uint xBit = vertexID & 1u;
    float fx  = (float)xBit;
    // r1.xz = utof(xBit) -> both x and z get fx
    float r1x = fx;
    float r1z = fx;

    Out.Pos.xy = float2(r1x, posY) * 2.0f - 1.0f;

    // mad o1.zw, r1.zzzw, cb0[68].xxxy, cb0[68].zzzw
    // r1.zzzw = (fx, fx, fx, fy), cb0[68].xxxy = (x,x,x,y), cb0[68].zzzw = (z,z,z,w)
    // o1.z = fx * NoiseParam.x + NoiseParam.z
    // o1.w = fy * NoiseParam.y + NoiseParam.w
    float2 uvZW = float2(r1z, r1w) * gVC_NoiseParam.xy + gVC_NoiseParam.zw;
    Out.UV.z = uvZW.x;
    Out.UV.w = uvZW.y;

    // mov o1.xy, r1.zwzz -> o1.x = r1.z = fx, o1.y = r1.w = fy
    Out.UV.x = r1z;
    Out.UV.y = r1w;

    return Out;
}
