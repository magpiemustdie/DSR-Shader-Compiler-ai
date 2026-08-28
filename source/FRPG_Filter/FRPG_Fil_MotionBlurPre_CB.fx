// FRPG_Fil_MotionBlurPre_CB.fx
// Reconstructed from DSR DXBC ps_5_0.
// Checkerboard motion blur prepass.
// t0=motion vector texture (SampleLevel), t1=depth (Texture2DMS, ldms)
// Uses resinfo to get t0 dimensions (not cb0[12]).
// cb0[8]  = CameraParam (z:near-far, w:near*far, y:far)
// cb0[57] = (scaleX, scaleY, normScale)
// cb0[58..61] = InvViewProj
// cb0[74,75,77] = PrevViewProj rows
// cb0[78] = camera offset
// cb0[81].y = checkerboard frame offset

#include "FRPG_Fil_Common.fxh"

// t1 overrides gSMP_1 from Common with MSAA variant — declare separately
// (gSMP_0 from Common used for velocity buffer at t0)
Texture2DMS<float4> gSMP_Depth1MS : register(t1);

float4 gFC_MotionParam  : register(c57);
float4 gFC_InvVP0       : register(c58);
float4 gFC_InvVP1       : register(c59);
float4 gFC_InvVP2       : register(c60);
float4 gFC_InvVP3       : register(c61);
float4 gFC_PrevVP0      : register(c74);
float4 gFC_PrevVP1      : register(c75);
float4 gFC_PrevVP3      : register(c77);
float4 gFC_CamOffset    : register(c78);
uint4  gFC_CBParam       : register(c81);

struct FIL_IN_CB { float4 Pos : SV_Position; float2 UV : TEXCOORD1; };
struct FIL_OUT_MV { float2 o0 : SV_Target0; };

