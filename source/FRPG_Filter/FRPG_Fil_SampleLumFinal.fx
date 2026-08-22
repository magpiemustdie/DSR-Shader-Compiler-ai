// FRPG_Fil_SampleLumFinal.fx
// Reconstructed from DSR DXBC.
// 4x4 = 16 fixed-UV samples of log-lum texture, average, then exp2.
// t0 = log-lum texture (s0)
// Output: exp2(sum * 0.090168) = geometric mean luminance

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_NOUV { float4 Pos : SV_Position; };
struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_NOUV In)
{
    FIL_OUT Out;

    static const float2 kUVs[16] =
    {
        float2(0.00f, 0.00f), float2(0.00f, 0.25f), float2(0.00f, 0.50f), float2(0.00f, 0.75f),
        float2(0.25f, 0.00f), float2(0.25f, 0.25f), float2(0.25f, 0.50f), float2(0.25f, 0.75f),
        float2(0.50f, 0.00f), float2(0.50f, 0.25f), float2(0.50f, 0.50f), float2(0.50f, 0.75f),
        float2(0.75f, 0.00f), float2(0.75f, 0.25f), float2(0.75f, 0.50f), float2(0.75f, 0.75f),
    };

    float acc = 0.0f;
    [unroll]
    for (int i = 0; i < 16; i++)
        acc += gSMP_0.Sample(gSMP_0Sampler, kUVs[i]).r;

    // SampleLumInitial writes ln(lum) = log2(lum)*ln(2)
    // SampleLumFinal computes exp(mean(ln(lum))) = geometric mean luminance
    // 0.090168 = ln(2)/16  →  exp2(sum * ln(2)/16) = exp(sum/16)
    Out.Color.xyz = exp2(acc * 0.0901684389f);
    Out.Color.w   = 1.0f;
    return Out;
}
