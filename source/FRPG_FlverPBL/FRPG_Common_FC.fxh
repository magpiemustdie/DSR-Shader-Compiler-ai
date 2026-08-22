// Copyright (c) FromSoftware, Inc.

#ifndef ___FRPG_Flver_FRPG_Common_FC_fxh___
#define ___FRPG_Flver_FRPG_Common_FC_fxh___

// Fragment shader constants.
// On X360, VS and PS share register(cN) space — only bind in FS (defined by Make_FS.bat).
#ifdef _FRAGMENT_SHADER
    #ifdef _PS3
        #define FC_REG(reg) reg // PS3: no register keyword
    #else
        #define FC_REG(reg) register(reg)
    #endif
#else // vertex shader
    #define FC_REG(reg) reg
#endif

#if defined(_PS3) || defined(_X360) || defined(_WIN32)
    #define UNIFORM_FLOAT    uniform float
    #define UNIFORM_FLOAT2   uniform float2
    #define UNIFORM_FLOAT3   uniform float3
    #define UNIFORM_FLOAT4   uniform float4
    #define UNIFORM_FLOAT4x4 uniform float4x4
    #define UNIFORM_HALF4    uniform float4
    #define UNIFORM_UINT4    uniform uint4
#else
    #error Unknown platform
#endif


