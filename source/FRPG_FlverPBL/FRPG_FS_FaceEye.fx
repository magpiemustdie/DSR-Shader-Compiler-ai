/***************************************************************************//**

    @file       FRPG_FS_FaceEye.fx
    @brief      Face eye fragment shader — forward-rendered
    @par        Non-FLVER, compact cb0[0..102] layout
    @author     decomp
    @version    v1.0

    Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/

//-----------------------------------------------------------------------------
// Resource bindings (match reference .fpo /dumpbin)
//-----------------------------------------------------------------------------
Texture2D    g_tBaseTex       : register(t0);
Texture2D    g_tNormalTex     : register(t1);
Texture2D    g_tShadowMap     : register(t7);
Texture2D    g_tSAOTex        : register(t8);
Texture2D    g_tGlowTex       : register(t9);
TextureCube  g_tEnvCube       : register(t11);
TextureCube  g_tSpecCube      : register(t12);

struct LightData {
    float4 position;
    float4 color;
    float attenuation;
    uint falloffMode;
    uint padding0;
    uint padding1;
};
StructuredBuffer<uint>    g_tNumLightsBuf   : register(t16);
StructuredBuffer<uint>    g_tLightIDBuf     : register(t17);
StructuredBuffer<LightData> g_tLightParamBuf: register(t18);

SamplerState g_sBaseSmp       : register(s0);
SamplerState g_sNormalSmp     : register(s1);
SamplerComparisonState g_sShadowCmp : register(s7);
SamplerState g_sSAOSmp        : register(s8);
SamplerState g_sGlowSmp       : register(s9);
SamplerState g_sEnvSmp        : register(s11);
SamplerState g_sSpecSmp       : register(s12);

//-----------------------------------------------------------------------------
// Constant buffer — FaceEye compact layout (cb0[0..102])
//-----------------------------------------------------------------------------
cbuffer Globals : register(b0)
{
    float4  gFC_Unused0          : packoffset(c0);
    float4  gFC_EnvDifMapMulCol2 : packoffset(c1);  // [unused]
    float4  gFC_EnvSpcMapMulCol2 : packoffset(c2);  // [unused]
    float4  gFC_EnvDifMapMulCol  : packoffset(c3);
    float4  gFC_EnvSpcMapMulCol  : packoffset(c4);
    float4  gFC_SpcLightVec      : packoffset(c5);  // [unused]
    float4  gFC_SpcLightCol      : packoffset(c6);  // [unused]
    float4  gFC_HemAmbCol_u      : packoffset(c7);
    float4  gFC_HemAmbCol_d      : packoffset(c8);
    float4  gFC_DifMapMulCol     : packoffset(c9);
    float4  gFC_SpcMapMulCol     : packoffset(c10);
    float4  gFC_SpcParam         : packoffset(c11); // [unused]
    float4  gFC_FogCol           : packoffset(c12);
    float4  gFC_LsBeta1PlusBeta2 : packoffset(c13);
    float4  gFC_LsTerrainReflectance : packoffset(c14);
    float4  gFC_LsOneOverBeta1PlusBeta2 : packoffset(c15);
    float4  gFC_LsHGg            : packoffset(c16);
    float4  gFC_LsBetaDash1      : packoffset(c17);
    float4  gFC_LsBetaDash2      : packoffset(c18);
    float4  gFC_LsSunColor       : packoffset(c19);
    float4  gFC_LsLightDir       : packoffset(c20);
    float4  gFC_ShadowMapParam   : packoffset(c21); // [unused]
    float4  gFC_ShadowColor      : packoffset(c22); // [unused]
    float4  gFC_ShadowStartDist  : packoffset(c23); // [unused]
    float   gFC_WaterReflectBand : packoffset(c24); // [unused]
    float   gFC_WaterRefractBand : packoffset(c25); // [unused]
    float   gFC_WaterWaveHeight  : packoffset(c26); // [unused]
    float4  gFC_WaterColor       : packoffset(c27); // [unused]
    float2  gFC_WaterFadeBegin   : packoffset(c28); // [unused]
    float   gFC_WaterFresnelPow  : packoffset(c29); // [unused]
    float   gFC_WaterFresnelBias : packoffset(c30); // [unused]
    float   gFC_WaterFresnelScale: packoffset(c31); // [unused]
    float4  gFC_WaterFresnelColor: packoffset(c32); // [unused]
    float4  gFC_WaterFresnelFakeColor : packoffset(c33); // [unused]
    float3  gFC_WaterTileBlend   : packoffset(c34); // [unused]
    float4  gFC_ToneMap          : packoffset(c35); // [unused]
    float4  gFC_GhostEdgeColor   : packoffset(c36);
    float4  gFC_GhostTexColor    : packoffset(c37);
    float4  gFC_GhostParam       : packoffset(c38);
    float4  gFC_ModelMulCol      : packoffset(c39); // [unused]
    float4x4 gFC_ShadowMapMtxArray[4] : packoffset(c40); // [unused]
    float4  gFC_ShadowMapClamp[4]: packoffset(c56); // [unused]
    float4  gFC_FgSkinAddColor   : packoffset(c60);
    float4  gFC_WaterWaveParam   : packoffset(c61); // [unused]
    float4  gFC_WaterHeightMapSize: packoffset(c62); // [unused]
    float4  gFC_WorldViewClipRow0 : packoffset(c63);
    float4  gFC_WorldViewClipRow1 : packoffset(c64);
    float4  gFC_WorldViewClipRow2 : packoffset(c65);
    float4  gFC_WorldViewClipRow3 : packoffset(c66);
    float4  gFC_SnowParam        : packoffset(c67); // [unused]
    float4  gFC_SnowColor        : packoffset(c68); // [unused]
    float4  gFC_SnowTileBlend    : packoffset(c69); // [unused]
    float4  gFC_SnowDetailParam  : packoffset(c70); // [unused]
    float4  gFC_SnowSpecParam    : packoffset(c71); // [unused]
    float4  gFC_FaceEyeCol       : packoffset(c72);
    float4  gFC_ShadowLightDir   : packoffset(c73); // [unused]
    float4  gFC_NormalToAlphaParam: packoffset(c74); // [unused]
    float4  gFC_SnowParam2       : packoffset(c75); // [unused]
    float4  gFC_GhostLightPos    : packoffset(c76);
    float4  gFC_GhostLightCol    : packoffset(c77);
    float4  gFC_DetailBumpParam  : packoffset(c78); // [unused]
    float4  gFC_LightProbeParam  : packoffset(c79);
    float4  gFC_SubsurfaceParam  : packoffset(c80); // [unused]
    uint4   gFC_PntLightCount    : packoffset(c81);
    float4  gFC_ParallaxParams   : packoffset(c82); // [unused]
    float4  gFC_GlowColor        : packoffset(c83); // [unused]
    float4  gFC_SfxLightScatteringParams: packoffset(c84); // [unused]
    uint4   gFC_MaterialWorkflow : packoffset(c85);
    float4  gFC_ClipInfo         : packoffset(c86);
    float4  gFC_ClusterParam     : packoffset(c87);
    float4  gFC_ToneCorrectParams: packoffset(c88); // [unused]
    float4  gFC_AdaptParam       : packoffset(c89); // [unused]
    float4  gFC_SAOParams        : packoffset(c90);
    float4  gFC_InverseToneMapEnable: packoffset(c91); // [unused]
    float4  gFC_PntLightPos[4]   : packoffset(c92); // [unused]
    float4  gFC_PntLightCol[4]   : packoffset(c96); // [unused]
    float4  gFC_MaterialOverrideParams: packoffset(c100);
    float4  gFC_DebugPointLightParams: packoffset(c101); // [unused]
    uint4   gFC_DebugDraw        : packoffset(c102);
}

//-----------------------------------------------------------------------------
// Input / Output
//-----------------------------------------------------------------------------
struct VS_OUT
{
    float4 Pos      : SV_Position;
    float4 WorldPos : TEXCOORD0;
#ifdef FACEEYE_SHADOW_PROJ
    float4 ShdProj  : TEXCOORD1;
#endif
    float4 Tangent  : TEXCOORD2;
    float4 ViewDir  : TEXCOORD3;
    float4 ColVtx   : COLOR0;
    float2 TexUV    : TEXCOORD6;
#ifndef FACEEYE_NO_FFACE
    uint   IsFront  : SV_IsFrontFace;
#endif
};

struct PS_OUT
{
    float4 Color : SV_Target0;
    float4 Debug : SV_Target1;
};

//=============================================================================
// FragmentMain — decompiled from FRPG_Gst_FaceEye____.fpo
//=============================================================================
PS_OUT FragmentMain(VS_OUT In)
{
    // Register-based body matching reference ASM
    float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13;
    float4 v0 = In.Pos, v1 = In.WorldPos, v2 = In.Tangent;
    float4 v3 = In.ViewDir, v4 = In.ColVtx, v5 = float4(In.TexUV,0,0);
#ifdef FACEEYE_SHADOW_PROJ
    float4 v6 = In.ShdProj;
#endif
    float4 o0 = 0, o1 = 0;

    r0.x = dot(v3.xyz, v3.xyz);
    r0.x = sqrt(r0.x);
    r0.yzw = v3.xyz / r0.xxx;
    r1.xyzw = g_tBaseTex.Sample(g_sBaseSmp, v5.xy);
    r2.xyz = r1.xyz * gFC_FaceEyeCol.xyz - r1.xyz;
    r1.xyz = mad(r1.www, r2.xyz, r1.xyz);
    r1.xyz = r1.xyz + gFC_FgSkinAddColor.xyz;
    r1.xyz = r1.xyz * v4.xyz;
    r1.w = dot(v2.xyz, v2.xyz);
    r1.w = rsqrt(r1.w);
    r2.xyz = r1.www * v2.xyz;
#if defined(FACEEYE_SHADOW_PROJ)
    float3 shadow_factor;
    {
        float4 shd = v6.wwww * gFC_ShadowMapClamp[0];
        shd.xy = (v6.xy < shd.xy) ? 1.0f : 0.0f;
        shd.xy = v6.xy - shd.xy * v6.w;
        shd.zw = (shd.zw < shd.xy) ? 1.0f : 0.0f;
        shd.xy = shd.xy + shd.zw * v6.w;
        r2.w = saturate((dot(gFC_ShadowLightDir.xyz, r2.xyz) + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
        shd.w = saturate((gFC_ShadowMapParam.y - r0.x) * gFC_ShadowMapParam.z);
        shd.z = v6.z;
        shd.xyz = shd.xyz / v6.w;
        float4 s0 = float4(
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(-1, -1)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(0, -1)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(1, -1)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(-1, 0)));
        r3.x = dot(s0, float4(0.111111112f, 0.111111112f, 0.111111112f, 0.111111112f));
        float4 s1 = float4(
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(0, 0)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(1, 0)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(-1, 1)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(0, 1)));
        r3.y = dot(s1, float4(0.111111112f, 0.111111112f, 0.111111112f, 0.111111112f));
        r3.x = r3.x + r3.y;
        r3.z = g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(1, 1));
        r3.x = mad(r3.z, 0.111111112f, r3.x);
        r2.w = min(r2.w + r3.x, 1.0f);
        shd.xyz = shd.www * gFC_ShadowColor.xyz;
        shd.xyz = 1.0f - shd.xyz * r2.w;
        shadow_factor = exp2(log2(abs(shd.xyz)) * gFC_DebugPointLightParams.z);
    }
#elif defined(WITH_ShadowMap) && WITH_ShadowMap == 2
    float3 shadow_factor;
    {
        float4 casSel = (gFC_ShadowStartDist.xyzw < v1.wwww) ? 1.0f : 0.0f;
        float casSum = dot(casSel, float4(1.0f, 1.0f, 1.0f, 1.0f));
        casSum = -1.0f + casSum;
        int casIdx = (int)casSum;
        float4 wpos = float4(v1.xyz, 1.0f);
        float4x4 casMtx = gFC_ShadowMapMtxArray[casIdx];
        float4 shd;
        shd.x = dot(wpos, casMtx._m00_m10_m20_m30);
        shd.y = dot(wpos, casMtx._m01_m11_m21_m31);
        shd.z = dot(wpos, casMtx._m02_m12_m22_m32);
        shd.w = dot(wpos, casMtx._m03_m13_m23_m33);
        float4 cl = gFC_ShadowMapClamp[casIdx] * shd.wwww;
        shd.xy -= (shd.xy < cl.xy) * shd.w;
        shd.xy += (shd.xy > cl.zw) * shd.w;
        r2.w = saturate((dot(gFC_ShadowLightDir.xyz, r2.xyz) + gFC_ShadowMapParam.x) * gFC_ShadowMapParam.w);
        shd.w = saturate((gFC_ShadowMapParam.y - r0.x) * gFC_ShadowMapParam.z);
        shd.xyz = shd.xyz / shd.w;
        float4 s0 = float4(
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(-1, -1)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(0, -1)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(1, -1)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(-1, 0)));
        r3.x = dot(s0, float4(0.111111112f, 0.111111112f, 0.111111112f, 0.111111112f));
        float4 s1 = float4(
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(0, 0)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(1, 0)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(-1, 1)),
            g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(0, 1)));
        r3.y = dot(s1, float4(0.111111112f, 0.111111112f, 0.111111112f, 0.111111112f));
        r3.x = r3.x + r3.y;
        r3.z = g_tShadowMap.SampleCmp(g_sShadowCmp, shd.xy, shd.z, int2(1, 1));
        r3.x = mad(r3.z, 0.111111112f, r3.x);
        r2.w = min(r2.w + r3.x, 1.0f);
        shd.xyz = shd.www * gFC_ShadowColor.xyz;
        shd.xyz = 1.0f - shd.xyz * r2.w;
        shadow_factor = exp2(log2(abs(shd.xyz)) * gFC_DebugPointLightParams.z);
    }
#endif
    r3.xyzw = g_tNormalTex.Sample(g_sNormalSmp, v5.xy).wxyz;
    if (gFC_MaterialWorkflow.x == 0) {
        float4 ov = gFC_MaterialOverrideParams;
        r4.xyz = float3(-1,-1,-1) + ov.xyz;
        r5.xyz = saturate(ov.xyz);
        r4.xy = -r3.yz + r4.xy;
        r6.xy = mad(r5.xy, r4.xy, r3.yz);
        r2.w = r3.w * 0.2f;
        r4.x = dot(gFC_SpcMapMulCol.xyz, float3(0.2126729f, 0.7151522f, 0.0721750f));
        r4.x = max(r4.x, 0.001f);
        r2.w = saturate(r2.w * r4.x);
        r4.x = r4.z - r2.w;
        r2.w = mad(r5.z, r4.x, r2.w);
        r4.x = -r3.x + 1.0f;
        r4.x = r4.x * ov.w;
        r4.x = r4.x * 10.0f;
        r4.yzw = -gFC_DifMapMulCol.xyz + gFC_SpcMapMulCol.xyz;
        r4.yzw = mad(r6.yyy, r4.yzw, gFC_DifMapMulCol.xyz);
        r4.yzw = r1.xyz * r4.yzw;
        r4.yzw = log2(abs(r4.yzw));
        r4.yzw = r4.yzw * 2.2f;
        r4.yzw = exp2(r4.yzw);
        r5.xyz = r3.xxx * r4.yzw;
        r5.w = 1.0f - r6.y;
        r5.xyz = r5.xyz * r5.www;
        r7.xyz = -r2.www + r4.yzw;
        r7.xyz = mad(r6.yyy, r7.xyz, r2.www);
        r7.xyz = saturate(r3.xxx * r7.xyz);
        r4.xyz = r4.yzw * r4.xxx;
    } else {
        r1.xyz = r1.xyz * gFC_DifMapMulCol.xyz;
        r1.xyz = log2(abs(r1.xyz));
        r1.xyz = r1.xyz * 2.2f;
        r5.xyz = exp2(r1.xyz);
        r1.xyz = saturate(r3.yzw * gFC_SpcMapMulCol.xyz);
        r1.xyz = log2(r1.xyz);
        r1.xyz = r1.xyz * 2.2f;
        r7.xyz = exp2(r1.xyz);
        float ovx = gFC_MaterialOverrideParams.x;
        r1.x = -1.0f + ovx;
        r1.y = saturate(ovx);
        r1.x = r1.x - r3.x;
        r6.x = mad(r1.y, r1.x, r3.x);
        r4.xyz = 0;
        r3.x = 1.0f;
    }
    uint dbg = gFC_DebugDraw.y;
    if (dbg != 0) {
        uint dbg0 = dbg & 3;
        uint dbg1 = (dbg >> 2) & 3;
        switch (dbg0) {
        case 1: r5.xyz = 0; break;
        case 2: r5.xyz = 1.0f; break;
        }
        switch (dbg1) {
        case 1: r7.xyz = 0; break;
        case 2: r7.xyz = 1.0f; break;
        }
    }
    r1.x = dot(r7.xyz, float3(0.33f, 0.33f, 0.33f));
    r1.x = min(r1.x * 50.0f, 1.0f);
    r1.y = dot(r2.xyz, r0.yzw);
    r1.z = r1.y + r1.y;
    r3.yzw = mad(r1.zzz, r2.xyz, -r0.yzw);
    r6.y = saturate(r1.y);
    r1.z = saturate(1.0f - r6.x);
    r2.w = sqrt(r1.z);
    r2.w = r2.w + r6.x;
    r1.z = r1.z * r2.w;
    r8.xyz = mad(-v2.xyz, r1.www, r3.yzw);
    r8.xyz = mad(r1.zzz, r8.xyz, r2.xyz);
    r1.z = -1.0f + gFC_LightProbeParam.w;
    r1.w = log2(r6.x);
    r1.z = mad(r1.w, 1.2f, r1.z);
    r1.z = r1.z - 2.0f;
    r9.xyz = gFC_EnvSpcMapMulCol.xyz * gFC_LightProbeParam.x;
    r8.xyz = g_tSpecCube.SampleLevel(g_sSpecSmp, r8.xyz, r1.z).xyz;
    r8.xyz = r9.xyz * r8.xyz;
    r1.z = dot(v2.xyz, r3.yzw);
    r1.z = saturate(mad(r1.z, 1.3f, 1.0f));
    r1.z = r1.z * r1.z;
    r3.yzw = r8.xyz * r1.zzz;
    r1.zw = g_tGlowTex.SampleLevel(g_sGlowSmp, r6.xy, 0).xy;
    r8.xyz = r7.xyz * r1.zzz + r1.xxx * r1.www;
    r3.yzw = r3.yzw * r8.xyz;
    r8.xyz = gFC_EnvDifMapMulCol.xyz * gFC_LightProbeParam.x;
    r9.xyz = g_tEnvCube.SampleLevel(g_sEnvSmp, r2.xyz, 0).xyz;
    r8.xyz = r8.xyz * r9.xyz;
    r3.yzw = r8.xyz * r5.xyz + r3.yzw;
#if defined(FACEEYE_SHADOW_PROJ) || (defined(WITH_ShadowMap) && WITH_ShadowMap == 2)
    r3.yzw = r3.xxx * r3.yzw;
#endif
    r1.z = r2.y * 0.5f + 0.5f;
    r8.xyz = gFC_HemAmbCol_u.xyz - gFC_HemAmbCol_d.xyz;
    r8.xyz = mad(r1.zzz, r8.xyz, gFC_HemAmbCol_d.xyz);
    r8.xyz = r5.xyz * r8.xyz;
#if defined(FACEEYE_SHADOW_PROJ) || (defined(WITH_ShadowMap) && WITH_ShadowMap == 2)
    r3.xyz = r3.yzw * shadow_factor + r8.xyz;
#else
    r3.xyz = mad(r3.xxx, r3.yzw, r8.xyz);
#endif
    if (gFC_SAOParams.w != 0) {
        r1.zw = v0.xy * gFC_SAOParams.xy;
        r1.z = g_tSAOTex.SampleLevel(g_sSAOSmp, r1.zw, 0).x;
        r3.xyz = r3.xyz * r1.zzz;
    }
    r3.xyz = r4.xyz + r3.xyz;
#ifndef WITH_PntS
    r8.xyz = v1.xyz;
    r8.w = 1.0f;
    r9.x = dot(r8.xyzw, gFC_WorldViewClipRow0);
    r9.y = dot(r8.xyzw, gFC_WorldViewClipRow1);
    r9.z = dot(r8.xyzw, gFC_WorldViewClipRow2);
    r1.z = dot(r8.xyzw, gFC_WorldViewClipRow3);
    r8.xyz = r9.xyz / r1.zzz;
    r1.zw = r8.xy * float2(0.5f, 0.5f) + 0.5f;
    r1.zw = r1.zw * float2(16.0f, 8.0f);
    r1.zw = floor(r1.zw);
    r1.zw = min(r1.zw, float2(15.0f, 7.0f));
    uint u_cx = (uint)r1.z;
    uint u_cy = (uint)r1.w;
    r2.w = mad(r8.z, gFC_ClipInfo.z, gFC_ClipInfo.y);
    r2.w = gFC_ClipInfo.w / r2.w;
    r2.w = r2.w / gFC_ClipInfo.x;
    r2.w = log2(r2.w);
    r2.w = r2.w * gFC_ClusterParam.x;
    r2.w = min(r2.w, 23.0f);
    {
        uint u_cz = (uint)r2.w;
        u_cz = u_cz << 3;
        u_cy = u_cy + u_cz;
        u_cy = u_cy << 4;
        u_cx = u_cy + u_cx;
    }
    uint packed = g_tNumLightsBuf[u_cx];
    uint num_lights = min(packed & 63, (uint)gFC_PntLightCount.x);
    uint cluster_offset = packed >> 12;
    uint total_lights = cluster_offset + num_lights;
    r4.xyz = r5.xyz * 0.318309873f;
    r2.w = max(r6.x, 0.014f);
    r9.xyz = -r1.xxx * r7.xyz + r1.xxx;
    r1.x = r2.w * r2.w;
    r2.w = r1.x * r1.x - 1.0f;
    r3.w = r1.x * 0.5f;
    r4.w = 1.0f - r1.x * 0.5f;
    r5.w = mad(r6.y, r4.w, r3.w);
    r5.w = 1.0f / r5.w;
    r10.xyz = 0;
    [loop] for (uint loop_idx = cluster_offset; loop_idx < total_lights; loop_idx++) {
        uint light_id = g_tLightIDBuf[loop_idx] & 511;
        LightData ld = g_tLightParamBuf[light_id];
        float4 r11v = ld.position;
        float4 r12v = ld.color;
        r11v.xyz = r11v.xyz - v1.xyz;
        float dist = length(r11v.xyz);
        [branch] if (dist < r12v.w) {
            float3 L = r11v.xyz / dist;
            float3 H = r0.yzw + L;
            float inv_len_h = rsqrt(dot(H, H));
            H = H * inv_len_h;
            float VdotH = saturate(dot(r0.yzw, H));
            float NdotH = saturate(dot(r2.xyz, H));
            float LdotH = saturate(dot(r2.xyz, L));
            float spec_alpha = exp2(mad(VdotH, -5.55473f, -6.98316f) * VdotH);
            float3 F = mad(r9.xyz, spec_alpha, r7.xyz);
            float D = r1.x / mad(NdotH * NdotH, r2.w, 1.0f);
            D = D * D * 0.318309873f;
            float G = 1.0f / mad(LdotH, r4.w, r3.w);
            G = r5.w * G;
            D = D * G;
            D = D * 0.25f;
            float3 contrib = F * D;
            float atten = r11v.w * (r12v.w - dist);
            atten = saturate(atten * atten * atten);
            contrib = contrib + r5.xyz * 0.318309873f;
            contrib = r12v.xyz * contrib;
            contrib = atten * contrib;
            contrib = LdotH * contrib;
            r10.xyz = mad(contrib, 3.14159274f, r10.xyz);
        }
    }
#else
    uint num_pnt = min(gFC_PntLightCount.x, 4u);
    r3.x = max(r6.x, 0.014f);
    r9.xyz = -r1.xxx * r7.xyz + r1.xxx;
    r1.x = r3.x * r3.x;
    r2.w = r1.x * r1.x - 1.0f;
    r3.w = r1.x * 0.5f;
    r4.w = 1.0f - r1.x * 0.5f;
    r5.w = mad(r6.y, r4.w, r3.w);
    r5.w = 1.0f / r5.w;
    r10.xyz = 0;
    [loop] for (uint loop_idx = 0; loop_idx < num_pnt; loop_idx++) {
        float4 r11v = gFC_PntLightPos[loop_idx];
        float4 r12v = gFC_PntLightCol[loop_idx];
        r11v.xyz = r11v.xyz - v1.xyz;
        float dist = length(r11v.xyz);
        [branch] if (dist < r12v.w) {
            float3 L = r11v.xyz / dist;
            float3 H = r0.yzw + L;
            float inv_len_h = rsqrt(dot(H, H));
            H = H * inv_len_h;
            float VdotH = saturate(dot(r0.yzw, H));
            float NdotH = saturate(dot(r2.xyz, H));
            float LdotH = saturate(dot(r2.xyz, L));
            float spec_alpha = exp2(mad(VdotH, -5.55473f, -6.98316f) * VdotH);
            float3 F = mad(r9.xyz, spec_alpha, r7.xyz);
            float D = r1.x / mad(NdotH * NdotH, r2.w, 1.0f);
            D = D * D * 0.318309873f;
            float G = 1.0f / mad(LdotH, r4.w, r3.w);
            G = r5.w * G;
            D = D * G;
            D = D * 0.25f;
            float3 contrib = F * D;
            float atten = r11v.w * (r12v.w - dist);
            atten = saturate(atten * atten * atten);
            contrib = contrib + r5.xyz * 0.318309873f;
            contrib = r12v.xyz * contrib;
            contrib = atten * contrib;
            contrib = LdotH * contrib;
            r10.xyz = mad(contrib, 3.14159274f, r10.xyz);
        }
    }
#endif
#ifdef WITH_GhostMap
    r11.xyz = -v1.xyz + gFC_GhostLightPos.xyz;
    r1.z = dot(r11.xyz, r11.xyz);
    r1.z = sqrt(r1.z);
    r12.xyz = r0.yzw + r11.xyz;
    r1.w = dot(r12.xyz, r12.xyz);
    r1.w = rsqrt(r1.w);
    r12.xyz = r12.xyz * r1.www;
    r1.w = saturate(dot(r0.yzw, r12.xyz));
    r6.y = saturate(dot(r2.xyz, r12.xyz));
    r6.w = saturate(dot(r2.xyz, r11.xyz));
    r7.w = mad(r1.w, -5.55473f, -6.98316f);
    r1.w = r1.w * r7.w;
    r1.w = exp2(r1.w);
    r9.xyz = mad(r9.xyz, r1.www, r7.xyz);
    r1.w = r6.y * r6.y;
    r1.w = mad(r1.w, r2.w, 1.0f);
    r1.x = r1.x / r1.w;
    r1.x = r1.x * r1.x;
    r1.x = r1.x * 0.318309873f;
    r1.w = mad(r6.w, r4.w, r3.w);
    r1.w = 1.0f / r1.w;
    r1.w = r1.w * r5.w;
    r1.x = r1.x * r1.w;
    r1.x = r1.x * 0.25f;
    r1.z = -r1.z + gFC_GhostLightCol.w;
    r1.z = r1.z * gFC_GhostLightPos.w;
    r1.w = r1.z * r1.z;
    r1.z = saturate(r1.z * r1.w);
    r8.xyz = mad(r9.xyz, r1.xxx, r5.xyz);
    r8.xyz = r8.xyz * gFC_GhostLightCol.xyz;
    r1.xzw = r1.zzz * r8.xyz;
    r1.xzw = r1.xzw * r6.www;
    r1.xzw = mad(r1.xzw, 3.14159274f, r10.xyz);
    r1.xzw = r3.xyz + r1.xzw;
    r3.xyz = gFC_GhostEdgeColor.xyz * gFC_GhostEdgeColor.www;
    r1.y = min(abs(r1.y), 0.7f);
    r1.y = max(r1.y, 0.1f);
    r1.y = r1.y - 0.1f;
    r1.y = r1.y * 1.6666666f;
    r8.xyz = gFC_GhostTexColor.xyz * gFC_GhostTexColor.www - r3.xyz;
    r3.xyz = mad(r1.yyy, r8.xyz, r3.xyz);
    r3.xyz = r3.xyz * gFC_GhostParam.x;
    r8.xyz = log2(abs(r3.xyz));
    r8.xyz = r8.xyz * 2.2f;
    r8.xyz = exp2(r8.xyz);
    r3.xyz = sign(r3.xyz);
    r1.xyz = saturate(mad(r8.xyz, r3.xyz, r1.xzw));
#else
    r1.xyz = r10.xyz + r3.xyz;
#endif
    r1.xyz = log2(abs(r1.xyz));
    r1.xyz = r1.xyz * (1.0f / 2.2f);
    r1.xyz = exp2(r1.xyz);
    r1.w = saturate(v2.w);
    r1.w = saturate(r1.w * gFC_FogCol.w);
    r3.xyz = -r1.xyz + gFC_FogCol.xyz;
    r1.xyz = mad(r1.www, r3.xyz, r1.xyz);
    r0.y = dot(r0.yzw, gFC_LsLightDir.xyz);
    r0.z = r0.y * r0.y + 1.0f;
    r3.xyz = r0.xxx * (-gFC_LsBeta1PlusBeta2.xyz);
    r3.xyz = r3.xyz * gFC_LsLightDir.w;
    r3.xyz = r3.xyz * 2.081369f;
    r3.xyz = exp2(r3.xyz);
    r8.xyz = r3.xyz * gFC_LsTerrainReflectance.xyz;
    r0.x = mad(gFC_LsHGg.z, -r0.y, gFC_LsHGg.y);
    r0.y = rsqrt(r0.x);
    r0.x = 1.0f / r0.x;
    r0.x = r0.y * r0.x;
    r0.x = r0.x * gFC_LsHGg.x;
    float4 b2phase = r0.xxxx * gFC_LsBetaDash2.xyxz;
    r0.xyw = b2phase.xyw;
    r0.xyz = gFC_LsBetaDash1.xyz * r0.zzz + r0.xyw;
    r3.xyz = -r3.xyz + 1.0f;
    r0.xyz = r0.xyz * r3.xyz;
    r0.xyz = r0.xyz * gFC_LsOneOverBeta1PlusBeta2.xyz;
    r0.xyz = r0.xyz * gFC_LsTerrainReflectance.www;
    r0.xyz = r0.xyz * gFC_LsSunColor.xyz;
    r0.xyz = r1.xyz * r8.xyz + r0.xyz;
    r0.xyz = r0.xyz - r1.xyz;
    r0.xyz = mad(gFC_LsSunColor.www, r0.xyz, r1.xyz);
    r0.xyz = log2(abs(r0.xyz));
    r0.xyz = r0.xyz * 2.2f;
    r0.xyz = exp2(r0.xyz);
    switch (asint(gFC_DebugDraw.x)) {
    case 1: r4.xyz = r0.xyz; break;
    case 2: r1.xyz = log2(abs(r5.xyz)); r1.xyz = r1.xyz * (1.0f/2.2f); r4.xyz = exp2(r1.xyz); break;
    case 3: r1.xyz = log2(r7.xyz); r1.xyz = r1.xyz * (1.0f/2.2f); r4.xyz = exp2(r1.xyz); break;
    case 4: break;
    case 5: r4.xyz = r2.xyz * 0.49804f + 0.49804f; break;
    case 6: r4.xyz = float3(r6.x, 0, 0); break;
    default: r4.xyz = 0; break;
    }
    o1.xyz = r4.xyz;
    o0.w = v4.w;
    o0.xyz = r0.xyz;
    o1.w = 0;

    PS_OUT Out;
    Out.Color = o0;
    Out.Debug = o1;
    return Out;
}
