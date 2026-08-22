// FRPG_Fil_BrightPassFilter.fx
// Reconstructed from DSR DXBC ps_5_0.
// t0=HDR color(s0), t2=luminance/depth(s2)
// cb0[8]  = CameraParam (x:near*far, y:far)
// cb0[11] = BloomParam  (x:bloom threshold low)
// cb0[71] = BloomDistParam (x:bloom threshold high, z:dist start, w:dist end)
//
// Референс ps_3.0 (.fpo.asm) использует DecodeDepthTexture (dp3) на t2.
// DSR ps_5_0 хранит depth/luminance как raw float в .r — dp3 не нужен.
// Linearized: linDepth = lerp(far, near*far, depth) = far + depth*(near*far-far)
// Exposure: near*far / linDepth
// Bloom rate: saturate((exposure - distStart/far) / ((distEnd-distStart)/far))
// Output: out.rgb = max(scene - threshold, 0) / (1-threshold)

#include "FRPG_Fil_Common.fxh"

Texture2D    gSMP_2 : register(t2);
SamplerState gSMP_2Sampler : register(s2);
float4 gFC_BloomDistParam : register(c71);

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float depth = gSMP_2.Sample(gSMP_2Sampler, In.UV).r;

    float r0y  = -gFC_CameraParam.y + gFC_CameraParam.x;
    float r0x  = depth * r0y + gFC_CameraParam.y;
    float exposure = gFC_CameraParam.x / r0x;

    float distStartN = gFC_BloomDistParam.z / gFC_CameraParam.y;
    float distEndN   = gFC_BloomDistParam.w / gFC_CameraParam.y;
    float bloomRate  = saturate((exposure - distStartN) / (distEndN - distStartN));

    float bloomScale = bloomRate * (gFC_BloomDistParam.x - gFC_BloomParam.x) + gFC_BloomParam.x;
    Out.Color.a = bloomRate;

    float4 hdr = gSMP_0.Sample(gSMP_0Sampler, In.UV);

    float3 bright = max(hdr.rgb - bloomScale, 0.0f);
    float  denom  = 1.0f - bloomScale;
    Out.Color.rgb = saturate(bright / denom);

    return Out;
}
