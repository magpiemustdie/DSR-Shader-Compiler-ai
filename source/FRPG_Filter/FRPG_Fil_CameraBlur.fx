// FRPG_Fil_CameraBlur.fx
// Reconstructed from DSR DXBC ps_5_0.
// Camera motion blur: 7 samples along motion vector, depth-tested.
// t0=scene(s0), t1=depth(s1), t2=velocity(s2)
// cb0[38].yzw, cb0[39].xyzw = 7 sample weights
// cb0[57].x = blur scale
// cb0[58..61] = reprojection matrix (rows 0,1,3 used)
//
// DXBC trace:
//   r0.z = t1.Sample(UV)                    // center depth
//   r0.xy = UV; r0.w = 1
//   r1.x = dot(r0, cb0[58])                 // reproject X
//   r1.y = dot(r0, cb0[59])                 // reproject Y
//   r0.x = dot(r0, cb0[61])                 // reproject W
//   r0.xy = r1.xy / r0.x                    // prevUV (NDC)
//   r0.xy = -r0.xy + UV                     // motion = UV - prevUV
//   r1.xyz = t2.Sample(UV)                  // velocity texture
//   r0.zw = r1.xy - 0.498040               // decode velocity
//   r0.xy = r0.zw * 2 + r0.xy              // add decoded velocity to motion
//   r0.xy *= cb0[57].x                     // scale
//   [7 samples at t=0.125..0.875, depth-tested, weighted by cb0[38..39]]
//   totalW = sum of weights where depth >= center depth
//   o0.xyz = center * (1 - totalW) + acc
//   o0.w = 1

#include "FRPG_Fil_Common.fxh"

Texture2D    gSMP_2 : register(t2);
SamplerState gSMP_2Sampler : register(s2);

float4 gFC_CameraBlurScale : register(c57); // x:scale
float4 gFC_ReprojectRow0   : register(c58);
float4 gFC_ReprojectRow1   : register(c59);
float4 gFC_ReprojectRow3   : register(c61);

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    // Center depth — must be first (matches ASM order)
    float centerDepth = gSMP_1.Sample(gSMP_1Sampler, In.UV).y;  // t1.yzxw → .y

    // Reproject UV+depth to get previous frame UV
    float4 r0 = float4(In.UV.x, In.UV.y, centerDepth, 1.0f);
    float2 prevXY;
    prevXY.x = dot(r0, gFC_ReprojectRow0);
    prevXY.y = dot(r0, gFC_ReprojectRow1);
    float  prevW = dot(r0, gFC_ReprojectRow3);
    float2 prevUV = prevXY / prevW;

    // Motion = UV - prevUV
    float2 motion = In.UV - prevUV;

    // Add decoded velocity from t2 — read after reprojection
    float2 vel = gSMP_2.Sample(gSMP_2Sampler, In.UV).xy;
    float2 velDecoded = vel.xy - 0.498040f;
    motion = velDecoded * 2.0f + motion;

    // Scale
    motion *= gFC_CameraBlurScale.x;

    // 7 sample weights from cb0[38].yzw and cb0[39].xyzw
    float weights[7] = {
        gFC_avSampleWeights0.y, gFC_avSampleWeights0.z, gFC_avSampleWeights0.w,
        gFC_avSampleWeights1.x, gFC_avSampleWeights1.y, gFC_avSampleWeights1.z,
        gFC_avSampleWeights1.w
    };
    float tvals[7] = { 0.125f, 0.25f, 0.375f, 0.5f, 0.625f, 0.75f, 0.875f };

    float4 acc    = 0.0f;
    float  totalW = 0.0f;

    [unroll]
    for (int i = 0; i < 7; i++)
    {
        float2 sUV = motion * tvals[i] + In.UV;
        // ref depth-tests each tap against the COLOR sample's alpha channel
        // (t0.w), not a separate t1 fetch
        float4 s   = gSMP_0.Sample(gSMP_0Sampler, sUV);
        float  w   = (float)(s.w >= centerDepth) * weights[i];
        acc    += float4(s.rgb * w, w);
        totalW += w;
    }

    float3 center = gSMP_0.Sample(gSMP_0Sampler, In.UV).rgb;
    Out.Color.rgb = center * (1.0f - totalW) + acc.rgb;
    Out.Color.a   = 1.0f;
    return Out;
}
