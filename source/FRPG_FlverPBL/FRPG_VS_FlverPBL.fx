/***************************************************************************//**

	@file		FRPG_VS_FlverPBL.fx
	@brief		Vertex shader for FlverPBL standard variants (Phn, Gst)
	@par		Reconstructed from DXBC references (128/128 byte-identical:
	            Phn/Gst x PIN/PINT/PIWN/PIWNT/PINTT/PIWNTT x D/DL/DD/DDL x
	            Non/Sdw/Dep/DepAlp/Vel/VelAlp)

	@note		Family rules:
	            - Gst compiles WITH_WITH_GhostMap define (binormal = cross
	              without w, tangent decoded as float3, color always mul).
	            - Phn (no GhostMap) with MultiTexture: color = mov (no mul);
	              binormal = cross * localTan.w; tangent decoded as float4.
	            - PIN/PINT have no BlendWeight: single bone via BlendIdx.x,
	              compiled WITHOUT WITH_Skin.
	            - Dep/DepAlp/Vel/VelAlp use the same transform logic as the
	              main path (4-bone skin blend when WITH_Skin).
	            - DepAlp/VelAlp write UV/color only when !WITH_MultiTexture.

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
/*!
	@par
*/
#define ENABLE_VS
#define ENABLE_FS

#include "FRPG_Common.fxh"

#if defined(WITH_PntNum)
// PntNum debug: clip position + clip.zw for point lookup
// o0=SV_Position, o1.xy=TEXCOORD0(clip.zw)
struct VTX_OUT_PNTNUM
{
    float4 VtxClp : SV_Position;
    float2 ClipZW : TEXCOORD0;
};

VTX_OUT_PNTNUM VertexMain(VTX_IN In)
{
    VTX_OUT_PNTNUM Out;
    float4 localPos;
    localPos.xyz = In.VecPos.xyz;
    localPos.w   = 1.0f;
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 row0 = gVC_LocalWorldMtxArray[In.BlendIdx.x][0] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][0] + gVC_LocalWorldMtxArray[In.BlendIdx.z][0] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][0] * weights.wwww;
    float4 row1 = gVC_LocalWorldMtxArray[In.BlendIdx.x][1] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][1] + gVC_LocalWorldMtxArray[In.BlendIdx.z][1] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][1] * weights.wwww;
    float4 row2 = gVC_LocalWorldMtxArray[In.BlendIdx.x][2] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][2] + gVC_LocalWorldMtxArray[In.BlendIdx.z][2] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][2] * weights.wwww;
    worldPos.x = dot(row0, localPos);
    worldPos.y = dot(row1, localPos);
    worldPos.z = dot(row2, localPos);
    worldPos.w = 1.0f;
#else
    int boneIdx = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], localPos);
    worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], localPos);
    worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], localPos);
    worldPos.w = 1.0f;
#endif
    Out.VtxClp  = mul(worldPos, gVC_WorldViewClipMtx);
    Out.ClipZW  = Out.VtxClp.zw;
    return Out;
}

#elif defined(WITH_Ghost)
// Ghost (Tod/Skin): o0=clip, o1=TEXCOORD0(worldPos), o2=TEXCOORD2(normal+fog),
// o3=TEXCOORD3(eye), o4=TEXCOORD4(tangent), o5=COLOR0, o6=TEXCOORD6(uv), o7.x=clip
// No VecBin output, color = mov (no ModelMulCol), UV = mul (no scroll)
struct VTX_OUT_GHOST
{
    float4 VtxClp : SV_Position;
    float4 VtxWld : TEXCOORD0;
    float4 VecNrm : TEXCOORD2;
    float4 VecEye : TEXCOORD3;
    float4 VecTan : TEXCOORD4;
    float4 ColVtx : COLOR0;
    float2 TexDif : TEXCOORD6;
    float oClip0 : SV_ClipDistance0;
};

