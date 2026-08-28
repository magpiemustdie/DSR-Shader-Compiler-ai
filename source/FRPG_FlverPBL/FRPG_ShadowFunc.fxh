// Copyright (c) FromSoftware, Inc.

#ifndef ___FRPG_Shader_FRPG_ShadowFunc_fxh___
#define ___FRPG_Shader_FRPG_ShadowFunc_fxh___

#define SHADOWMAP_SIZE  2048.0f
#define _ENABLE_SHADOW  (1)

#ifndef CUBESHADOWMAP_ENABLE

// -----------------------------------------------------------------------
// PS3 shadow sampling
// -----------------------------------------------------------------------
#ifdef _PS3
    float __GetShadowRate_PCF4(float4 position_in_light)
    {
        return tex2Dproj(gSMP_ShadowMap, position_in_light).x;
    }

    float __GetShadowRate_PCF16(float4 position_in_light)
    {
        float offset = 1.0f / SHADOWMAP_SIZE;
        float4 aOffsets[] = {
            float4( 0,       0,       0, 0),
            float4( 0,       offset,  0, 0),
            float4( 0,      -offset,  0, 0),
            float4(-offset,  0,       0, 0),
            float4(-offset, -offset,  0, 0),
            float4(-offset,  offset,  0, 0),
            float4( offset,  0,       0, 0),
            float4( offset, -offset,  0, 0),
            float4( offset,  offset,  0, 0),
        };
        float shadowed = 0;
        for (int i = 0; i < 9; ++i)
            shadowed += tex2Dproj(gSMP_ShadowMap, position_in_light + aOffsets[i] * position_in_light.w).x;
        return shadowed / 9.0f;
    }

    float __GetShadowRate_PCF9(float4 position_in_light)
    {
        float offset = 0.5f / SHADOWMAP_SIZE;
        float4 aOffsets[] = {
            float4(-offset, -offset, 0, 0),
            float4(-offset,  offset, 0, 0),
            float4( offset, -offset, 0, 0),
            float4( offset,  offset, 0, 0),
        };
        float shadowed = 0;
        for (int i = 0; i < 4; ++i)
            shadowed += tex2Dproj(gSMP_ShadowMap, position_in_light + aOffsets[i] * position_in_light.w).x;
        return shadowed / 4.0f;
    }

    float __GetShadowRate_PCF16L(float4 position_in_light)
    {
        float offset = 1.0f / SHADOWMAP_SIZE;
        float4 aOffsets[] = {
            float4(-offset, -offset, 0, 0),
            float4(-offset,  offset, 0, 0),
            float4( offset, -offset, 0, 0),
            float4( offset,  offset, 0, 0),
        };
        float shadowed = 0;
        for (int i = 0; i < 4; ++i)
            shadowed += tex2Dproj(gSMP_ShadowMap, position_in_light + aOffsets[i] * position_in_light.w).x;
        return shadowed / 4.0f;
    }

    float __GetShadowRate_Rotated4(float4 position_in_light)
    {
        float offset = 0.7f / SHADOWMAP_SIZE;
        float gap    = 0.2f / SHADOWMAP_SIZE;
        float4 aOffsets[] = {
            float4(-offset,  gap,    0, 0),
            float4( gap,     offset, 0, 0),
            float4( offset, -gap,    0, 0),
            float4(-gap,    -offset, 0, 0),
        };
        float shadowed = 0;
        for (int i = 0; i < 4; ++i)
            shadowed += tex2Dproj(gSMP_ShadowMap, position_in_light + aOffsets[i] * position_in_light.w).x;
        return shadowed / 4.0f;
    }

    float __GetShadowRate_PoissonDisc9(float4 position_in_light)
    {
        float offset = position_in_light.w * 2.0f / SHADOWMAP_SIZE;
        const float4 poissonDisc[9] = {
            float4( 0.0f,      0.0f,      0, 0),
            float4(-0.695914f, 0.457137f, 0, 0),
            float4(-0.203345f, 0.620716f, 0, 0),
            float4( 0.96234f, -0.194983f, 0, 0),
            float4( 0.473434f,-0.480026f, 0, 0),
            float4( 0.519456f, 0.767022f, 0, 0),
            float4( 0.185461f,-0.893124f, 0, 0),
            float4( 0.507431f, 0.064425f, 0, 0),
            float4(-0.791559f,-0.59771f,  0, 0),
        };
        float shadowed = 0;
        for (int i = 0; i < 9; ++i)
            shadowed += tex2Dproj(gSMP_ShadowMap, position_in_light + poissonDisc[i] * offset).x / 9.0f;
        return shadowed;
    }

    float __GetShadowRate_PoissonDiscN(float4 position_in_light, int N)
    {
        float offset = position_in_light.w * 1.0f / SHADOWMAP_SIZE;
        const float4 poissonDisc[9] = {
            float4( 0.0f,      0.0f,      0, 0),
            float4(-0.695914f, 0.457137f, 0, 0),
            float4(-0.203345f, 0.620716f, 0, 0),
            float4( 0.96234f, -0.194983f, 0, 0),
            float4( 0.473434f,-0.480026f, 0, 0),
            float4( 0.519456f, 0.767022f, 0, 0),
            float4( 0.185461f,-0.893124f, 0, 0),
            float4( 0.507431f, 0.064425f, 0, 0),
            float4(-0.791559f,-0.59771f,  0, 0),
        };
        float shadowed = 0;
        for (int i = 0; i < N; ++i)
            shadowed += tex2Dproj(gSMP_ShadowMap, position_in_light + poissonDisc[i] * offset).x;
        return shadowed / (float)N;
    }

    float __GetShadowRate_PoissonDisc8(float4 p) { return __GetShadowRate_PoissonDiscN(p, 8); }
    float __GetShadowRate_PoissonDisc7(float4 p) { return __GetShadowRate_PoissonDiscN(p, 7); }
    float __GetShadowRate_PoissonDisc6(float4 p) { return __GetShadowRate_PoissonDiscN(p, 6); }
    float __GetShadowRate_PoissonDisc5(float4 p) { return __GetShadowRate_PoissonDiscN(p, 5); }
    float __GetShadowRate_PoissonDisc4(float4 p) { return __GetShadowRate_PoissonDiscN(p, 4); }
    float __GetShadowRate_PoissonDisc3(float4 p) { return __GetShadowRate_PoissonDiscN(p, 3); }
