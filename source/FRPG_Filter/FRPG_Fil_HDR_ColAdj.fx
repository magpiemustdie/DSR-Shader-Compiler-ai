// FRPG_Fil_HDR_ColAdj.fx
// Reconstructed from DSR DXBC ps_5_0.
// HDR + color adjustment matrix + soft-light noise overlay.
// t0=scene(s0), t1=bloom(s1), t2=noise(s2,v1.zw), t3=star(s3)
// cb0[56]=PostEffectScale, cb0[62..65]=ColorAdjustMatrix, cb0[68]=NoiseParam, cb0[71]=BloomDistParam

#include "FRPG_Fil_Common.fxh"

float4 gFC_PostEffectScale3 : register(c56);
float4 gFC_ColorAdjMtx0     : register(c62);
float4 gFC_ColorAdjMtx1     : register(c63);
float4 gFC_ColorAdjMtx2     : register(c64);
float4 gFC_ColorAdjMtx3     : register(c65);
float4 gFC_NoiseParam3      : register(c68);
float4 gFC_BloomDistParam3  : register(c71);

Texture2D gSMP_Noise3 : register(t2); SamplerState gSMP_Noise3Sampler : register(s2);
Texture2D gSMP_Star   : register(t3); SamplerState gSMP_StarSampler   : register(s3);

struct FIL_IN_HDR { float4 Pos : SV_Position; float4 UV : TEXCOORD1; };
struct FIL_OUT    { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_HDR In)
{
    FIL_OUT Out;

    float3 scene = gSMP_0.Sample(gSMP_0Sampler, In.UV.xy).rgb;
    scene = saturate(scene * gFC_PostEffectScale3.z);

    float4 bloom = gSMP_1.Sample(gSMP_1Sampler, In.UV.xy);
    float bloomBlend = gFC_BloomDistParam3.y - gFC_PostEffectScale3.x;
    float blendFactor = bloom.w * bloomBlend + gFC_PostEffectScale3.x;
    scene = blendFactor * bloom.rgb + scene;

    float3 star = gSMP_Star.Sample(gSMP_StarSampler, In.UV.xy).rgb;
    scene = gFC_PostEffectScale3.y * star + scene;

    float4 s4 = float4(scene, 1.0f);
    float3 adjusted;
    adjusted.x = dot(s4, gFC_ColorAdjMtx0);
    adjusted.y = dot(s4, gFC_ColorAdjMtx1);
    adjusted.z = dot(s4, gFC_ColorAdjMtx2);
    float  adjustedW = dot(s4, gFC_ColorAdjMtx3);  // dp4 r1.w — must be before noise sample

    float4 noise = gSMP_Noise3.Sample(gSMP_Noise3Sampler, In.UV.zw);
    float4 base  = float4(adjusted, adjustedW);

    // Soft-light blend on all 4 channels: ref does mul where noise>=0.5, screen where noise<0.5
    float4 mul2   = base * noise * 2.0f;
    float4 inv2n  = (1.0f - noise) * 2.0f;
    float4 inv1b  = 1.0f - base;
    float4 screen = 1.0f - inv2n * inv1b;
    float4 mask   = (float4)(noise >= 0.5f);
    float4 blended = mul2 * mask + screen * (1.0f - mask);
    float4 delta   = blended - base;
    float4 result  = gFC_NoiseParam3.x * delta + base;

    Out.Color.xyz = result.xyz;
    Out.Color.w   = result.w;  // w channel from soft-light (matches ASM xyzw operations)
    return Out;
}