VTX_OUT_GHOST VertexMain(VTX_IN In)
{
    VTX_OUT_GHOST Out;
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
    float4 vtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxWld = worldPos;
    Out.VecEye.xyz = gVC_CameraPos.xyz - worldPos.xyz;
    Out.VecEye.w   = 0.0f;
    Out.VtxClp = vtxClp;
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
    Out.VecTan.w = In.VecTan.w * 2.007871f - 1.0f;
    float3 localTan = (In.VecTan.xyz - 0.498040f) * 2.007871f;
#ifdef WITH_Skin
    Out.VecTan.x = dot(row0.xyz, localTan);
    Out.VecTan.y = dot(row1.xyz, localTan);
    Out.VecTan.z = dot(row2.xyz, localTan);
#else
    Out.VecTan.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localTan);
    Out.VecTan.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localTan);
    Out.VecTan.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localTan);
#endif
    Out.ColVtx = In.ColVtx;
    Out.TexDif.xy = (float2)In.TexDif_int_qloc * 0.0009765625f;
    Out.oClip0 = qlocClipPlaneDistance(Out.VtxClp);
    return Out;
}

#elif defined(WITH_NtoA) && defined(WITH_DepthWrite)
// NtoA Dep: o0=clip, o1.xy=TEXCOORD0(clip.zw), o1.zw=TEXCOORD6(uv),
// o2=TEXCOORD2(normal), o3=TEXCOORD3(eye), o4=COLOR0, o5.x=clip
struct VTX_OUT_NTOA_DEP
{
    float4 VtxClp : SV_Position;
    float2 Depth : TEXCOORD0;
    float2 UV : TEXCOORD6;
    float4 VecNrm : TEXCOORD2;
    float4 VecEye : TEXCOORD3;
    float4 ColVtx : COLOR0;
    float oClip0 : SV_ClipDistance0;
};

VTX_OUT_NTOA_DEP VertexMain(VTX_IN In)
{
    VTX_OUT_NTOA_DEP Out;
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
    int boneIdx = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], localPos);
    worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], localPos);
    worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], localPos);
    worldPos.w = 1.0f;
#endif
    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.Depth.xy = Out.VtxClp.zw;
    Out.UV.xy = (float2)In.TexDif_int_qloc * 0.0009765625f + gVC_TexScrl_0.xy;
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
    Out.VecNrm.w = 1.0f;
    Out.VecEye.xyz = gVC_CameraPos.xyz - worldPos.xyz;
    Out.VecEye.w = 0.0f;
    Out.ColVtx = In.ColVtx;
    Out.oClip0 = qlocClipPlaneDistance(Out.VtxClp);
    return Out;
}

#elif defined(WITH_DepthWrite) && defined(WITH_AlphaBlend)
// DepAlp: o0=clip, o1.xy=TEXCOORD0(clip.zw), o1.zw=TEXCOORD7(uv), o2=TEXCOORD6(color)
// (uv/color only when !WITH_MultiTexture; ref MT variants have no uv/color)
struct VTX_OUT_DEPALP
{
    float4 VtxClp : SV_Position;
    float2 Depth : TEXCOORD0;
#ifndef WITH_MultiTexture
    float2 UV : TEXCOORD7;
    float4 ColVtx : TEXCOORD6;
#endif
};

VTX_OUT_DEPALP VertexMain(VTX_IN In)
{
    VTX_OUT_DEPALP Out;
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
    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.Depth.xy = Out.VtxClp.zw;
#ifndef WITH_MultiTexture
#ifdef WITH_INSTANCE
#ifdef WITH_LightMap
    Out.UV.xy = (float2)In.TexDifLit_int_qloc.xy * 0.0009765625f + In.InstUV.xy;
#else
    Out.UV.xy = (float2)In.TexDif_int_qloc * 0.0009765625f + In.InstUV.xy;
#endif
#else
#ifdef WITH_LightMap
    Out.UV.xy = (float2)In.TexDifLit_int_qloc.xy * 0.0009765625f + gVC_TexScrl_0.xy;
#else
    Out.UV.xy = (float2)In.TexDif_int_qloc * 0.0009765625f + gVC_TexScrl_0.xy;
#endif
#endif
    Out.ColVtx = In.ColVtx;
#endif
    return Out;
}

#elif defined(WITH_DepthWrite)
// Dep: o0=clip, o1.xy=TEXCOORD0(clip.zw)
struct VTX_OUT_DEP
{
    float4 VtxClp : SV_Position;
    float2 Depth : TEXCOORD0;
};

