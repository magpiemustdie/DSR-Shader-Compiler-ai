// FRPG_Water_Common.fxh
// Shared structures, texture declarations, and cbuffer constants for water shaders.

#ifndef FRPG_WATER_COMMON_FXH
#define FRPG_WATER_COMMON_FXH

// ---------------------------------------------------------------------------
// Textures (base Env/Reflect variants)
// ---------------------------------------------------------------------------
Texture2D    gSMP_DiffuseMap     : register(t1);
SamplerState gSMP_DiffuseMapSampler : register(s1);
Texture2D    gSMP_NormalMap      : register(t2);
SamplerState gSMP_NormalMapSampler  : register(s2);
Texture2D    gSMP_MaskMap        : register(t3);
SamplerState gSMP_MaskMapSampler    : register(s3);
struct s_lightWater {
    float4 position;
    float4 color;
};
StructuredBuffer<uint> gLightGrid          : register(t16);
StructuredBuffer<uint> gLightIndexList     : register(t17);
StructuredBuffer<s_lightWater> gLightDataBuffer : register(t18);

// TextureCube for environment water
TextureCube  gSMP_EnvMap         : register(t12);
SamplerState gSMP_EnvMapSampler  : register(s12);

// Texture2D for screen-space reflection water
Texture2D    gSMP_ReflectionMap  : register(t0);
SamplerState gSMP_ReflectionMapSampler : register(s0);

// Height map texture
Texture2D    gSMP_HeightMap      : register(t2);
SamplerState gSMP_HeightMapSampler  : register(s2);

// Wave mask texture
Texture2D    gSMP_WaveMask       : register(t0);
SamplerState gSMP_WaveMaskSampler   : register(s0);

// ---------------------------------------------------------------------------
// cbuffer: Water specific constants (non-OLD_VERSION layout from FC)
// Water reuses light scattering slots (cb0[13-20]) for its own BRDF params.
// ---------------------------------------------------------------------------
float4 gFC_SpcLightVec             : FC_REG(c5);
float4 gFC_SpcLightCol             : FC_REG(c6);
float4 gFC_SpcParam                : FC_REG(c11);
float4 gFC_FogCol                  : FC_REG(c12);
float4 gFC_WaterFresnelAttn        : FC_REG(c13);
float4 gFC_WaterSpecColor          : FC_REG(c14);
float4 gFC_WaterRoughness          : FC_REG(c15);
float4 gFC_WaterGGXInner           : FC_REG(c16);
float4 gFC_WaterGGXA               : FC_REG(c17);
float4 gFC_WaterGGXB               : FC_REG(c18);
float4 gFC_WaterSpecTint           : FC_REG(c19);
float4 gFC_WaterFresnelFactors     : FC_REG(c20);

float  gFC_WaterReflectBand        : FC_REG(c24);
float  gFC_WaterRefractBand        : FC_REG(c25);
float  gFC_WaterWaveHeight         : FC_REG(c26);
float4 gFC_WaterColor              : FC_REG(c27);
float2 gFC_WaterFadeBegin          : FC_REG(c28);
float  gFC_WaterFresnelPow         : FC_REG(c29);
float  gFC_WaterFresnelBias        : FC_REG(c30);
float  gFC_WaterFresnelScale       : FC_REG(c31);
float4 gFC_WaterFresnelColor       : FC_REG(c32);
float4 gFC_WaterFresnelFakeColor   : FC_REG(c33);
float3 gFC_WaterTileBlend          : FC_REG(c34);

float4x4 gFC_WorldViewClipMtx      : FC_REG(c63);
uint4    gFC_PntLightCount          : FC_REG(c81);
float4   gFC_ClipInfo               : FC_REG(c86);
float4   gFC_ClusterParam           : FC_REG(c87);
float4   gFC_SAOParams              : FC_REG(c90);
float4   gFC_WaterWaveParam         : FC_REG(c61);
float4   gFC_WaterHeightMapSize     : FC_REG(c62);

// ---------------------------------------------------------------------------
// Input structures
// ---------------------------------------------------------------------------
struct WATER_IN_BASE {
    float4 Pos       : SV_Position;
    float4 WorldPos  : TEXCOORD0;
    float4 Fog       : TEXCOORD1;
    float4 WorldNrm  : TEXCOORD2;
    float4 Unused3   : TEXCOORD3;
    float4 Color     : COLOR0;
    float4 TanFrameA : TEXCOORD6;
    float4 TanFrameB : TEXCOORD7;
    float4 ProjUV_A  : TEXCOORD8;
    float4 ProjUV_B  : TEXCOORD9;
};

