// FRPG_Snow_FC.fxh - full forward $Globals for snow (auto-generated from
// FRPG_Snow_LitCsd.fpo reference RDEF; declaration order = reference).

#ifndef ___FRPG_Snow_FC_fxh___
#define ___FRPG_Snow_FC_fxh___

    float4         gFC_EnvDifMapMulCol2             : register(c1); // [unused]
    float4         gFC_EnvSpcMapMulCol2             : register(c2); // [unused]
    float4         gFC_EnvDifMapMulCol              : register(c3);
    float4         gFC_EnvSpcMapMulCol              : register(c4);
    float4         gFC_SpcLightVec                  : register(c5); // [unused]
    float4         gFC_SpcLightCol                  : register(c6); // [unused]
    float4         gFC_HemAmbCol_u                  : register(c7);
    float4         gFC_HemAmbCol_d                  : register(c8);
    float4         gFC_DifMapMulCol                 : register(c9);
    float4         gFC_SpcMapMulCol                 : register(c10);
    float4         gFC_SpcParam                     : register(c11); // [unused]
    float4         gFC_FogCol                       : register(c12);
    float4         gFC_LsBeta1PlusBeta2             : register(c13);
    float4         gFC_LsTerrainReflectance         : register(c14);
    float4         gFC_LsOneOverBeta1PlusBeta2      : register(c15); // [unused]
    float4         gFC_LsHGg                        : register(c16);
    float4         gFC_LsBetaDash1                  : register(c17);
    float4         gFC_LsBetaDash2                  : register(c18);
    float4         gFC_LsSunColor                   : register(c19);
    float4         gFC_LsLightDir                   : register(c20);
    float4         gFC_ShadowMapParam               : register(c21);
    float4         gFC_ShadowColor                  : register(c22);
    float4         gFC_ShadowStartDist              : register(c23);
    float          gFC_WaterReflectBand             : register(c24); // [unused]
    float          gFC_WaterRefractBand             : register(c25); // [unused]
    float          gFC_WaterWaveHeight              : register(c26); // [unused]
    float4         gFC_WaterColor                   : register(c27); // [unused]
    float2         gFC_WaterFadeBegin               : register(c28); // [unused]
    float          gFC_WaterFresnelPow              : register(c29); // [unused]
    float          gFC_WaterFresnelBias             : register(c30); // [unused]
    float          gFC_WaterFresnelScale            : register(c31); // [unused]
    float4         gFC_WaterFresnelColor            : register(c32); // [unused]
    float4         gFC_WaterFresnelFakeColor        : register(c33); // [unused]
    float3         gFC_WaterTileBlend               : register(c34); // [unused]
    float4         gFC_ToneMap                      : register(c35); // [unused]
    float4         gFC_GhostEdgeColor               : register(c36); // [unused]
    float4         gFC_GhostTexColor                : register(c37); // [unused]
    float4         gFC_GhostParam                   : register(c38); // [unused]
    float4         gFC_ModelMulCol                  : register(c39);
    float4x4       gFC_ShadowMapMtxArray[4]         : register(c40);
    float4         gFC_ShadowMapClamp[4]            : register(c56);
    float4         gFC_FgSkinAddColor               : register(c60);
    float4         gFC_WaterWaveParam               : register(c61); // [unused]
    float4         gFC_WaterHeightMapSize           : register(c62); // [unused]
    float4x4       gFC_WorldViewClipMtx             : register(c63);
    float4         gFC_SnowParam                    : register(c67);
    float4         gFC_SnowColor                    : register(c68);
    float4         gFC_SnowTileBlend                : register(c69); // [unused]
    float4         gFC_SnowDetailParam              : register(c70);
    float4         gFC_SnowSpecParam                : register(c71);
    float4         gFC_FaceEyeCol                   : register(c72); // [unused]
    float4         gFC_ShadowLightDir               : register(c73);
    float4         gFC_NormalToAlphaParam           : register(c74); // [unused]
    float4         gFC_SnowParam2                   : register(c75);
    float4         gFC_GhostLightPos                : register(c76); // [unused]
    float4         gFC_GhostLightCol                : register(c77); // [unused]
    float4         gFC_DetailBumpParam              : register(c78);
    float4         gFC_LightProbeParam              : register(c79);
    float4         gFC_SubsurfaceParam              : register(c80); // [unused]
    uint4          gFC_PntLightCount                : register(c81);
    float4         gFC_ParallaxParams               : register(c82); // [unused]
    float4         gFC_GlowColor                    : register(c83); // [unused]
    uint4          gFC_MaterialWorkflow             : register(c85);
    float4         gFC_ClipInfo                     : register(c86);
    float4         gFC_ClusterParam                 : register(c87);
    float4         gFC_ToneCorrectParams            : register(c88); // [unused]
    float4         gFC_AdaptParam                   : register(c89); // [unused]
    float4         gFC_SAOParams                    : register(c90);
    float4         gFC_InverseToneMapEnable         : register(c91); // [unused]
    float4         gFC_PntLightPos[4]               : register(c92); // [unused]
    float4         gFC_PntLightCol[4]               : register(c96); // [unused]
    float4         gFC_MaterialOverrideParams       : register(c100);
    float4         gFC_DebugPointLightParams        : register(c101);
    uint4          gFC_DebugDraw                    : register(c102);
    float4x4       gVC_WorldViewClipMtx             : register(c103); // [unused]
    float4         gVC_CameraPos                    : register(c107); // [unused]
    float4         gVC_WindParam_0                  : register(c108); // [unused]
    float4         gVC_WindParam_1                  : register(c109); // [unused]
    float4         gVC_FogParam                     : register(c110); // [unused]
    float4x4       gVC_CommonREG8                   : register(c111); // [unused]
    float4x4       gVC_CommonREG12                  : register(c115); // [unused]
    float4x4       gVC_ShadowMapMtx                 : register(c119); // [unused]
    float4         gVC_WaterTileScale               : register(c123); // [unused]
    float4         gVC_WaterWaveParam               : register(c124); // [unused]
    float4         gVC_SnowTileScale                : register(c125); // [unused]
    float4         gVC_SnowDiffuseTileScale         : register(c127); // [unused]
    float4         gVC_TexScrl_0                    : register(c128); // [unused]
    float4         gVC_TexScrl_1                    : register(c129); // [unused]
    float4         gVC_ModelMulCol                  : register(c130); // [unused]

#endif