VTX_OUT_DEP VertexMain(VTX_IN In)
{
    VTX_OUT_DEP Out;
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
    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.Depth.xy = Out.VtxClp.zw;
    return Out;
}

#elif defined(WITH_Velocity) && defined(WITH_AlphaBlend)
// VelAlp: o0=clip, o1=TEXCOORD0(worldPos*REG12), o2=TEXCOORD1(prev*REG8)
// (color/uv only when !WITH_MultiTexture; semantic indexes shift)
struct VTX_OUT_VELALP
{
    float4 VtxClp : SV_Position;
#ifndef WITH_MultiTexture
    float4 ColVtx : COLOR0;
    float2 UV : TEXCOORD0;
    float4 VtxWld : TEXCOORD1;
    float4 VtxPrev : TEXCOORD2;
#else
    float4 VtxWld : TEXCOORD0;
    float4 VtxPrev : TEXCOORD1;
#endif
};

VTX_OUT_VELALP VertexMain(VTX_IN In)
{
    VTX_OUT_VELALP Out;
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
    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
#ifndef WITH_MultiTexture
#ifdef WITH_INSTANCE
#ifdef WITH_LightMap
    Out.UV.xy = (float2)In.TexDifLit_int_qloc.xy * 0.0009765625f + In.InstUV.xy;
#else
    Out.UV.xy = (float2)In.TexDif_int_qloc * 0.0009765625f + In.InstUV.xy;
#endif
#else
#ifdef WITH_LightMap
    Out.UV.xy = (float2)In.TexDifLit_int_qloc.xy * 0.0009765625f + gVC_TexScrl_0.xy;
#else
    Out.UV.xy = (float2)In.TexDif_int_qloc * 0.0009765625f + gVC_TexScrl_0.xy;
#endif
#endif
    Out.ColVtx = In.ColVtx;
#endif
    Out.VtxWld = mul(worldPos, gVC_CommonREG12);
    float4 prevWorldPos;
#ifdef WITH_Skin
    float4 prow0 = gVC_prevLocalWorldMtxArray[In.BlendIdx.x][0] * weights.xxxx + weights.yyyy * gVC_prevLocalWorldMtxArray[In.BlendIdx.y][0] + gVC_prevLocalWorldMtxArray[In.BlendIdx.z][0] * weights.zzzz + gVC_prevLocalWorldMtxArray[In.BlendIdx.w][0] * weights.wwww;
    float4 prow1 = gVC_prevLocalWorldMtxArray[In.BlendIdx.x][1] * weights.xxxx + weights.yyyy * gVC_prevLocalWorldMtxArray[In.BlendIdx.y][1] + gVC_prevLocalWorldMtxArray[In.BlendIdx.z][1] * weights.zzzz + gVC_prevLocalWorldMtxArray[In.BlendIdx.w][1] * weights.wwww;
    float4 prow2 = gVC_prevLocalWorldMtxArray[In.BlendIdx.x][2] * weights.xxxx + weights.yyyy * gVC_prevLocalWorldMtxArray[In.BlendIdx.y][2] + gVC_prevLocalWorldMtxArray[In.BlendIdx.z][2] * weights.zzzz + gVC_prevLocalWorldMtxArray[In.BlendIdx.w][2] * weights.wwww;
    prevWorldPos.x = dot(prow0, localPos);
    prevWorldPos.y = dot(prow1, localPos);
    prevWorldPos.z = dot(prow2, localPos);
    prevWorldPos.w = 1.0f;
#elif defined(WITH_INSTANCE)
    prevWorldPos.x = dot(In.PInstMtx0, localPos);
    prevWorldPos.y = dot(In.PInstMtx1, localPos);
    prevWorldPos.z = dot(In.PInstMtx2, localPos);
    prevWorldPos.w = 1.0f;
#else
    prevWorldPos.x = dot(gVC_prevLocalWorldMtxArray[boneIdx][0], localPos);
    prevWorldPos.y = dot(gVC_prevLocalWorldMtxArray[boneIdx][1], localPos);
    prevWorldPos.z = dot(gVC_prevLocalWorldMtxArray[boneIdx][2], localPos);
    prevWorldPos.w = 1.0f;
#endif
    Out.VtxPrev = mul(prevWorldPos, gVC_CommonREG8);
    return Out;
}

