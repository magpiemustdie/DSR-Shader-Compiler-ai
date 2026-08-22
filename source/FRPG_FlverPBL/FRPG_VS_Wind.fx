/***************************************************************************//**

	@file		FRPG_VS_Wind.fx
	@brief		Vertex shader for Wind variants (grass/foliage sway)
	@par		Reconstructed from DXBC references (FRPG_Wind_*.vpo)

	@note		Wind displacement: pos' = pos + (-hOff.x, -vOff, -hOff.y)
	            horizontal = cos(a)*cos(3a)*cos(5a)*cos(7a)
	            vertical   = cos(1.5a)*cos(0.5a)*cos(2.5a)*cos(3.5a)*amp
	            a = dot(Wind0.xy, pos.xz)*0.1 + Wind1.x*Wind0.z + seed.y*Wind1.w/1024
	            amp = seed.x*Wind1.y/1024; seed = TEXCOORD1 (int2/int4) / TEXCOORD2 (float4)

	            Defines:
	                WITH_Skin      4-bone skinning (PIWN families)
	                WITH_Tangent   TANGENT0 input, TEXCOORD4/5 outputs (PINT, PIWNT)
	                WITH_Binormal  BINORMAL0 input, TEXCOORD8/9 outputs (PINTT, PIWNTT)
	                WIND_DL        int4 TexDif; UV.zw scroll via gVC_TexScrl_1.zw
	                WIND_DD        int4 TexDif; UV.zw scroll via gVC_TexScrl_1.xy
	                WIND_DDL       int4 TexDif + int2 TexDif2 + float4 WindParam (trunc)

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
#define ENABLE_VS
#define ENABLE_FS

#include "FRPG_Common.fxh"

struct WT_IN
{
    float3 VecPos   : POSITION;
    uint4  BlendIdx : BLENDINDICES;
#ifdef WITH_Skin
    float4 BlendWeight : BLENDWEIGHT;
#endif
    float3 VecNrm : NORMAL;
#ifdef WITH_Tangent
    float4 VecTan : TANGENT0;
#endif
#ifdef WITH_Binormal
    float4 VecBin : BINORMAL0;
#endif
    float4 ColVtx : COLOR0;
#if defined(WIND_DDL)
    int4   TexDif : TEXCOORD0;
    int2   TexDif2 : TEXCOORD1;
    float4 WindParam : TEXCOORD2;
#elif defined(WIND_DL) || defined(WIND_DD)
    int4   TexDif : TEXCOORD0;
    int4   WindParam : TEXCOORD1;
#else
    int2   TexDif : TEXCOORD0;
    int4   WindParam : TEXCOORD1;
#endif
#ifdef WITH_INSTANCE
    float4 InstCol : INSTANCECOLOR;
    float4 InstUV : INSTANCEUV;
    float4 InstMtx0 : INSTANCEMTX;
    float4 InstMtx1 : INSTANCEMTX1;
    float4 InstMtx2 : INSTANCEMTX2;
    float4 PInstMtx0 : P_INSTANCEMTX;
    float4 PInstMtx1 : P_INSTANCEMTX1;
    float4 PInstMtx2 : P_INSTANCEMTX2;
#endif
};

float3 WindDisplace(float3 pos, float2 seed)
{
    float amp = seed.x * gVC_WindParam_1.y * (1.0f / 1024.0f);
    float ang = gVC_WindParam_1.x * gVC_WindParam_0.z + dot(gVC_WindParam_0.xy, pos.xz) * 0.1f;
    ang += seed.y * gVC_WindParam_1.w * (1.0f / 1024.0f);
    float c0 = cos(ang);
    float4 cA = cos(ang * float4(3.0f, 5.0f, 7.0f, 0.5f));
    float3 cB = cos(ang * float3(1.5f, 2.5f, 3.5f));
    float horizontal = c0 * cA.x * cA.y * cA.z;
    float vertical = cA.w * cB.x * cB.y * cB.z;
    float2 hOff = (amp * gVC_WindParam_0.xy) * horizontal;
    float vOff = amp * vertical * gVC_WindParam_1.z;
    float3 windOff = 0.0f;
    windOff.x = -hOff.x;
    windOff.z = -hOff.y;
    windOff.y = -vOff;
    return windOff;
}

float4 SkinRow(uint4 idx, float4 w, int row)
{
    return gVC_LocalWorldMtxArray[idx.x][row] * w.xxxx + w.yyyy * gVC_LocalWorldMtxArray[idx.y][row] + gVC_LocalWorldMtxArray[idx.z][row] * w.zzzz + gVC_LocalWorldMtxArray[idx.w][row] * w.wwww;
}

float4 SkinPrevRow(uint4 idx, float4 w, int row)
{
    return gVC_prevLocalWorldMtxArray[idx.x][row] * w.xxxx + w.yyyy * gVC_prevLocalWorldMtxArray[idx.y][row] + gVC_prevLocalWorldMtxArray[idx.z][row] * w.zzzz + gVC_prevLocalWorldMtxArray[idx.w][row] * w.wwww;
}

#if defined(WITH_DepthWrite) && defined(WITH_AlphaBlend)
struct WT_OUT_DEPALP
{
    float4 VtxClp : SV_Position;
    float2 Depth : TEXCOORD0;
#if !defined(WIND_DDL) && !defined(WIND_DD)
    float2 TexUV : TEXCOORD7;
    float4 ColVtx : TEXCOORD6;
#endif
};

WT_OUT_DEPALP VertexMain(WT_IN In)
{
    WT_OUT_DEPALP Out;
#if defined(WIND_DDL)
    float2 seed = trunc(In.WindParam.xy);
#else
    float2 seed = (float2)In.WindParam;
#endif
    float4 localPos;
    localPos.xyz = WindDisplace(In.VecPos.xyz, seed) + In.VecPos.xyz;
    localPos.w   = 1.0f;
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 skinRow0 = SkinRow(In.BlendIdx, weights, 0);
    worldPos.x = dot(skinRow0, localPos);
    float4 skinRow1 = SkinRow(In.BlendIdx, weights, 1);
    worldPos.y = dot(skinRow1, localPos);
    float4 skinRow2 = SkinRow(In.BlendIdx, weights, 2);
    worldPos.z = dot(skinRow2, localPos);
    worldPos.w = 1.0f;
#elif defined(WITH_INSTANCE)
    worldPos.x = dot(In.InstMtx0, localPos);
    worldPos.y = dot(In.InstMtx1, localPos);
    worldPos.z = dot(In.InstMtx2, localPos);
    worldPos.w = 1.0f;
#else
    int boneIdx = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], localPos);
    worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], localPos);
    worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], localPos);
    worldPos.w = 1.0f;
#endif
    float4 vtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxClp = vtxClp;
    Out.Depth.xy = vtxClp.zw;
#if !defined(WIND_DDL) && !defined(WIND_DD)
#ifdef WITH_INSTANCE
    Out.TexUV.xy = (float2)In.TexDif * 0.0009765625f + In.InstUV.xy;
#else
    Out.TexUV.xy = (float2)In.TexDif * 0.0009765625f + gVC_TexScrl_0.xy;
#endif
    Out.ColVtx = In.ColVtx;
#endif
    return Out;
}

#elif defined(WITH_DepthWrite)
struct WT_OUT_DEP
{
    float4 VtxClp : SV_Position;
    float2 Depth : TEXCOORD0;
};

WT_OUT_DEP VertexMain(WT_IN In)
{
    WT_OUT_DEP Out;
#if defined(WIND_DDL)
    float2 seed = trunc(In.WindParam.xy);
#else
    float2 seed = (float2)In.WindParam;
#endif
    float4 localPos;
    localPos.xyz = WindDisplace(In.VecPos.xyz, seed) + In.VecPos.xyz;
    localPos.w   = 1.0f;
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 skinRow0 = SkinRow(In.BlendIdx, weights, 0);
    worldPos.x = dot(skinRow0, localPos);
    float4 skinRow1 = SkinRow(In.BlendIdx, weights, 1);
    worldPos.y = dot(skinRow1, localPos);
    float4 skinRow2 = SkinRow(In.BlendIdx, weights, 2);
    worldPos.z = dot(skinRow2, localPos);
    worldPos.w = 1.0f;
#elif defined(WITH_INSTANCE)
    worldPos.x = dot(In.InstMtx0, localPos);
    worldPos.y = dot(In.InstMtx1, localPos);
    worldPos.z = dot(In.InstMtx2, localPos);
    worldPos.w = 1.0f;
#else
    int boneIdx = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], localPos);
    worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], localPos);
    worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], localPos);
    worldPos.w = 1.0f;
#endif
    float4 vtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxClp = vtxClp;
    Out.Depth.xy = vtxClp.zw;
    return Out;
}

#elif defined(WITH_Velocity) && defined(WITH_AlphaBlend)
struct WT_OUT_VELALP
{
    float4 VtxClp : SV_Position;
#if !defined(WIND_DDL) && !defined(WIND_DD)
    float4 ColVtx : COLOR0;
    float2 UV : TEXCOORD0;
    float4 VtxWld : TEXCOORD1;
    float4 VtxPrev : TEXCOORD2;
#else
    float4 VtxWld : TEXCOORD0;
    float4 VtxPrev : TEXCOORD1;
#endif
};

WT_OUT_VELALP VertexMain(WT_IN In)
{
    WT_OUT_VELALP Out;
#if defined(WIND_DDL)
    float2 seed = trunc(In.WindParam.xy);
#else
    float2 seed = (float2)In.WindParam;
#endif
    float2 amp2 = seed * gVC_WindParam_1.yw;
    float ampX = amp2.x * (1.0f / 1024.0f);
    float4 ang = gVC_WindParam_1.x * gVC_WindParam_0.zzzw + dot(gVC_WindParam_0.xy, In.VecPos.xz) * 0.1f;
    ang += amp2.yyyy * (1.0f / 1024.0f);
    float2 ca = cos(ang.zw);
    float4 cA = cos(ang.z * float4(3.0f, 5.0f, 7.0f, 0.5f));
    float horizontal = ca.x * cA.x * cA.y * cA.z;
    float2 hOff = ampX * gVC_WindParam_0.xy;
    float4 pos1;
    pos1.xz = In.VecPos.xz - hOff * horizontal;
    float4 cB = cos(ang * float4(1.5f, 2.5f, 3.5f, 3.0f));
    float vertical = cA.w * cB.x * cB.y * cB.z;
    float verticalW = ca.y * cB.w;
    float vOff = ampX * vertical;
    pos1.y = In.VecPos.y - vOff * gVC_WindParam_1.z;
    pos1.w = 1.0f;
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 skinRow0 = SkinRow(In.BlendIdx, weights, 0);
    worldPos.x = dot(skinRow0, pos1);
    float4 skinRow1 = SkinRow(In.BlendIdx, weights, 1);
    worldPos.y = dot(skinRow1, pos1);
    float4 skinRow2 = SkinRow(In.BlendIdx, weights, 2);
    worldPos.z = dot(skinRow2, pos1);
    worldPos.w = 1.0f;
#elif defined(WITH_INSTANCE)
    worldPos.x = dot(In.InstMtx0, pos1);
    worldPos.y = dot(In.InstMtx1, pos1);
    worldPos.z = dot(In.InstMtx2, pos1);
    worldPos.w = 1.0f;
#else
    int boneIdx = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], pos1);
    worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], pos1);
    worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], pos1);
    worldPos.w = 1.0f;
#endif
    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
#if !defined(WIND_DDL) && !defined(WIND_DD)
    Out.ColVtx = In.ColVtx;
#ifdef WITH_INSTANCE
    Out.UV.xy = (float2)In.TexDif * 0.0009765625f + In.InstUV.xy;
#else
    Out.UV.xy = (float2)In.TexDif * 0.0009765625f + gVC_TexScrl_0.xy;
#endif
#endif
    Out.VtxWld = mul(worldPos, gVC_CommonREG12);
    float2 cbw = ang.w * float2(2.5f, 3.5f);
    float4 caw = cos(ang.w * float4(5.0f, 7.0f, 0.5f, 1.5f));
    float2 cb = cos(cbw);
    float vOff2 = ampX * (caw.z * caw.w * cb.x * cb.y);
    float4 pos2;
    pos2.y = In.VecPos.y - vOff2 * gVC_WindParam_1.z;
    float horizontal2 = verticalW * caw.x * caw.y;
    pos2.xz = In.VecPos.xz - hOff * horizontal2;
    pos2.w = 1.0f;
    float4 prevWorldPos;
#ifdef WITH_Skin
    float4 prevRow0 = SkinPrevRow(In.BlendIdx, weights, 0);
    prevWorldPos.x = dot(prevRow0, pos2);
    float4 prevRow1 = SkinPrevRow(In.BlendIdx, weights, 1);
    prevWorldPos.y = dot(prevRow1, pos2);
    float4 prevRow2 = SkinPrevRow(In.BlendIdx, weights, 2);
    prevWorldPos.z = dot(prevRow2, pos2);
    prevWorldPos.w = 1.0f;
#else
#ifdef WITH_INSTANCE
    int boneIdx = (int)In.BlendIdx.x;
#endif
    prevWorldPos.x = dot(gVC_prevLocalWorldMtxArray[boneIdx][0], pos2);
    prevWorldPos.y = dot(gVC_prevLocalWorldMtxArray[boneIdx][1], pos2);
    prevWorldPos.z = dot(gVC_prevLocalWorldMtxArray[boneIdx][2], pos2);
    prevWorldPos.w = 1.0f;
#endif
    Out.VtxPrev = mul(prevWorldPos, gVC_CommonREG8);
    return Out;
}

#elif defined(WITH_Velocity)
struct WT_OUT_VEL
{
    float4 VtxClp : SV_Position;
    float4 VtxWld : TEXCOORD0;
    float4 VtxPrev : TEXCOORD1;
};

WT_OUT_VEL VertexMain(WT_IN In)
{
    WT_OUT_VEL Out;
#if defined(WIND_DDL)
    float2 seed = trunc(In.WindParam.xy);
#else
    float2 seed = (float2)In.WindParam;
#endif
    float2 amp2 = seed * gVC_WindParam_1.yw;
    float ampX = amp2.x * (1.0f / 1024.0f);
    float4 ang = gVC_WindParam_1.x * gVC_WindParam_0.zzzw + dot(gVC_WindParam_0.xy, In.VecPos.xz) * 0.1f;
    ang += amp2.yyyy * (1.0f / 1024.0f);
    float2 ca = cos(ang.zw);
    float4 cA = cos(ang.z * float4(3.0f, 5.0f, 7.0f, 0.5f));
    float horizontal = ca.x * cA.x * cA.y * cA.z;
    float2 hOff = ampX * gVC_WindParam_0.xy;
    float4 pos1;
    pos1.xz = In.VecPos.xz - hOff * horizontal;
    float4 cB = cos(ang * float4(1.5f, 2.5f, 3.5f, 3.0f));
    float vertical = cA.w * cB.x * cB.y * cB.z;
    float verticalW = ca.y * cB.w;
    float vOff = ampX * vertical;
    pos1.y = In.VecPos.y - vOff * gVC_WindParam_1.z;
    pos1.w = 1.0f;
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 skinRow0 = SkinRow(In.BlendIdx, weights, 0);
    worldPos.x = dot(skinRow0, pos1);
    float4 skinRow1 = SkinRow(In.BlendIdx, weights, 1);
    worldPos.y = dot(skinRow1, pos1);
    float4 skinRow2 = SkinRow(In.BlendIdx, weights, 2);
    worldPos.z = dot(skinRow2, pos1);
    worldPos.w = 1.0f;
#elif defined(WITH_INSTANCE)
    worldPos.x = dot(In.InstMtx0, pos1);
    worldPos.y = dot(In.InstMtx1, pos1);
    worldPos.z = dot(In.InstMtx2, pos1);
    worldPos.w = 1.0f;
#else
    int boneIdx = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], pos1);
    worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], pos1);
    worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], pos1);
    worldPos.w = 1.0f;
#endif
    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxWld = mul(worldPos, gVC_CommonREG12);
    float2 cbw = ang.w * float2(2.5f, 3.5f);
    float4 caw = cos(ang.w * float4(5.0f, 7.0f, 0.5f, 1.5f));
    float2 cb = cos(cbw);
    float vOff2 = ampX * (caw.z * caw.w * cb.x * cb.y);
    float4 pos2;
    pos2.y = In.VecPos.y - vOff2 * gVC_WindParam_1.z;
    float horizontal2 = verticalW * caw.x * caw.y;
    pos2.xz = In.VecPos.xz - hOff * horizontal2;
    pos2.w = 1.0f;
    float4 prevWorldPos;
#ifdef WITH_Skin
    float4 prevRow0 = SkinPrevRow(In.BlendIdx, weights, 0);
    prevWorldPos.x = dot(prevRow0, pos2);
    float4 prevRow1 = SkinPrevRow(In.BlendIdx, weights, 1);
    prevWorldPos.y = dot(prevRow1, pos2);
    float4 prevRow2 = SkinPrevRow(In.BlendIdx, weights, 2);
    prevWorldPos.z = dot(prevRow2, pos2);
    prevWorldPos.w = 1.0f;
#else
#ifdef WITH_INSTANCE
    int boneIdx = (int)In.BlendIdx.x;
#endif
    prevWorldPos.x = dot(gVC_prevLocalWorldMtxArray[boneIdx][0], pos2);
    prevWorldPos.y = dot(gVC_prevLocalWorldMtxArray[boneIdx][1], pos2);
    prevWorldPos.z = dot(gVC_prevLocalWorldMtxArray[boneIdx][2], pos2);
    prevWorldPos.w = 1.0f;
#endif
    Out.VtxPrev = mul(prevWorldPos, gVC_CommonREG8);
    return Out;
}

#else
// ============================================================================
// Non / Sdw (forward / shadow passes)
// ============================================================================
#ifdef WITH_ShadowMap
#define WT_OUT WT_OUT_SDW
struct WT_OUT_SDW
{
    float4 VtxClp : SV_Position;
    float4 VtxWld : TEXCOORD0;
    float4 VtxLit : TEXCOORD1;
    float4 VecNrm : TEXCOORD2;
    float4 VecEye : TEXCOORD3;
#ifdef WITH_Tangent
    float4 VecTan : TEXCOORD4;
#ifdef WITH_Binormal
    float4 VecBin : TEXCOORD5;
    float3 CrossTan : TEXCOORD8;
    float3 CrossBin : TEXCOORD9;
#else
    float3 VecBin : TEXCOORD5;
#endif
#endif
    float4 ColVtx : COLOR0;
#if defined(WIND_DL) || defined(WIND_DD) || defined(WIND_DDL)
    float4 TexDif : TEXCOORD6;
#else
    float2 TexDif : TEXCOORD6;
#endif
#if defined(WIND_DDL)
    float2 TexDif2 : TEXCOORD7;
#endif
    float oClip0 : SV_ClipDistance0;
};
#else
#define WT_OUT WT_OUT_NON
struct WT_OUT_NON
{
    float4 VtxClp : SV_Position;
    float4 VtxWld : TEXCOORD0;
    float4 VecNrm : TEXCOORD2;
    float4 VecEye : TEXCOORD3;
#ifdef WITH_Tangent
    float4 VecTan : TEXCOORD4;
#ifdef WITH_Binormal
    float4 VecBin : TEXCOORD5;
    float3 CrossTan : TEXCOORD8;
    float3 CrossBin : TEXCOORD9;
#else
    float3 VecBin : TEXCOORD5;
#endif
#endif
    float4 ColVtx : COLOR0;
#if defined(WIND_DL) || defined(WIND_DD) || defined(WIND_DDL)
    float4 TexDif : TEXCOORD6;
#else
    float2 TexDif : TEXCOORD6;
#endif
#if defined(WIND_DDL)
    float2 TexDif2 : TEXCOORD7;
#endif
    float oClip0 : SV_ClipDistance0;
};
#endif

WT_OUT VertexMain(WT_IN In)
{
    WT_OUT Out;
#if defined(WIND_DDL)
    float2 seed = trunc(In.WindParam.xy);
#else
    float2 seed = (float2)In.WindParam;
#endif
    float4 localPos;
    localPos.xyz = WindDisplace(In.VecPos.xyz, seed) + In.VecPos.xyz;
    localPos.w   = 1.0f;
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 skinRow0 = SkinRow(In.BlendIdx, weights, 0);
    worldPos.x = dot(skinRow0, localPos);
    float4 skinRow1 = SkinRow(In.BlendIdx, weights, 1);
    worldPos.y = dot(skinRow1, localPos);
    float4 skinRow2 = SkinRow(In.BlendIdx, weights, 2);
    worldPos.z = dot(skinRow2, localPos);
    worldPos.w = 1.0f;
#elif defined(WITH_INSTANCE)
    worldPos.x = dot(In.InstMtx0, localPos);
    worldPos.y = dot(In.InstMtx1, localPos);
    worldPos.z = dot(In.InstMtx2, localPos);
    worldPos.w = 1.0f;
#else
    int boneIdx = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], localPos);
    worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], localPos);
    worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], localPos);
    worldPos.w = 1.0f;
#endif
    float4 vtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxClp = vtxClp;
    Out.VtxWld.xyz = worldPos.xyz;
    Out.VecEye.xyz = gVC_CameraPos.xyz - worldPos.xyz;
    Out.VtxWld.w = vtxClp.w;
    float fogCoef = (vtxClp.w - gVC_FogParam.x) * gVC_FogParam.y;
    Out.VecNrm.w = fogCoef;
    float3 localNrm = (In.VecNrm.xyz - 0.498040f) * 2.007871f;
    float3 worldNrm;
#ifdef WITH_Skin
    worldNrm.x = dot(skinRow0.xyz, localNrm);
    worldNrm.y = dot(skinRow1.xyz, localNrm);
    worldNrm.z = dot(skinRow2.xyz, localNrm);
#elif defined(WITH_INSTANCE)
    worldNrm.x = dot(In.InstMtx0.xyz, localNrm);
    worldNrm.y = dot(In.InstMtx1.xyz, localNrm);
    worldNrm.z = dot(In.InstMtx2.xyz, localNrm);
#else
    worldNrm.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localNrm);
    worldNrm.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localNrm);
    worldNrm.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localNrm);
#endif
    Out.VecNrm.xyz = worldNrm;
    Out.VecEye.w = 0.0f;
#ifdef WITH_Tangent
#ifdef WITH_Skin
    float4 localTan = (In.VecTan - 0.498040f) * 2.007871f;
    float3 worldTan;
    worldTan.x = dot(skinRow0.xyz, localTan.xyz);
    worldTan.y = dot(skinRow1.xyz, localTan.xyz);
    worldTan.z = dot(skinRow2.xyz, localTan.xyz);
    Out.VecTan.xyz = worldTan;
    Out.VecTan.w = In.VecTan.w * 2.007871f - 1.0f;
#elif defined(WITH_INSTANCE)
    Out.VecTan.w = In.VecTan.w * 2.007871f - 1.0f;
    float4 localTan = (In.VecTan - 0.498040f) * 2.007871f;
    float3 worldTan;
    worldTan.x = dot(In.InstMtx0.xyz, localTan.xyz);
    worldTan.y = dot(In.InstMtx1.xyz, localTan.xyz);
    worldTan.z = dot(In.InstMtx2.xyz, localTan.xyz);
    Out.VecTan.xyz = worldTan;
#else
    Out.VecTan.w = In.VecTan.w * 2.007871f - 1.0f;
    float4 localTan = (In.VecTan - 0.498040f) * 2.007871f;
    float3 worldTan;
    worldTan.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localTan.xyz);
    worldTan.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localTan.xyz);
    worldTan.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localTan.xyz);
    Out.VecTan.xyz = worldTan;
#endif
#ifdef WITH_Binormal
#ifdef WITH_Skin
    float4 localBin = (In.VecBin - 0.498040f) * 2.007871f;
    float3 worldBin;
    worldBin.x = dot(skinRow0.xyz, localBin.xyz);
    worldBin.y = dot(skinRow1.xyz, localBin.xyz);
    worldBin.z = dot(skinRow2.xyz, localBin.xyz);
    Out.VecBin.xyz = worldBin;
    Out.VecBin.w = In.VecBin.w * 2.007871f - 1.0f;
#elif defined(WITH_INSTANCE)
    Out.VecBin.w = In.VecBin.w * 2.007871f - 1.0f;
    float4 localBin = (In.VecBin - 0.498040f) * 2.007871f;
    float3 worldBin;
    worldBin.x = dot(In.InstMtx0.xyz, localBin.xyz);
    worldBin.y = dot(In.InstMtx1.xyz, localBin.xyz);
    worldBin.z = dot(In.InstMtx2.xyz, localBin.xyz);
    Out.VecBin.xyz = worldBin;
#else
    Out.VecBin.w = In.VecBin.w * 2.007871f - 1.0f;
    float4 localBin = (In.VecBin - 0.498040f) * 2.007871f;
    float3 worldBin;
    worldBin.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localBin.xyz);
    worldBin.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localBin.xyz);
    worldBin.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localBin.xyz);
    Out.VecBin.xyz = worldBin;
#endif
    Out.CrossTan.xyz = cross(worldNrm, worldTan) * localTan.w;
    Out.CrossBin.xyz = cross(worldNrm, worldBin) * localBin.w;
#else
    Out.VecBin.xyz = cross(worldNrm, worldTan) * localTan.w;
#endif
#endif
#ifdef WITH_INSTANCE
    Out.ColVtx = In.ColVtx * In.InstCol;
#else
    Out.ColVtx = In.ColVtx * gVC_ModelMulCol;
#endif
#if defined(WIND_DDL)
    float4 uvF = (float4)In.TexDif;
#ifdef WITH_INSTANCE
    Out.TexDif.xyzw = uvF * 0.0009765625f + float4(In.InstUV.xy, In.InstUV.xy);
    Out.TexDif2.xy = (float2)In.TexDif2 * 0.0009765625f + In.InstUV.xy;
#else
    Out.TexDif.xy = uvF.xy * 0.0009765625f + gVC_TexScrl_0.xy;
    Out.TexDif.zw = uvF.zw * 0.0009765625f + gVC_TexScrl_1.xy;
    Out.TexDif2.xy = (float2)In.TexDif2 * 0.0009765625f + gVC_TexScrl_1.zw;
#endif
#elif defined(WIND_DL) || defined(WIND_DD)
    float4 uvF = (float4)In.TexDif;
#ifdef WITH_INSTANCE
    Out.TexDif.xyzw = uvF * 0.0009765625f + float4(In.InstUV.xy, In.InstUV.xy);
#else
    Out.TexDif.xy = uvF.xy * 0.0009765625f + gVC_TexScrl_0.xy;
#if defined(WIND_DL)
    Out.TexDif.zw = uvF.zw * 0.0009765625f + gVC_TexScrl_1.zw;
#else
    Out.TexDif.zw = uvF.zw * 0.0009765625f + gVC_TexScrl_1.xy;
#endif
#endif
#else
#ifdef WITH_INSTANCE
    Out.TexDif.xy = (float2)In.TexDif * 0.0009765625f + In.InstUV.xy;
#else
    Out.TexDif.xy = (float2)In.TexDif * 0.0009765625f + gVC_TexScrl_0.xy;
#endif
#endif
#ifdef WITH_ShadowMap
    Out.VtxLit = mul(worldPos, gVC_ShadowMapMtx);
#endif
    Out.oClip0 = qlocClipPlaneDistance(vtxClp);
    return Out;
}
#endif
