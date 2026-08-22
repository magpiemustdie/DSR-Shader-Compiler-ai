// FRPG_Fil_HDR_Menu.fx
// Reconstructed from DSR DXBC ps_5_0.
// Filmic tonemapper for menu (Reinhard-like with shoulder).
// t0 = HDR scene (s0), NO cbuffer
// Input: TEXCOORD1 (index 1) - critical!
//
// Exact ASM (14 instructions):
//   sample t0 at v1.xy -> r0.xyzw
//   mad r1.xyz, r0.xyzx, l(0.1,0.1,0.1,0), l(0.03,0.03,0.03,0)
//   mad r1.xyz, r0.xyzx, r1.xyzx, l(0.005,0.005,0.005,0)
//   mad r2.xyz, r0.xyzx, l(0.1,0.1,0.1,0), l(0.3,0.3,0.3,0)
//   mad r0.xyz, r0.xyzx, r2.xyzx, l(0.075,0.075,0.075,0)
//   mov_sat r0.w, r0.w    <- saturate to TEMP first
//   mov o0.w, r0.w        <- then write to output
//   div r0.xyz, r1.xyzx, r0.xyzx
//   add r0.xyz, r0.xyzx, l(-0.066667,-0.066667,-0.066667,0)
//   mul_sat r0.xyz, r0.xyzx, l(1.875,1.875,1.875,0)
//   log r0.xyz, r0.xyzx
//   mul r0.xyz, r0.xyzx, l(0.454545,0.454545,0.454545,0)
//   exp o0.xyz, r0.xyzx

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_HDR_MENU
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD1;  // NOTE: index 1, not 0!
};

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_HDR_MENU In)
{
    FIL_OUT Out;

    float4 r0 = gSMP_0.Sample(gSMP_0Sampler, In.UV);

    // Filmic curve numerator: x*(0.1x+0.03)+0.005
    float3 r1 = r0.xyz * (0.1f * r0.xyz + 0.0300000012f) + 0.005f;

    // Filmic curve denominator: x*(0.1x+0.3)+0.075
    float3 r2 = 0.1f * r0.xyz + 0.3f;
    r0.xyz = r0.xyz * r2 + 0.075f;

    // Saturate alpha in-place, then write to output
    // This matches: mov_sat r0.w, r0.w; mov o0.w, r0.w
    // Must write to temp first, then to output — two separate instructions
    float alphaTemp = saturate(r0.w);
    r0.w = alphaTemp;
    Out.Color.w = r0.w;

    // Tone mapping
    r0.xyz = r1 / r0.xyz;
    r0.xyz = r0.xyz - 0.0666666627f;
    r0.xyz = saturate(r0.xyz * 1.87500012f);

    // Gamma 2.2: exp2(log2(x) * 0.454545)
    r0.xyz = log2(r0.xyz);
    r0.xyz = r0.xyz * (5.0f/11.0f);
    Out.Color.xyz = exp2(r0.xyz);

    return Out;
}