#ifdef OLD_VERSION

    // Environment light texture multiply colors (for blend switching)
    #define gFC_EnvDifMapMulCol2 DL_FREG_084
    #define gFC_EnvSpcMapMulCol2 DL_FREG_085
    UNIFORM_HALF4 gFC_EnvDifMapMulCol2 : FC_REG(c84); // env diffuse multiply color 2 (a: blend rate 0..1)
    UNIFORM_HALF4 gFC_EnvSpcMapMulCol2 : FC_REG(c85); // env specular multiply color 2 (a: blend rate 0..1)

    // Environment light texture multiply colors
    #define gFC_EnvDifMapMulCol DL_FREG_086
    #define gFC_EnvSpcMapMulCol DL_FREG_087
    UNIFORM_HALF4 gFC_EnvDifMapMulCol : FC_REG(c86); // env diffuse multiply color
    UNIFORM_HALF4 gFC_EnvSpcMapMulCol : FC_REG(c87); // env specular multiply color

    #define gFC_SpcLightVec DL_FREG_088
    #define gFC_SpcLightCol DL_FREG_089
    UNIFORM_FLOAT4 gFC_SpcLightVec : FC_REG(c88); // directional specular light direction
    UNIFORM_HALF4  gFC_SpcLightCol : FC_REG(c89); // directional specular light color

    #define gFC_HemLightCol_u DL_FREG_090
    #define gFC_HemLightCol_d DL_FREG_091
    UNIFORM_HALF4 gFC_HemLightCol_u : FC_REG(c90); // hemisphere light upper color
    UNIFORM_HALF4 gFC_HemLightCol_d : FC_REG(c91); // hemisphere light lower color

    UNIFORM_HALF4 gFC_DirLightVec[3] : FC_REG(c92); // directional light directions
    UNIFORM_HALF4 gFC_DirLightCol[3] : FC_REG(c95); // directional light colors

    #define gFC_HemAmbCol_u DL_FREG_098
    #define gFC_HemAmbCol_d DL_FREG_099
    UNIFORM_HALF4 gFC_HemAmbCol_u : FC_REG(c98); // hemisphere ambient upper color
    UNIFORM_HALF4 gFC_HemAmbCol_d : FC_REG(c99); // hemisphere ambient lower color

    #define gFC_DifMapMulCol DL_FREG_100
    UNIFORM_HALF4 gFC_DifMapMulCol : FC_REG(c100); // diffuse map multiply color

    #define gFC_SpcMapMulCol DL_FREG_101
    UNIFORM_HALF4 gFC_SpcMapMulCol : FC_REG(c101); // specular map multiply color

    #define gFC_SpcParam DL_FREG_102
    UNIFORM_FLOAT4 gFC_SpcParam : FC_REG(c102);
    #define gFC_DebugDraw ((uint4)gFC_SpcParam) // specular parameters (x: exponent)

    #define gFC_FogCol DL_FREG_103
    UNIFORM_HALF4 gFC_FogCol : FC_REG(c103); // fog color (note: gVC side holds fog params)

    // Light scattering parameters
    #define gFC_LsBeta1PlusBeta2        DL_FREG_104
    #define gFC_LsTerrainReflectance    DL_FREG_105
    #define gFC_LsOneOverBeta1PlusBeta2 DL_FREG_106
    #define gFC_LsHGg                   DL_FREG_107
    #define gFC_LsBetaDash1             DL_FREG_108
    #define gFC_LsBetaDash2             DL_FREG_109
    #define gFC_LsSunColor              DL_FREG_110
    #define gFC_LsLightDir              DL_FREG_111
    UNIFORM_FLOAT4 gFC_LsBeta1PlusBeta2        : FC_REG(c104); // light scattering: beta1+beta2
    UNIFORM_FLOAT4 gFC_LsTerrainReflectance    : FC_REG(c105); // light scattering: rgb=ground reflectance, a=inscatter scale
    UNIFORM_FLOAT4 gFC_LsOneOverBeta1PlusBeta2 : FC_REG(c106); // light scattering: 1/(beta1+beta2)
    UNIFORM_FLOAT4 gFC_LsHGg                   : FC_REG(c107); // light scattering: Henyey-Greenstein g
    UNIFORM_FLOAT4 gFC_LsBetaDash1             : FC_REG(c108); // light scattering: betaDash1
    UNIFORM_FLOAT4 gFC_LsBetaDash2             : FC_REG(c109); // light scattering: betaDash2
    UNIFORM_FLOAT4 gFC_LsSunColor              : FC_REG(c110); // light scattering: rgb=sun color, a=blend factor
    UNIFORM_FLOAT4 gFC_LsLightDir              : FC_REG(c111); // light scattering: xyz=light dir (world, normalized), w=distance scale

    UNIFORM_FLOAT4 gFC_PntLightPos[4] : FC_REG(c112); // point light position (xyz: pos, w: 1/(falloffEnd-falloffStart))
    UNIFORM_FLOAT4 gFC_PntLightCol[4] : FC_REG(c116); // point light color (rgb: color, a: falloff end distance)

    #define gFC_AlphaChannelMask DL_FREG_120
    UNIFORM_FLOAT gFC_AlphaChannelMask : FC_REG(c120); // alpha channel mask for shadow map rendering

    #define gFC_ShadowMapParam  DL_FREG_121
    #define gFC_ShadowColor     DL_FREG_122
    #define gFC_ShadowStartDist DL_FREG_123
    UNIFORM_FLOAT4 gFC_ShadowMapParam  : FC_REG(c121); // shadow map parameters
    UNIFORM_HALF4  gFC_ShadowColor     : FC_REG(c122); // shadow color
    UNIFORM_FLOAT4 gFC_ShadowStartDist : FC_REG(c123); // shadow cascade start distances

    #define gFC_WaterReflectBand      DL_FREG_124
    #define gFC_WaterRefractBand      DL_FREG_125
    #define gFC_WaterWaveHeight       DL_FREG_126
    #define gFC_WaterColor            DL_FREG_127
    #define gFC_WaterFadeBegin        DL_FREG_128
    #define gFC_WaterFresnelPow       DL_FREG_129
    #define gFC_WaterFresnelBias      DL_FREG_130
    #define gFC_WaterFresnelScale     DL_FREG_131
    #define gFC_WaterFresnelColor     DL_FREG_132
    #define gFC_WaterFresnelFakeColor DL_FREG_133
    #define gFC_WaterTileBlend        DL_FREG_134
    UNIFORM_FLOAT  gFC_WaterReflectBand      : FC_REG(c124); // water reflection ripple width
    UNIFORM_FLOAT  gFC_WaterRefractBand      : FC_REG(c125); // water refraction ripple width
    UNIFORM_FLOAT  gFC_WaterWaveHeight       : FC_REG(c126); // water wave height scale
    UNIFORM_FLOAT4 gFC_WaterColor            : FC_REG(c127); // water color
    UNIFORM_FLOAT2 gFC_WaterFadeBegin        : FC_REG(c128); // water fade start alpha (0..1)
    UNIFORM_FLOAT  gFC_WaterFresnelPow       : FC_REG(c129); // Fresnel exponent (1..128)
    UNIFORM_FLOAT  gFC_WaterFresnelBias      : FC_REG(c130); // Fresnel bias (0..1)
    UNIFORM_FLOAT  gFC_WaterFresnelScale     : FC_REG(c131); // Fresnel scale (0..1)
    UNIFORM_FLOAT4 gFC_WaterFresnelColor     : FC_REG(c132); // Fresnel color
    UNIFORM_FLOAT4 gFC_WaterFresnelFakeColor : FC_REG(c133); // Fresnel fake color
    UNIFORM_FLOAT3 gFC_WaterTileBlend        : FC_REG(c134); // tile blend (x: tile0, y: tile1, z: tile2)

    #define gFC_ToneMap DL_FREG_135
    UNIFORM_FLOAT4 gFC_ToneMap : FC_REG(c135); // tonemap: x=exposure scale, y=tonemap scale, z=unused, w=texture gamma (unused)

    // Ghost (translucency) parameters
    #define gFC_GhostEdgeColor DL_FREG_136
    #define gFC_GhostTexColor  DL_FREG_137
    #define gFC_GhostParam     DL_FREG_138
    UNIFORM_HALF4  gFC_GhostEdgeColor : FC_REG(c136); // ghost edge color
    UNIFORM_HALF4  gFC_GhostTexColor  : FC_REG(c137); // ghost texture color
    UNIFORM_FLOAT4 gFC_GhostParam     : FC_REG(c138); // ghost params: x=blend rate (0..1), yzw=unused

    #define gFC_ModelMulCol DL_FREG_139
    UNIFORM_HALF4 gFC_ModelMulCol : FC_REG(c139); // model multiply color

    #define SHADOWMAP_SLICE_NUM 4
    #define gFC_ShadowMapMtxArray  DL_FREG_140A
    #define gFC_ShadowMapMtxArray0 gFC_ShadowMapMtxArray[0]
    #define gFC_ShadowMapMtxArray1 gFC_ShadowMapMtxArray[1]
    #define gFC_ShadowMapMtxArray2 gFC_ShadowMapMtxArray[2]
    #define gFC_ShadowMapMtxArray3 gFC_ShadowMapMtxArray[3]
    UNIFORM_FLOAT4x4 gFC_ShadowMapMtxArray[SHADOWMAP_SLICE_NUM] : FC_REG(c140); // shadow cascade matrices

    #define gFC_FgSkinAddColor DL_FREG_156
    UNIFORM_HALF4 gFC_FgSkinAddColor : FC_REG(c156); // FaceGen skin additive color

    #define gFC_ShadowMapClamp  DL_FREG_157A
    #define gFC_ShadowMapClamp0 gFC_ShadowMapClamp[0]
    #define gFC_ShadowMapClamp1 gFC_ShadowMapClamp[1]
    #define gFC_ShadowMapClamp2 gFC_ShadowMapClamp[2]
    #define gFC_ShadowMapClamp3 gFC_ShadowMapClamp[3]
    UNIFORM_FLOAT4 gFC_ShadowMapClamp[SHADOWMAP_SLICE_NUM] : FC_REG(c157); // shadow map UV clamp regions

    #define gFC_WaterWaveParam DL_FREG_163
    UNIFORM_FLOAT4 gFC_WaterWaveParam : FC_REG(c163); // water wave: x=camera FovY tan, y=wave fade dist, z=snow fade dist, w=heightmap min dimension

    #define gFC_WaterHeightMapSize DL_FREG_164
    UNIFORM_FLOAT4 gFC_WaterHeightMapSize : FC_REG(c164); // water heightmap: xy=size, zw=1/size

    #define gFC_WorldViewClipMtx DL_FREG_165
    UNIFORM_FLOAT4x4 gFC_WorldViewClipMtx : FC_REG(c165); // world-view-clip matrix

    #define gFC_SnowParam DL_FREG_169
    UNIFORM_FLOAT4 gFC_SnowParam : FC_REG(c169); // snow: x=height scale, y=subsurface, z=subsurface power, w=parallax scale

    #define gFC_SnowColor DL_FREG_170
    UNIFORM_FLOAT4 gFC_SnowColor : FC_REG(c170); // snow color

    #define gFC_SnowTileBlend DL_FREG_171
    UNIFORM_FLOAT4 gFC_SnowTileBlend : FC_REG(c171); // snow tile blend (x: tile0, y: tile1, z: tile2)

    #define gFC_SnowDetailParam DL_FREG_172
    UNIFORM_FLOAT4 gFC_SnowDetailParam : FC_REG(c172); // snow detail: x=bump scale, y=1/(blendTop-blendBot), z=blendBot, w=unused

    #define gFC_SnowSpecParam DL_FREG_173
    UNIFORM_FLOAT4 gFC_SnowSpecParam : FC_REG(c173); // snow specular: x=1/(specTop-specBot), y=specBot, z=inverse diff clamp, w=unused

    #define gFC_FaceEyeCol DL_FREG_174
    UNIFORM_FLOAT4 gFC_FaceEyeCol : FC_REG(c174); // FaceGen eye color

    #define gFC_ShadowLightDir DL_FREG_175
    UNIFORM_FLOAT4 gFC_ShadowLightDir : FC_REG(c175); // shadow casting light direction

    #define gFC_NormalToAlphaParam DL_FREG_176
    UNIFORM_FLOAT4 gFC_NormalToAlphaParam : FC_REG(c176); // normal-to-alpha: x=minAngle, y=1/(maxAngle-minAngle)

    #define gFC_SnowParam2 DL_FREG_177
    UNIFORM_FLOAT4 gFC_SnowParam2 : FC_REG(c177); // x=Roughness, y=MetalMask, z=DiffuseF0

    #define gFC_GhostLightPos DL_FREG_180
    UNIFORM_FLOAT4 gFC_GhostLightPos : FC_REG(c180); // ghost light position (xyz: pos, w: 1/(falloffEnd-falloffStart))

    #define gFC_GhostLightCol DL_FREG_181
    UNIFORM_FLOAT4 gFC_GhostLightCol : FC_REG(c181); // ghost light color (rgb: color, a: falloff end)

    #define gFC_DetailBumpParam DL_FREG_182
    UNIFORM_FLOAT4 gFC_DetailBumpParam : FC_REG(c182); // detail bump: xy=UV scale, z=bump power

    #define gFC_LightProbeParam DL_FREG_184
    UNIFORM_FLOAT4 gFC_LightProbeParam : FC_REG(c184); // light probe params

    #define gFC_DebugMaterialParams DL_FREG_185
    #define gFC_MaterialOverrideParams DL_FREG_185
    UNIFORM_FLOAT4 gFC_DebugMaterialParams : FC_REG(c185);

    #define gFC_DebugPointLightParams DL_FREG_186
    UNIFORM_FLOAT4 gFC_DebugPointLightParams : FC_REG(c186);

    #define gFC_SHEnabled DL_FREG_187
    UNIFORM_FLOAT gFC_SHEnabled : FC_REG(c187);

    #define gFC_IVMtx DL_FREG_188
    UNIFORM_FLOAT4x4 gFC_IVMtx : FC_REG(c188); // inverse view matrix

    #define gFC_SubsurfaceParam DL_FREG_192
    UNIFORM_FLOAT4 gFC_SubsurfaceParam : FC_REG(c192);

    #define gFC_SAOEnabled DL_FREG_193
    UNIFORM_FLOAT gFC_SAOEnabled : FC_REG(c193);

    #define gFC_MagicLightParam DL_FREG_194
    UNIFORM_FLOAT4 gFC_MagicLightParam : FC_REG(c194);
    #define gFC_NormalScale gFC_MagicLightParam.z

    #define gFC_GammaFlag DL_FREG_195
    UNIFORM_FLOAT4 gFC_GammaFlag : FC_REG(c195);

    #define gFC_PntLightCount DL_FREG_196
    UNIFORM_UINT4 gFC_PntLightCount : FC_REG(c196);

    #define gFC_ParallaxParams DL_FREG_197
    UNIFORM_FLOAT4 gFC_ParallaxParams : FC_REG(c197);

    #define gFC_DirLightCount DL_FREG_198
    UNIFORM_UINT4 gFC_DirLightCount : FC_REG(c198);

    #define gFC_DirLightParam DL_FREG_199
    UNIFORM_FLOAT4 gFC_DirLightParam : FC_REG(c199);

    // SFX
    #define gFC_GlowColor DL_FREG_35
    UNIFORM_FLOAT4 gFC_GlowColor : FC_REG(c35);

    #define gFC_SfxLightScatteringParams DL_FREG_34
    UNIFORM_FLOAT4 gFC_SfxLightScatteringParams : FC_REG(c34);

    #define gFC_MaterialWorkflow DL_FREG_202
    UNIFORM_UINT4 gFC_MaterialWorkflow : FC_REG(c202);

    #define gFC_ClipInfo DL_FREG_203
    UNIFORM_FLOAT4 gFC_ClipInfo : FC_REG(c203); // x=near, y=far, z=near-far, w=near*far

    #define gFC_ClusterParam DL_FREG_204
    UNIFORM_FLOAT4 gFC_ClusterParam : FC_REG(c204);

    #define gFC_ToneCorrectParams DL_FREG_205
    UNIFORM_FLOAT4 gFC_ToneCorrectParams : FC_REG(c205);

    #define gFC_AdaptParam DL_FREG_206
    UNIFORM_FLOAT4 gFC_AdaptParam : FC_REG(c206);

    #define gFC_fMiddleGray DL_FREG_207
    UNIFORM_FLOAT4 gFC_fMiddleGray : FC_REG(c207);

    #define gFC_PostEffectScale DL_FREG_208
    UNIFORM_FLOAT4 gFC_PostEffectScale : FC_REG(c208);

