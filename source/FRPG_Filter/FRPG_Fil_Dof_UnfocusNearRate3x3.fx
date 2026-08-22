// FRPG_Fil_Dof_UnfocusNearRate3x3.fx
// Reconstructed from DSR DXBC.
// DOF near rate 3x3 max-filter: max of 5 taps (4 corners + center).
// Output: rgb=1, a=max near rate.
//
// DXBC sample mapping (v1=TEXCOORD0, v2=TEXCOORD1, v3=TEXCOORD2):
//   sample r0.x, v1.xy, t0.wxyz  -> r0.x = texture.w  (wxyz: first component = w)
//   sample r0.y, v1.zw, t0.xwyz  -> r0.y = texture.w  (xwyz: second component = w)
//   sample r0.z, v2.xy, t0.yzwx  -> r0.z = texture.w  (yzwx: third component = w)
//   sample r0.w, v2.zw, t0.yzxw  -> r0.w = texture.w  (yzxw: fourth component = w)
//   max r0.xy, r0.zw, r0.xy      -> r0.x=max(r0.z,r0.x), r0.y=max(r0.w,r0.y)
//   max r0.x, r0.y, r0.x         -> r0.x = max(r0.y, r0.x)
//   sample r0.y, v3.xy, t0.xwyz  -> r0.y = texture.w
//   max o0.w, r0.x, r0.y

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_NR
{
    float4 Pos : SV_Position;
    float4 UV1 : TEXCOORD0;  // v1: first two corner UVs (xy, zw) — read .w via wxyz/xwyz swizzle
    float4 UV2 : TEXCOORD1;  // v2: next two corner UVs (xy, zw) — read .w via yzwx/yzxw swizzle
    float2 UV3 : TEXCOORD2;  // v3: center UV
};

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_NR In)
{
    FIL_OUT Out;

    // All four corner samples read .w channel (different swizzles, same result)
    float r0x = gSMP_0.Sample(gSMP_0Sampler, In.UV1.xy).w;
    float r0y = gSMP_0.Sample(gSMP_0Sampler, In.UV1.zw).w;
    float r0z = gSMP_0.Sample(gSMP_0Sampler, In.UV2.xy).w;
    float r0w = gSMP_0.Sample(gSMP_0Sampler, In.UV2.zw).w;

    // max r0.xy, r0.zw, r0.xy -> r0.x=max(r0.z,r0.x), r0.y=max(r0.w,r0.y)
    float2 m = max(float2(r0z, r0w), float2(r0x, r0y));
    // max r0.x, r0.y, r0.x
    float mx = max(m.y, m.x);

    // Center sample
    float e = gSMP_0.Sample(gSMP_0Sampler, In.UV3.xy).w;
    float maxRate = max(mx, e);

    Out.Color = float4(1.0f, 1.0f, 1.0f, maxRate);
    return Out;
}
