// FRPG_VS_Deferred_Quad.fx - fullscreen quad vertex shader (deferred light passes).
// BYTE-REPRO NOTE (same as FRPG_Fil_Quad.fx): UV store goes AFTER Pos with
// IMPLICIT uint->float conversion -> direct `utof o1` output writes, no CSE.

struct VS_OUT
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD1;
};

VS_OUT VSMain(uint vertexID : SV_VertexID)
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
