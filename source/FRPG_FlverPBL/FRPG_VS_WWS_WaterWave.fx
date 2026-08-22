// FRPG_VS_WWS_WaterWave.fx - Water wave mask VS (WWS family)
// Reconstructed from FRPG_WWS_PIN_D_WaterWave.vpo (16 instr) etc.
//
// VS outputs:
//   o0 = SV_Position (worldPos * gVC_WorldViewClipMtx)
//   o1 = COLOR0 = vertex color passthrough (no ModelMulCol!)
//   o2 = COLOR1 = gVC_ModelMulCol
//   o3 = TEXCOORD7: D: xy = uv*0.000977 + TexScrl_0.xy
//                   DD: xy = uv.xy*0.000977 + TexScrl_0.xy, zw = uv.zw*0.000977 + TexScrl_1.xy

#define ENABLE_VS
#define ENABLE_FS
#include "FRPG_Common.fxh"

struct WW_IN
{
    float3 VecPos  : POSITION;
    uint4  BlendIdx : BLENDINDICES;
#ifdef WITH_Skin
    float4 BlendWeight : BLENDWEIGHT;
#endif
    float3 VecNrm : NORMAL;
    float4 ColVtx : COLOR0;
#ifdef WITH_MultiTexture
    int4 TexUV : TEXCOORD0;
#else
    int2 TexUV : TEXCOORD0;
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

struct WW_OUT
{
    float4 Pos  : SV_Position;
    float4 Col0 : COLOR0;
    float4 Col1 : COLOR1;
#ifdef WITH_MultiTexture
    float4 Uv : TEXCOORD7;
#else
    float2 Uv : TEXCOORD7;
#endif
};

WW_OUT VertexMain(WW_IN In)
{
    WW_OUT Out;
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
#elif defined(WITH_INSTANCE)
    worldPos.x = dot(In.InstMtx0, pos4);
    worldPos.y = dot(In.InstMtx1, pos4);
    worldPos.z = dot(In.InstMtx2, pos4);
    worldPos.w = 1.0f;
#else
    int bone = (int)In.BlendIdx.x;
    worldPos.x = dot(gVC_LocalWorldMtxArray[bone][0], pos4);
    worldPos.y = dot(gVC_LocalWorldMtxArray[bone][1], pos4);
    worldPos.z = dot(gVC_LocalWorldMtxArray[bone][2], pos4);
    worldPos.w = 1.0f;
#endif
    Out.Pos = mul(worldPos, gVC_WorldViewClipMtx);
    Out.Col0 = In.ColVtx;
#ifdef WITH_INSTANCE
    Out.Col1 = In.InstCol;
#else
    Out.Col1 = gVC_ModelMulCol;
#endif
#ifdef WITH_MultiTexture
#ifdef WITH_INSTANCE
    Out.Uv.xy = (float2)In.TexUV.xy * 0.0009765625f + In.InstUV.xy;
    Out.Uv.zw = (float2)In.TexUV.zw * 0.0009765625f + In.InstUV.xy;
#else
    Out.Uv.xy = (float2)In.TexUV.xy * 0.0009765625f + gVC_TexScrl_0.xy;
    Out.Uv.zw = (float2)In.TexUV.zw * 0.0009765625f + gVC_TexScrl_1.xy;
#endif
#else
#ifdef WITH_INSTANCE
    Out.Uv = (float2)In.TexUV * 0.0009765625f + In.InstUV.xy;
#else
    Out.Uv = (float2)In.TexUV * 0.0009765625f + gVC_TexScrl_0.xy;
#endif
#endif
    return Out;
}