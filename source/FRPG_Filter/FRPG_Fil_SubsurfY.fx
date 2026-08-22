// FRPG_Fil_SubsurfY.fx - from FRPG_Fil_SubsurfY.fpo.asm
// Vertical SSS blur. Differs from SubsurfX:
//   mul r0.yz, r0.yyyy, l(0,0,0.06,0) -> step = (0, invViewZ*sss*0.06), no ScreenSize mul
//   mul r2.xyz, r1.yzwy -> r2.xyz = r1.yzw * weights (yzwy.xyz = yzw)
// ld r1.yzw, t0.wxyz -> r1.yzw = tex.xyz (same as SubsurfX)
// ld t2.yzwx -> .x=original .y; ld t1.yzwx -> .x=original .y
#include "FRPG_Fil_Common.fxh"
Texture2D gSMP_Depth1 : register(t1);
Texture2D gSMP_Mask2  : register(t2);
struct FIL_OUT { float4 Color : SV_Target0; };
FIL_OUT FragmentMain(FIL_IN In) {
    FIL_OUT Out;
    float4 x0[11];
    x0[1]  = float4(0.00471690996f, 0.000184770994f, 5.07564982e-05f, -2.000f);
    x0[2]  = float4(0.0192830991f, 0.00282018003f, 0.000842139998f, -1.280f);
    x0[3]  = float4(0.036390f, 0.0130999004f, 0.00643684994f, -0.720f);
    x0[4]  = float4(0.0821904019f, 0.0358607993f, 0.0209260993f, -0.320f);
    x0[5]  = float4(0.0771801993f, 0.113491f, 0.0793803036f, -0.080f);
    x0[6]  = float4(0.0771801993f, 0.113491f, 0.0793803036f,  0.080f);
    x0[7]  = float4(0.0821904019f, 0.0358607993f, 0.0209260993f,  0.320f);
    x0[8]  = float4(0.036390f, 0.0130999004f, 0.00643684994f,  0.720f);
    x0[9]  = float4(0.0192830991f, 0.00282018003f, 0.000842139998f,  1.280f);
    x0[10] = float4(0.00471690996f, 0.000184770994f, 5.07566001e-05f,  2.000f);
    int2 coord = (int2)(In.UV * gFC_ScreenSize.xy);
    float4 r1;
    r1.x = gSMP_Mask2.Load(int3(coord, 0)).x;
    if (r1.x == 0.0f) discard;
    // ld r1.yzw, t0.wxyz -> r1.yzw = tex.xyz
    r1.yzw = gSMP_0.Load(int3(coord, 0)).xyz;
    float r0x = gSMP_Depth1.Load(int3(coord, 0)).x;
    r0x = gFC_CameraParam.w / (r0x * gFC_CameraParam.z + gFC_CameraParam.y);
    // div r0.y, l(1), r0.x / mul r0.y, r0.y, r1.x
    float r0y = (1.0f / r0x) * r1.x;
    // mul r0.yz, r0.yyyy, l(0,0,0.06,0) -> r0.y=0, r0.z=r0y*0.06
    float2 r0yz = float2(0.0f, r0y * 0.060000f);
    // mul r2.xyz, r1.yzwy, l(0.560479,0.669086,0.784728,0)
    // r1.yzwy.xyz = r1.yzw -> r2.xyz = r1.yzw * weights
    float3 r2xyz = r1.yzw * float3(0.560479f, 0.669086f, 0.784728f);
    float3 r4xyz = r2xyz;
    [loop]
    for (int i = 1; i < 11; i++) {
        float r2w = x0[i].w;
        float2 r5xy = r2w.xx * r0yz + In.UV;
        int2 sc = (int2)(r5xy * gFC_ScreenSize.xy);
        r2w = gSMP_Mask2.Load(int3(sc, 0)).y;
        bool noSSS = (r2w == 0.0f);
        float3 r5xyz = gSMP_0.Load(int3(sc, 0)).xyz;
        // movc r5.xyz, r2.w, r1.yzwy, r5.xyz -> r1.yzwy.xyz = r1.yzw
        r5xyz = noSSS ? r1.yzw : r5xyz;
        r2w = gSMP_Depth1.Load(int3(sc, 0)).y;
        r2w = gFC_CameraParam.w / (r2w * gFC_CameraParam.z + gFC_CameraParam.y);
        r2w = saturate(r1.x * abs(r0x - r2w) * 36.0f);
        // add r6.xyz, r1.yzwy, -r5.xyz -> r1.yzwy.xyz = r1.yzw
        r5xyz = r2w * (r1.yzw - r5xyz) + r5xyz;
        r4xyz += x0[i].xyz * r5xyz;
    }
    Out.Color.xyz = r4xyz;
    Out.Color.w = 1.0f;
    return Out;
}
