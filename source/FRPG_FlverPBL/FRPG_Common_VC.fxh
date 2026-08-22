// Copyright (c) FromSoftware, Inc.

#ifndef ___FRPG_Flver_FRPG_Common_VC_fxh___
#define ___FRPG_Flver_FRPG_Common_VC_fxh___

// Vertex shader constants.
// On X360, VS and PS share register(cN) space — only bind in VS (defined by Make_FS.bat).
#ifdef _FRAGMENT_SHADER
    #define VC_REG(reg) reg
#else // vertex shader
    #define VC_REG(reg) register(reg)
#endif

#ifdef OLD_VERSION

    #define gVC_WorldViewClipMtx VR_000
    #define gVC_CameraMtx        VR_004
    uniform float4x4 gVC_WorldViewClipMtx : VC_REG(c0); // world -> view -> clip matrix
    uniform float4x4 gVC_CameraMtx        : VC_REG(c4); // camera matrix (world space)

#define LOCAL_WORLD_MTX_NUM (38) // number of local->world matrices (registers c8~c121)
    #define gVC_LocalWorldMtx      VR_008
    #define gVC_LocalWorldMtxArray VR_008A

#ifdef _PS3
    uniform float3x4 gVC_LocalWorldMtx                          : VC_REG(c8); // local->world matrix (note: transposed)
    uniform float3x4 gVC_LocalWorldMtxArray[LOCAL_WORLD_MTX_NUM]: VC_REG(c8); // local->world matrix array (note: transposed)
#else // column_major: float3x4 constant uses 4 registers
    uniform row_major float3x4 gVC_LocalWorldMtx                          : VC_REG(c8); // local->world matrix (note: transposed)
    uniform row_major float3x4 gVC_LocalWorldMtxArray[LOCAL_WORLD_MTX_NUM]: VC_REG(c8); // local->world matrix array (note: transposed)
#endif

    #define gVC_FogParam VR_128
    uniform float4 gVC_FogParam : VC_REG(c128); // fog params: x=view-space start, y=view-space end minus start, z=unknown, w=fog coefficient multiplier (note: gFC side holds fog color)

    // Light scattering parameters
    #define gVC_LsBeta1PlusBeta2        VR_129
    #define gVC_LsTerrainReflectance    VR_130
    #define gVC_LsOneOverBeta1PlusBeta2 VR_131
    #define gVC_LsHGg                   VR_132
    #define gVC_LsBetaDash1             VR_133
    #define gVC_LsBetaDash2             VR_134
    #define gVC_LsSunColor              VR_135
    #define gVC_LsLightDir              VR_136

    uniform float4 gVC_LsBeta1PlusBeta2        : VC_REG(c129); // light scattering: beta1+beta2
    uniform float4 gVC_LsTerrainReflectance    : VC_REG(c130); // light scattering: rgb=ground reflectance, a=inscatter scale
    uniform float4 gVC_LsOneOverBeta1PlusBeta2 : VC_REG(c131); // light scattering: 1/(beta1+beta2)
    uniform float4 gVC_LsHGg                   : VC_REG(c132); // light scattering: Henyey-Greenstein g
    uniform float4 gVC_LsBetaDash1             : VC_REG(c133); // light scattering: betaDash1
    uniform float4 gVC_LsBetaDash2             : VC_REG(c134); // light scattering: betaDash2
    uniform float4 gVC_LsSunColor              : VC_REG(c135); // light scattering: rgb=sun color, a=blend factor
    uniform float4 gVC_LsLightDir              : VC_REG(c136); // light scattering: xyz=light dir (world, normalized), w=distance scale

    #define gVC_ShadowMapMtx VR_137
    uniform float4x4 gVC_ShadowMapMtx : VC_REG(c137); // world->light matrix (light space)

    #define gVC_WaterTileScale VR_141
    uniform float4 gVC_WaterTileScale : VC_REG(c141);

    // Water surface height
    #define gVC_WaterWaveParam VR_142
    uniform float4 gVC_WaterWaveParam : VC_REG(c142); // water wave: x=camera FovY tan, y=wave fade dist, z=heightmap size, w=1/heightmap size

    #define gVC_SnowTileScale0         VR_143
    #define gVC_SnowDetailBumpTileScale VR_144
    #define gVC_SnowDiffuseTileScale    VR_145
    uniform float4 gVC_SnowTileScale           : VC_REG(c143);
    uniform float4 gVC_SnowDetailBumpTileScale : VC_REG(c144);
    uniform float4 gVC_SnowDiffuseTileScale    : VC_REG(c145);

    #define gVC_WindParam_0 VR_122
    #define gVC_WindParam_1 VR_123
    uniform float4 gVC_WindParam_0 : VC_REG(c122);
    uniform float4 gVC_WindParam_1 : VC_REG(c123);

