// FRPG_Fil_Dof_Unfocus3x3.fx
// Reconstructed from DSR DXBC ps_5_0.
// 5-tap DOF unfocus: 4 corners + center.
// Corner weight = 0.212121 if corner.a >= center.a, else 0.
// DXBC: lt r1, cornerAlpha, centerAlpha Р Р†РІР‚В РІР‚в„ў movc r1, r1, 0, 0.212121

#include "FRPG_Fil_Common.fxh"

struct FIL_IN_DOF
{
    float4 Pos : SV_Position;
    float4 UV1 : TEXCOORD0;  // xy=corner0, zw=corner1
    float4 UV2 : TEXCOORD1;  // xy=corner2, zw=corner3
    float2 UV3 : TEXCOORD2;  // xy=center
};

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_DOF In)
{
    FIL_OUT Out;

    float4 c0 = gSMP_0.Sample(gSMP_0Sampler, In.UV1.xy);
    float4 c1 = gSMP_0.Sample(gSMP_0Sampler, In.UV1.zw);
    float4 c2 = gSMP_0.Sample(gSMP_0Sampler, In.UV2.xy);
    float4 c3 = gSMP_0.Sample(gSMP_0Sampler, In.UV2.zw);
    float4 cc = gSMP_0.Sample(gSMP_0Sampler, In.UV3.xy);

    float4 lt = (float4)(float4(c0.a, c1.a, c2.a, c3.a) < cc.a);
    float4 weights = (1.0f - lt) * 0.212121f;

    float4 result  = c0 * weights.x;
    float  centerWeight = 1.0f - dot(weights, 1.0f);

    result += cc * centerWeight;
    result += c1 * weights.y;
    result += c2 * weights.z;
    result += c3 * weights.w;

    Out.Color = result;
    return Out;
}
