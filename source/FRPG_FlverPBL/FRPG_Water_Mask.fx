// FRPG_Water_Mask.fx — Water mask shader
// Reconstructed from FRPG_Water_Mask.fpo.hlsl
// Outputs constant white (1,1,1,1) to SV_Target1 (mask buffer).

MASK_OUT FragmentMain_WaterMask(MASK_IN In)
{
    MASK_OUT Out;
    Out.Color1 = float4(1.0f, 1.0f, 1.0f, 1.0f);
    return Out;
}
