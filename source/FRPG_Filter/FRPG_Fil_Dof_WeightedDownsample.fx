// FRPG_Fil_Dof_WeightedDownsample.fx
// Reconstructed from DSR DXBC.
// 5-sample weighted downsample using an icb (immediate constant buffer) with
// rotated grid offsets. Scale from cb0[12].zw (1/screenSize).
// icb offsets (from DXBC comments):
//   { 0.860, 0.500 }, { -0.500, 0.860 }, { -0.860, -0.500 },
//   { 0.500, -0.860 }, { 0, 0 }  (center)
// Weight = 1/5 = 0.2

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT
{
    float4 Color : SV_Target0;
};

// icb offsets (from DXBC — index 0 = center, 1..4 = rotated grid):
//   { 0, 0 }, { 0.860, 0.500 }, { -0.500, 0.860 },
//   { -0.860, -0.500 }, { 0.500, -0.860 }
static const float2 kOffsets[5] =
{
    float2( 0.0f,    0.0f),
    float2( 0.860f,  0.500f),
    float2(-0.500f,  0.860f),
    float2(-0.860f, -0.500f),
    float2( 0.500f, -0.860f),
};

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float4 acc = 0.0f;
    [loop]
    for (int i = 0; i < 5; i++)
    {
        float2 uv = kOffsets[i] * gFC_ScreenSize.zw + In.UV;
        acc += gSMP_0.SampleLevel(gSMP_0Sampler, uv, 0.0f);
    }
    acc *= 0.2f;
    Out.Color = max(acc, 0.0f);
    return Out;
}
