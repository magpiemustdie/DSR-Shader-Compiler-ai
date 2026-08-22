// FRPG_Fil_BlackBars_VS.fx
// Vertex shader for BlackBars — takes POSITION input (not SV_VertexID).
// Original ASM:
//   dcl_input v0.xy
//   dcl_output_siv o0.xyzw, position
//   mov o0.xy, v0.xyxx
//   mov o0.zw, l(0,0,0,1)

struct VS_IN  { float2 Pos : POSITION; };
struct VS_OUT { float4 Pos : SV_POSITION; };

VS_OUT VertexMain(VS_IN In)
{
    VS_OUT Out;
    Out.Pos = float4(In.Pos, 0.0f, 1.0f);
    return Out;
}
