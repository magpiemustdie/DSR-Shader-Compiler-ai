// FRPG_Fil_HDR_PBL_ColAdj.fx
// Reconstructed from DSR DXBC.
// PBL HDR + color adjustment: 3 tonemapper modes, color matrix, noise overlay.
// t0=HDR scene, t1=bloom, t2=noise, t3=color adjust, t5=adapted lum (1x1)
// cb0[54] = (exposureKey, whitePoint, minLum, maxLum)
// cb0[55] = (A, B, C, D)  — Hable curve params
// cb0[56] = (bloomScale, bloomScale2, adaptedLumMin, adaptedLumMax)
// cb0[57].x = tonemapper mode (uint: 0=Hable, 1=Reinhard, 2=Reinhard2)
// cb0[62..64] = color matrix rows (with alpha)
// cb0[68].x = noise blend
// cb0[71].y = bloom lerp target

#include "FRPG_Fil_Common.fxh"

Texture2D gSMP_ColAdj  : register(t3); SamplerState gSMP_ColAdjSampler  : register(s3);
Texture2D gSMP_AdpLum  : register(t5); SamplerState gSMP_AdpLumSampler  : register(s5);
// t2 = noise (gSMP_2 not in Common, declare here)
Texture2D    gSMP_2 : register(t2);
SamplerState gSMP_2Sampler : register(s2);

