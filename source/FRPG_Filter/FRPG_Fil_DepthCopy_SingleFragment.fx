// FRPG_Fil_DepthCopy_SingleFragment.fx
// Reconstructed from DSR DXBC + vanilla source.
// Copies depth from MSAA Texture2DMS<float> t0 to depth output.
// Original: r0.xy = v1.xy * cb0[12].xy (screen size); t0.Load(uint2, 0) → oDepth

#include "FRPG_Fil_Common.fxh"

Texture2DMS<float> g_depth : register(t0);

// Extended registers - exact reference names/layout ($Globals, c54-c91)
float4               DL_FREG_054        : register(c54); // [unused]
float4               DL_FREG_055        : register(c55); // [unused]
float4               DL_FREG_056        : register(c56); // [unused]
float4               DL_FREG_057        : register(c57); // [unused]
float4x4             DL_FREG_058        : register(c58); // [unused]
float4x4             DL_FREG_062        : register(c62); // [unused]
float4               DL_FREG_066        : register(c66); // [unused]
float4               DL_FREG_067        : register(c67); // [unused]
float4               DL_FREG_068        : register(c68); // [unused]
float4               DL_FREG_069        : register(c69); // [unused]
float4               DL_FREG_070        : register(c70); // [unused]
float4               DL_FREG_071        : register(c71); // [unused]
float4               DL_FREG_072        : register(c72); // [unused]
float4               DL_FREG_073        : register(c73); // [unused]
float4x4             DL_FREG_074        : register(c74); // [unused]
float4               DL_FREG_078        : register(c78); // [unused]
float4               gFC_TAAFilterWeights0 : register(c81); // [unused]
float4               gFC_TAAFilterWeights1 : register(c82); // [unused]
float4               gFC_TAAFilterWeights2 : register(c83); // [unused]
float4               gFC_TAAFilterWeights3 : register(c84); // [unused]
float4               gFC_TAAFilterWeights4 : register(c85); // [unused]
float4               gFC_TAAFilterWeights5 : register(c86); // [unused]
float4x4             gVC_WorldViewClipMtx : register(c87); // [unused]
float4x4             gVC_CameraMtx      : register(c91); // [unused]
float4               gVC_ScreenSize     : register(c95); // [unused]
float4               gVC_NoiseParam     : register(c96); // [unused]

struct FIL_DEPTH_IN
{
    float4 Pos : SV_Position;
    float2 UV  : Texcoord0;
};

float FragmentMain(FIL_DEPTH_IN In) : SV_Depth
{
    // Original: r0.xy = v1.xy * cb0[12].xy; ftou; t0.Load(r0.xy, 0)
    uint2 coord = (uint2)(In.UV * gFC_ScreenSize.xy);
    return g_depth.Load(coord, 0);
}