#elif defined(WITH_Velocity)
// Vel: o0=clip, o1=TEXCOORD0(worldPos*REG12), o2=TEXCOORD1(prevWorldPos*REG8)
struct VTX_OUT_VEL
{
    float4 VtxClp : SV_Position;
    float4 VtxWld : TEXCOORD0;
    float4 VtxPrev : TEXCOORD1;
};

VTX_OUT_VEL VertexMain(VTX_IN In)
{
    VTX_OUT_VEL Out;
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
    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxWld = mul(worldPos, gVC_CommonREG12);
    float4 prevWorldPos;
#ifdef WITH_Skin
    float4 prow0 = gVC_prevLocalWorldMtxArray[In.BlendIdx.x][0] * weights.xxxx + weights.yyyy * gVC_prevLocalWorldMtxArray[In.BlendIdx.y][0] + gVC_prevLocalWorldMtxArray[In.BlendIdx.z][0] * weights.zzzz + gVC_prevLocalWorldMtxArray[In.BlendIdx.w][0] * weights.wwww;
    float4 prow1 = gVC_prevLocalWorldMtxArray[In.BlendIdx.x][1] * weights.xxxx + weights.yyyy * gVC_prevLocalWorldMtxArray[In.BlendIdx.y][1] + gVC_prevLocalWorldMtxArray[In.BlendIdx.z][1] * weights.zzzz + gVC_prevLocalWorldMtxArray[In.BlendIdx.w][1] * weights.wwww;
    float4 prow2 = gVC_prevLocalWorldMtxArray[In.BlendIdx.x][2] * weights.xxxx + weights.yyyy * gVC_prevLocalWorldMtxArray[In.BlendIdx.y][2] + gVC_prevLocalWorldMtxArray[In.BlendIdx.z][2] * weights.zzzz + gVC_prevLocalWorldMtxArray[In.BlendIdx.w][2] * weights.wwww;
    prevWorldPos.x = dot(prow0, localPos);
    prevWorldPos.y = dot(prow1, localPos);
    prevWorldPos.z = dot(prow2, localPos);
    prevWorldPos.w = 1.0f;
#elif defined(WITH_INSTANCE)
    prevWorldPos.x = dot(In.PInstMtx0, localPos);
    prevWorldPos.y = dot(In.PInstMtx1, localPos);
    prevWorldPos.z = dot(In.PInstMtx2, localPos);
    prevWorldPos.w = 1.0f;
#else
    prevWorldPos.x = dot(gVC_prevLocalWorldMtxArray[boneIdx][0], localPos);
    prevWorldPos.y = dot(gVC_prevLocalWorldMtxArray[boneIdx][1], localPos);
    prevWorldPos.z = dot(gVC_prevLocalWorldMtxArray[boneIdx][2], localPos);
    prevWorldPos.w = 1.0f;
#endif
    Out.VtxPrev = mul(prevWorldPos, gVC_CommonREG8);
    return Out;
}

#else
// ============================================================================
// Vertex shader (forward / shadow passes)
// ============================================================================
VTX_OUT VertexMain(VTX_IN In)
{
	VTX_OUT Out;

	// ---- Bone matrix index ----
	// gVC_LocalWorldMtxArray[i] = float3x4 matrix for bone i
	// Rows accessed as [i][0], [i][1], [i][2]
#ifndef WITH_INSTANCE
	int boneIdx = (int)In.BlendIdx.x;
#endif

	// ---- Local -> World transform ----
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
#elif defined(WITH_INSTANCE)
	worldPos.x = dot(In.InstMtx0, localPos);
	worldPos.y = dot(In.InstMtx1, localPos);
	worldPos.z = dot(In.InstMtx2, localPos);
	worldPos.w = 1.0f;
#else
	worldPos.x = dot(gVC_LocalWorldMtxArray[boneIdx][0], localPos);
	worldPos.y = dot(gVC_LocalWorldMtxArray[boneIdx][1], localPos);
	worldPos.z = dot(gVC_LocalWorldMtxArray[boneIdx][2], localPos);
	worldPos.w = 1.0f;
#endif

	// ---- World -> Clip ----
	Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);

	// ---- World position output ----
	Out.VtxWld.xyz = worldPos.xyz;
	Out.VtxWld.w   = Out.VtxClp.w;  // view-space Z (clip W)

	// ---- Eye vector ----
	Out.VecEye.xyz = gVC_CameraPos.xyz - worldPos.xyz;
	Out.VecEye.w   = 0.0f;

	// ---- Fog coefficient ----
	// FogParam: x=start, y=1/(end-start)
	float fogCoef = (Out.VtxClp.w - gVC_FogParam.x) * gVC_FogParam.y;
	Out.VecNrm.w = fogCoef;

	// ---- Normal transform (local -> world) ----
	// Normal is packed as uint8 in [-1,1] range: (v - 0.498040) * 2.007871
	float3 localNrm = (In.VecNrm.xyz - 0.498040f) * 2.007871f;
