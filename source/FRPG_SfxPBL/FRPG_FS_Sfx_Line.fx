// FRPG_FS_Sfx_Line.fx — SFX Line pixel shader (LineType0)
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11)
// Compile: /E FragmentMain /T ps_5_0 /DLINE_TYPE=0
// No diffuse texture: COLOR0/COLOR1, gamma round-trip, fog, tone map

#ifndef LINE_TYPE
#define LINE_TYPE 0
#endif
#define SFXPBL_HAS_ALPHATEST
#include "FRPG_SfxPBL_Common.fxh"

struct LINE_PS_IN
{
    float4 Pos    : SV_Position;
    float4 Color0 : COLOR0;
    float2 Color1 : COLOR1;
};

float4 FragmentMain(LINE_PS_IN In) : SV_Target0
{
    float3 lin = pow(abs(In.Color0.xyz), 1.0f / 2.2f);
    float3 fogged = lerp(lin * 0.5f, g_fog_color.xyz, g_fog_color.w * In.Color1.y);
    float alpha = In.Color0.w * (1.0f - In.Color1.x * g_fog_color.w);
    if (AlphaTest == 1 && AlphaTestRef.x >= alpha) discard;
    float3 col = pow(abs(fogged), 2.2f);
    return SfxToneMap(float4(col, alpha));
}
