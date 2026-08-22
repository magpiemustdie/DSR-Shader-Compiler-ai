// FRPG_Fil_Dof_GaussX.fx
// Reconstructed from DSR DXBC.
// DOF horizontal Gaussian blur (9-tap, symmetric pairs from vertex shader UVs).
// t0=source, UV offsets passed via v2..v5 (pairs of UVs per register)
// cb0[13..17] = Gauss weights (center, pair1, pair2, pair3, pair4)

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

FIL_OUT FragmentMain(FIL_IN_GAUSS In)
{
    FIL_OUT Out;

    // Center
    float4 c = gSMP_0.Sample(gSMP_0Sampler, In.UV) * gFC_GaussWeight0.x;

    // Pair 1 (nearest)
    float4 p1a = gSMP_0.Sample(gSMP_0Sampler, In.UV2.xy);
    float4 p1b = gSMP_0.Sample(gSMP_0Sampler, In.UV2.zw);
    c += (p1a + p1b) * gFC_GaussWeight1.x;

    // Pair 2
    float4 p2a = gSMP_0.Sample(gSMP_0Sampler, In.UV3.xy);
    float4 p2b = gSMP_0.Sample(gSMP_0Sampler, In.UV3.zw);
    c += (p2a + p2b) * gFC_GaussWeight2.x;

    // Pair 3
    float4 p3a = gSMP_0.Sample(gSMP_0Sampler, In.UV4.xy);
    float4 p3b = gSMP_0.Sample(gSMP_0Sampler, In.UV4.zw);
    c += (p3a + p3b) * gFC_GaussWeight3.x;

    // Pair 4 (outermost)
    float4 p4a = gSMP_0.Sample(gSMP_0Sampler, In.UV5.xy);
    float4 p4b = gSMP_0.Sample(gSMP_0Sampler, In.UV5.zw);
    c += (p4a + p4b) * gFC_GaussWeight4.x;

    Out.Color = c;
    return Out;
}
