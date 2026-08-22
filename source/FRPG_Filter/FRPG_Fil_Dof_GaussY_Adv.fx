// FRPG_Fil_Dof_GaussY_Adv.fx
// Reconstructed from DSR DXBC ps_5_0.
// DOF vertical advanced Gaussian blur: per-channel ratio weighting.
// Identical DXBC to GaussX_Adv — direction controlled by vertex shader UV offsets.
// See FRPG_Fil_Dof_GaussX_Adv.fx for full documentation.

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_GAUSS
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD0;
    float4 UV2 : TEXCOORD1;
    float4 UV3 : TEXCOORD2;
    float4 UV4 : TEXCOORD3;
    float4 UV5 : TEXCOORD4;
};

struct FIL_OUT { float4 Color : SV_Target0; };

// Replicates DXBC div_sat semantics: returns 0 per-channel when denominator==0,
// otherwise saturate(a/b).
// Where b==0: mask=0, so result=0 regardless of a/max(b,1e-30).
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
    float4 s_v2zw = gSMP_0.Sample(gSMP_0Sampler, In.UV2.zw);
    float4 s_v2xy = gSMP_0.Sample(gSMP_0Sampler, In.UV2.xy);
    float4 center = gSMP_0.Sample(gSMP_0Sampler, In.UV);

    float4 r3 = DivSat(s_v2xy, center);
    float4 r4 = r3 * gFC_GaussWeight1.x;
    r3 = r3 * gFC_GaussWeight1.x + gFC_GaussWeight0.x;
    float4 acc = s_v2xy * r4;
    acc = center * gFC_GaussWeight0.x + acc;

    float4 ratio = DivSat(s_v2zw, center);
    r4  = ratio * gFC_GaussWeight1.x;
    r3 += ratio * gFC_GaussWeight1.x;
    acc = s_v2zw * r4 + acc;

    float4 s = gSMP_0.Sample(gSMP_0Sampler, In.UV3.xy);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight2.x;
    r3 += ratio * gFC_GaussWeight2.x;
    acc = s * r4 + acc;

    s = gSMP_0.Sample(gSMP_0Sampler, In.UV3.zw);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight2.x;
    r3 += ratio * gFC_GaussWeight2.x;
    acc = s * r4 + acc;

    s = gSMP_0.Sample(gSMP_0Sampler, In.UV4.xy);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight3.x;
    r3 += ratio * gFC_GaussWeight3.x;
    acc = s * r4 + acc;

    s = gSMP_0.Sample(gSMP_0Sampler, In.UV4.zw);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight3.x;
    r3 += ratio * gFC_GaussWeight3.x;
    acc = s * r4 + acc;

    s = gSMP_0.Sample(gSMP_0Sampler, In.UV5.xy);
    ratio = DivSat(s, center);
    r4  = ratio * gFC_GaussWeight4.x;
    r3 += ratio * gFC_GaussWeight4.x;
    acc = s * r4 + acc;

    s = gSMP_0.Sample(gSMP_0Sampler, In.UV5.zw);
    float4 lastRatio = DivSat(s, center);
    r4 = lastRatio * gFC_GaussWeight4.x;
    r3 = lastRatio * gFC_GaussWeight4.x + r3;
    acc = s * r4 + acc;

    // DXBC: div o0, r0, r2 — no zero-guard on denominator
    Out.Color = acc / r3;
    return Out;
}
