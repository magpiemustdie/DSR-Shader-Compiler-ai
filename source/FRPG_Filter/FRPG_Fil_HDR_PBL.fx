// FRPG_Fil_HDR_PBL.fx
// Reconstructed from DSR DXBC ps_5_0.
// PBL HDR tonemapper: Hable filmic curve + noise soft-light overlay.
// t0=HDR scene, t1=bloom, t2=noise (sampled at v1.zw — separate noise UV)
// cb0[54] = (exposureKey, whitePoint, minLum, maxLum)
// cb0[55] = (A, B, C, D)  — Hable curve params
// cb0[56] = (bloomScale, ?, adaptedLumMin, ?)
// cb0[68].x = noise blend strength
//
// DXBC trace:
//   r0.x = 0.0001 + cb0[56].z                    // adaptedLum floor
//   r1 = t0.Sample(v1.xy)                         // HDR
//   r2 = t1.Sample(v1.xy)                         // bloom
//   r1 = cb0[56].x * r2 + r1                      // col = bloom*scale + hdr
//   r0.y = dot(r1.rgb, lum_weights)               // lum
//   r0.y = max(r0.y, 0.0001)
//   r0.z = r0.y * cb0[54].x                       // lum * exposureKey
//   r0.x = r0.z / r0.x                            // exposure = lum*key / adaptedLum
//   r0.x = r0.x / r0.y                            // scale = exposure / lum
//   r0.xyz = r0.x * r1.xyz                        // exposed = scale * col
//   r1.w = saturate(r1.w)
//   [Hable numerator]   r2.xyz = A*exposed + B;   r2 = exposed*r2 + D*C
//   [Hable denominator] r4.xyz = A*exposed + B*C; r0 = exposed*r4 + D*B; r0 /= r2
//   [white point]       wp = cb0[54].z/cb0[54].w
//   [white scale]       whiteScale = f(whitePoint) - wp  (same curve applied to scalar)
//   r0 = saturate((r0 - wp) / whiteScale)
//   r1.xyz = exp2(log2(r0) * 0.454545)            // gamma 2.2
//   r0 = t2.Sample(v1.zw)                         // noise
//   [soft-light blend of r0(noise) onto r1(tonemapped)]
//   o0 = cb0[68].x * (blended - r1) + r1

#include "FRPG_Fil_Common.fxh"

Texture2D gSMP_Noise : register(t2); SamplerState gSMP_NoiseSampler : register(s2);

float4 gFC_ToneParam0 : register(c54); // x:exposureKey, y:whitePoint, z:minLum, w:maxLum
float4 gFC_ToneParam1 : register(c55); // x:A, y:B, z:C, w:D
float4 gFC_BloomScale : register(c56); // x:bloomScale, z:adaptedLumMin
float4 gFC_NoiseBlend : register(c68); // x:noise blend

