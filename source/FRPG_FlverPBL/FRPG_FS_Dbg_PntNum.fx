// Dbg PntNum — debug point light cluster visualization (5 variants)

// Defines: WITH_S, WITH_SS, WITH_SSS, WITH_SSSS
// Pnt:      —
// PntS:     S
// PntSS:    S + SS
// PntSSS:   S + SS + SSS
// PntSSSS:  S + SS + SSS + SSSS

//-----------------------------------------------------------------------------
// Input
//-----------------------------------------------------------------------------
struct PS_INPUT {
    float4 Pos : SV_Position;
    float4 T0  : TEXCOORD0;
};

//-----------------------------------------------------------------------------
// Constant buffer — offset depends on WITH_SS
//-----------------------------------------------------------------------------
cbuffer Globals : register(b0) {
#if defined(WITH_SS)
    float4 gFC_Extra   : packoffset(c115);
    float4 gFC_DbgScale : packoffset(c135);
#else
    float4 gFC_DbgScale : packoffset(c35);
#endif
}

cbuffer AlphaTestBuffer : register(b1) {
    int   AlphaTest;
    float3 AlphaTestRef;
}

//-----------------------------------------------------------------------------
// FragmentMain
//-----------------------------------------------------------------------------
float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    if (AlphaTest == 1 && AlphaTestRef.x >= 1.0) discard;

#if defined(WITH_SSSS)
    float3 color = (gFC_Extra.w > 0.0)
        ? float3(0.500000, 0.250000, 0.250000)
        : float3(0.500000, 0.500000, 0.250000);
#elif defined(WITH_SSS)
    float3 color = float3(0.500000, 0.500000, 0.250000);
#elif defined(WITH_SS)
    float3 color = float3(0.250000, 0.500000, 0.250000);
#elif defined(WITH_S)
    float3 color = float3(0.250000, 0.250000, 0.500000);
#else
    float3 color = float3(0.250000, 0.250000, 0.250000);
#endif

    color *= gFC_DbgScale.x;
    return float4(saturate(color / gFC_DbgScale.y), 1);
}
