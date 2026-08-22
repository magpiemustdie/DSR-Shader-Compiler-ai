// Copyright (c) QLOC S.A.

#ifndef ___FRPG_Common_Tonemap_fxh___
#define ___FRPG_Common_Tonemap_fxh___

#ifndef OLD_VERSION
float3 ReverseToneMap(float3 linearCol)
{
    float expScale = clamp(tex2D(gSMP_LumTex, float2(0.5f, 0.5f)).r,
                           gFC_AdaptParam.z, gFC_AdaptParam.w);
    float middleGray = gFC_AdaptParam.x;
    float3 mapped    = gFC_AdaptParam.y * linearCol * (expScale + 0.0001f) / middleGray;
    mapped           = max(mapped, 0.0f); // prevent negative values from NaN propagation
    return lerp(linearCol, mapped, gFC_InverseToneMapEnable.x);
}
#endif // !OLD_VERSION

#endif // ___FRPG_Common_Tonemap_fxh___
