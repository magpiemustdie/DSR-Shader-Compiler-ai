// FRPG_Fil_SAO_Minify.fx
// Reconstructed from DSR DXBC.
// SAO mipmap minification: loads from t0 at a bit-reversed coordinate
// (used to build the SAO depth mip chain with interleaved access pattern).
// No UV input — uses SV_Position directly.
// t0=SAO depth mip (Load)

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_POS
{
    float4 Pos : SV_Position;
    float2 Tex : TEXCOORD0;
};

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_POS In)
{
    FIL_OUT Out;

    uint2 iC = (uint2)(int2)In.Pos.xy;
    uint2 revCoord = (iC << 1) | ((iC.yx & 1u) ^ 1u);

    Out.Color = gSMP_0.Load(int3(revCoord, 0));
    return Out;
}
