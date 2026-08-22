// FRPG_Water_HeightMap.fx — Water height map shader
// Reconstructed from FRPG_Water_HeightMap.fpo.hlsl
// Samples 3 height tiles and blends with depth fade.

#include "FRPG_Water_Common.fxh"

HM_OUT FragmentMain_WaterHeightMap(HM_IN In)
{
    float4 h0 = gSMP_HeightMap.Sample(gSMP_HeightMapSampler, In.TexA.zw);
    float h0sum = dot(h0.xyz, 1.0f) * gFC_WaterTileBlend.y * (1.0f / 3.0f);

    float4 h1 = gSMP_HeightMap.Sample(gSMP_HeightMapSampler, In.TexA.xy);
    float h1sum = dot(h1.xyz, 1.0f) * gFC_WaterTileBlend.x * (1.0f / 3.0f);

    float4 h2 = gSMP_HeightMap.Sample(gSMP_HeightMapSampler, In.TexB.xy);
    float h2sum = dot(h2.xyz, 1.0f) * gFC_WaterTileBlend.z * (1.0f / 3.0f);

    float height = h0sum + h1sum + h2sum;

    float depthFade = saturate((gFC_WaterWaveParam.y - In.TexB.z) / gFC_WaterWaveParam.y);

    HM_OUT Out;
    Out.Color.x = depthFade * height;
    Out.Color.yzw = float3(1.0f, 1.0f, 1.0f);
    return Out;
}
