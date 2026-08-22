// FRPG_VS_Water.fx - Water VS (Water / Water_Skin / Water_HeightMap / Water_HeightMap_Skin / Water_Mask / Water_Mask_Skin)
// Reconstructed from FRPG_Water.vpo (58 instr)
//
// VS outputs:
//   o0 = SV_Position
//   o1 = TEXCOORD0: xyz=worldPos, w=viewZ
//   o2 = TEXCOORD1: xyz=worldNrm, w=fog
//   o3 = TEXCOORD2: xyz=VecEye, w=0
//   o4 = TEXCOORD3: xyz=worldTan, w=tan.w*2.007871-1
//   o5 = COLOR0 = vertex color
//   o6 = TEXCOORD6: xyz=bitan*scale, w=0
//   o7 = TEXCOORD7: xyz=tan*scale, w=0
//   o8 = TEXCOORD8: proj(worldPos + bitan*scale)
//   o9 = TEXCOORD9: proj(worldPos + tan*scale)

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
    float4 VecTan : TANGENT;
    float4 ColVtx : COLOR0;
    int2 TexUV : TEXCOORD0;
};

struct WT_OUT
{
    float4 VtxClp  : SV_Position;
    float4 VtxWld  : TEXCOORD0;
    float4 VecNrm  : TEXCOORD1;
    float4 VecEye  : TEXCOORD2;
    float4 VecTan  : TEXCOORD3;
    float4 ColVtx  : COLOR0;
    float4 TanFrame : TEXCOORD6;
    float4 WorldTanD : TEXCOORD7;
    float4 ProjA   : TEXCOORD8;
    float4 ProjB   : TEXCOORD9;
};

struct WT_OUT_MASK
{
    float4 VtxClp : SV_Position;
    float2 TexCoord : TEXCOORD0;
};

struct WT_OUT_HM
{
    float4 VtxClp : SV_Position;
    float4 Uv01 : TEXCOORD0;
    float4 Uv2 : TEXCOORD1;
};

#ifdef WITH_Mask
WT_OUT_MASK VertexMain(WT_IN In)
{
    WT_OUT_MASK Out;
    float4 pos4 = float4(In.VecPos.xyz, 1.0f);
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 row0 = gVC_LocalWorldMtxArray[In.BlendIdx.x][0] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][0] + gVC_LocalWorldMtxArray[In.BlendIdx.z][0] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][0] * weights.wwww;
    float4 row1 = gVC_LocalWorldMtxArray[In.BlendIdx.x][1] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][1] + gVC_LocalWorldMtxArray[In.BlendIdx.z][1] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][1] * weights.wwww;
    float4 row2 = gVC_LocalWorldMtxArray[In.BlendIdx.x][2] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][2] + gVC_LocalWorldMtxArray[In.BlendIdx.z][2] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][2] * weights.wwww;
    worldPos.x = dot(row0, pos4);
    worldPos.y = dot(row1, pos4);
    worldPos.z = dot(row2, pos4);
    worldPos.w = 1.0f;
#else
    int bone = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[bone][0], pos4);
    worldPos.y = dot(gVC_LocalWorldMtxArray[bone][1], pos4);
    worldPos.z = dot(gVC_LocalWorldMtxArray[bone][2], pos4);
    worldPos.w = 1.0f;
#endif
    float4 vtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxClp = vtxClp;
    Out.TexCoord = vtxClp.zw;
    return Out;
}
#elif defined(WITH_HeightMap)
WT_OUT_HM VertexMain(WT_IN In)
{
    WT_OUT_HM Out;
    float4 pos4 = float4(In.VecPos.xyz, 1.0f);
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 row0 = gVC_LocalWorldMtxArray[In.BlendIdx.x][0] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][0] + gVC_LocalWorldMtxArray[In.BlendIdx.z][0] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][0] * weights.wwww;
    float4 row1 = gVC_LocalWorldMtxArray[In.BlendIdx.x][1] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][1] + gVC_LocalWorldMtxArray[In.BlendIdx.z][1] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][1] * weights.wwww;
    float4 row2 = gVC_LocalWorldMtxArray[In.BlendIdx.x][2] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][2] + gVC_LocalWorldMtxArray[In.BlendIdx.z][2] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][2] * weights.wwww;
    worldPos.x = dot(row0, pos4);
    worldPos.y = dot(row1, pos4);
    worldPos.z = dot(row2, pos4);
    worldPos.w = 1.0f;
#else
    int bone = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[bone][0], pos4);
    worldPos.y = dot(gVC_LocalWorldMtxArray[bone][1], pos4);
    worldPos.z = dot(gVC_LocalWorldMtxArray[bone][2], pos4);
    worldPos.w = 1.0f;
