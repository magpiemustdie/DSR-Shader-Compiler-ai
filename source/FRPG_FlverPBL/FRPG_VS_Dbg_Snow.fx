/***************************************************************************//**

	@file		FRPG_VS_Dbg_Snow.fx
	@brief		Vertex shader for FRPG_Dbg_Snow_*_Nrm debug variants
	@par		Reconstructed from DXBC references (4 variants: D/DL x Skin/non-Skin)

	@note		Dbg_Snow_Nrm = standard snow (FRPG_VS_Snow.fx) with:
	            - o2.w = 0 (no fog)
	            - o5   = (1,1,1,1) (constant color, no vertex color read)
	            - o6   = (0,0,0,0) (no UV, no itof/mul)
	            - o9.zw = 0 (no lightmap UV even for WITH_LightMap)
	            - Color/TexCoord declared-but-unread (ISGN entries, no dcl)

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
/*!
	@par
*/
#define ENABLE_VS
#define ENABLE_FS
#include "FRPG_Common.fxh"

struct VS_IN {
    float3 Pos          : POSITION;
    uint4  BlendIndices : BLENDINDICES;
#ifdef WITH_Skin
    float4 BlendWeight  : BLENDWEIGHT;
#endif
    float3 Normal       : NORMAL;
    float4 Tangent      : TANGENT;
    float4 Color        : COLOR0;
#ifdef WITH_LightMap
    int4   TexCoord     : TEXCOORD0;
#else
    int2   TexCoord     : TEXCOORD0;
#endif
};

struct VS_OUT {
    float4 Pos      : SV_Position;
    float4 WorldPos : TEXCOORD0;
    float4 WorldNrm : TEXCOORD1;
    float4 VecEye   : TEXCOORD2;
    float4 WorldTan : TEXCOORD3;
    float4 Color    : COLOR0;
    float4 TexSnow  : TEXCOORD6;
    float4 TanFrame : TEXCOORD7;
    float4 ProjPos  : TEXCOORD8;
    float4 ProjW    : TEXCOORD9;
};

VS_OUT VertexMain(VS_IN In)
{
    VS_OUT Out;
    uint bone = In.BlendIndices.x;

    // imul r2.x, v1.x, 3  -> bone*3 for cb0 indexing
    // dp4 r0.xyz with cb0[bone*3+28..30] (= gVC_LocalWorldMtxArray[bone] rows)
    float4 pos4 = float4(In.Pos, 1.0f);
    float3 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 skinRow0 = gVC_LocalWorldMtxArray[In.BlendIndices.x][0] * weights.xxxx
        + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIndices.y][0]
        + gVC_LocalWorldMtxArray[In.BlendIndices.z][0] * weights.zzzz
        + gVC_LocalWorldMtxArray[In.BlendIndices.w][0] * weights.wwww;
    worldPos.x = dot(skinRow0, pos4);
    float4 skinRow1 = gVC_LocalWorldMtxArray[In.BlendIndices.x][1] * weights.xxxx
        + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIndices.y][1]
        + gVC_LocalWorldMtxArray[In.BlendIndices.z][1] * weights.zzzz
        + gVC_LocalWorldMtxArray[In.BlendIndices.w][1] * weights.wwww;
    worldPos.y = dot(skinRow1, pos4);
    float4 skinRow2 = gVC_LocalWorldMtxArray[In.BlendIndices.x][2] * weights.xxxx
        + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIndices.y][2]
        + gVC_LocalWorldMtxArray[In.BlendIndices.z][2] * weights.zzzz
        + gVC_LocalWorldMtxArray[In.BlendIndices.w][2] * weights.wwww;
    worldPos.z = dot(skinRow2, pos4);
#else
    worldPos.x = dot(gVC_LocalWorldMtxArray[bone][0], pos4);
    worldPos.y = dot(gVC_LocalWorldMtxArray[bone][1], pos4);
    worldPos.z = dot(gVC_LocalWorldMtxArray[bone][2], pos4);
