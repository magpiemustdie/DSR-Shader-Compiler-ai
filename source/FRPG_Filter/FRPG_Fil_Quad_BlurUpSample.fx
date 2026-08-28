// FRPG_Fil_Quad_BlurUpSample.fx - VS for Dof_BlurUpSample
// 4 diagonal UV offsets (half-pixel) + center UV
// o1.xy=UV+(0.5,0.5)*texel  o1.zw=UV-(0.5,0.5)*texel
// o2.xy=UV+(0.5,-0.5)*texel o2.zw=UV-(0.5,-0.5)*texel
// o3.xy=UV center
// BYTE-REPRO NOTES (see FRPG_Fil_Quad_Unfocus3x3.fx): lane-mapped temp +
// subtraction written as `raw - cb*vec` so the negate lands on the CBUFFER
// operand (ref: `mad o1.zw, -cb0[12].zzzw, l(0,0,.5,.5), raw`), and separate
// float2 statements per output half.
#include "FRPG_Fil_Common.fxh"
struct VS_OUT { float4 Pos:SV_Position; float4 UV1:TEXCOORD0; float4 UV2:TEXCOORD1; float2 UV3:TEXCOORD2; };
VS_OUT VertexMain(uint vertexID : SV_VertexID) {
    VS_OUT Out;
    Out.Pos.zw = float2(0.0f, 1.0f);
    uint yBit = vertexID >> 1u;
    uint xBit = vertexID & 1u;
    float4 r1;
    r1.w  = yBit;
    r1.y  = 1.0f - (float)yBit;
    r1.xz = xBit;
    Out.Pos.xy = r1.xy * 2.0f - 1.0f;
    float2 s = gFC_ScreenSize.zw;
    Out.UV1.xy = s * float2(0.5f,  0.5f) + r1.zw;
    Out.UV1.zw = r1.zw - s * float2(0.5f,  0.5f);
    Out.UV2.xy = s * float2(0.5f, -0.5f) + r1.zw;
    Out.UV2.zw = r1.zw - s * float2(0.5f, -0.5f);
    Out.UV3    = r1.zw;
    return Out;
}