#else // !OLD_VERSION

    float4   gFC_EnvDifMapMulCol2        : FC_REG(c1);
    float4   gFC_EnvSpcMapMulCol2        : FC_REG(c2);
    float4   gFC_EnvDifMapMulCol         : FC_REG(c3);
    float4   gFC_EnvSpcMapMulCol         : FC_REG(c4);
    float4   gFC_SpcLightVec             : FC_REG(c5);
    float4   gFC_SpcLightCol             : FC_REG(c6);
    float4   gFC_HemAmbCol_u             : FC_REG(c7);
    float4   gFC_HemAmbCol_d             : FC_REG(c8);
    float4   gFC_DifMapMulCol            : FC_REG(c9);
    float4   gFC_SpcMapMulCol            : FC_REG(c10);
    float4   gFC_SpcParam                : FC_REG(c11);
    float4   gFC_FogCol                  : FC_REG(c12);
    float4   gFC_LsBeta1PlusBeta2        : FC_REG(c13);
    float4   gFC_LsTerrainReflectance    : FC_REG(c14);
    float4   gFC_LsOneOverBeta1PlusBeta2 : FC_REG(c15);
    float4   gFC_LsHGg                   : FC_REG(c16);
    float4   gFC_LsBetaDash1             : FC_REG(c17);
    float4   gFC_LsBetaDash2             : FC_REG(c18);
    float4   gFC_LsSunColor              : FC_REG(c19);
    float4   gFC_LsLightDir              : FC_REG(c20);
    float4   gFC_ShadowMapParam          : FC_REG(c21);
    float4   gFC_ShadowColor             : FC_REG(c22);
    float4   gFC_ShadowStartDist         : FC_REG(c23);
    float    gFC_WaterReflectBand        : FC_REG(c24);
    float    gFC_WaterRefractBand        : FC_REG(c25);
    float    gFC_WaterWaveHeight         : FC_REG(c26);
    float4   gFC_WaterColor              : FC_REG(c27);
    float2   gFC_WaterFadeBegin          : FC_REG(c28);
    float    gFC_WaterFresnelPow         : FC_REG(c29);
    float    gFC_WaterFresnelBias        : FC_REG(c30);
    float    gFC_WaterFresnelScale       : FC_REG(c31);
    float4   gFC_WaterFresnelColor       : FC_REG(c32);
    float4   gFC_WaterFresnelFakeColor   : FC_REG(c33);
    float3   gFC_WaterTileBlend          : FC_REG(c34);
    float4   gFC_ToneMap                 : FC_REG(c35);
    float4   gFC_GhostEdgeColor          : FC_REG(c36);
    float4   gFC_GhostTexColor           : FC_REG(c37);
    float4   gFC_GhostParam              : FC_REG(c38);
    float4   gFC_ModelMulCol             : FC_REG(c39);