struct WATER_OUT {
    float4 Color : SV_Target0;
};

struct MASK_IN {
    float4 Pos     : SV_Position;
    float2 UV      : TEXCOORD0;   // declared-unread in reference ISGN
};

struct MASK_OUT {
    float4 Color1 : SV_Target1;
};

struct HM_IN {
    float4 Pos  : SV_Position;
    float4 TexA : TEXCOORD0;   // ref ISGN: TEXCOORD0 xyzw
    float4 TexB : TEXCOORD1;   // ref ISGN: TEXCOORD1 xyzw
};

struct HM_OUT {
    float4 Color : SV_Target0;
};

struct WV_IN {
    float4 Pos     : SV_Position;
    float4 MulA    : COLOR0;
    float4 MulB    : COLOR1;
    float2 TexUV   : TEXCOORD7;
};

struct WV_OUT {
    float4 Color : SV_Target0;
};

struct WV_MUL_IN {
    float4 Pos     : SV_Position;
    float4 MulA    : COLOR0;
    float4 MulB    : COLOR1;
    float4 TexUV   : TEXCOORD7;
};

// ---------------------------------------------------------------------------
// Clustered light loop: matches Env____ / Reflect____ assembly pattern
// ---------------------------------------------------------------------------
float3 AccumulateClusteredLights(float3 worldPos, float3 R, float specPower)
{
    float4 wp4 = float4(worldPos, 1.0f);
    float4 clipPos = mul(wp4, gFC_WorldViewClipMtx);
    clipPos.xyz /= clipPos.w;

    float2 tile = floor(saturate(clipPos.xy * 0.5f + 0.5f) * float2(16.0f, 8.0f));
    tile = min(tile, float2(15.0f, 7.0f));

    float linZ = gFC_ClipInfo.w / (clipPos.z * gFC_ClipInfo.z + gFC_ClipInfo.y);
    linZ /= gFC_ClipInfo.x;
    float sliceF = min(log2(linZ) * gFC_ClusterParam.x, 23.0f);

    uint tileX   = (uint)tile.x;
    uint tileY   = (uint)tile.y;
    uint slice   = (uint)sliceF;
    uint flatIdx = tileX + (tileY + slice * 8u) * 16u;
    uint packed  = gLightGrid[flatIdx];

    uint lightCount = min(packed & 63u, gFC_PntLightCount.x);
    uint lightStart = packed >> 12u;
    uint lightEnd   = lightStart + lightCount;

    float3 accum = 0;

    [loop]
    while (lightStart < lightEnd) {
        uint lid = gLightIndexList[lightStart] & 511u;

        s_lightWater lt = gLightDataBuffer[lid];
        float4 lpos = lt.position;
        float4 lcol = lt.color;

        float3 L    = lpos.xyz - worldPos;
        float  dist = sqrt(dot(L, L));

        if (dist < lcol.w) {
            L /= dist;

            float NdotL = max(dot(R, L), 0.0f);
            float spec  = exp2(log2(NdotL) * specPower);

            float atten  = (lcol.w - dist) * lpos.w;
            atten = saturate(atten);

            accum += spec * lcol.xyz * atten;
        }
        lightStart++;
    }
    return accum;
}

// ---------------------------------------------------------------------------
// Water wave normal reconstruction from 2-layer height samples
// ---------------------------------------------------------------------------
float3 ReconstructWaveNormal(float2 hA, float2 hB, float3 tanA, float3 tanB, float waveStr)
{
    float hDeltaX = hA.x - hA.y;  // half-difference for first layer
    float hDeltaY = hB.x - hB.y;

    float3 n1 = normalize(float3(tanA.y + tanA.y + hDeltaX * waveStr,
                                 tanA.z * 2.0f,
                                 tanA.x * 2.0f));

    float3 n2 = normalize(float3(tanB.y + tanB.y + hDeltaY * waveStr,
                                 tanB.z * 2.0f,
                                 tanB.x * 2.0f));

    return cross(n1.zxy * n2.yzx, n1.yzx * n2.zxy);
}

#endif // FRPG_WATER_COMMON_FXH
