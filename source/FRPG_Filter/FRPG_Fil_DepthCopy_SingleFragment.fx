// FRPG_Fil_DepthCopy_SingleFragment.fx
// Reconstructed from DSR DXBC + vanilla source.
// Copies depth from MSAA Texture2DMS<float> t0 to depth output.
// Original: r0.xy = v1.xy * cb0[12].xy (screen size); t0.Load(uint2, 0) → oDepth

#include "FRPG_Fil_Common.fxh"

Texture2DMS<float> gSMP_DepthMS : register(t0);

struct FIL_DEPTH_IN
{
    float4 Pos : SV_Position;
    float2 UV  : TEXCOORD1;
};

float FragmentMain(FIL_DEPTH_IN In) : SV_Depth
{
    // Original: r0.xy = v1.xy * cb0[12].xy; ftou; t0.Load(r0.xy, 0)
    uint2 coord = (uint2)(In.UV * gFC_ScreenSize.xy);
    return gSMP_DepthMS.Load(coord, 0);
}
