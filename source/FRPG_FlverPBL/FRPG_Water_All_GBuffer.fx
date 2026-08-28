// FRPG_Water_All_GBuffer.fx — Entry point for water GBuffer (PntSS/PntSSSS) variants.
// NEW reconstruction (AGENTS.md п.19): unified body in FRPG_Water_GB_new.fx with
// auto-generated OLD_VERSION DL_FREG layout in FRPG_Water_GB_FC_new.fxh.
//
// Define contract (ShaderBuilder.BuildWater):
//   WATER_ENV | WATER_REFLECT            reflection source
//   WITH_ShadowMap=1|2                   Ncs / Csd (declares t7/s7; code identical)
//   WITH_GBUFFER_4LIGHTS                 PntSSSS (4 static lights + per-light spec)

#include "FRPG_Water_GB_new.fx"

WATER_GB_OUT FragmentMain(
    float4 v0  : SV_Position0,
    float4 v1  : TEXCOORD0,
    float4 v2  : TEXCOORD1,
    float4 v3  : TEXCOORD2,
    float4 v4  : TEXCOORD3,
    float4 v5  : COLOR0,
    float4 v6  : TEXCOORD5,
    float4 v7  : TEXCOORD6,
    float4 v8  : TEXCOORD7,
    float4 v9  : TEXCOORD8,
    float4 v10 : TEXCOORD9)
{
    return FragmentMain_WaterGB(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10);
}