#define gFC_ShadowMapMtxArray0 gFC_ShadowMapMtxArray[0]
#define gFC_ShadowMapMtxArray1 gFC_ShadowMapMtxArray[1]
#define gFC_ShadowMapMtxArray2 gFC_ShadowMapMtxArray[2]
#define gFC_ShadowMapMtxArray3 gFC_ShadowMapMtxArray[3]
    float4x4 gFC_ShadowMapMtxArray[4]   : FC_REG(c40);

#define gFC_ShadowMapClamp0 gFC_ShadowMapClamp[0]
#define gFC_ShadowMapClamp1 gFC_ShadowMapClamp[1]
#define gFC_ShadowMapClamp2 gFC_ShadowMapClamp[2]
#define gFC_ShadowMapClamp3 gFC_ShadowMapClamp[3]
    float4   gFC_ShadowMapClamp[4]       : FC_REG(c56);
    float4   gFC_FgSkinAddColor          : FC_REG(c60);
    float4   gFC_WaterWaveParam          : FC_REG(c61);
    float4   gFC_WaterHeightMapSize      : FC_REG(c62);
    float4x4 gFC_WorldViewClipMtx        : FC_REG(c63);
    float4   gFC_SnowParam               : FC_REG(c67);
    float4   gFC_SnowColor               : FC_REG(c68);
    float4   gFC_SnowTileBlend           : FC_REG(c69);
    float4   gFC_SnowDetailParam         : FC_REG(c70);
    float4   gFC_SnowSpecParam           : FC_REG(c71);
    float4   gFC_FaceEyeCol              : FC_REG(c72);
    float4   gFC_ShadowLightDir          : FC_REG(c73);
    float4   gFC_NormalToAlphaParam      : FC_REG(c74);
    float4   gFC_SnowParam2              : FC_REG(c75);
    float4   gFC_GhostLightPos           : FC_REG(c76);
    float4   gFC_GhostLightCol           : FC_REG(c77);
    float4   gFC_DetailBumpParam         : FC_REG(c78);

