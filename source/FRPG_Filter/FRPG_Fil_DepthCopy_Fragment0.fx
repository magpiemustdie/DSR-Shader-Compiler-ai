// FRPG_Fil_DepthCopy_Fragment0.fx
// Reconstructed from DSR DXBC.
// Depth copy fragment 0: loads sample 0 from MSAA depth t0 at integer pixel coord.
// No color output. No UV input — uses SV_Position directly.
// t0=Texture2DMS depth (ldms sample 0)

Texture2DMS<float> g_depth : register(t0);

struct FIL_IN_POS { float4 Pos : SV_Position; };
struct FIL_OUT    { float  Depth : SV_Depth; };

FIL_OUT FragmentMain(FIL_IN_POS In)
{
    FIL_OUT Out;

    uint2 iCoord = (uint2)In.Pos.xy;
    Out.Depth = g_depth.Load(iCoord, 0).r;
    return Out;
}
