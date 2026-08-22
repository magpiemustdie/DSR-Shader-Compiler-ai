// FRPG_Fil_Dof_VS.fx
// Reconstructed from DSR DX11 vs_5_0 DOF-family vertex shaders (6 unique binaries,
// 14 files total; pairs are byte-identical: Dof==Dof_CB, DofRate==DofRate_CB==DownSample
// ==NearRate==WeightedDownsample, GaussX==StretchAlphaX, GaussY==StretchAlphaY,
// Unfocus3x3==UnfocusNearRate3x3).
// Fullscreen quad from SV_VertexID; uv.y inverted only for SV_Position (raw uv in
// TEXCOORD outputs, ref: r1.zwzw).
// DOF_KIND selects the output layout:
//   0 Dof / Dof_CB:                    o1=(uv,uv), o2=(uv,0,0)
//   1 DofRate / _CB / DownSample /     o1.xy=uv
//     NearRate / WeightedDownsample
//   2 BlurUpSample:                    o1/o2 = uv +- 0.5 texel of cb0[12].zw, o3.xy=uv
//   3 GaussX / StretchAlphaX:          o2..o5 = uv +- N/width  (N=1.5/3.5/5.5/7.5)
//   4 GaussY / StretchAlphaY:          o2..o5 = uv +- N/height
//   5 Unfocus3x3 / UnfocusNearRate3x3: o1/o2 = uv +- cb0[12].zw*(1,0.28)/(0.28,-1), o3.xy=uv
// cb0[12] = gFC_ScreenSize (xy:size, zw:1/size).

#include "FRPG_Fil_Common.fxh"

struct VS_OUT
{
    float4 Pos : SV_Position;
    float4 UV1 : TEXCOORD0;
#if DOF_KIND == 0 || DOF_KIND == 2 || DOF_KIND == 5
    float4 UV2 : TEXCOORD1;
#endif
#if DOF_KIND == 0
    float4 UV3 : TEXCOORD2;
#endif
#if DOF_KIND == 2 || DOF_KIND == 5
    float2 UV3 : TEXCOORD2;
#endif
#if DOF_KIND == 3 || DOF_KIND == 4
    float4 UV2 : TEXCOORD1;
    float4 UV3 : TEXCOORD2;
    float4 UV4 : TEXCOORD3;
    float4 UV5 : TEXCOORD4;
#endif
};

VS_OUT VertexMain(uint vertexID : SV_VertexID)
{
    VS_OUT Out;

    uint  yBit = vertexID >> 1u;
    float fy   = (float)yBit;
    uint  xBit = vertexID & 1u;
    float fx   = (float)xBit;

    float2 raw = float2(fx, fy);            // r1.zw
    float2 uv  = float2(fx, 1.0f - fy);     // r1.xy: inverted y for clip space

    Out.Pos = float4(uv * 2.0f - 1.0f, 0.0f, 1.0f);

#if DOF_KIND == 0
    Out.UV1 = float4(raw, raw);
    Out.UV2 = float4(raw, 0.0f, 0.0f);
#elif DOF_KIND == 1
    Out.UV1 = float4(raw, 0.0f, 0.0f);
#elif DOF_KIND == 2
    Out.UV1 = float4(raw + gFC_ScreenSize.zw * float2(0.5f, 0.5f),
                     raw - gFC_ScreenSize.zw * float2(0.5f, 0.5f));
    Out.UV2 = float4(raw + gFC_ScreenSize.zw * float2(0.5f, -0.5f),
                     raw - gFC_ScreenSize.zw * float2(0.5f, -0.5f));
    Out.UV3 = raw;
#elif DOF_KIND == 3
    Out.UV1 = float4(raw, 0.0f, 0.0f);
    Out.UV2 = float4(-1.5f, 0.0f,  1.5f, 0.0f) / gFC_ScreenSize.x + raw.xyxy;
    Out.UV3 = float4(-3.5f, 0.0f,  3.5f, 0.0f) / gFC_ScreenSize.x + raw.xyxy;
    Out.UV4 = float4(-5.5f, 0.0f,  5.5f, 0.0f) / gFC_ScreenSize.x + raw.xyxy;
    Out.UV5 = float4(-7.5f, 0.0f,  7.5f, 0.0f) / gFC_ScreenSize.x + raw.xyxy;
#elif DOF_KIND == 4
    Out.UV1 = float4(raw, 0.0f, 0.0f);
    Out.UV2 = float4(0.0f, -1.5f, 0.0f,  1.5f) / gFC_ScreenSize.y + raw.xyxy;
    Out.UV3 = float4(0.0f, -3.5f, 0.0f,  3.5f) / gFC_ScreenSize.y + raw.xyxy;
    Out.UV4 = float4(0.0f, -5.5f, 0.0f,  5.5f) / gFC_ScreenSize.y + raw.xyxy;
    Out.UV5 = float4(0.0f, -7.5f, 0.0f,  7.5f) / gFC_ScreenSize.y + raw.xyxy;
#elif DOF_KIND == 5
    Out.UV1 = float4(raw + gFC_ScreenSize.zw * float2(1.0f, 0.28f),
                     raw - gFC_ScreenSize.zw * float2(1.0f, 0.28f));
    Out.UV2 = float4(raw + gFC_ScreenSize.zw * float2(0.28f, -1.0f),
                     raw - gFC_ScreenSize.zw * float2(0.28f, -1.0f));
    Out.UV3 = raw;
#endif

    return Out;
}