#define gFC_NormalScale gFC_LightProbeParam.z
    float4   gFC_LightProbeParam         : FC_REG(c79);
    float4   gFC_SubsurfaceParam         : FC_REG(c80);
    uint4    gFC_PntLightCount           : FC_REG(c81);
    float4   gFC_ParallaxParams          : FC_REG(c82);
    float4   gFC_GlowColor               : FC_REG(c83);
#ifndef WITH_GBuffer
    float4   gFC_SfxLightScatteringParams: FC_REG(c84);
    uint4    gFC_MaterialWorkflow        : FC_REG(c85);
    float4   gFC_ClipInfo                : FC_REG(c86);
    float4   gFC_ClusterParam            : FC_REG(c87);
    float4   gFC_ToneCorrectParams       : FC_REG(c88);
    float4   gFC_AdaptParam              : FC_REG(c89);

#define gFC_SAOEnabled gFC_SAOParams.w
    float4   gFC_SAOParams               : FC_REG(c90);
    float4   gFC_InverseToneMapEnable    : FC_REG(c91);
    float4   gFC_PntLightPos[4]          : FC_REG(c92);
    float4   gFC_PntLightCol[4]          : FC_REG(c96);

#define gFC_DebugMaterialParams gFC_MaterialOverrideParams
    float4   gFC_MaterialOverrideParams  : FC_REG(c100);
    float4   gFC_DebugPointLightParams   : FC_REG(c101);
    uint4    gFC_DebugDraw               : FC_REG(c102);
