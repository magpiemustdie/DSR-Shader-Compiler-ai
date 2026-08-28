// FRPG_Water_FC.fxh — $Globals layout for FRPG_Water_* / FRPG_WWS_* shaders.
// Reconstructed 1:1 from reference RDEF (FRPG_Water_Env____.fpo Buffer Definitions
// + 3DMigoto decompile). Declaration ORDER matters: RDEF lists variables in
// source order. First slot is c1 — c0 is not declared by the original source.

#ifndef ___FRPG_Water_FC_fxh___
#define ___FRPG_Water_FC_fxh___

#define WFC_REG(reg) register(reg)

float4   gFC_EnvDifMapMulCol2           : WFC_REG(c1);
float4   gFC_EnvSpcMapMulCol2           : WFC_REG(c2);
float4   gFC_EnvDifMapMulCol            : WFC_REG(c3);
float4   gFC_EnvSpcMapMulCol            : WFC_REG(c4);
float4   gFC_SpcLightVec                : WFC_REG(c5);
float4   gFC_SpcLightCol                : WFC_REG(c6);
float4   gFC_HemAmbCol_u                : WFC_REG(c7);
float4   gFC_HemAmbCol_d                : WFC_REG(c8);
float4   gFC_DifMapMulCol               : WFC_REG(c9);
float4   gFC_SpcMapMulCol               : WFC_REG(c10);
float4   gFC_SpcParam                   : WFC_REG(c11);
float4   gFC_FogCol                     : WFC_REG(c12);
float4   gFC_LsBeta1PlusBeta2           : WFC_REG(c13);
float4   gFC_LsTerrainReflectance       : WFC_REG(c14);
float4   gFC_LsOneOverBeta1PlusBeta2    : WFC_REG(c15);
float4   gFC_LsHGg                      : WFC_REG(c16);
float4   gFC_LsBetaDash1                : WFC_REG(c17);
float4   gFC_LsBetaDash2                : WFC_REG(c18);
float4   gFC_LsSunColor                 : WFC_REG(c19);
float4   gFC_LsLightDir                 : WFC_REG(c20);
float4   gFC_ShadowMapParam             : WFC_REG(c21);
float4   gFC_ShadowColor                : WFC_REG(c22);
float4   gFC_ShadowStartDist            : WFC_REG(c23);
float    gFC_WaterReflectBand           : WFC_REG(c24);
float    gFC_WaterRefractBand           : WFC_REG(c25);
float    gFC_WaterWaveHeight            : WFC_REG(c26);
float4   gFC_WaterColor                 : WFC_REG(c27);
float2   gFC_WaterFadeBegin             : WFC_REG(c28);
float    gFC_WaterFresnelPow            : WFC_REG(c29);
float    gFC_WaterFresnelBias           : WFC_REG(c30);
float    gFC_WaterFresnelScale          : WFC_REG(c31);
float4   gFC_WaterFresnelColor          : WFC_REG(c32);
float4   gFC_WaterFresnelFakeColor      : WFC_REG(c33);
float3   gFC_WaterTileBlend             : WFC_REG(c34);
float4   gFC_ToneMap                    : WFC_REG(c35);
float4   gFC_GhostEdgeColor             : WFC_REG(c36);
float4   gFC_GhostTexColor              : WFC_REG(c37);
float4   gFC_GhostParam                 : WFC_REG(c38);
float4   gFC_ModelMulCol                : WFC_REG(c39);
float4x4 gFC_ShadowMapMtxArray[4]       : WFC_REG(c40);
float4   gFC_ShadowMapClamp[4]          : WFC_REG(c56);
float4   gFC_FgSkinAddColor             : WFC_REG(c60);
float4   gFC_WaterWaveParam             : WFC_REG(c61);
float4   gFC_WaterHeightMapSize         : WFC_REG(c62);
float4x4 gFC_WorldViewClipMtx           : WFC_REG(c63);
float4   gFC_SnowParam                  : WFC_REG(c67);
float4   gFC_SnowColor                  : WFC_REG(c68);
float4   gFC_SnowTileBlend              : WFC_REG(c69);
float4   gFC_SnowDetailParam            : WFC_REG(c70);
float4   gFC_SnowSpecParam              : WFC_REG(c71);
float4   gFC_FaceEyeCol                 : WFC_REG(c72);
float4   gFC_ShadowLightDir             : WFC_REG(c73);
float4   gFC_NormalToAlphaParam         : WFC_REG(c74);
float4   gFC_SnowParam2                 : WFC_REG(c75);
float4   gFC_GhostLightPos              : WFC_REG(c76);
float4   gFC_GhostLightCol              : WFC_REG(c77);
float4   gFC_DetailBumpParam            : WFC_REG(c78);
float4   gFC_LightProbeParam            : WFC_REG(c79);
float4   gFC_SubsurfaceParam            : WFC_REG(c80);
uint4    gFC_PntLightCount              : WFC_REG(c81);
float4   gFC_ParallaxParams             : WFC_REG(c82);
float4   gFC_GlowColor                  : WFC_REG(c83);
float4   gFC_SfxLightScatteringParams   : WFC_REG(c84);
uint4    gFC_MaterialWorkflow           : WFC_REG(c85);
float4   gFC_ClipInfo                   : WFC_REG(c86);
float4   gFC_ClusterParam               : WFC_REG(c87);
float4   gFC_ToneCorrectParams          : WFC_REG(c88);
float4   gFC_AdaptParam                 : WFC_REG(c89);
float4   gFC_SAOParams                  : WFC_REG(c90);
float4   gFC_InverseToneMapEnable       : WFC_REG(c91);
float4   gFC_PntLightPos[4]             : WFC_REG(c92);
float4   gFC_PntLightCol[4]             : WFC_REG(c96);
float4   gFC_MaterialOverrideParams     : WFC_REG(c100);
float4   gFC_DebugPointLightParams      : WFC_REG(c101);
uint4    gFC_DebugDraw                  : WFC_REG(c102);
float4x4 gVC_WorldViewClipMtx           : WFC_REG(c103);
float4   gVC_CameraPos                  : WFC_REG(c107);
float4   gVC_WindParam_0                : WFC_REG(c108);
float4   gVC_WindParam_1                : WFC_REG(c109);
float4   gVC_FogParam                   : WFC_REG(c110);
float4x4 gVC_CommonREG8                 : WFC_REG(c111);
float4x4 gVC_CommonREG12                : WFC_REG(c115);
float4x4 gVC_ShadowMapMtx               : WFC_REG(c119);
float4   gVC_WaterTileScale             : WFC_REG(c123);
float4   gVC_WaterWaveParam             : WFC_REG(c124);
float4   gVC_SnowTileScale              : WFC_REG(c125);
float4   gVC_SnowDetailBumpTileScale    : WFC_REG(c126);
float4   gVC_SnowDiffuseTileScale       : WFC_REG(c127);
float4   gVC_TexScrl_0                  : WFC_REG(c128);
float4   gVC_TexScrl_1                  : WFC_REG(c129);
float4   gVC_ModelMulCol                : WFC_REG(c130);
row_major float3x4 gVC_LocalWorldMtxArray[38]     : WFC_REG(c131);
row_major float3x4 gVC_prevLocalWorldMtxArray[38]  : WFC_REG(c245);

#endif // ___FRPG_Water_FC_fxh___