#endif

    // viewZ = dp4(worldPos4, cb0[3]) = dot with gVC_WorldViewClipMtx row3
    float4 wp4 = float4(worldPos, 1.0f);
    // Use mul() to correctly handle column-major HLSL matrix with row-major cbuffer data
    float4 clipPos = mul(wp4, gVC_WorldViewClipMtx);
    float viewZ = clipPos.w;

    // clip pos
    Out.Pos = clipPos;

    // o1: worldPos + viewZ
    Out.WorldPos.xyz = worldPos;
    Out.WorldPos.w = viewZ;

    // parallax scale: ASM: mul r0.w, r1.x, cb0[21].x (hoisted early, no fog block)
    float scaledViewZ = viewZ * gVC_WaterWaveParam.x;

    // no fog: o2.w = 0
    Out.WorldNrm.w = 0.0f;

    // decode normal: (v2 - 0.498040) * 2.007871
    float3 localNrm = (In.Normal - 0.498040f) * 2.007871f;
    float3 worldNrm;
#ifdef WITH_Skin
    worldNrm.x = dot(skinRow0.xyz, localNrm);
    worldNrm.y = dot(skinRow1.xyz, localNrm);
    worldNrm.z = dot(skinRow2.xyz, localNrm);
#else
    worldNrm.x = dot(gVC_LocalWorldMtxArray[bone][0].xyz, localNrm);
    worldNrm.y = dot(gVC_LocalWorldMtxArray[bone][1].xyz, localNrm);
    worldNrm.z = dot(gVC_LocalWorldMtxArray[bone][2].xyz, localNrm);
#endif
    Out.WorldNrm.xyz = worldNrm;

    // o3: VecEye = CameraPos - worldPos, w=0
    Out.VecEye.xyz = gVC_CameraPos.xyz - worldPos;
    Out.VecEye.w = 0.0f;

    // decode tangent: (v3 - 0.498040) * 2.007871
    float4 localTan = (In.Tangent - 0.498040f) * 2.007871f;
    float3 worldTan;
#ifdef WITH_Skin
    worldTan.x = dot(skinRow0.xyz, localTan.xyz);
    worldTan.y = dot(skinRow1.xyz, localTan.xyz);
    worldTan.z = dot(skinRow2.xyz, localTan.xyz);
#else
    worldTan.x = dot(gVC_LocalWorldMtxArray[bone][0].xyz, localTan.xyz);
    worldTan.y = dot(gVC_LocalWorldMtxArray[bone][1].xyz, localTan.xyz);
    worldTan.z = dot(gVC_LocalWorldMtxArray[bone][2].xyz, localTan.xyz);
#endif
    Out.WorldTan = float4(worldTan, localTan.w);

    // o5: constant color (1,1,1,1) - no vertex color read
    Out.Color = float4(1.0f, 1.0f, 1.0f, 1.0f);

    // o6: no UV output
    Out.TexSnow = float4(0.0f, 0.0f, 0.0f, 0.0f);

    // bitangent = cross(worldNrm, worldTan) * handedness
    float3 bitan = cross(worldNrm, worldTan) * localTan.w;

    // parallax scale denominator
    float pScaleDenom = 0.125f * gVC_WaterWaveParam.w;
    float pScale = scaledViewZ / pScaleDenom;

    // r2.xyz = bitan * pScale
    float3 dispBitan = bitan * pScale;
    // r1.xyz = bitan*pScale + worldPos  (bitangent-displaced)
    float3 posA = dispBitan + worldPos;
    // r0.xyz = worldTan*pScale + worldPos  (tangent-displaced)
    float3 posB = worldTan * pScale + worldPos;

    // o7 = r2*2 where r2 = (dispBitan, pScale) → o7.w = pScale*2
    float4 frame4 = float4(dispBitan, pScale);
    Out.TanFrame = frame4 + frame4;

    // project posA (r1) and posB (r0):
    float4 pA4 = float4(posA, 1.0f);
    float4 pB4 = float4(posB, 1.0f);
    float4 projA = mul(pA4, gVC_WorldViewClipMtx);
    float4 projB = mul(pB4, gVC_WorldViewClipMtx);
    // projA: displaced position along bitangent
    Out.ProjPos.zw = projA.xy;  // X,Y -> Z,W
    Out.ProjW.y    = projA.w;   // parallax denominator A
    // projB: displaced position along tangent
    Out.ProjPos.xy = projB.xy;  // X,Y -> X,Y
    Out.ProjW.x    = projB.w;   // parallax denominator B

    // no lightmap UV output even for WITH_LightMap
    Out.ProjW.zw = 0;

    return Out;
}