#else
    // GBuffer path: DL_FREG registers (dynamic lighting data, OLD_VERSION layout, offset 1344+)
    #define gFC_EnvDifMapMulCol2 DL_FREG_084
    #define gFC_EnvSpcMapMulCol2 DL_FREG_085
    float4   DL_FREG_084              : FC_REG(c84);
    float4   DL_FREG_085              : FC_REG(c85);
    #define gFC_EnvDifMapMulCol DL_FREG_086
    #define gFC_EnvSpcMapMulCol DL_FREG_087
    float4   DL_FREG_086              : FC_REG(c86);
    float4   DL_FREG_087              : FC_REG(c87);
    #define gFC_SpcLightVec DL_FREG_088
    #define gFC_SpcLightCol DL_FREG_089
    float4   DL_FREG_088              : FC_REG(c88);
    float4   DL_FREG_089              : FC_REG(c89);
    #define gFC_HemLightCol_u DL_FREG_090
    #define gFC_HemLightCol_d DL_FREG_091
    float4   DL_FREG_090              : FC_REG(c90);
    float4   DL_FREG_091              : FC_REG(c91);
    float4   DL_FREG_092              : FC_REG(c92); // gFC_DirLightVec[0]
    float4   DL_FREG_093              : FC_REG(c93);
    float4   DL_FREG_094              : FC_REG(c94);
    float4   DL_FREG_095              : FC_REG(c95); // gFC_DirLightCol[0]
    float4   DL_FREG_096              : FC_REG(c96);
    float4   DL_FREG_097              : FC_REG(c97);
    #define gFC_HemAmbCol_u     DL_FREG_098
    #define gFC_HemAmbCol_d     DL_FREG_099
    float4   DL_FREG_098              : FC_REG(c98);
    float4   DL_FREG_099              : FC_REG(c99);
    #define gFC_DifMapMulCol    DL_FREG_100
    #define gFC_SpcMapMulCol    DL_FREG_101
    float4   DL_FREG_100              : FC_REG(c100);
    float4   DL_FREG_101              : FC_REG(c101);
    #define gFC_SpcParam DL_FREG_102
    float4   DL_FREG_102              : FC_REG(c102);
    #define gFC_DebugDraw ((uint4)gFC_SpcParam)
    #define gFC_FogCol          DL_FREG_103
    float4   DL_FREG_103              : FC_REG(c103);
    #define gFC_LsBeta1PlusBeta2        DL_FREG_104
    #define gFC_LsTerrainReflectance    DL_FREG_105
    #define gFC_LsOneOverBeta1PlusBeta2 DL_FREG_106
    #define gFC_LsHGg                   DL_FREG_107
    #define gFC_LsBetaDash1             DL_FREG_108
    #define gFC_LsBetaDash2             DL_FREG_109
    #define gFC_LsSunColor              DL_FREG_110
    #define gFC_LsLightDir              DL_FREG_111
    float4   DL_FREG_104              : FC_REG(c104);
    float4   DL_FREG_105              : FC_REG(c105);
    float4   DL_FREG_106              : FC_REG(c106);
    float4   DL_FREG_107              : FC_REG(c107);
    float4   DL_FREG_108              : FC_REG(c108);
    float4   DL_FREG_109              : FC_REG(c109);
    float4   DL_FREG_110              : FC_REG(c110);
    float4   DL_FREG_111              : FC_REG(c111);
    #define gFC_PntLightPos   DL_FREG_112A
    #define gFC_PntLightPos0  DL_FREG_112
    #define gFC_PntLightPos1  DL_FREG_113
    #define gFC_PntLightPos2  DL_FREG_114
    #define gFC_PntLightPos3  DL_FREG_115
    float4   DL_FREG_112              : FC_REG(c112);
    float4   DL_FREG_113              : FC_REG(c113);
    float4   DL_FREG_114              : FC_REG(c114);
    float4   DL_FREG_115              : FC_REG(c115);
    #define gFC_PntLightCol   DL_FREG_116A
    #define gFC_PntLightCol0  DL_FREG_116
    #define gFC_PntLightCol1  DL_FREG_117
    #define gFC_PntLightCol2  DL_FREG_118
    #define gFC_PntLightCol3  DL_FREG_119
    float4   DL_FREG_116              : FC_REG(c116);
    float4   DL_FREG_117              : FC_REG(c117);
    float4   DL_FREG_118              : FC_REG(c118);
    float4   DL_FREG_119              : FC_REG(c119);
    #define gFC_AlphaChannelMask DL_FREG_120
    float    DL_FREG_120              : FC_REG(c120);
    #define gFC_ShadowMapParam  DL_FREG_121
    #define gFC_ShadowColor     DL_FREG_122
    #define gFC_ShadowStartDist DL_FREG_123
    float4   DL_FREG_121              : FC_REG(c121);
    float4   DL_FREG_122              : FC_REG(c122);
    float4   DL_FREG_123              : FC_REG(c123);
    float4   DL_FREG_124              : FC_REG(c124);
    float4   DL_FREG_125              : FC_REG(c125);
    float    DL_FREG_126              : FC_REG(c126);
    float4   DL_FREG_127              : FC_REG(c127);
    float2   DL_FREG_128              : FC_REG(c128);
    float    DL_FREG_129              : FC_REG(c129);
    float    DL_FREG_130              : FC_REG(c130);
    float    DL_FREG_131              : FC_REG(c131);
    float4   DL_FREG_132              : FC_REG(c132);
    float4   DL_FREG_133              : FC_REG(c133);
    float4   DL_FREG_134              : FC_REG(c134);
    #define gFC_ToneMap DL_FREG_135
    float4   DL_FREG_135              : FC_REG(c135);
    #define gFC_GhostEdgeColor DL_FREG_136
    #define gFC_GhostTexColor  DL_FREG_137
    #define gFC_GhostParam     DL_FREG_138
    float4   DL_FREG_136              : FC_REG(c136);
    float4   DL_FREG_137              : FC_REG(c137);
    float4   DL_FREG_138              : FC_REG(c138);
    #define gFC_ModelMulCol     DL_FREG_139
    float4   DL_FREG_139              : FC_REG(c139);
    #define gFC_ShadowMapMtxArray  DL_FREG_140A
    float4x4 DL_FREG_140A[4]          : FC_REG(c140);
    #define gFC_ShadowMapClamp  DL_FREG_157A
    float4   DL_FREG_157A[4]          : FC_REG(c157);
    #define gFC_ShadowLightDir DL_FREG_175
    #define gFC_FgSkinAddColor  DL_FREG_156
    float4   DL_FREG_156              : FC_REG(c156);
    float4   DL_FREG_163              : FC_REG(c163);
    float4   DL_FREG_164              : FC_REG(c164);
    float4x4 DL_FREG_165             : FC_REG(c165);
    float4   DL_FREG_169              : FC_REG(c169);
    float4   DL_FREG_170              : FC_REG(c170);
    float4   DL_FREG_171              : FC_REG(c171);
    float4   DL_FREG_172              : FC_REG(c172);
    float4   DL_FREG_173              : FC_REG(c173);
    float4   DL_FREG_174              : FC_REG(c174);
    float4   DL_FREG_175              : FC_REG(c175);
    float4   DL_FREG_176              : FC_REG(c176);
    float4   DL_FREG_177              : FC_REG(c177);
    #define gFC_GhostLightPos DL_FREG_180
    #define gFC_GhostLightCol DL_FREG_181
    float4   DL_FREG_180              : FC_REG(c180);
    float4   DL_FREG_181              : FC_REG(c181);
    float4   DL_FREG_182              : FC_REG(c182);
    #define gFC_LightProbeParam DL_FREG_184
    float4   DL_FREG_184              : FC_REG(c184);
    #define gFC_DebugMaterialParams DL_FREG_185
    float4   DL_FREG_185              : FC_REG(c185);
    #define gFC_DebugPointLightParams DL_FREG_186
    float4   DL_FREG_186              : FC_REG(c186);
    #define gFC_SHEnabled DL_FREG_187
    float    DL_FREG_187              : FC_REG(c187);
    #define gFC_IVMtx DL_FREG_188
    float4x4 DL_FREG_188             : FC_REG(c188);
    float4   DL_FREG_192              : FC_REG(c192);
    #define gFC_SAOEnabled DL_FREG_193
    float    DL_FREG_193              : FC_REG(c193);
    #define gFC_MagicLightParam DL_FREG_194
    float4   DL_FREG_194              : FC_REG(c194);
    #define gFC_GammaFlag DL_FREG_195
    float4   DL_FREG_195              : FC_REG(c195);
#endif

#endif // OLD_VERSION

#endif // ___FRPG_Flver_FRPG_Common_FC_fxh___