#endif // _PS3

// -----------------------------------------------------------------------
// Xbox 360 shadow sampling
// -----------------------------------------------------------------------
#ifdef _X360
    float __GetShadowRate_PCF4(float4 position_in_light)
    {
        float3 vShadowCoord = position_in_light.xyz / position_in_light.w;
        float4 SampledDepth;
        asm {
            tfetch2D SampledDepth.x___, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -0.5, OffsetY = -0.5
            tfetch2D SampledDepth._x__, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.5, OffsetY = -0.5
            tfetch2D SampledDepth.__x_, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -0.5, OffsetY =  0.5
            tfetch2D SampledDepth.___x, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.5, OffsetY =  0.5
        };
        float4 Weights = 0.25f;
        float4 Attenuation = (vShadowCoord.zzzz < SampledDepth);
        return dot(Attenuation, Weights);
    }

    float __GetShadowRate_PCF9(float4 position_in_light)
    {
        float3 vShadowCoord = position_in_light.xyz / position_in_light.w;
        float4 SampledDepth;
        float  SampledDepth2;
        asm {
            tfetch2D SampledDepth.x___, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -1.0, OffsetY = -1.0
            tfetch2D SampledDepth._x__, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.0, OffsetY = -1.0
            tfetch2D SampledDepth.__x_, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  1.0, OffsetY = -1.0
            tfetch2D SampledDepth.___x, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -1.0, OffsetY =  0.0
        };
        float shadowed = dot((vShadowCoord.zzzz < SampledDepth), 1.0f);
        asm {
            tfetch2D SampledDepth.x___, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.0, OffsetY =  0.0
            tfetch2D SampledDepth._x__, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  1.0, OffsetY =  0.0
            tfetch2D SampledDepth.__x_, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -1.0, OffsetY =  1.0
            tfetch2D SampledDepth.___x, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.0, OffsetY =  1.0
            tfetch2D SampledDepth2,     vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  1.0, OffsetY =  1.0
        };
        shadowed += dot((vShadowCoord.zzzz < SampledDepth), 1.0f) + (vShadowCoord.z < SampledDepth2);
        return shadowed / 9.0f;
    }

    float __GetShadowRate_PCF16(float4 position_in_light)
    {
        float3 vShadowCoord = position_in_light.xyz / position_in_light.w;
        float4 SampledDepth;
        float  shadowed = 0;
        asm {
            tfetch2D SampledDepth.x___, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -1.5, OffsetY = -1.5
            tfetch2D SampledDepth._x__, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -0.5, OffsetY = -1.5
            tfetch2D SampledDepth.__x_, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.5, OffsetY = -1.5
            tfetch2D SampledDepth.___x, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  1.5, OffsetY = -1.5
        };
        shadowed += dot((vShadowCoord.zzzz < SampledDepth), 1.0f);
        asm {
            tfetch2D SampledDepth.x___, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -1.5, OffsetY = -0.5
            tfetch2D SampledDepth._x__, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -0.5, OffsetY = -0.5
            tfetch2D SampledDepth.__x_, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.5, OffsetY = -0.5
            tfetch2D SampledDepth.___x, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  1.5, OffsetY = -0.5
        };
        shadowed += dot((vShadowCoord.zzzz < SampledDepth), 1.0f);
        asm {
            tfetch2D SampledDepth.x___, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -1.5, OffsetY =  0.5
            tfetch2D SampledDepth._x__, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -0.5, OffsetY =  0.5
            tfetch2D SampledDepth.__x_, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.5, OffsetY =  0.5
            tfetch2D SampledDepth.___x, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  1.5, OffsetY =  0.5
        };
        shadowed += dot((vShadowCoord.zzzz < SampledDepth), 1.0f);
        asm {
            tfetch2D SampledDepth.x___, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -1.5, OffsetY =  1.5
            tfetch2D SampledDepth._x__, vShadowCoord.xy, gSMP_ShadowMap, OffsetX = -0.5, OffsetY =  1.5
            tfetch2D SampledDepth.__x_, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  0.5, OffsetY =  1.5
            tfetch2D SampledDepth.___x, vShadowCoord.xy, gSMP_ShadowMap, OffsetX =  1.5, OffsetY =  1.5
        };
        shadowed += dot((vShadowCoord.zzzz < SampledDepth), 1.0f);
        return shadowed / 16.0f;
    }
