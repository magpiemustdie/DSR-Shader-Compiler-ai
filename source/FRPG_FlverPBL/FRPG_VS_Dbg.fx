/***************************************************************************//**

	@file		FRPG_VS_Dbg.fx
	@brief		Vertex shader for FRPG_Dbg_*_Nrm debug variants
	@par		Reconstructed from DXBC references (16 variants: PIN/PINT/PINTT/
	            PIWN/PIWNT/PIWNTT x D/DL/DD/DDL)

	@note		Dbg_Nrm output = standard VTX_OUT minus VtxLit (TEXCOORD1),
	            minus TexLit (TEXCOORD7) even for DL/DDL, minus oClip0
	            (no WITH_ClipPlane, no cb2), minus isFrontFace.
	            ColVtx = mov (no ModelMulCol mul).
	            UV: TEXCOORD6 f2 (TexDif) for non-MT, f4 (TexDifDif) for MT.

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
/*!
	@par
*/
#define ENABLE_VS
#define ENABLE_FS

#include "FRPG_Common.fxh"

struct VTX_OUT_DBG
{
    float4 VtxClp : SV_Position;
    float4 VtxWld : TEXCOORD0;
    float4 VecNrm : TEXCOORD2;
    float4 VecEye : TEXCOORD3;
#ifdef WITH_BumpMap
    #ifdef WITH_MultiTexture
        float4 VecTan  : TEXCOORD4;
        float4 VecTan2 : TEXCOORD5;
        float3 VecBin  : TEXCOORD8;
        float3 VecBin2 : TEXCOORD9;
    #else
        float4 VecTan : TEXCOORD4;
        float3 VecBin : TEXCOORD5;
    #endif
#endif
    float4 ColVtx : COLOR;
#ifdef WITH_MultiTexture
    float4 TexDifDif : TEXCOORD6;
#else
    float2 TexDif : TEXCOORD6;
#endif
};

VTX_OUT_DBG VertexMain(VTX_IN In)
{
    VTX_OUT_DBG Out;
    int boneIdx = (int)In.BlendIdx.x;
    float4 localPos;
    localPos.xyz = In.VecPos.xyz;
    localPos.w   = 1.0f;
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    int4 bIdx = (int4)In.BlendIdx;
    float4 row0 = gVC_LocalWorldMtxArray[In.BlendIdx.x][0] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][0] + gVC_LocalWorldMtxArray[In.BlendIdx.z][0] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][0] * weights.wwww;
    float4 row1 = gVC_LocalWorldMtxArray[In.BlendIdx.x][1] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][1] + gVC_LocalWorldMtxArray[In.BlendIdx.z][1] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][1] * weights.wwww;
    float4 row2 = gVC_LocalWorldMtxArray[In.BlendIdx.x][2] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][2] + gVC_LocalWorldMtxArray[In.BlendIdx.z][2] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][2] * weights.wwww;
    worldPos.x = dot(row0, localPos);
    worldPos.y = dot(row1, localPos);
    worldPos.z = dot(row2, localPos);
    worldPos.w = 1.0f;
#else
    worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], localPos);
    worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], localPos);
    worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], localPos);
    worldPos.w = 1.0f;
#endif

    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxWld.xyz = worldPos.xyz;
    Out.VtxWld.w   = Out.VtxClp.w;
    Out.VecEye.xyz = gVC_CameraPos.xyz - worldPos.xyz;
    Out.VecEye.w   = 0.0f;
    float fogCoef = (Out.VtxClp.w - gVC_FogParam.x) * gVC_FogParam.y;
    Out.VecNrm.w = fogCoef;
    float3 localNrm = (In.VecNrm.xyz - 0.498040f) * 2.007871f;
#ifdef WITH_Skin
    Out.VecNrm.x = dot(row0.xyz, localNrm);
    Out.VecNrm.y = dot(row1.xyz, localNrm);
    Out.VecNrm.z = dot(row2.xyz, localNrm);
#else
    Out.VecNrm.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localNrm);
    Out.VecNrm.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localNrm);
    Out.VecNrm.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localNrm);
#endif

#ifdef WITH_BumpMap
    Out.VecTan.w = In.VecTan.w * 2.007871f - 1.0f;
    float4 localTan = (In.VecTan - 0.498040f) * 2.007871f;
#ifdef WITH_Skin
    Out.VecTan.x = dot(row0.xyz, localTan.xyz);
    Out.VecTan.y = dot(row1.xyz, localTan.xyz);
    Out.VecTan.z = dot(row2.xyz, localTan.xyz);
#else
    Out.VecTan.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localTan.xyz);
    Out.VecTan.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localTan.xyz);
    Out.VecTan.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localTan.xyz);
#endif
    Out.VecBin = cross(Out.VecNrm.xyz, Out.VecTan.xyz) * localTan.w;

    #ifdef WITH_MultiTexture
    float4 localTan2 = (In.VecTan2 - 0.498040f) * 2.007871f;
#ifdef WITH_Skin
    Out.VecTan2.x = dot(row0.xyz, localTan2.xyz);
    Out.VecTan2.y = dot(row1.xyz, localTan2.xyz);
    Out.VecTan2.z = dot(row2.xyz, localTan2.xyz);
#else
    Out.VecTan2.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localTan2.xyz);
    Out.VecTan2.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localTan2.xyz);
    Out.VecTan2.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localTan2.xyz);
#endif
    Out.VecTan2.w = In.VecTan2.w * 2.007871f - 1.0f;
    Out.VecBin2 = cross(Out.VecNrm.xyz, Out.VecTan2.xyz) * localTan2.w;
    #endif
#endif

    Out.ColVtx = In.ColVtx;

#ifdef WITH_MultiTexture
    Out.TexDifDif.xy = (float2)In.TexDifDif_int_qloc.xy * 0.0009765625f + gVC_TexScrl_0.xy;
    Out.TexDifDif.zw = (float2)In.TexDifDif_int_qloc.zw * 0.0009765625f + gVC_TexScrl_1.xy;
#else
    #ifdef WITH_LightMap
        Out.TexDif.xy = (float2)In.TexDifLit_int_qloc.xy * 0.0009765625f + gVC_TexScrl_0.xy;
    #else
        Out.TexDif.xy = (float2)In.TexDif_int_qloc * 0.0009765625f + gVC_TexScrl_0.xy;
    #endif
#endif

    return Out;
}