#ifdef WITH_Skin
	Out.VecNrm.x = dot(row0.xyz, localNrm);
	Out.VecNrm.y = dot(row1.xyz, localNrm);
	Out.VecNrm.z = dot(row2.xyz, localNrm);
#elif defined(WITH_INSTANCE)
	Out.VecNrm.x = dot(In.InstMtx0.xyz, localNrm);
	Out.VecNrm.y = dot(In.InstMtx1.xyz, localNrm);
	Out.VecNrm.z = dot(In.InstMtx2.xyz, localNrm);
#else
	Out.VecNrm.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localNrm);
	Out.VecNrm.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localNrm);
	Out.VecNrm.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localNrm);
#endif

#ifdef WITH_BumpMap
	// ---- Tangent transform ----
	// Tangent is packed same as normal; w = binormal sign (packed separately)
	Out.VecTan.w = In.VecTan.w * 2.007871f - 1.0f;  // decode binormal sign
#ifdef WITH_GhostMap
	// Gst: tangent decoded as float3 (ref adds r.xyz only)
	float3 localTan = (In.VecTan.xyz - 0.498040f) * 2.007871f;
#else
	// Phn: float4 decode (w needed for binormal cross)
	float4 localTan = (In.VecTan - 0.498040f) * 2.007871f;
#endif
#ifdef WITH_Skin
	Out.VecTan.x = dot(row0.xyz, localTan.xyz);
	Out.VecTan.y = dot(row1.xyz, localTan.xyz);
	Out.VecTan.z = dot(row2.xyz, localTan.xyz);
#elif defined(WITH_INSTANCE)
	Out.VecTan.x = dot(In.InstMtx0.xyz, localTan.xyz);
	Out.VecTan.y = dot(In.InstMtx1.xyz, localTan.xyz);
	Out.VecTan.z = dot(In.InstMtx2.xyz, localTan.xyz);
#else
	Out.VecTan.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localTan.xyz);
	Out.VecTan.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localTan.xyz);
	Out.VecTan.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localTan.xyz);
#endif

	#ifdef CALC_VS_BINORMAL
	#ifdef WITH_GhostMap
	Out.VecBin = cross(Out.VecNrm.xyz, Out.VecTan.xyz);
	#else
	Out.VecBin = cross(Out.VecNrm.xyz, Out.VecTan.xyz) * localTan.w;
	#endif
	#endif

	#ifdef WITH_MultiTexture
#ifdef WITH_GhostMap
	float3 localTan2 = (In.VecTan2.xyz - 0.498040f) * 2.007871f;
#else
	float4 localTan2 = (In.VecTan2 - 0.498040f) * 2.007871f;
#endif
#ifdef WITH_Skin
	Out.VecTan2.x = dot(row0.xyz, localTan2.xyz);
	Out.VecTan2.y = dot(row1.xyz, localTan2.xyz);
	Out.VecTan2.z = dot(row2.xyz, localTan2.xyz);
#elif defined(WITH_INSTANCE)
	Out.VecTan2.x = dot(In.InstMtx0.xyz, localTan2.xyz);
	Out.VecTan2.y = dot(In.InstMtx1.xyz, localTan2.xyz);
	Out.VecTan2.z = dot(In.InstMtx2.xyz, localTan2.xyz);
#else
	Out.VecTan2.x = dot(gVC_LocalWorldMtxArray[boneIdx][0].xyz, localTan2.xyz);
	Out.VecTan2.y = dot(gVC_LocalWorldMtxArray[boneIdx][1].xyz, localTan2.xyz);
	Out.VecTan2.z = dot(gVC_LocalWorldMtxArray[boneIdx][2].xyz, localTan2.xyz);
