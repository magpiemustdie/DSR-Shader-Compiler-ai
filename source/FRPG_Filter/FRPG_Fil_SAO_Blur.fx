// FRPG_Fil_SAO_Blur.fx
// Reconstructed from DSR DXBC ps_5_0.
// SAO bilateral blur: 8-tap depth-aware blur of AO value (NO center tap!).
// AO in t0.x; depth encoded in t0.yz: depth = y*0.996109 + z*0.003891
// cb0[72].xy = blur step (pixel offset per tap, can be diagonal)
// cb0[12] = ScreenSize
//
// DXBC tap order (8 taps, symmetric -4..+4, no center):
//   tap0: step*(-4,-4)  weight=0.362970
//   tap1: step*(-3,-3)  weight=0.392902017
//   tap2: step*(-2,-2)  weight=0.422649026
//   tap3: step*(-1,-1)  weight=0.444893
//   tap4: step*(+1,+1)  weight=0.444893
//   tap5: step*(+2,+2)  weight=0.422649026
//   tap6: step*(+3,+3)  weight=0.392902017
//   tap7: step*(+4,+4)  weight=0.362970
// center weight = 0.153170
// Final: ao = aoAcc / (wTotal + 0.0001)
// Output: o0.x=ao, o0.yz=r1.yz (center depth channels), o0.w=1
//
// 08/17: fixed — previous reconstruction had 9 taps incl. a duplicate (+3,+3) making
// 0.422649 x6 vs ref x4. Depth weight: ref emits POSITIVE l(2000.0) with negate on |diff|
// (`mad rN.w, -|rN.w|, l(2000), l(1)`); form `-abs(d)*2000+1` emits l(-2000) — WRONG.

#include "FRPG_Fil_Common.fxh"

float4 gFC_SAOParam : register(c72); // xy:blur step

struct FIL_OUT { float4 Color : SV_Target0; };

float DecodeDepth_SAO(float2 enc)
{
    return dot(enc, float2(0.996108949f, 0.00389105058f));
}

float BilateralWeight(float centerDepth, float sDepth, float gaussW)
{
    float diff = 1.0f - abs(centerDepth - sDepth) * 2000.0f;
    return max(diff, 0.0f) * gaussW;
}

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    int2   iCoord = (int2)(In.UV * gFC_ScreenSize.xy);
    float2 pixPos = trunc(In.UV * gFC_ScreenSize.xy);

    // Center
    float3 center      = gSMP_0.Load(int3(iCoord, 0)).xyz;
    float  centerDepth = DecodeDepth_SAO(center.yz);

    // Early out if depth == 1
    if (centerDepth == 1.0f)
    {
        Out.Color = float4(center, 1.0f);
        return Out;
    }

    float aoAcc  = center.x * 0.153170f;
    float wTotal = 0.153170f;

    // Tap helper macro (inline)
    #define TAP(offset, gaussW) { \
        int2 sc = (int2)(pixPos + gFC_SAOParam.xy * (offset)); \
        float3 s = gSMP_0.Load(int3(sc, 0)).xyz; \
        float w = BilateralWeight(centerDepth, DecodeDepth_SAO(s.yz), gaussW); \
        aoAcc += s.x * w; wTotal += w; }

    // DXBC tap order exactly (8 taps, symmetric -4..+4):
    TAP(-4.0f, 0.362970f)  // tap0
    TAP(-3.0f, 0.392902017f)  // tap1
    TAP(-2.0f, 0.422649026f)  // tap2
    TAP(-1.0f, 0.444893f)  // tap3
    TAP(+1.0f, 0.444893f)  // tap4
    TAP(+2.0f, 0.422649026f)  // tap5
    TAP(+3.0f, 0.392902017f)  // tap6
    TAP(+4.0f, 0.362970f)  // tap7

    #undef TAP

    float ao = aoAcc / (wTotal + 0.0001f);

    // o0.yz = r1.yz = center.yz (depth channels)
    Out.Color = float4(ao, center.yz, 1.0f);
    return Out;
}
