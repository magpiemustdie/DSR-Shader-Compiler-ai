// FRPG_Fil_HDR.fx
// Reconstructed from DSR DXBC ps_5_0.
// HDR composite: bloom + scene with soft-light noise overlay.
// t0=scene(s0), t1=bloom(s1), t2=noise(s2, v1.zw UV)
// cb0[56].x=bloomScale, cb0[56].z=sceneScale
// cb0[68].x=noise blend weight

#include "FRPG_Fil_Common.fxh"

Texture2D    gSMP_2 : register(t2);
SamplerState gSMP_2Sampler : register(s2);

float4 gFC_PostEffectScale2 : register(c56); // x:bloomScale, z:sceneScale
float4 gFC_NoiseParam2      : register(c68); // x:noise blend

struct FIL_IN_HDR { float4 Pos : SV_Position; float4 UV : TEXCOORD1; };
struct FIL_OUT    { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_HDR In)
{
    FIL_OUT Out;

    float4 bloom = gSMP_1.Sample(gSMP_1Sampler, In.UV.xy);
    float4 scene = gSMP_0.Sample(gSMP_0Sampler, In.UV.xy);
    scene.xyz = saturate(scene.xyz * gFC_PostEffectScale2.z);
    scene.w   = saturate(scene.w);
    float4 hdr = gFC_PostEffectScale2.x * bloom + scene;

    float4 noise = gSMP_2.Sample(gSMP_2Sampler, In.UV.zw);

    // Soft-light blend: multiply where noise<0.5, screen where noise>=0.5
    float4 mul2   = hdr * noise * 2.0f;
    float4 inv2n  = (1.0f - noise) * 2.0f;
    float4 inv1h  = 1.0f - hdr;
    float4 screen = 1.0f - inv2n * inv1h;
    float4 mask   = (float4)(noise < 0.5f);
    float4 blended = mul2 * mask + screen * (1.0f - mask);
    float4 delta   = blended - hdr;
    Out.Color = gFC_NoiseParam2.x * delta + hdr;
    return Out;
}
