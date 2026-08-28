// FRPG_Snow_All.fx – Master entry point for all snow shader variants
// Entry point: FragmentMain

#define ENABLE_FS
#ifdef WITH_GBuffer
#define USE_SH 1
#endif

// HeightMap pass
#ifdef WITH_HeightMap
#include "FRPG_Snow_Common_new.fxh"

struct HM_OUT { float4 Color : SV_Target0; };

HM_OUT FragmentMain(HM_IN In)
{
    HM_OUT Out;
    // NOTE: written xy-first; retail scheduler emits zw-sample first, matching ref
    float3 s1 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, In.TexUV.xy).xyz;
    float h = dot(s1, float3(1.0f, 1.0f, 1.0f)) * gFC_SnowTileBlend.x * (1.0f/3.0f);
    float3 s0 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, In.TexUV.zw).xyz;
    h += dot(s0, float3(1.0f, 1.0f, 1.0f)) * gFC_SnowTileBlend.y * (1.0f/3.0f);
    float3 s2 = gSMP_BumpMap.Sample(gSMP_BumpMapSampler, In.TexUV2.xy).xyz;
    h += dot(s2, float3(1.0f, 1.0f, 1.0f)) * gFC_SnowTileBlend.z * (1.0f/3.0f);
    float fade = saturate((-In.TexUV2.z + gFC_WaterWaveParam.z) / gFC_WaterWaveParam.z);
    Out.Color = float4(-h * fade + 1.0f, 1.0f, 1.0f, 1.0f);
    return Out;
}

#elif defined(WITH_GBuffer)

// GBuffer pass — different input/output layout
#define USE_SH 1
#include "FRPG_Snow_GBuffer.fx"

#else // main forward snow pass

#include "FRPG_Snow_Common_new.fxh"
#include "FRPG_Snow_Forward.fx"

struct SNOW_OUT {
    float4 Color : SV_Target0;
    float4 GBuf1 : SV_Target1;
};

SNOW_OUT FragmentMain(SNOW_IN In)
{
    SNOW_OUT_FWD fwd = FragmentMain_Forward(In);
    SNOW_OUT Out;
    Out.Color = fwd.Color;
    Out.GBuf1 = fwd.GBuf1;
    return Out;
}

#endif
