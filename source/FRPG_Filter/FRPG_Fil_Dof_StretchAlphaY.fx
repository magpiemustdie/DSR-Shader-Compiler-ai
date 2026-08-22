// FRPG_Fil_Dof_StretchAlphaY.fx
// Reconstructed from DSR DXBC.
// DOF vertical alpha stretch: identical DXBC to StretchAlphaX (direction from VS).
// out.a = (maxA - center.a) * center.a + center.a
// Output: rgb=center.rgb, a=stretched alpha.

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_STRETCH
{
    float4 Pos : SV_Position;
    float2 UV1 : TEXCOORD0;
    float4 UV2 : TEXCOORD1;
    float4 UV3 : TEXCOORD2;
    float4 UV4 : TEXCOORD3;
    float4 UV5 : TEXCOORD4;
};

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_STRETCH In)
{
    FIL_OUT Out;

    float4 r0;
    r0.x = gSMP_0.Sample(gSMP_0Sampler, In.UV4.xy).w;
    r0.y = gSMP_0.Sample(gSMP_0Sampler, In.UV3.zw).w;
    r0.z = gSMP_0.Sample(gSMP_0Sampler, In.UV3.xy).w;
    r0.w = gSMP_0.Sample(gSMP_0Sampler, In.UV2.zw).w;

    float r1x = gSMP_0.Sample(gSMP_0Sampler, In.UV2.xy).w;
    float4 r2 = gSMP_0.Sample(gSMP_0Sampler, In.UV1.xy);

    r1x  = max(r1x,  r2.w);
    r0.w = max(r0.w, r1x);
    r0.z = max(r0.w, r0.z);
    r0.y = max(r0.z, r0.y);
    r0.x = max(r0.y, r0.x);

    r0.x = max(r0.x, gSMP_0.Sample(gSMP_0Sampler, In.UV4.zw).w);
    r0.x = max(r0.x, gSMP_0.Sample(gSMP_0Sampler, In.UV5.xy).w);
    r0.x = max(r0.x, gSMP_0.Sample(gSMP_0Sampler, In.UV5.zw).w);

    r0.x = r0.x - r2.w;
    r0.x = dot(r0.xx, r2.ww);
    Out.Color.w   = r0.x + r2.w;
    Out.Color.xyz = r2.xyz;
    return Out;
}