float4 gFC_ToneParam0  : register(c54); // x:exposureKey, y:whitePoint, z:minLum, w:maxLum
float4 gFC_ToneParam1  : register(c55); // x:A, y:B, z:C, w:D
float4 gFC_BloomParam2 : register(c56); // x:bloomScale, y:bloomScale2, z:adaptedLumMin, w:adaptedLumMax
float4 gFC_ToneMode    : register(c57); // x:mode (uint)
float4 gFC_ColMtxR     : register(c62);
float4 gFC_ColMtxG     : register(c63);
float4 gFC_ColMtxB     : register(c64);
float4 gFC_NoiseBlend  : register(c68); // x:noise blend
float4 gFC_BloomLerp   : register(c71); // y:bloom lerp target

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN4 In)
{
    FIL_OUT Out;

    // Sample inputs (v1.xy for scene, v1.xy for bloom/colAdj)
    float3 hdr   = max(gSMP_0.Sample(gSMP_0Sampler, In.UV.xy).rgb, 0.000001f);
    // t1.wxyz → bloom.x=t1.w (alpha/mask), bloom.yzw=t1.xyz (rgb)
    float4 bloom = gSMP_1.Sample(gSMP_1Sampler, In.UV.xy).wxyz;
    bloom.yzw    = max(bloom.yzw, 0.000001f);
    bloom.x      = saturate(bloom.x);
    float3 colAdj = gSMP_ColAdj.Sample(gSMP_ColAdjSampler, In.UV.xy).rgb;

    // Bloom lerp + color adjust blend
    float bloomLerp = bloom.x * (-gFC_BloomParam2.x + gFC_BloomLerp.y) + gFC_BloomParam2.x;
    float3 col = bloomLerp * bloom.yzw + hdr;
    col = gFC_BloomParam2.y * colAdj + col;

    float3 result;
    switch ((uint)gFC_ToneMode.x)
    {
    case 0:
        {
            // Hable filmic — exact DXBC trace:
            // exposed = (exposureKey / adaptedLum) * col
            // num = exposed*(A*exposed + B*C) + minLum*D
            // den = exposed*(A*exposed + B)   + maxLum*D
            // tonemapped = num/den
            // wp = minLum/maxLum
            // whiteScale = f(whitePoint) - wp  where f(x) = (x*(A*x+B*C)+minLum*D) / (x*(A*x+B)+maxLum*D)
            // result = (tonemapped - wp) / whiteScale
            float adaptedLum = gSMP_AdpLum.Sample(gSMP_AdpLumSampler, float2(0.5f, 0.5f)).y;
            adaptedLum = max(adaptedLum, gFC_BloomParam2.z);
            adaptedLum = min(adaptedLum, gFC_BloomParam2.w);
            adaptedLum += 0.0001f;
            float3 exposed = (gFC_ToneParam0.x / adaptedLum) * col;
            float  BC  = gFC_ToneParam1.y * gFC_ToneParam1.z;  // B*C
            float  minD = gFC_ToneParam0.z * gFC_ToneParam1.w; // minLum*D
            float  maxD = gFC_ToneParam0.w * gFC_ToneParam1.w; // maxLum*D
            float3 num = exposed * (gFC_ToneParam1.x * exposed + BC) + minD;
            float3 den = exposed * (gFC_ToneParam1.x * exposed + gFC_ToneParam1.y) + maxD;
            float3 tonemapped = num / den;
            float  wp = gFC_ToneParam0.z / gFC_ToneParam0.w;
            float3 r2 = tonemapped - wp;
            // f(whitePoint)
            float  wy = gFC_ToneParam0.y;
            float  wpNum = wy * (gFC_ToneParam1.x * wy + BC) + minD;
            float  wpDen = wy * (gFC_ToneParam1.x * wy + gFC_ToneParam1.y) + maxD;
            float  whiteScale = wpNum / wpDen - wp;
            result = r2 / whiteScale;
            break;
        }
    case 1:
        {
            // Reinhard
            float adaptedLum = gSMP_AdpLum.Sample(gSMP_AdpLumSampler, float2(0.5f, 0.5f)).y;
            adaptedLum = max(adaptedLum, gFC_BloomParam2.z);
            adaptedLum = min(adaptedLum, gFC_BloomParam2.w);
            adaptedLum += 0.0001f;
            float3 exposed = (gFC_ToneParam0.x / adaptedLum) * col;
            float lum = max(dot(exposed, float3(0.2126729f, 0.7151522f, 0.072175f)), 0.0001f);
            float lumTM = lum / (lum + 1.0f);
            result = (exposed / lum) * lumTM;
            break;
        }
    case 2:
        {
            // Reinhard2 (with white point)
            float adaptedLum = gSMP_AdpLum.Sample(gSMP_AdpLumSampler, float2(0.5f, 0.5f)).y;
            adaptedLum = max(adaptedLum, gFC_BloomParam2.z);
            adaptedLum = min(adaptedLum, gFC_BloomParam2.w);
            adaptedLum += 0.0001f;
            float3 exposed = (gFC_ToneParam0.x / adaptedLum) * col;
            float lum = max(dot(exposed, float3(0.2126729f, 0.7151522f, 0.072175f)), 0.0001f);
            float wp2 = gFC_ToneParam0.y * gFC_ToneParam0.y;
            float lumTM = lum * (1.0f + lum / wp2) / (lum + 1.0f);
            result = (exposed / lum) * lumTM;
            break;
        }
    default:
        {
            result = float3(1.0f, 0.0f, 1.0f); // magenta = error
            break;
        }
    }

    result = saturate(result);

    // Gamma 2.2
    result = exp2(log2(result) * (5.0f/11.0f));

    // Color matrix
    float4 r4 = float4(result, 1.0f);
    float3 colMtx;
    colMtx.x = dot(r4, gFC_ColMtxR);
    colMtx.y = dot(r4, gFC_ColMtxG);
    colMtx.z = dot(r4, gFC_ColMtxB);

    // Noise overlay (soft-light blend)
    // DXBC: multiply (2*n*c) where noise > 0.5, screen (1-2*(1-n)*(1-c)) where noise <= 0.5
    float3 noise = gSMP_2.Sample(gSMP_2Sampler, In.UV.zw).rgb;
    float3 mul2   = noise * colMtx * 2.0f;                    // multiply blend
    float3 inv2n  = (1.0f - noise) * 2.0f;                    // 2*(1-noise)
    float3 inv1c  = 1.0f - colMtx;                            // 1-colMtx
    float3 screen = 1.0f - inv2n * inv1c;                     // screen blend
    float3 mask   = (float3)(noise <= 0.5f);                  // 1 where noise <= 0.5
    float3 invMask = 1.0f - mask;                             // 1 where noise > 0.5
    // screen where noise<=0.5, multiply where noise>0.5
    float3 blended = screen * mask + mul2 * invMask;
    float3 delta = blended - colMtx;
    float3 final = gFC_NoiseBlend.x * delta + colMtx;

    Out.Color.rgb = final;
    Out.Color.a   = dot(final, float3(0.299f, 0.587f, 0.114f));
    return Out;
}