#endif // _X360

// -----------------------------------------------------------------------
// Win32 / DX11 shadow sampling
// -----------------------------------------------------------------------
#ifdef _WIN32
#if !defined(WITH_GBuffer) && !defined(WITH_HemDir3)
    float DecodeDepthCmp(const float3 uvw)    {
        return gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z).x;
    }
    float DecodeDepthCmp(const float3 uvw, const int2 offset)
    {
        return gSMP_ShadowMap.SampleCmp(gSMP_ShadowMapSampler, uvw.xy, uvw.z, offset).x;
    }
#endif // !WITH_GBuffer && !WITH_HemDir3

    // GBuffer path: ref uses a 16-tap PCF with packed-depth decode via plain Sample.
    // Weights unpack RGB8-packed depth; offsets are 4x4 grid at +/-1.5/+/-0.5 texel (2048).
    // Matches ref GB asm (0.996094/0.003891/1.51991844e-005, 0.0625, +/-0.000732/+/-0.000244).
#if defined(WITH_GBuffer) || defined(WITH_HemDir3)
    float __GetShadowRate_GB16(const float4 position_in_light)
    {
        const float3 uv = position_in_light.xyz / position_in_light.w;
        const float3 decW = float3(0.99609375f, 0.00389099121f, 1.51991844e-05f);
        const float2 o = float2(0.000732421875f, 0.000244140625f); // 1.5/2048, 0.5/2048

        float4 taps;
        float shadowed = 0;

        taps.x = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(-o.x, -o.x)).xyz, decW);
        taps.y = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(-o.y, -o.x)).xyz, decW);
        taps.z = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(o.y, -o.x)).xyz, decW);
        taps.w = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(o.x, -o.x)).xyz, decW);
        shadowed += dot((taps < uv.z), float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));

        taps.x = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(-o.x, -o.y)).xyz, decW);
        taps.y = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(-o.y, -o.y)).xyz, decW);
        taps.z = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(o.y, -o.y)).xyz, decW);
        taps.w = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(o.x, -o.y)).xyz, decW);
        shadowed += dot((taps < uv.z), float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));

        taps.x = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(-o.x, o.y)).xyz, decW);
        taps.y = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(-o.y, o.y)).xyz, decW);
        taps.z = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(o.y, o.y)).xyz, decW);
        taps.w = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(o.x, o.y)).xyz, decW);
        shadowed += dot((taps < uv.z), float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));

        taps.x = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(-o.x, o.x)).xyz, decW);
        taps.y = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(-o.y, o.x)).xyz, decW);
        taps.z = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(o.y, o.x)).xyz, decW);
        taps.w = dot(gSMP_ShadowMap.Sample(gSMP_ShadowMapSampler, uv.xy + float2(o.x, o.x)).xyz, decW);
        shadowed += dot((taps < uv.z), float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));

        return shadowed;
    }
