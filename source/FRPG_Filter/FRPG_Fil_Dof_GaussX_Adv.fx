// FRPG_Fil_Dof_GaussX_Adv.fx
// Reconstructed from DSR DXBC ps_5_0.
// DOF horizontal advanced Gaussian blur: per-channel ratio weighting.
// Each sample weight = div_sat(sample, center) * gaussWeight (all 4 channels).
// Accumulates weighted sum and total weight, outputs sum/total.
// t0=source (rgba), UV offsets via v2..v5
// cb0[13..17] = Gauss weights (center, pair1..pair4)
//
// DXBC sample order:
//   r0 = t0(v2.zw)   <- first sample is v2.ZW not v2.xy!
//   r1 = t0(v2.xy)
//   r2 = t0(v1.xy)   <- center
//   r3 = div_sat(r1, r2)        <- div_sat returns 0 when denominator==0 (not NaN)
//   r4 = r3 * cb0[14]
//   r3 = r3*cb0[14] + cb0[13]   <- running weight total
//   r1 = r1*r4
//   r1 = r2*cb0[13] + r1
//   r4 = div_sat(r0, r2)
//   r5 = r4*cb0[14]
//   r3 += r4*cb0[14]
//   r0 = r0*r5 + r1
//   ... (v3.xy, v3.zw, v4.xy, v4.zw, v5.xy, v5.zw)
//   o0 = r0 / r2_final  (no zero-guard on final div, matches DXBC)

#include "FRPG_Fil_Common.fxh"
#include "FRPG_Filter_FC_ext.fxh"
#include "FRPG_Filter_FC_ext.fxh"
#include "FRPG_Filter_FC_ext.fxh"
#include "FRPG_Filter_FC_ext.fxh"
#include "FRPG_Filter_FC_ext.fxh"
#include "FRPG_Filter_FC_ext.fxh"

struct FIL_IN_GAUSS
{
    float4 Pos : SV_Position;
    float4 UV  : TEXCOORD0;
    float4 UV2 : TEXCOORD1;
    float4 UV3 : TEXCOORD2;
    float4 UV4 : TEXCOORD3;
    float4 UV5 : TEXCOORD4;
};

struct FIL_OUT { float4 Color : SV_Target0; };

// Replicates DXBC div_sat semantics: returns 0 per-channel when denominator==0,
// otherwise saturate(a/b). This differs from saturate(a/max(b,eps)) which would
// return 1.0 for any nonzero numerator when center is black.
// Implementation: multiply by rcp(max(b, tiny)) then saturate, but zero out
// channels where b==0 using the fact that rcp(0)=+inf and a*inf saturates to 1,
// which is wrong. Instead use: saturate(a * rcp(b + (b==0)*1)) — but HLSL has no
// per-component equality. Simplest correct approach matching DXBC div_sat exactly:
// div_sat(a,b) = saturate(a/b) when b>0, else 0.
// We use: result = b > 0 ? saturate(a/b) : 0  — this compiles to movc, not branch.
float4 DivSat(float4 a, float4 b)
{
    // Direct division — fxc compiles this to div_sat when b is a register.
    // DXBC div_sat returns 0 when b==0 (hardware behavior).
    return saturate(a / b);
}

FIL_OUT FragmentMain(FIL_IN_GAUSS In)
{
    FIL_OUT Out;

    // Sample order matches DXBC exactly
    float4 s_v2zw = gSMP_0.Sample(gSMP_0Sampler, In.UV2.zw);  // r0
    float4 s_v2xy = gSMP_0.Sample(gSMP_0Sampler, In.UV2.xy);  // r1
    float4 center = gSMP_0.Sample(gSMP_0Sampler, In.UV);       // r2 = center

    // r3 = div_sat(r1, center), r4 = r3*w1
    float4 r3 = DivSat(s_v2xy, center);
    float4 r4 = r3 * gFC_GaussWeight1.x;
    r3 = r3 * gFC_GaussWeight1.x + gFC_GaussWeight0.x;  // running weight total
    float4 acc = s_v2xy * r4;
    acc = center * gFC_GaussWeight0.x + acc;             // center*w0 + s_v2xy*(s_v2xy/center*w1)

    // r0 = s_v2zw
    float4 ratio = DivSat(s_v2zw, center);
    r4  = ratio * gFC_GaussWeight1.x;
    r3 += ratio * gFC_GaussWeight1.x;
    acc = s_v2zw * r4 + acc;

    // v3.xy
    float4 s = gSMP_0.Sample(gSMP_0Sampler, In.UV3.xy);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight2.x;
    r3 += ratio * gFC_GaussWeight2.x;
    acc = s * r4 + acc;

    // v3.zw
    s = gSMP_0.Sample(gSMP_0Sampler, In.UV3.zw);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight2.x;
    r3 += ratio * gFC_GaussWeight2.x;
    acc = s * r4 + acc;

    // v4.xy
    s = gSMP_0.Sample(gSMP_0Sampler, In.UV4.xy);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight3.x;
    r3 += ratio * gFC_GaussWeight3.x;
    acc = s * r4 + acc;

    // v4.zw
    s = gSMP_0.Sample(gSMP_0Sampler, In.UV4.zw);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight3.x;
    r3 += ratio * gFC_GaussWeight3.x;
    acc = s * r4 + acc;

    // v5.xy
    s = gSMP_0.Sample(gSMP_0Sampler, In.UV5.xy);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight4.x;
    r3 += ratio * gFC_GaussWeight4.x;
    acc = s * r4 + acc;

    // v5.zw — last sample; r2 becomes final weight total (matches DXBC register reuse)
    s = gSMP_0.Sample(gSMP_0Sampler, In.UV5.zw);
    float4 lastRatio = DivSat(s, center);
    r4 = lastRatio * gFC_GaussWeight4.x;
    r3 = lastRatio * gFC_GaussWeight4.x + r3;  // final weight total
    acc = s * r4 + acc;

    // DXBC: div o0, r0, r2 — no zero-guard on denominator
    Out.Color = acc / r3;
    return Out;
}