#endif
    float4 vtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxClp = vtxClp;
    Out.Uv2.z = vtxClp.w;
    float2 uv = float2(In.TexUV.xy) * (1.0f / 1024.0f);
    Out.Uv01 = float4(uv * gVC_WaterTileScale.x + gVC_TexScrl_0.xy, uv * gVC_WaterTileScale.y + gVC_TexScrl_1.xy);
    Out.Uv2.xy = uv * gVC_WaterTileScale.z + gVC_TexScrl_1.zw;
    Out.Uv2.w = 0.0f;
    return Out;
}
#else
WT_OUT VertexMain(WT_IN In)
{
    WT_OUT Out;
    float4 pos4 = float4(In.VecPos.xyz, 1.0f);
    float4 worldPos;
#ifdef WITH_Skin
    float wsum = In.BlendWeight.x + In.BlendWeight.y + In.BlendWeight.z + In.BlendWeight.w;
    float4 weights = In.BlendWeight / wsum;
    float4 row0 = gVC_LocalWorldMtxArray[In.BlendIdx.x][0] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][0] + gVC_LocalWorldMtxArray[In.BlendIdx.z][0] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][0] * weights.wwww;
    float4 row1 = gVC_LocalWorldMtxArray[In.BlendIdx.x][1] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][1] + gVC_LocalWorldMtxArray[In.BlendIdx.z][1] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][1] * weights.wwww;
    float4 row2 = gVC_LocalWorldMtxArray[In.BlendIdx.x][2] * weights.xxxx + weights.yyyy * gVC_LocalWorldMtxArray[In.BlendIdx.y][2] + gVC_LocalWorldMtxArray[In.BlendIdx.z][2] * weights.zzzz + gVC_LocalWorldMtxArray[In.BlendIdx.w][2] * weights.wwww;
    worldPos.x = dot(row0, pos4);
    worldPos.y = dot(row1, pos4);
    worldPos.z = dot(row2, pos4);
    worldPos.w = 1.0f;
#else
    int bone = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[bone][0], pos4);
    worldPos.y = dot(gVC_LocalWorldMtxArray[bone][1], pos4);
    worldPos.z = dot(gVC_LocalWorldMtxArray[bone][2], pos4);
    worldPos.w = 1.0f;
#endif
    Out.VtxClp = mul(worldPos, gVC_WorldViewClipMtx);
    Out.VtxWld.xyz = worldPos.xyz;
    Out.VtxWld.w   = Out.VtxClp.w;
    float3 localNrm = (In.VecNrm.xyz - 0.498040f) * 2.007871f;
    float3 worldNrm;
#ifdef WITH_Skin
    worldNrm.x = dot(row0.xyz, localNrm);
    worldNrm.y = dot(row1.xyz, localNrm);
    worldNrm.z = dot(row2.xyz, localNrm);
#else
    worldNrm.x = dot(gVC_LocalWorldMtxArray[bone][0].xyz, localNrm);
    worldNrm.y = dot(gVC_LocalWorldMtxArray[bone][1].xyz, localNrm);
    worldNrm.z = dot(gVC_LocalWorldMtxArray[bone][2].xyz, localNrm);
#endif
    float fogCoef = (Out.VtxClp.w - gVC_FogParam.x) * gVC_FogParam.y;
    Out.VecNrm = float4(worldNrm, fogCoef);
    float scaledViewZ = Out.VtxClp.w * gVC_WaterWaveParam.x;
    Out.VecEye.xyz = gVC_CameraPos.xyz - worldPos.xyz;
    Out.VecEye.w   = 0.0f;
    Out.VecTan.w = In.VecTan.w * 2.007871f - 1.0f;
    float4 localTan = (In.VecTan - 0.498040f) * 2.007871f;
    float3 worldTan;
#ifdef WITH_Skin
    worldTan.x = dot(row0.xyz, localTan.xyz);
    worldTan.y = dot(row1.xyz, localTan.xyz);
    worldTan.z = dot(row2.xyz, localTan.xyz);
#else
    worldTan.x = dot(gVC_LocalWorldMtxArray[bone][0].xyz, localTan.xyz);
    worldTan.y = dot(gVC_LocalWorldMtxArray[bone][1].xyz, localTan.xyz);
    worldTan.z = dot(gVC_LocalWorldMtxArray[bone][2].xyz, localTan.xyz);
#endif
    Out.VecTan.xyz = worldTan;
    Out.ColVtx = In.ColVtx;
    float3 tanDisp = (worldTan * scaledViewZ) / (0.0625f * gVC_WaterWaveParam.w);
    Out.TanFrame.xyz = tanDisp;
    Out.TanFrame.w   = 0.0f;
    float3 posA = worldPos.xyz + tanDisp;
    float3 bitan = cross(worldNrm, worldTan) * localTan.w;
    float3 bitanDisp = (bitan * scaledViewZ) / (0.0625f * gVC_WaterWaveParam.w);
    Out.WorldTanD.xyz = bitanDisp;
    Out.WorldTanD.w   = 0.0f;
    float3 posB = worldPos.xyz + bitanDisp;
    Out.ProjA = mul(float4(posA, 1.0f), gVC_WorldViewClipMtx);
    Out.ProjB = mul(float4(posB, 1.0f), gVC_WorldViewClipMtx);
    return Out;
}
#endif