#endif // defined(WITH_GBuffer) || defined(WITH_HemDir3)

    // 1 hardware-filtered sample (bilinear PCF from the comparison sampler)
#if !defined(WITH_GBuffer) && !defined(WITH_HemDir3)
    float __GetShadowRate_PCF4(const float4 position_in_light)
    {
        const float3 uv = position_in_light.xyz / position_in_light.w;
        return DecodeDepthCmp(uv);
    }

    // 3x3 PCF — 9 uniformly-weighted samples
    // Packed as 2x dot4 + mad to match ref codegen (9 literal copies of 1/9)
    float __GetShadowRate_PCF9(const float4 position_in_light)
    {
        const float3 uv = position_in_light.xyz / position_in_light.w;
        const float  w  = 1.0f / 9.0f;
        float s = 0.0f;
        s += dot(float4(
            DecodeDepthCmp(uv, int2(-1, -1)),
            DecodeDepthCmp(uv, int2( 0, -1)),
            DecodeDepthCmp(uv, int2( 1, -1)),
            DecodeDepthCmp(uv, int2(-1,  0))), float4(w, w, w, w));
        s += dot(float4(
            DecodeDepthCmp(uv, int2( 0,  0)),
            DecodeDepthCmp(uv, int2( 1,  0)),
            DecodeDepthCmp(uv, int2(-1,  1)),
            DecodeDepthCmp(uv, int2( 0,  1))), float4(w, w, w, w));
        s += DecodeDepthCmp(uv, int2( 1,  1)) * w;
        return s;
    }

    // 5x5 Gaussian PCF — 25 samples with Gaussian weights for soft, natural-looking shadows
    // Kernel weights: corners=1, outer-edges=2, inner-ring=4, center=4
    // Weight sum = 4*1 + 12*2 + 9*4 = 64
    float __GetShadowRate_PCF16(const float4 position_in_light)
    {
        const float3 uv = position_in_light.xyz / position_in_light.w;

        float s = 0.0f;

        // Row -2
        s += dot(float4(
            DecodeDepthCmp(uv, int2(-2, -2)),
            DecodeDepthCmp(uv, int2(-1, -2)),
            DecodeDepthCmp(uv, int2( 0, -2)),
            DecodeDepthCmp(uv, int2( 1, -2))),
            float4(1, 2, 2, 2));
        s += DecodeDepthCmp(uv, int2(2, -2)) * 1.0f;

        // Row -1
        s += dot(float4(
            DecodeDepthCmp(uv, int2(-2, -1)),
            DecodeDepthCmp(uv, int2(-1, -1)),
            DecodeDepthCmp(uv, int2( 0, -1)),
            DecodeDepthCmp(uv, int2( 1, -1))),
            float4(2, 4, 4, 4));
        s += DecodeDepthCmp(uv, int2(2, -1)) * 2.0f;

        // Row 0
        s += dot(float4(
            DecodeDepthCmp(uv, int2(-2, 0)),
            DecodeDepthCmp(uv, int2(-1, 0)),
            DecodeDepthCmp(uv, int2( 0, 0)),
            DecodeDepthCmp(uv, int2( 1, 0))),
            float4(2, 4, 4, 4));
        s += DecodeDepthCmp(uv, int2(2, 0)) * 2.0f;

        // Row 1
        s += dot(float4(
            DecodeDepthCmp(uv, int2(-2, 1)),
            DecodeDepthCmp(uv, int2(-1, 1)),
            DecodeDepthCmp(uv, int2( 0, 1)),
            DecodeDepthCmp(uv, int2( 1, 1))),
            float4(2, 4, 4, 4));
        s += DecodeDepthCmp(uv, int2(2, 1)) * 2.0f;

        // Row 2
        s += dot(float4(
            DecodeDepthCmp(uv, int2(-2, 2)),
            DecodeDepthCmp(uv, int2(-1, 2)),
            DecodeDepthCmp(uv, int2( 0, 2)),
            DecodeDepthCmp(uv, int2( 1, 2))),
            float4(1, 2, 2, 2));
        s += DecodeDepthCmp(uv, int2(2, 2)) * 1.0f;

        return s / 64.0f;
    }
