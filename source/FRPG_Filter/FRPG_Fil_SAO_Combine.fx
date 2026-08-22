// FRPG_Fil_SAO_Combine.fx
// Reconstructed from DSR DXBC.
// SAO combine: reads AO value from t0 and outputs it to alpha channel.
// t0=SAO result (x=AO)

#include "FRPG_Fil_Common.fxh"

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    float ao = gSMP_0.Sample(gSMP_0Sampler, In.UV).r;
    Out.Color = float4(0.0f, 0.0f, 0.0f, ao);
    return Out;
}
