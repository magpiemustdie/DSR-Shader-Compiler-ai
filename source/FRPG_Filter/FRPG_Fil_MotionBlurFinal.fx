// FRPG_Fil_MotionBlurFinal.fx
// Direct register-level translation of FRPG_Fil_MotionBlurFinal.fpo.asm
// t0 = tile max velocity, t1 = HDR scene, t2 = per-pixel velocity (1/mvLen, viewZ)
// cb0[12].zw = 1/screenSize,  cb0[56].x = blur scale

#include "FRPG_Fil_Common.fxh"

Texture2D    gSMP_2 : register(t2);
SamplerState gSMP_2Sampler : register(s2);

float4 gFC_BlurScale : register(c56);

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float4 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11;
    float2 v1 = In.UV;

    // sample_l r0.xy, v1, t0.xyzw
    r0.xy = gSMP_0.SampleLevel(gSMP_0Sampler, v1, 0.0f).xy;
    // sample_l r1.xyz, v1, t1.xyzw
    r1.xyz = gSMP_1.SampleLevel(gSMP_1Sampler, v1, 0.0f).xyz;
    // dp2 r0.z, cb0[12].zwzz, cb0[12].zwzz
    r0.z = dot(gFC_ScreenSize.zw, gFC_ScreenSize.zw);
    // dp2 r0.w, r0.xyxx, r0.xyxx
    r0.w = dot(r0.xy, r0.xy);
    // add r0.z, -r0.z, r0.w  → r0.z = r0.w - r0.z
    r0.z = r0.w - r0.z;
    // lt r0.z, l(0), r0.z
    r0.z = (float)(0.0f < r0.z);

    if (r0.z)
    {
        // mul r2.xyzw, r0.xyxy, cb0[56].xxxx
        r2.xyzw = r0.xyxy * gFC_BlurScale.xxxx;
        // sample_l r3.xy, v1, t2.yxzw  → r3.x=texel.y, r3.y=texel.x
        r3.xy = gSMP_2.SampleLevel(gSMP_2Sampler, v1, 0.0f).yx;
        // mad r0.xyzw, -r0.xyxy, cb0[56].xxxx, v1.xyxy
        // r0.xy = v1 - r0.xy*scale,  r0.zw = v1 - r0.xy*scale  (same value, r0.xy==r0.zw after)
        r0.xyzw = -r0.xyxy * gFC_BlurScale.xxxx + float4(v1, v1);
        // dp2 r1.w, r2.zwzz, r2.zwzz
        r1.w = dot(r2.zw, r2.zw);
        // sqrt r1.w, r1.w
        r1.w = sqrt(r1.w);
        // mad_sat r4.xyzw, r2.zwzw, l(0,0,0.666667,0.666667), r0.zwzw
        // r4.xy = sat(r2.zw*0 + r0.zw) = r0.zw
        // r4.zw = sat(r2.zw*0.666667 + r0.zw)
        r4.xyzw = saturate(r2.zwzw * float4(0,0,0.666666687f,0.666666687f) + r0.zwzw);
        // mad_sat r0.xyzw, r2.xyzw, l(1.333333,1.333333,2,2), r0.xyzw
        r0.xyzw = saturate(r2.xyzw * float4(1.33333337f,1.33333337f,2,2) + r0.xyzw);
        // sample_l r2.xy, r4.xyxx, t2.xyzw  → r2.xy = texel.xy
        r2.xy = gSMP_2.SampleLevel(gSMP_2Sampler, r4.xy, 0.0f).xy;
        // sample_l r2.zw, r4.zwzz, t2.zwxy  → (tex.z, tex.w, tex.x, tex.y), write .zw
        r2.zw = gSMP_2.SampleLevel(gSMP_2Sampler, r4.zw, 0.0f).xy;
        // sample_l r5.xy, r0.xyxx, t2.xyzw  → r5.xy = texel.xy
        r5.xy = gSMP_2.SampleLevel(gSMP_2Sampler, r0.xy, 0.0f).xy;
        // sample_l r5.zw, r0.zwzz, t2.zwxy  → (tex.z, tex.w, tex.x, tex.y), write .zw
        r5.zw = gSMP_2.SampleLevel(gSMP_2Sampler, r0.zw, 0.0f).xy;
        // mul r6.xyzw, r1.wwww, l(-1,-0.333333,0.333333,1)
        r6.xyzw = r1.wwww * float4(-1,-0.333333313f,0.333333373f,1);
        // mov r7.y, |r3.x|
        r7.y = abs(r3.x);
        // mov r7.xz, |r2.yywy|  → r7.x=|r2.y|, r7.z=|r2.w|
        r7.x = abs(r2.y);
        r7.z = abs(r2.w);
        // add r8.xy, r7.yxyy, l(1,1,0,0)  → r8.x=r7.y+1, r8.y=r7.x+1
        r8.x = r7.y + 1.0f;
        r8.y = r7.x + 1.0f;
        // add_sat r8.xy, -r7.xyxx, r8.xyxx  → r8.x=sat(r8.x-r7.x), r8.y=sat(r8.y-r7.y)
        r8.x = saturate(r8.x - r7.x);
        r8.y = saturate(r8.y - r7.y);
        // mov r3.xz, r2.xxzx  → r3.x=r2.x, r3.z=r2.z
        r3.x = r2.x;
        r3.z = r2.z;
        // mad_sat r9.xyzw, -|r6.xxxx|, r3.xyxy, l(1,1,1.95,1.95)
        r9.xyzw  = saturate(-abs(r6.xxxx) * r3.xyxy + float4(1,1,1.95f,1.95f));
        // mad_sat r10.xyzw, -|r6.yyyy|, r3.zyzy, l(1,1,1.95,1.95)
        r10.xyzw = saturate(-abs(r6.yyyy) * r3.zyzy + float4(1,1,1.95f,1.95f));
        // mov r7.xw, |r5.wwwy|  → r7.x=|r5.w|, r7.w=|r5.y|
        r7.x = abs(r5.w);
        r7.w = abs(r5.y);
        // add r2.xyzw, r7.yzyw, l(1,1,1,1)
        r2.x = r7.y + 1.0f;
        r2.y = r7.z + 1.0f;
        r2.z = r7.y + 1.0f;
        r2.w = r7.w + 1.0f;
        // add_sat r2.xyzw, -r7.zywy, r2.xyzw
        r2.x = saturate(r2.x - r7.z);
        r2.y = saturate(r2.y - r7.y);
        r2.z = saturate(r2.z - r7.w);
        r2.w = saturate(r2.w - r7.z);
        // mov r3.w, r5.x
        r3.w = r5.x;
        // mad_sat r11.xyzw, -|r6.zzzz|, r3.wywy, l(1,1,1.95,1.95)
        r11.xyzw = saturate(-abs(r6.zzzz) * r3.wywy + float4(1,1,1.95f,1.95f));
        // add r3.xz, r7.yyxy, l(1,0,1,0)  → r3.x=r7.y+1, r3.z=r7.x+1
        r3.x = r7.y + 1.0f;
        r3.z = r7.x + 1.0f;
        // add_sat r3.xz, -r7.xxyx, r3.xxzx  → r3.x=sat(r3.x-r7.x), r3.z=sat(r3.z-r7.x)
        r3.x = saturate(r3.x - r7.x);
        r3.z = saturate(r3.z - r7.x);
        // mov r5.xz, r5.zzzz  → r5.x=r5.z, r5.z=r5.z (no-op for r5.z)
        r5.x = r5.z;
        // mov r5.yw, r3.yyyy  → r5.y=r3.y, r5.w=r3.y
        r5.y = r3.y;
        r5.w = r3.y;
        // mad_sat r5.xyzw, -|r6.wwww|, r5.xyzw, l(1,1,1.95,1.95)
        r5.xyzw = saturate(-abs(r6.wwww) * r5.xyzw + float4(1,1,1.95f,1.95f));
        // dp2 r1.w, r8.xyxx, r9.xyxx
        r1.w = dot(r8.xy, r9.xy);
        // mul r3.y, r9.w, r9.z
        r3.y = r9.w * r9.z;
        // mad r6.x, r3.y, l(2), r1.w
        r6.x = r3.y * 2.0f + r1.w;
        // dp2 r1.w, r2.xyxx, r10.xyxx
        r1.w = dot(r2.xy, r10.xy);
        // mul r2.x, r10.w, r10.z
        r2.x = r10.w * r10.z;
        // mad r6.y, r2.x, l(2), r1.w
        r6.y = r2.x * 2.0f + r1.w;
        // dp2 r1.w, r2.zwzz, r11.xyxx
        r1.w = dot(r2.zw, r11.xy);
        // mul r2.x, r11.w, r11.z
        r2.x = r11.w * r11.z;
        // mad r6.z, r2.x, l(2), r1.w
        r6.z = r2.x * 2.0f + r1.w;
        // dp2 r1.w, r3.xzxx, r5.xyxx
        r1.w = dot(r3.xz, r5.xy);
        // mul r2.x, r5.w, r5.z
        r2.x = r5.w * r5.z;
        // mad r6.w, r2.x, l(2), r1.w
        r6.w = r2.x * 2.0f + r1.w;
        // sample_l r2.xyz, r4.xyxx, t1.xyzw
        r2.xyz = gSMP_1.SampleLevel(gSMP_1Sampler, r4.xy, 0.0f).xyz;
        // sample_l r3.xyz, r4.zwzz, t1.xyzw
        r3.xyz = gSMP_1.SampleLevel(gSMP_1Sampler, r4.zw, 0.0f).xyz;
        // sample_l r4.xyz, r0.xyxx, t1.xyzw
        r4.xyz = gSMP_1.SampleLevel(gSMP_1Sampler, r0.xy, 0.0f).xyz;
        // sample_l r0.xyz, r0.zwzz, t1.xyzw
        r0.xyz = gSMP_1.SampleLevel(gSMP_1Sampler, r0.zw, 0.0f).xyz;
        // mul r3.xyz, r6.yyy, r3.xyzx
        r3.xyz = r6.yyy * r3.xyz;
        // mad r2.xyz, r2.xyzx, r6.xxxx, r3.xyzx
        r2.xyz = r2.xyz * r6.xxx + r3.xyz;
        // mad r2.xyz, r4.xyzx, r6.zzzz, r2.xyzx
        r2.xyz = r4.xyz * r6.zzz + r2.xyz;
        // mad r0.xyz, r0.xyzx, r6.wwww, r2.xyzx
        r0.xyz = r0.xyz * r6.www + r2.xyz;
        // add r1.xyz, r0.xyzx, r1.xyzx
        r1.xyz = r0.xyz + r1.xyz;
        // dp4 r0.x, r6.xyzw, l(1,1,1,1)
        r0.x = dot(r6.xyzw, 1.0f);
        // add r0.x, r0.x, l(1)
        r0.x = r0.x + 1.0f;
    }
    else
    {
        r0.x = 1.0f;
    }

    r0.x = 1.0f / r0.x;
    Out.Color.xyz = r0.xxx * r1.xyz;
    Out.Color.w   = 1.0f;
    return Out;
}