struct FIL_IN_HDR
{
    float4 Pos : SV_Position;
    float4 UV  : TEXCOORD1; // xy=scene UV, zw=noise UV
};

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_HDR In)
{
    FIL_OUT Out;

    // Sample HDR + bloom, combine
    float4 hdr   = gSMP_0.Sample(gSMP_0Sampler, In.UV.xy);
    float4 bloom = gSMP_1.Sample(gSMP_1Sampler, In.UV.xy);
    float4 col   = gFC_BloomScale.x * bloom + hdr;

    // Luminance
    float lum = dot(col.rgb, float3(0.2126729f, 0.7151522f, 0.072175f));
    lum = max(lum, 0.0001f);

    // Exposure: scale = (lum * exposureKey / adaptedLum) / lum
    //         = exposureKey / adaptedLum
    // adaptedLum = 0.0001 + cb0[56].z
    float adaptedLum = 0.0001f + gFC_BloomScale.z;
    float scale      = (lum * gFC_ToneParam0.x / adaptedLum) / lum;
    float3 exposed   = scale * col.rgb;
    float  colW      = saturate(col.w);

    // Hable filmic tonemapper
    // numerator:   exposed * (A*exposed + C) + D*B
    // denominator: exposed * (A*exposed + B) + D*C
    // From DXBC:
    //   r2 = A*exposed + B  (cb0[55].x * r0 + cb0[55].y)
    //   r3.x = minLum*D     (cb0[54].z * cb0[55].w)  → numerator addend
    //   r3.y = maxLum*D     (cb0[54].w * cb0[55].w)  → denominator addend
    //   r2 = exposed*(A*exposed+B) + r3.y   => denominator
    //   r0.w = B*C          (cb0[55].y * cb0[55].z)
    //   r4 = A*exposed + r0.w    => A*exposed + B*C
    //   r0 = exposed*r4 + r3.x   => numerator
    //   r0 /= r2                 => numerator / denominator
    float3 A = gFC_ToneParam1.xxx;
    float3 B = gFC_ToneParam1.yyy;
    float3 C = gFC_ToneParam1.zzz;
    float3 D = gFC_ToneParam1.www;

    float  r3x = gFC_ToneParam0.z * gFC_ToneParam1.w; // cb0[54].z * cb0[55].w  = minLum * D
    float  r3y = gFC_ToneParam0.w * gFC_ToneParam1.w; // cb0[54].w * cb0[55].w  = maxLum * D
    float3 den = exposed * (A * exposed + B) + r3y;
    float3 r0w = B * C;                                // B*C (float3)
    float3 num = exposed * (A * exposed + r0w) + r3x;
    float3 tonemapped = num / den;

    float wp = gFC_ToneParam0.z / gFC_ToneParam0.w;
    float wy = gFC_ToneParam0.y;
    float wpDen = wy * (A.x * wy + B.x) + r3y;
    float wpNum = wy * (A.x * wy + r0w.x) + r3x;
    float wpCurve = wpNum / wpDen;
    float whiteScale = wpCurve - wp;

    float3 result = saturate((tonemapped - wp) / whiteScale);

    // Gamma 2.2
    float3 r1xyz = exp2(log2(result) * (5.0f/11.0f));
    float4 r1    = float4(r1xyz, colW);

    // Noise soft-light blend (t2 sampled at v1.zw)
    float4 r0n = gSMP_Noise.Sample(gSMP_NoiseSampler, In.UV.zw);

    // DXBC soft-light:
    //   r2 = r0*r1*2                                    (multiply blend)
    //   r3 = (0.5 >= r0) ? 1 : 0                        (mask: noise <= 0.5)
    //   r0 = 1 - r0; r0 = r0 + r0                       (2*(1-noise))
    //   r4 = (r3 != 0) ? 0 : 1                          (inverted mask)
    //   r3 = asuint(r3) & 1                              (r3 = mask as float 0/1)
    //   r2 = r2 * r4                                     (multiply branch: only where noise > 0.5)
    //   r4 = 1 - r1                                      (1 - tonemapped)
    //   r0 = 1 - r0*r4                                   (1 - 2*(1-noise)*(1-tonemapped))
    //   r0 = r0*r3 + r2                                  (combine branches)
    //   r0 = r0 - r1                                     (delta)
    //   o0 = cb0[68].x * r0 + r1                        (blend)
    float4 mul2  = r0n * r1 * 2.0f;
    float4 mask  = (float4)(r0n <= 0.5f);                // 1 where noise <= 0.5
    float4 inv2n = (1.0f - r0n) * 2.0f;                  // 2*(1-noise)
    float4 inv1r = 1.0f - r1;                             // 1-tonemapped
    float4 screen = 1.0f - inv2n * inv1r;                 // 1 - 2*(1-n)*(1-r)
    // multiply branch only fires where noise > 0.5 (mask==0)
    float4 invMask = 1.0f - mask;
    float4 blended = screen * mask + mul2 * invMask;
    float4 delta   = blended - r1;
    Out.Color = gFC_NoiseBlend.x * delta + r1;
    return Out;
}
