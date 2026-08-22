// FRPG_Fil_Bilateral.fx
// Reconstructed from DSR DXBC ps_5_0.
// Bilateral filter: 4-tap depth-weighted blur.
// t0=color(s0), t1=depth(s1), t2=reference(s2)
// cb0[12]=ScreenSize (xy:size, zw:1/size)
//
// Exact ASM (41 instructions):
//   mul r0.xy, v1.xyxx, cb0[12].xyxx
//   frc r0.xy, r0.xyxx
//   lt r0.xy, l(0.5,0.5,0,0), r0.xyxx
//   and r0.xy, r0.xyxx, l(0x3f800000,0x3f800000,0,0)
//   mad r0.xy, r0.xyxx, l(2,2,0,0), l(-1,-1,0,0)
//   mad r0.zw, r0.xxxy, cb0[12].zzzw, v1.xxxy
//   mul r1.xy, r0.xyxx, cb0[12].zwzz
//   sample t1 at r0.zw -> r0.x
//   sample t0 at r0.zw -> r2.xyzw
//   sample t2.yxzw at v1.xy -> r0.y   (reads .y channel)
//   add r0.x, -r0.x, r0.y; add r0.x, |r0.x|, 0.0001; div r0.x, 1, r0.x; mul r3.w, r0.x, 0.0625
//   mov r1.z, 0; add r1.xyzw, r1.xzzy, v1.xyxy
//   sample t1 at r1.xy -> r0.x; ...; mul r3.y, r0.x, 0.1875
//   sample t1 at r1.zw -> r0.x; ...; mul r3.z, r0.x, 0.1875
//   sample t1 at v1.xy -> r0.x; ...; mul r3.x, r0.x, 0.5625
//   dp4 r0.x, r3.xyzw, l(1,1,1,1); div r0.xyzw, r3.xyzw, r0.xxxx
//   sample t0 at r1.xy -> r3.xyzw
//   sample t0 at r1.zw -> r1.xyzw
//   mul r3.xyzw, r0.yyyy, r3.xyzw
//   sample t0 at v1.xy -> r4.xyzw
//   mad r3.xyzw, r4.xyzw, r0.xxxx, r3.xyzw
//   mad r1.xyzw, r1.xyzw, r0.zzzz, r3.xyzw
//   mad o0.xyzw, r2.xyzw, r0.wwww, r1.xyzw

#include "FRPG_Fil_Common.fxh"

Texture2D    gSMP_2        : register(t2);
SamplerState gSMP_2Sampler : register(s2);

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    // r0.xy = frac(UV * screenSize)
    float2 r0xy = frac(In.UV * gFC_ScreenSize.xy);

    // r0.xy = (0.5 < r0.xy) ? 1.0 : 0.0  then * 2 - 1 = -1 or +1
    r0xy = (float2)(float2(0.5f, 0.5f) < r0xy);
    r0xy = r0xy * 2.0f + float2(-1.0f, -1.0f);

    // r0.zw = r0.xy * cb0[12].zw + v1.xy  (diagonal UV)
    // mad r0.zw, r0.xxxy, cb0[12].zzzw, v1.xxxy
    float2 r0zw = r0xy * gFC_ScreenSize.zw + In.UV;

    // r1.xy = r0.xy * cb0[12].zw  (neighbor offsets: r1.x=r0.x*cb0[12].z, r1.y=r0.y*cb0[12].w)
    // mul r1.xy, r0.xyxx, cb0[12].zwzz
    float2 r1xy = r0xy * gFC_ScreenSize.zw;

    // Sample diagonal depth (t1)
    float r0x = gSMP_1.Sample(gSMP_1Sampler, r0zw).x;

    // Sample diagonal color (t0)
    float4 r2 = gSMP_0.Sample(gSMP_0Sampler, r0zw);

    // Sample reference from t2 — swizzle yxzw reads .y channel into r0.y
    float r0y = gSMP_2.Sample(gSMP_2Sampler, In.UV).y;

    // Diagonal weight: rcp(|depth - ref| + 0.0001) * 0.0625
    r0x = -r0x + r0y;
    r0x = abs(r0x) + 0.0001f;
    r0x = 1.0f / r0x;
    float r3w = r0x * 0.0625f;

    // Build neighbor UVs:
    // mov r1.z, 0; add r1.xyzw, r1.xzzy, v1.xyxy
    // r1.x = r1.x + v1.x, r1.y = 0 + v1.y, r1.z = 0 + v1.x, r1.w = r1.y + v1.y
    float4 r1;
    r1.x = r1xy.x + In.UV.x;
    r1.y = 0.0f   + In.UV.y;
    r1.z = 0.0f   + In.UV.x;
    r1.w = r1xy.y + In.UV.y;

    // Horiz depth weight (t1 at r1.xy)
    r0x = gSMP_1.Sample(gSMP_1Sampler, r1.xy).x;
    r0x = -r0x + r0y;
    r0x = abs(r0x) + 0.0001f;
    r0x = 1.0f / r0x;
    float r3y = r0x * 0.1875f;

    // Vert depth weight (t1 at r1.zw)
    r0x = gSMP_1.Sample(gSMP_1Sampler, r1.zw).x;
    r0x = -r0x + r0y;
    r0x = abs(r0x) + 0.0001f;
    r0x = 1.0f / r0x;
    float r3z = r0x * 0.1875f;

    // Center depth weight (t1 at v1.xy)
    r0x = gSMP_1.Sample(gSMP_1Sampler, In.UV).x;
    r0x = -r0x + r0y;
    r0x = abs(r0x) + 0.0001f;
    r0x = 1.0f / r0x;
    float r3x = r0x * 0.5625f;

    // Normalize weights: dp4 then div
    float4 r3 = float4(r3x, r3y, r3z, r3w);
    r0x = dot(r3, float4(1, 1, 1, 1));
    float4 r0 = r3 / r0x;

    // Sample colors and blend
    // sample t0 at r1.xy -> r3.xyzw
    // sample t0 at r1.zw -> r1.xyzw
    // mul r3.xyzw, r0.yyyy, r3.xyzw
    // sample t0 at v1.xy -> r4.xyzw
    // mad r3.xyzw, r4.xyzw, r0.xxxx, r3.xyzw
    // mad r1.xyzw, r1.xyzw, r0.zzzz, r3.xyzw
    // mad o0.xyzw, r2.xyzw, r0.wwww, r1.xyzw
    float4 r3c = gSMP_0.Sample(gSMP_0Sampler, r1.xy);
    float4 r1c = gSMP_0.Sample(gSMP_0Sampler, r1.zw);
    r3c = r0.y * r3c;
    float4 r4 = gSMP_0.Sample(gSMP_0Sampler, In.UV);
    r3c = r4 * r0.x + r3c;
    r1c = r1c * r0.z + r3c;
    Out.Color = r2 * r0.w + r1c;
    return Out;
}