FIL_OUT_MV FragmentMain(FIL_IN_CB In)
{
    FIL_OUT_MV Out;

    // resinfo t0 → r1.xy = (width, height) as float (use float overload to avoid utof)
    float2 r1xy;
    {
        float fw, fh;
        gSMP_0.GetDimensions(fw, fh);
        r1xy = float2(fw, fh);
    }

    // r2.x = 0.5 / width,  r0.w = 1.0 / height
    float r2x = 0.5f / r1xy.x;
    float r0w = 1.0f / r1xy.y;

    // r0.x = -r2.x,  r0.z = -r0.w
    float r0x = -r2x;
    float r0z = -r0w;

    // Checkerboard: ftou v0.xy → r1.yz
    uint2 r1yz = (uint2)In.Pos.xy;
    // iadd r3.x = r1.z + r1.y + cb0[81].y; and r3.x, 1
    uint r3x = (r1yz.x + r1yz.y + (uint)gFC_CBParam.y) & 1u;

    // movc r3.yz, r3.x, r0.xy, r0.xz  → if r3.x: r3.y=r0.x, r3.z=r0.y; else r3.y=r0.x, r3.z=r0.z
    // r0.y = 0 (from mov r0.y, 0 at start)
    float r0y = 0.0f;
    float2 r3yz = (r3x != 0u) ? float2(r0x, r0y) : float2(r0x, r0z);

    // r2.zw = r0.zw (r0.z=-r0w, r0.w=r0w)
    float2 r2zw = float2(r0z, r0w);

    // add r3.yz, r3.yz, v1.xy  → UV + offset
    float2 uv3 = r3yz + In.UV;
    // sample t0.xy → r3.yz = (t0.x, t0.y) = (r, g) per ref
    float2 r3yz_s = gSMP_0.SampleLevel(gSMP_0Sampler, uv3, 0.0f).xy;

    // movc r4.xy, r3.x, r2.xy, r2.xz  → if r3.x: r4=(r2.x,r2.y)=(0.5/W,0); else r4=(r2.x,r2.z)=(0.5/W,-1/H)
    float r2y = 0.0f;
    float2 r4xy = (r3x != 0u) ? float2(r2x, r2y) : float2(r2x, r0z);

    // movc r0.yz, r3.x, r0.yw, r2.xw  → if r3.x: r0.y=r0.y=0, r0.z=r0.w=1/H; else r0.y=r2.x=0.5/W, r0.z=r2.w=1/H
    float2 r0yz = (r3x != 0u) ? float2(r0y, r0w) : float2(r2x, r0w);

    // movc r0.xw, r3.x, r2.yyy, r0.xw  → if r3.x: r0.x=0, r0.w=0; else r0.x=r0.x=-0.5/W, r0.w=r0.w=1/H
    float2 r0xw = (r3x != 0u) ? float2(r2y, r2y) : float2(r0x, r0w);

    // add r0.xw, r0.xw, v1.xy  → UV + offset
    float2 uv0xw = r0xw + In.UV;
    // sample t0.xy → r0.xw = (t0.x, t0.y) per ref
    float2 r0xw_s = gSMP_0.SampleLevel(gSMP_0Sampler, uv0xw, 0.0f).xy;

    // add r0.yz, r0.yz, v1.xy
    float2 uv0yz = r0yz + In.UV;
    // sample t0.xy → r0.yz = (t0.x, t0.y) per ref
    float2 r0yz_s = gSMP_0.SampleLevel(gSMP_0Sampler, uv0yz, 0.0f).xy;

    // add r2.xy, r4.xy, v1.xy
    float2 uv2 = r4xy + In.UV;
    // sample t0.xyzw → r2.xy = (t0.x, t0.y)
    float2 r2xy_s = gSMP_0.SampleLevel(gSMP_0Sampler, uv2, 0.0f).xy;

    // add r2.xy, r2.xy, r3.yz  (sum of two samples)
    r2xy_s += r3yz_s;
    // add r0.xw, r0.xw, r2.xy
    r0xw_s += r2xy_s;
    // add r0.xy, r0.yz, r0.xw  (final sum)
    float2 mvSum = r0yz_s + r0xw_s;

    // lt r0.z, r0.x, 4.0  → r0.z = (mvSum.x < 4)
    bool useMV = (mvSum.x < 4.0f);

    // mul r0.xy, r0.xy, (0.25, -0.25)  → average and negate y
    float2 mvAvg = mvSum * float2(0.25f, -0.25f);

    // Depth: ldms t1 with checkerboard sample index
    // ref: r1.z = Load(r1.xz, r3.x).x → depth = .x (R)
    uint halfX = r1yz.x >> 1u;
    float depth = gSMP_Depth1MS.Load(uint2(halfX, r1yz.y), r3x).x;

    // Linearize depth
    float r0w2 = depth * gFC_CameraParam.z + gFC_CameraParam.y;
    Out.o0.y = gFC_CameraParam.w / r0w2;

    // Reprojection path
    float2 ndc = In.UV * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f);
    float4 r1xyzw = float4(ndc, depth, 1.0f);
    float4 wp;
    wp.x = dot(r1xyzw, gFC_InvVP0);
    wp.y = dot(r1xyzw, gFC_InvVP1);
    wp.z = dot(r1xyzw, gFC_InvVP2);
    wp.w = dot(r1xyzw, gFC_InvVP3);
    float3 world = wp.xyz / wp.w + gFC_CamOffset.xyz;
    float4 wh = float4(world, 1.0f);
    float2 prevClip;
    prevClip.x = dot(wh, gFC_PrevVP0);
    prevClip.y = dot(wh, gFC_PrevVP1);
    float  prevW = dot(wh, gFC_PrevVP3);
    float2 prevUV = prevClip / prevW * float2(0.5f, -0.5f) + 0.5f;
    float2 mvReproj = In.UV - prevUV;

    // movc: use mvAvg if useMV, else mvReproj
    float2 mvFinal = useMV ? mvAvg : mvReproj;

    // Normalize and scale
    float2 mvN = mvFinal;
    float  lenSq = dot(mvN, mvN);
    float  normFactor = saturate(rsqrt(lenSq) * gFC_MotionParam.z);
    mvN = normFactor * mvN * gFC_MotionParam.xy;
    float  mvLen = sqrt(dot(mvN, mvN));

    Out.o0.x = 1.0f / mvLen;
    return Out;
}
