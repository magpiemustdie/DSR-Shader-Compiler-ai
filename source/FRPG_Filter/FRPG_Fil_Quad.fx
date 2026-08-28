// FRPG_Fil_Quad.fx - Standard fullscreen quad vertex shader.
// BYTE-REPRO NOTE: the UV store must come AFTER the Pos computation and use
// IMPLICIT uint->float conversion (raw uints into float2). The conversion is
// then inserted at store time and emitted as direct `utof o1.y/o1.x` writes,
// NOT CSE-folded with the explicit casts used for Pos. Storing UV first (or
// with explicit casts) makes fxc sink everything into a trailing mov o1.xy.

struct VS_OUT
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD0;
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;
    uint  yBit = vertexID >> 1u;
    uint  xBit = vertexID & 1u;
    float fy   = (float)yBit;
    float posY = 1.0f - fy;
    float fx   = (float)xBit;
    Out.Pos = float4(float2(fx, posY) * 2.0f - 1.0f, 0.0f, 1.0f);
    Out.UV  = float2(xBit, yBit);
    return Out;
}