#endif // !WITH_GBuffer && !WITH_HemDir3 (SampleCmp variants)
#endif // _WIN32

// -----------------------------------------------------------------------
// Shadow rate wrapper macro — applies distance fade and normal bias
// -----------------------------------------------------------------------
#define DECL_SHADOW_FUNC(FuncName, ShadowFunc) \
    float3 FuncName(float4 position_in_light, float normalShadow, float4 eyeVec = 0) \
    { \
        float3 rate = 1; \
        if (_ENABLE_SHADOW) { \
            float dist = saturate((gFC_ShadowMapParam.y - eyeVec.w) * gFC_ShadowMapParam.z); \
            float fShadow = saturate(ShadowFunc(position_in_light.xyzw) + normalShadow); \
            rate = 1 - ((float3)dist) * gFC_ShadowColor.xyz * fShadow; \
        } \
        return rate; \
    }

#ifdef _PS3
DECL_SHADOW_FUNC(GetShadowRate_PCF4,          __GetShadowRate_PCF4)
DECL_SHADOW_FUNC(GetShadowRate_PCF9,          __GetShadowRate_PCF9)
DECL_SHADOW_FUNC(GetShadowRate_PCF16,         __GetShadowRate_PCF16L)
DECL_SHADOW_FUNC(GetShadowRate_PoissonDisc9,  __GetShadowRate_PoissonDisc9)
DECL_SHADOW_FUNC(GetShadowRate_PoissonDisc8,  __GetShadowRate_PoissonDisc8)
DECL_SHADOW_FUNC(GetShadowRate_PoissonDisc7,  __GetShadowRate_PoissonDisc7)
DECL_SHADOW_FUNC(GetShadowRate_PoissonDisc6,  __GetShadowRate_PoissonDisc6)
DECL_SHADOW_FUNC(GetShadowRate_PoissonDisc5,  __GetShadowRate_PoissonDisc5)
DECL_SHADOW_FUNC(GetShadowRate_PoissonDisc4,  __GetShadowRate_PoissonDisc4)
DECL_SHADOW_FUNC(GetShadowRate_PoissonDisc3,  __GetShadowRate_PoissonDisc3)
DECL_SHADOW_FUNC(GetShadowRate_Rotated4,      __GetShadowRate_Rotated4)
#endif

