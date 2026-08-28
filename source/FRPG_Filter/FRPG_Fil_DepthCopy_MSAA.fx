// FRPG_Fil_DepthCopy_MSAA.fx
// Reconstructed from DSR DXBC.
// MSAA depth copy: samples t0 at two UV positions (v1.xy and v1.zw),
// outputs min depth to SV_Depth, color = white.
// t0=MSAA depth texture

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_MSAA
{
    float4 Pos : SV_Position;
    float4 UV  : TEXCOORD0; // xy=UV0, zw=UV1
};

struct FIL_OUT
{
    float4 Color : SV_Target0;
    float  Depth : SV_Depth;
};

FIL_OUT FragmentMain(FIL_IN_MSAA In)
{
    FIL_OUT Out;

    float d0 = gSMP_0.Sample(gSMP_0Sampler, In.UV.xy).r;
    float d1 = gSMP_0.Sample(gSMP_0Sampler, In.UV.zw).r;

    Out.Color = float4(1.0f, 1.0f, 1.0f, 1.0f);
    Out.Depth = min(d0, d1);
    return Out;
}
