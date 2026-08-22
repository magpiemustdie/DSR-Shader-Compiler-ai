void VSMain(uint vid : SV_VertexID, out float4 o0 : SV_Position, out float2 o1 : TEXCOORD1)
{
    uint row = vid >> 1;
    uint col = vid & 1;
    o1.y = (float)row;
    o1.x = (float)col;
    o0 = float4(2.0f * float2((float)col, 1.0f - (float)row) - 1.0f, 0.0f, 1.0f);
}