// FRPG_FS_Sfx_PointSprite.fx вЂ” SFX PointSprite pixel shader (PointSpriteType0)
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11)
// Compile: /E FragmentMain /T ps_5_0 /DPOINT_SPRITE_TYPE=0
// Diffuse (uv = COLOR1.zw) * nointerp COLOR0, gamma round-trip, fog, rim (DL_FREG_7), tone

#ifndef POINT_SPRITE_TYPE
#define POINT_SPRITE_TYPE 0
#endif
#define SFXPBL_HAS_ALPHATEST
#define SFXPBL_C4_IS_DL_FREG_004
#include "FRPG_SfxPBL_Common.fxh"

struct POINTSPRITE_PS_IN
{
    float4 Pos : SV_Position;
    nointerpolation float4 Color0 : COLOR0;
    float4 Color1 : COLOR1;          // xy = fog, zw = diffuse uv
    float4 Rim1 : TEXCOORD0;
    float3 Rim2 : TEXCOORD1;
};

float4 FragmentMain(POINTSPRITE_PS_IN In) : SV_Target0
{
    float4 dif = gSMP_0.Sample(gSMP_0Sampler, In.Color1.zw) * In.Color0;
    float3 lin = pow(abs(dif.xyz), 1.0f / 2.2f);
    float3 fogged = lerp(lin, g_fog_color.xyz, g_fog_color.w * In.Color1.y);
    float alpha = dif.w * (1.0f - In.Color1.x * g_fog_color.w);
    float3 rimA = fogged.xyz * In.Rim1.xyz + In.Rim2.xyz;
    float4 rimDiff4 = float4(rimA - fogged.xyz, 0.0f);
    float4 Out = mad(DL_FREG_7.x, rimDiff4, float4(fogged, alpha));
    if (AlphaTestRef.x >= Out.w) { if (AlphaTest == 1) discard; }
    Out.xyz = pow(abs(Out.xyz), 2.2f);
    return SfxToneMap(Out);
}