#ifndef _DX11 // qloc: dx11: avoid error X4019: multiple variables found with the same user-specified location

    // Motion blur registers c128~c241 (120 registers, can overlap with other constants)
    #define gVC_prevLocalWorldMtx      VR_128_ // VR_128_ to avoid compile error with VR_128 overlap
    #define gVC_prevLocalWorldMtxArray VR_128A
#ifdef _PS3
    uniform float3x4 gVC_prevLocalWorldMtx                          : VC_REG(c128); // previous frame local->world matrix (note: transposed)
    uniform float3x4 gVC_prevLocalWorldMtxArray[LOCAL_WORLD_MTX_NUM]: VC_REG(c128); // previous frame local->world matrix array (note: transposed)
#else
    uniform row_major float3x4 gVC_prevLocalWorldMtx                          : VC_REG(c128); // previous frame local->world matrix (note: transposed)
    uniform row_major float3x4 gVC_prevLocalWorldMtxArray[LOCAL_WORLD_MTX_NUM]: VC_REG(c128); // previous frame local->world matrix (note: transposed)
#endif

#endif // !_DX11

    #define gVC_TexScrl_0 VR_246
    #define gVC_TexScrl_1 VR_247
    #define gVC_TexScrl_2 VR_248
    uniform float4 gVC_TexScrl_0 : VC_REG(c246); // texture scroll 0
    uniform float4 gVC_TexScrl_1 : VC_REG(c247); // texture scroll 1
    uniform float4 gVC_TexScrl_2 : VC_REG(c248); // texture scroll 2

    // User clip planes (PS3 only)
#if defined(CLIPPLANE_ENABLE)
    #define gVC_aClipPlane VR_249A
    uniform float4 gVC_aClipPlane[6] : VC_REG(c249); // only slot 0 is currently used

    #ifdef _PS3
        #define DECLARE_OUT_CLIPPLANE0  out float oClip0 : CLP0
        #define DECLARE_OUT_CLIPPLANE1  out float oClip1 : CLP1
        #define DECLARE_OUT_CLIPPLANE2  out float oClip2 : CLP2
        #define DECLARE_OUT_CLIPPLANE3  out float oClip3 : CLP3
        #define DECLARE_OUT_CLIPPLANE4  out float oClip4 : CLP4
        #define DECLARE_OUT_CLIPPLANE5  out float oClip5 : CLP5

        #ifdef WITH_ClipPlane
            #define COMPUTE_CLIPPLANE0(pos) oClip0 = dot(gVC_aClipPlane[0], pos)
            #define COMPUTE_CLIPPLANE1(pos) oClip1 = dot(gVC_aClipPlane[1], pos)
            #define COMPUTE_CLIPPLANE2(pos) oClip2 = dot(gVC_aClipPlane[2], pos)
            #define COMPUTE_CLIPPLANE3(pos) oClip3 = dot(gVC_aClipPlane[3], pos)
            #define COMPUTE_CLIPPLANE4(pos) oClip4 = dot(gVC_aClipPlane[4], pos)
            #define COMPUTE_CLIPPLANE5(pos) oClip5 = dot(gVC_aClipPlane[5], pos)
        #else
            #define COMPUTE_CLIPPLANE0(pos) // no-op
            #define COMPUTE_CLIPPLANE1(pos) // no-op
            #define COMPUTE_CLIPPLANE2(pos) // no-op
            #define COMPUTE_CLIPPLANE3(pos) // no-op
            #define COMPUTE_CLIPPLANE4(pos) // no-op
            #define COMPUTE_CLIPPLANE5(pos) // no-op
        #endif

    #elif defined(_DX11) // qloc
        #define DECLARE_OUT_CLIPPLANE0
        #define DECLARE_OUT_CLIPPLANE1
        #define DECLARE_OUT_CLIPPLANE2
        #define DECLARE_OUT_CLIPPLANE3
        #define DECLARE_OUT_CLIPPLANE4
        #define DECLARE_OUT_CLIPPLANE5

        #ifdef WITH_ClipPlane
            #define COMPUTE_CLIPPLANE0(pos) Out.oClip0 = qlocClipPlaneDistance(pos);
            #define COMPUTE_CLIPPLANE1(pos) Out.oClip1 = 0.0;
            #define COMPUTE_CLIPPLANE2(pos) Out.oClip2 = 0.0;
            #define COMPUTE_CLIPPLANE3(pos) Out.oClip3 = 0.0;
            #define COMPUTE_CLIPPLANE4(pos) Out.oClip4 = 0.0;
            #define COMPUTE_CLIPPLANE5(pos) Out.oClip5 = 0.0;
        #else
            #define COMPUTE_CLIPPLANE0(pos) // no-op
            #define COMPUTE_CLIPPLANE1(pos) // no-op
            #define COMPUTE_CLIPPLANE2(pos) // no-op
            #define COMPUTE_CLIPPLANE3(pos) // no-op
            #define COMPUTE_CLIPPLANE4(pos) // no-op
            #define COMPUTE_CLIPPLANE5(pos) // no-op
        #endif

    #else
        #define DECLARE_OUT_CLIPPLANE0
        #define DECLARE_OUT_CLIPPLANE1
        #define DECLARE_OUT_CLIPPLANE2
        #define DECLARE_OUT_CLIPPLANE3
        #define DECLARE_OUT_CLIPPLANE4
        #define DECLARE_OUT_CLIPPLANE5

        #define COMPUTE_CLIPPLANE0(pos) // no-op
        #define COMPUTE_CLIPPLANE1(pos) // no-op
        #define COMPUTE_CLIPPLANE2(pos) // no-op
        #define COMPUTE_CLIPPLANE3(pos) // no-op
        #define COMPUTE_CLIPPLANE4(pos) // no-op
        #define COMPUTE_CLIPPLANE5(pos) // no-op
    #endif

