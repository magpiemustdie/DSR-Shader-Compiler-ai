// FRPG_Fil_FxAA2.fx
// Rewritten directly from translated HLSL (FRPG_Fil_FxAA2.fpo.translated.hlsl)
// Full FXAA 2.0 with iterative edge search (4 passes: 1.5, 2, 4, 12 steps).
// t0=scene (luma in .y), cb0[12]=ScreenSize (zw=1/size)
//
// Key ASM details:
//   gather4 s0.y = gather GREEN channel only
//   gather4_aoffimmi(-1,-1) t0.xzwy = gather with offset, swizzle result
//   sample_l_aoffimmi(1,-1) t0.xzwy = sample with texel offset
//   sample_l_aoffimmi(-1,1) t0.yxzw = sample with texel offset, swap xy

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;
    float2 v1 = In.UV;

    float4 r0 = 0, r1 = 0, r2 = 0, r3 = 0, r4 = 0, r5 = 0;

    r0.xyzw = gSMP_0.SampleLevel(gSMP_0Sampler, v1, 0.0f);

    // gather4 green channel — s0.y means gather .y (green)
    r1.xyz = gSMP_0.GatherGreen(gSMP_0Sampler, v1).xyz;
    // gather4_aoffimmi(-1,-1) t0.xzwy — gather green with offset, swizzle xzwy
    float4 g2 = gSMP_0.GatherGreen(gSMP_0Sampler, v1, int2(-1,-1));
    r2.xyz = g2.xzw; // swizzle .xzwy → take .x .z .w

    r1.w = max(r0.y, r1.x);
    r2.w = min(r0.y, r1.x);
    r1.w = max(r1.w, r1.z);
    r2.w = min(r1.z, r2.w);
    r3.x = max(r2.x, r2.y);
    r3.y = min(r2.x, r2.y);
    r1.w = max(r1.w, r3.x);
    r2.w = min(r2.w, r3.y);
    r3.x = r1.w * 0.166f;
    r1.w = r1.w - r2.w;
    r2.w = max(r3.x, 0.0833f);
    r2.w = (float)(r1.w >= r2.w);

    if (r2.w)
    {
        // sample_l_aoffimmi(1,-1) t0.xzwy → swizzle puts green in .w, write r2.w
        r2.w = gSMP_0.SampleLevel(gSMP_0Sampler, v1, 0.0f, int2(1,-1)).xzwy.w;
        // sample_l_aoffimmi(-1,1) t0.yxzw → sample at offset (-1,1), take .y (green after yxzw)
        r3.x = gSMP_0.SampleLevel(gSMP_0Sampler, v1, 0.0f, int2(-1,1)).y;

        r3.yz = float2(r1.x + r2.y, r1.z + r2.x);
        r1.w = 1.0f / r1.w;
        r3.w = r3.z + r3.y;
        r3.yz = r0.yy * float2(-2,-2) + r3.yz;
        r4.x = r1.y + r2.w;
        r2.w = r2.w + r2.z;
        r4.y = r1.z * -2.0f + r4.x;
        r2.w = r2.y * -2.0f + r2.w;
        r2.z = r2.z + r3.x;
        r1.y = r1.y + r3.x;
        r3.x = abs(r3.y) * 2.0f + abs(r4.y);
        r2.w = abs(r3.z) * 2.0f + abs(r2.w);
        r3.y = r2.x * -2.0f + r2.z;
        r1.y = r1.x * -2.0f + r1.y;
        r3.x = r3.x + abs(r3.y);
        r1.y = r2.w + abs(r1.y);
        r2.z = r4.x + r2.z;
        r1.y = (float)(r3.x >= r1.y);
        r2.z = r3.w * 2.0f + r2.z;
        r2.x = (r1.y != 0) ? r2.y : r2.x;
        r1.x = (r1.y != 0) ? r1.x : r1.z;
        r1.z = (r1.y != 0) ? gFC_ScreenSize.w : gFC_ScreenSize.z;
        r2.y = r2.z * 0.0833333358f - r0.y;
        r2.z = -r0.y + r2.x;
        r2.w = -r0.y + r1.x;
        r2.x = r0.y + r2.x;
        r1.x = r0.y + r1.x;
        r3.x = (float)(abs(r2.z) >= abs(r2.w));
        r2.z = max(abs(r2.w), abs(r2.z));
        r1.z = (r3.x != 0) ? -r1.z : r1.z;
        r1.w = saturate(r1.w * abs(r2.y));
        r2.y = asfloat(asuint(r1.y) & asuint(gFC_ScreenSize.z));
        r2.w = (r1.y != 0) ? 0 : gFC_ScreenSize.w;
        r3.yz = r1.zz * float2(0.5f, 0.5f) + v1.xy;
        r3.y = (r1.y != 0) ? v1.x : r3.y;
        r3.z = (r1.y != 0) ? r3.z : v1.y;
        r4.xy = -float2(r2.y, r2.w) + r3.yz;
        r5.xy = float2(r2.y, r2.w) + r3.yz;
        r3.y = r1.w * -2.0f + 3.0f;
        // sample_l t0.xzyw → swizzle puts green in .z, write r3.z
        r3.z = gSMP_0.SampleLevel(gSMP_0Sampler, r4.xy, 0.0f).xzyw.z;
        r1.w = r1.w * r1.w;
        // sample_l t0.xzwy → swizzle puts green in .w, write r3.w
        r3.w = gSMP_0.SampleLevel(gSMP_0Sampler, r5.xy, 0.0f).xzwy.w;
        r1.x = (r3.x != 0) ? r2.x : r1.x;
        r2.x = r2.z * 0.25f;
        r2.z = -r1.x * 0.5f + r0.y;
        r1.w = r1.w * r3.y;
        r2.z = (float)(r2.z < 0.0f);
        r3.x = -r1.x * 0.5f + r3.z;
        r3.y = -r1.x * 0.5f + r3.w;
        r3.zw = (float2)(abs(r3.xy) >= r2.xx);
        r4.z = -r2.y * 1.5f + r4.x;
        r4.x = (r3.z != 0) ? r4.x : r4.z;
        r4.w = -r2.w * 1.5f + r4.y;
        r4.z = (r3.z != 0) ? r4.y : r4.w;
        r4.yw = asfloat(~asuint(r3.zw));
        r4.y = asfloat(asuint(r4.w) | asuint(r4.y));
        r4.w = r2.y * 1.5f + r5.x;
        r5.x = (r3.w != 0) ? r5.x : r4.w;
        r4.w = r2.w * 1.5f + r5.y;
        r5.z = (r3.w != 0) ? r5.y : r4.w;

        static const float kSteps[4] = { 1.5f, 2.0f, 4.0f, 12.0f };
        [unroll]
        for (int iPass = 0; iPass < 4; iPass++)
        {
            if (r4.y)
            {
                if (!r3.z)
                    // t0.yxzw → swizzle puts green in .x, write r3.x
                    r3.x = gSMP_0.SampleLevel(gSMP_0Sampler, float2(r4.x, r4.z), 0.0f).yxzw.x;
                if (!r3.w)
                    // t0.xyzw → green is .y
                    r3.y = gSMP_0.SampleLevel(gSMP_0Sampler, float2(r5.x, r5.z), 0.0f).y;

                float r4y_tmp = -r1.x * 0.5f + r3.x;
                r3.x = (r3.z != 0) ? r3.x : r4y_tmp;
                float r3z_tmp = -r1.x * 0.5f + r3.y;
                r3.y = (r3.w != 0) ? r3.y : r3z_tmp;
                r3.zw = (float2)(abs(r3.xy) >= r2.xx);

                float step = kSteps[iPass];
                float r4y2 = -r2.y * step + r4.x;
                r4.x = (r3.z != 0) ? r4.x : r4y2;
                float r4y3 = -r2.w * step + r4.z;
                r4.z = (r3.z != 0) ? r4.z : r4y3;
                r4.yw = asfloat(~asuint(r3.zw));
                r4.y = asfloat(asuint(r4.w) | asuint(r4.y));
                float r4w2 = r2.y * step + r5.x;
                r5.x = (r3.w != 0) ? r5.x : r4w2;
                float r4w3 = r2.w * step + r5.z;
                r5.z = (r3.w != 0) ? r5.z : r4w3;
            }
        }

        r1.x = -r4.x + v1.x;
        float r2y_tmp = -r4.z + v1.y;
        r1.x = (r1.y != 0) ? r1.x : r2y_tmp;
        r2.xy = float2(r5.x, r5.z) - v1.xy;
        r2.x = (r1.y != 0) ? r2.x : r2.y;
        r2.yw = (float2)(r3.xy < 0.0f);
        r3.x = r1.x + r2.x;
        r2.yz = (float2)((int2)asuint(r2.zz) != (int2)asuint(r2.yw));
        r2.w = 1.0f / r3.x;
        r3.x = (float)(r1.x < r2.x);
        r1.x = min(r1.x, r2.x);
        r2.x = (r3.x != 0) ? r2.y : r2.z;
        r1.w = r1.w * r1.w;
        r1.x = r1.x * -r2.w + 0.5f;
        r1.w = r1.w * 0.75f;
        r1.x = asfloat(asuint(r1.x) & asuint(r2.x));
        r1.x = max(r1.w, r1.x);
        r1.xz = r1.xx * r1.zz + v1.xy;
        r2.x = (r1.y != 0) ? v1.x : r1.x;
        r2.y = (r1.y != 0) ? r1.z : v1.y;
        r1.xyz = gSMP_0.SampleLevel(gSMP_0Sampler, r2.xy, 0.0f).xyz;
        Out.Color.xyz = r1.xyz;
        Out.Color.w   = r0.y;
    }
    else
    {
        Out.Color = r0;
    }

    return Out;
}
