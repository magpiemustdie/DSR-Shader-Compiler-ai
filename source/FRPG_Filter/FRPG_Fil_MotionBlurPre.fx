// FRPG_Fil_MotionBlurPre.fx
// Reconstructed from DSR DXBC ps_5_0.
// Output: o0.x = 1/mvLen, o0.y = viewZ
// t0=velocity buffer (xy), t1=depth buffer
// cb0[8]  = CameraParam (x:near*far, y:far, z:near-far, w:near*far)
// cb0[57] = (motionScale.x, motionScale.y, normScale)
// cb0[58..61] = InvViewProj rows
// cb0[74,75,77] = PrevViewProj rows (x,y,w)
// cb0[78] = camera world position
//
// ASM trace:
//   r0.z = t1.sample(v1.xy).y          // depth (swizzle t1.yzxw → .y = depth)
//   r1.x = r0.z * cb0[8].z + cb0[8].y  // depth * (near-far) + far
//   o0.y = cb0[8].w / r1.x             // viewZ = near*far / (depth*(near-far)+far)
//   r0.xy = v1.xy * (2,-2) + (-1,1)    // NDC
//   r0.w = 1
//   r1.xyz = InvVP * r0                // world pos (unnormalized)
//   r0.x = InvVP[3] * r0               // w
//   r0.xyz = r1.xyz / r0.x             // world pos
//   r0.xyz += cb0[78].xyz              // + camera offset
//   r0.w = 1
//   r1.xy = PrevVP[0,1] * r0           // prev clip xy
//   r0.x  = PrevVP[3] * r0             // prev clip w
//   r0.xy = r1.xy / r0.x               // prev NDC
//   r0.xy = r0.xy * (0.5,-0.5) + 0.5   // prev UV
//   r0.xy = v1.xy - r0.xy              // mv = current - prev
//   r0.zw = t0.sample(v1.xy).zwxy      // velocity override: r0.z=t0.z, r0.w=t0.w
//   r1.x = r0.z < 1.0                  // hasOverride = (t0.z < 1.0)
//   r0.zw = r0.zw * (1,-1)             // override: (t0.z, -t0.w)
//   r0.xy = hasOverride ? r0.zw : r0.xy
//   r0.z = dot(r0.xy, r0.xy)
//   r0.z = rsq(r0.z)
//   r0.z = saturate(r0.z * cb0[57].z)
//   r0.xy = r0.z * r0.xy
//   r0.xy = r0.xy * cb0[57].xy
//   r0.x = dot(r0.xy, r0.xy)
//   r0.x = sqrt(r0.x)
//   o0.x = 1 / r0.x

#include "FRPG_Fil_Common.fxh"

// t0 = velocity buffer (= gSMP_0 from Common), t1 = depth buffer (= gSMP_1 from Common)

// Extended registers — exact reference names/layout ($Globals, c54-c87)
float4               DL_FREG_054        : register(c54); // [unused]
float4               DL_FREG_055        : register(c55); // [unused]
float4               DL_FREG_056        : register(c56); // [unused]
float4               DL_FREG_057        : register(c57);  // x:scaleX, y:scaleY, z:normScale
float4x4             DL_FREG_058        : register(c58);  // InvViewProj rows c58-c61
float4x4             DL_FREG_062        : register(c62); // [unused]
float4               DL_FREG_066        : register(c66); // [unused]
float4               DL_FREG_067        : register(c67); // [unused]
float4               DL_FREG_068        : register(c68); // [unused]
float4               DL_FREG_069        : register(c69); // [unused]
float4               DL_FREG_070        : register(c70); // [unused]
float4               DL_FREG_071        : register(c71); // [unused]
float4               DL_FREG_072        : register(c72); // [unused]
float4               DL_FREG_073        : register(c73); // [unused]
float4x4             DL_FREG_074        : register(c74);  // PrevViewProj rows c74-c77
float4               DL_FREG_078        : register(c78);  // camera world position
uint4                gFC_FrameIndex     : register(c81); // [unused]
float4x4             gVC_WorldViewClipMtx : register(c82); // [unused]
float4               gVC_ScreenSize     : register(c86); // [unused]
float4               gVC_NoiseParam     : register(c87); // [unused]

struct FIL_IN_MV  { float4 Pos : SV_Position; float2 UV : TEXCOORD0; };
struct FIL_OUT_MV { float2 o0 : SV_Target0; };

FIL_OUT_MV FragmentMain(FIL_IN_MV In)
{
    FIL_OUT_MV Out;

    // Sample depth — ASM: t1.yzxw → r0.z, swizzle[z]=x → depth = texel.x
    float depth = gSMP_1.SampleLevel(gSMP_1Sampler, In.UV, 0.0f).x;

    // viewZ = cb0[8].w / (depth * cb0[8].z + cb0[8].y)  — per HLSL
    float r1x = depth * gFC_CameraParam.z + gFC_CameraParam.y;
    Out.o0.y = gFC_CameraParam.w / r1x;

    // NDC from UV
    float2 ndc = In.UV * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f);
    float4 r0 = float4(ndc, depth, 1.0f);

    // Unproject to world space
    float4 r1 = mul(r0, DL_FREG_058);
    float3 worldPos = r1.xyz / r1.w;

    // Add camera offset
    worldPos += DL_FREG_078.xyz;

    // Project to previous frame
    float4 wp = float4(worldPos, 1.0f);
    float4 prevClip = mul(wp, DL_FREG_074);
    float2 prevUV = prevClip.xy / prevClip.w * float2(0.5f, -0.5f) + 0.5f;

    // Reprojection motion vector
    float2 mv = In.UV - prevUV;

    // Velocity override from t0
    // ASM: sample_l t0.zwxy → r0.zw; swizzle[z]=x, swizzle[w]=y → r0.z=texel.x, r0.w=texel.y
    // hasOverride = (r0.z < 1.0) = (texel.x < 1.0); override = (texel.x, -texel.y)
    float4 velSample = gSMP_0.SampleLevel(gSMP_0Sampler, In.UV, 0.0f);
    float2 velOverride = velSample.xy;
    bool   hasOverride = (velOverride.x < 1.0f);
    velOverride *= float2(1.0f, -1.0f);
    float2 mvFinal = hasOverride ? velOverride : mv;

    // Normalize and scale
    // ASM: mul r0.xy, r0.zzzz, r0.xyxx  → norm * mvFinal (norm first)
    float lenSq = dot(mvFinal, mvFinal);
    float norm  = saturate(rsqrt(lenSq) * DL_FREG_057.z);
    float2 mvNorm = mvFinal * norm * DL_FREG_057.xy;
    float  mvLen  = sqrt(dot(mvNorm, mvNorm));

    Out.o0.x = 1.0f / mvLen;
    return Out;
}