#else // !CLIPPLANE_ENABLE

    #define DECLARE_OUT_CLIPPLANE0
    #define DECLARE_OUT_CLIPPLANE1
    #define DECLARE_OUT_CLIPPLANE2
    #define DECLARE_OUT_CLIPPLANE3
    #define DECLARE_OUT_CLIPPLANE4

    #define COMPUTE_CLIPPLANE0(pos)
    #define COMPUTE_CLIPPLANE1(pos)
    #define COMPUTE_CLIPPLANE2(pos)
    #define COMPUTE_CLIPPLANE3(pos)
    #define COMPUTE_CLIPPLANE4(pos)

#endif // CLIPPLANE_ENABLE

    // Ghost parameters (ghost texture scroll removed 2010/08/30 by nacheon)

#else // !OLD_VERSION

    float4x4           gVC_WorldViewClipMtx        : VC_REG(c0);
    float4             gVC_CameraPos               : VC_REG(c4);
    float4             gVC_WindParam_0              : VC_REG(c5);
    float4             gVC_WindParam_1              : VC_REG(c6);
    float4             gVC_FogParam                : VC_REG(c7);
    float4x4           gVC_CommonREG8              : VC_REG(c8);
    float4x4           gVC_CommonREG12             : VC_REG(c12);
    float4x4           gVC_ShadowMapMtx            : VC_REG(c16);
    float4             gVC_WaterTileScale           : VC_REG(c20);
    float4             gVC_WaterWaveParam           : VC_REG(c21);
    float4             gVC_SnowTileScale            : VC_REG(c22);
    float4             gVC_SnowDetailBumpTileScale  : VC_REG(c23);
    float4             gVC_SnowDiffuseTileScale     : VC_REG(c24);
    float4             gVC_TexScrl_0               : VC_REG(c25);
    float4             gVC_TexScrl_1               : VC_REG(c26);
    float4             gVC_ModelMulCol             : VC_REG(c27);
    row_major float3x4 gVC_LocalWorldMtxArray[38]  : VC_REG(c28);
    row_major float3x4 gVC_prevLocalWorldMtxArray[38] : VC_REG(c142);

#endif // OLD_VERSION

#ifdef _PS3
    #ifdef CLIPPLANE_ENABLE
        #define __DECL_VertexShader(FuncName, _in) FuncName(_in, DECLARE_OUT_CLIPPLANE0)
    #else
        #define __DECL_VertexShader(FuncName, _in) FuncName(_in)
    #endif
#else
    #define __DECL_VertexShader(FuncName, _in) FuncName(_in)
#endif

#endif // ___FRPG_Flver_FRPG_Common_VC_fxh___