#ifdef _X360
DECL_SHADOW_FUNC(GetShadowRate_PCF4,  __GetShadowRate_PCF4)
DECL_SHADOW_FUNC(GetShadowRate_PCF9,  __GetShadowRate_PCF9)
DECL_SHADOW_FUNC(GetShadowRate_PCF16, __GetShadowRate_PCF16)
#endif

#ifdef _WIN32
#if defined(WITH_GBuffer) || defined(WITH_HemDir3)
// GB path: ref does a software 16-tap PCF with plain Sample (see __GetShadowRate_GB16)
// HemDir3: same 16-tap PCF, but bias added separately after normal (no pow, no c186)
DECL_SHADOW_FUNC(GetShadowRate_PCF16GB, __GetShadowRate_GB16)
#else
DECL_SHADOW_FUNC(GetShadowRate_PCF4,  __GetShadowRate_PCF4)
DECL_SHADOW_FUNC(GetShadowRate_PCF9,  __GetShadowRate_PCF9)
DECL_SHADOW_FUNC(GetShadowRate_PCF16, __GetShadowRate_PCF16)
#endif
#endif

// Compute shadow rate with normal bias for the current pixel.
float3 CalcGetShadowRate(float4 position_in_light, float3 normal, float4 eyeVec = 0)
{
    float NdotL   = dot(gFC_ShadowLightDir.xyz, normal);
    float fShadow = saturate((NdotL + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
#if defined(WITH_GBuffer) || defined(WITH_HemDir3)
    return pow(abs(GetShadowRate_PCF16GB(position_in_light, fShadow, eyeVec)), gFC_DebugPointLightParams.z);
#else
    return pow(abs(GetShadowRate_PCF9(position_in_light, fShadow, eyeVec)), gFC_DebugPointLightParams.z);
#endif
}

// Shadow rate when the shadow matrix was computed in the vertex shader (single cascade).
float3 CalcGetShadowRateLitSpace(float4 position_in_light, float3 normal, float4 eyeVec = 0)
{
    float4 clampRect = gFC_ShadowMapClamp0 * position_in_light.w;
    position_in_light.xy -= (position_in_light.xy < clampRect.xy) * position_in_light.w;
    position_in_light.xy += (position_in_light.xy > clampRect.zw) * position_in_light.w;
    return CalcGetShadowRate(position_in_light, normal, eyeVec);
}

// Shadow rate computed per-pixel from world position (cascaded shadow maps).
float3 CalcGetShadowRateWorldSpace(float4 worldspace_Pos, float3 normal, float4 eyeVec = 0)
{
    float4x4 shadowMtx;
    float  viewZ  = worldspace_Pos.w;
    float4 zGreater = (gFC_ShadowStartDist < viewZ);
    float4 clampRect = 0;

    int slice = (int)(dot(zGreater, 1.0f) - 1.0f);
    shadowMtx  = gFC_ShadowMapMtxArray[slice];
    clampRect  = gFC_ShadowMapClamp[slice];

    float4 worldPos          = float4(worldspace_Pos.xyz, 1.0f);
    float4 position_in_light = mul(worldPos, shadowMtx);

    clampRect *= position_in_light.w;
    position_in_light.xy -= (position_in_light.xy < clampRect.xy) * position_in_light.w;
    position_in_light.xy += (position_in_light.xy > clampRect.zw) * position_in_light.w;

    return CalcGetShadowRate(position_in_light, normal, eyeVec);
}

#if defined(WITH_GBuffer)
// GB Csd path: ref blends the 4 cascades by weight (endDist 65535), NOT a hard select.
// Verified against ref: FRPG_Gst_DifSpcBmpMulLitCsd_HemEnvPntSS.fpo (c123/c140-155/c157-160).
float3 CalcGetShadowRateWorldSpaceBlend(float4 worldspace_Pos, float3 normal, float4 eyeVec = 0)
{
    float4 fEndDist = float4(gFC_ShadowStartDist.yzw, 65535.0f);
    float4 zGreater = (gFC_ShadowStartDist < worldspace_Pos.w);
    float4 zLess = (fEndDist >= worldspace_Pos.w);
    float4 fWeight = zGreater * zLess;

    float4x4 shadowMtx = gFC_ShadowMapMtxArray0 * fWeight.x;
    shadowMtx += gFC_ShadowMapMtxArray1 * fWeight.y;
    shadowMtx += gFC_ShadowMapMtxArray2 * fWeight.z;
    shadowMtx += gFC_ShadowMapMtxArray3 * fWeight.w;

    float4 clampRect = gFC_ShadowMapClamp0 * fWeight.x;
    clampRect += gFC_ShadowMapClamp1 * fWeight.y;
    clampRect += gFC_ShadowMapClamp2 * fWeight.z;
    clampRect += gFC_ShadowMapClamp3 * fWeight.w;

    float4 worldPos          = float4(worldspace_Pos.xyz, 1.0f);
    float4 position_in_light = mul(worldPos, shadowMtx);

    clampRect *= position_in_light.w;
    position_in_light.xy -= (position_in_light.xy < clampRect.xy) * position_in_light.w;
    position_in_light.xy += (position_in_light.xy > clampRect.zw) * position_in_light.w;

    return CalcGetShadowRate(position_in_light, normal, eyeVec);
}
#endif

// Shadow rate computed per-pixel, single cascade (used for water surface displacement).
float3 CalcGetShadowRateWorldSpaceNoCsd(float4 worldspace_Pos, float3 normal, float4 eyeVec = 0)
{
    float4 worldPos          = float4(worldspace_Pos.xyz, 1.0f);
    float4 position_in_light = mul(worldPos, gFC_ShadowMapMtxArray0);
    float4 clampRect         = gFC_ShadowMapClamp0 * position_in_light.w;

    position_in_light.xy -= (position_in_light.xy < clampRect.xy) * position_in_light.w;
    position_in_light.xy += (position_in_light.xy > clampRect.zw) * position_in_light.w;

    return CalcGetShadowRate(position_in_light, normal, eyeVec);
}

// Non family: multi-cascade select, but WITHOUT the clamp-rect wrap that the
// generic path applies (ref Non PCF skips it — the cascade matrix already bounds UVs).
float3 CalcGetShadowRateWorldSpaceNon(float4 worldspace_Pos, float3 normal, float4 eyeVec = 0)
{
    float4x4 shadowMtx;
    float  viewZ  = worldspace_Pos.w;
    float4 zGreater = (gFC_ShadowStartDist < viewZ);
    int slice = (int)(dot(zGreater, 1.0f) - 1.0f);
    shadowMtx  = gFC_ShadowMapMtxArray[slice];

    float4 worldPos          = float4(worldspace_Pos.xyz, 1.0f);
    float4 position_in_light = mul(worldPos, shadowMtx);

    return CalcGetShadowRate(position_in_light, normal, eyeVec);
}

#define GetShadowRate_Cube(a) (1)
#define GetShadowRate_Proj(a) float3(1, 0, 1) // do not use — debug color

#else
    #pragma error // CUBESHADOWMAP_ENABLE not supported
#endif

#endif // ___FRPG_Shader_FRPG_ShadowFunc_fxh___