#endif
	Out.VecTan2.w = In.VecTan2.w * 2.007871f - 1.0f;
	#ifdef CALC_VS_BINORMAL
	#ifdef WITH_GhostMap
	Out.VecBin2 = cross(Out.VecNrm.xyz, Out.VecTan2.xyz);
	#else
	Out.VecBin2 = cross(Out.VecNrm.xyz, Out.VecTan2.xyz) * localTan2.w;
	#endif
	#endif
	#endif
#endif // WITH_BumpMap

	// ---- Vertex color ----
	// Phn (no GhostMap) MultiTexture: mov o8 (no ModelMulCol!)
	// NtoA: always mov (no ModelMulCol)
#if defined(WITH_MultiTexture) && !defined(WITH_GhostMap) || defined(WITH_NtoA)
	Out.ColVtx = In.ColVtx;
#elif defined(WITH_INSTANCE)
	Out.ColVtx = In.ColVtx * In.InstCol;
#else
	Out.ColVtx = In.ColVtx * gVC_ModelMulCol;
#endif

	// ---- Texture coordinates ----
	// UV is packed as uint16 (integer), scaled by 1/1024 = 0.000977
#ifdef WITH_INSTANCE
	#ifdef WITH_MultiTexture
		#ifdef WITH_LightMap
			Out.TexDifDif.xyzw = (float4)In.TexDifDif_int_qloc * 0.0009765625f + float4(In.InstUV.xy, In.InstUV.xy);
			Out.TexLit.xy = (float2)In.TexLit_int_qloc * 0.0009765625f + In.InstUV.xy;
		#else
			Out.TexDifDif.xyzw = (float4)In.TexDifDif_int_qloc * 0.0009765625f + float4(In.InstUV.xy, In.InstUV.xy);
		#endif
	#else
		#ifdef WITH_LightMap
			Out.TexDifLit.xyzw = (float4)In.TexDifLit_int_qloc * 0.0009765625f + float4(In.InstUV.xy, In.InstUV.xy);
		#else
			Out.TexDif.xy = (float2)In.TexDif_int_qloc * 0.0009765625f + In.InstUV.xy;
		#endif
	#endif
#else
	#ifdef WITH_MultiTexture
		#ifdef WITH_LightMap
			Out.TexDifDif.xy = (float2)In.TexDifDif_int_qloc.xy * 0.0009765625f + gVC_TexScrl_0.xy;
			Out.TexDifDif.zw = (float2)In.TexDifDif_int_qloc.zw * 0.0009765625f + gVC_TexScrl_1.xy;
			Out.TexLit.xy = (float2)In.TexLit_int_qloc * 0.0009765625f + gVC_TexScrl_1.zw;
		#else
			Out.TexDifDif.xy = (float2)In.TexDifDif_int_qloc.xy * 0.0009765625f + gVC_TexScrl_0.xy;
			Out.TexDifDif.zw = (float2)In.TexDifDif_int_qloc.zw * 0.0009765625f + gVC_TexScrl_1.xy;
		#endif
	#else
		#ifdef WITH_LightMap
			Out.TexDifLit.xy = (float2)In.TexDifLit_int_qloc.xy * 0.0009765625f + gVC_TexScrl_0.xy;
			Out.TexDifLit.zw = (float2)In.TexDifLit_int_qloc.zw * 0.0009765625f + gVC_TexScrl_1.zw;
		#else
			// TexScrl_0.xy = UV scroll offset (cb0[25].xy)
			Out.TexDif.xy = (float2)In.TexDif_int_qloc * 0.0009765625f + gVC_TexScrl_0.xy;
		#endif
	#endif
#endif

	// ---- Shadow map position (VS-side, CalcLispPos_VS) ----
#if WITH_ShadowMap == CalcLispPos_VS
	Out.VtxLit = mul(worldPos, gVC_ShadowMapMtx);
#endif

	// ---- User clip plane (water/object clipping) ----
#ifdef WITH_ClipPlane
	Out.oClip0 = qlocClipPlaneDistance(Out.VtxClp);
#endif

	return Out;
}
#endif