// FRPG_Fil_Quad_BlurUpSample.fx - VS for Dof_BlurUpSample
// 4 diagonal UV offsets (half-pixel) + center UV
// o1.xy=UV+(0.5,0.5)*texel  o1.zw=UV+(-0.5,0.5)*texel
// o2.xy=UV+(0.5,-0.5)*texel o2.zw=UV+(-0.5,-0.5)*texel
// o3.xy=UV center
#include "FRPG_Fil_Common.fxh"
struct VS_OUT { float4 Pos:SV_Position; float4 UV1:TEXCOORD0; float4 UV2:TEXCOORD1; float2 UV3:TEXCOORD2; };
VS_OUT VertexMain(uint vertexID : SV_VertexID) {
    VS_OUT Out;
    Out.Pos.zw = float2(0,1);
    float4 r1;
    r1.w = (float)(vertexID >> 1u);
    r1.y = 1.0f - r1.w;
    r1.xz = (float)(vertexID & 1u);
    Out.Pos.xy = r1.xy * 2.0f - 1.0f;
    float2 uv = r1.zw;
    Out.UV1.xy = gFC_ScreenSize.zw * float2( 0.5f, 0.5f) + uv;
    Out.UV1.zw = -gFC_ScreenSize.zz * float2( 0.5f, 0.5f) + uv;
    Out.UV2.xy = gFC_ScreenSize.zw * float2( 0.5f,-0.5f) + uv;
    Out.UV2.zw = -gFC_ScreenSize.zz * float2( 0.5f,-0.5f) + uv;
    Out.UV3 = uv;
    return Out;
}
