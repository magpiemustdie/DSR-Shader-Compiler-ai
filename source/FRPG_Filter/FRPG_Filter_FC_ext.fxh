// FRPG_Filter_FC_ext.fxh - extended DL_FREG registers c54-c87 for Filter shaders
// (subset of FRPG_Filter_FC.fxh; include AFTER FRPG_Fil_Common.fxh which owns c7-c53).
// Unused globals land in RDEF with [unused] flag - matches reference metadata-only members.

#ifndef ___FRPG_Filter_FC_ext_fxh___
#define ___FRPG_Filter_FC_ext_fxh___

    float4         DL_FREG_054              : register(c54); // [unused]
    float4         DL_FREG_055              : register(c55); // [unused]
    float4         DL_FREG_056              : register(c56); // [unused]
    float4         DL_FREG_057              : register(c57); // [unused]
    float4x4       DL_FREG_058              : register(c58); // [unused]
    float4x4       DL_FREG_062              : register(c62); // [unused]
    float4         DL_FREG_066              : register(c66); // [unused]
    float4         DL_FREG_067              : register(c67); // [unused]
    float4         DL_FREG_068              : register(c68); // [unused]
    float4         DL_FREG_069              : register(c69); // [unused]
    float4         DL_FREG_070              : register(c70); // [unused]
    float4         DL_FREG_071              : register(c71); // [unused]
    float4         DL_FREG_072              : register(c72); // [unused]
    float4         DL_FREG_073              : register(c73); // [unused]
    float4x4       DL_FREG_074              : register(c74); // [unused]
    float4         DL_FREG_078              : register(c78); // [unused]
    uint4          gFC_FrameIndex           : register(c81); // [unused]
    float4x4       gVC_WorldViewClipMtx     : register(c82); // [unused]
    float4         gVC_ScreenSize           : register(c86); // [unused]
    float4         gVC_NoiseParam           : register(c87); // [unused]

#endif
