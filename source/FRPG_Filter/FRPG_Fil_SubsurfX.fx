// FRPG_Fil_SubsurfX.fx - from ASM
// ld r1.yzw, t0.wxyz -> swizzle wxyz means pos0=tex.w,pos1=tex.x,pos2=tex.y,pos3=tex.z
//   r1.y=pos1=tex.x, r1.z=pos2=tex.y, r1.w=pos3=tex.z -> r1.yzw = tex.xyz (RGB)
// mul r0.yzw, r1.yyzw -> r0.y=r1.y*0.560479, r0.z=r1.y*0.669086, r0.w=r1.z*0.784728
//   = (R*0.560479, R*0.669086, G*0.784728)
// ld t2.yzwx -> .x=original .y; ld t1.yzwx -> .x=original .y
// movc r5.xyz, r2.w, r1.yzwy, r5.xyz -> r1.yzwy.xyz = r1.yzw = tex.xyz
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
    // ld r1.yzw, t0.wxyz -> r1.yzw = tex.xyz (see comment above)
    r1.yzw = gSMP_0.Load(int3(coord, 0)).xyz;
    float r0x = gSMP_Depth1.Load(int3(coord, 0)).x;
    r0x = gFC_CameraParam.w / (r0x * gFC_CameraParam.z + gFC_CameraParam.y);
    float r0y = 1.0f / r0x;
    float r0z = gFC_ScreenSize.z * gFC_ScreenSize.y;
    r0y = r0y * r1.x;
    r0y = r0z * r0y;
    float2 r2xy = float2(r0y * 0.060000f, 0.0f);
    // Standard RGB weights for center pixel accumulation.
    // NOTE: original ASM uses r1.yyzw (R channel twice) but this causes yellow tint.
    // Using r1.yzw (correct RGB) matches visual output.
    float3 r4xyz = r1.yzw * float3(0.560479f, 0.669086f, 0.784728f);
    [loop]
    for (int i = 1; i < 11; i++) {
        float r2w = x0[i].w;
        float2 r5xy = r2w.xx * r2xy + In.UV;
        int2 sc = (int2)(r5xy * gFC_ScreenSize.xy);
        r2w = gSMP_Mask2.Load(int3(sc, 0)).y;
        bool noSSS = (r2w == 0.0f);
        float3 r5xyz = gSMP_0.Load(int3(sc, 0)).xyz;
        r5xyz = noSSS ? r1.yzw : r5xyz;
        r2w = gSMP_Depth1.Load(int3(sc, 0)).y;
        r2w = gFC_CameraParam.w / (r2w * gFC_CameraParam.z + gFC_CameraParam.y);
        r2w = saturate(r1.x * abs(r0x - r2w) * 36.0f);
        r5xyz = r2w * (r1.yzw - r5xyz) + r5xyz;
        r4xyz += x0[i].xyz * r5xyz;
    }
    Out.Color.xyz = r4xyz;
    Out.Color.w = 1.0f;
    return Out;
}
