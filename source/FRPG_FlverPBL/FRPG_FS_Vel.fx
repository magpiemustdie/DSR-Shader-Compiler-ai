/***************************************************************************//**

	@file		FRPG_FS_Vel.fx
	@brief		Motion vector (velocity) pixel shader

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
#ifdef _PS3
	#define ENABLE_FS
#else
	#define ENABLE_VS
	#define ENABLE_FS
#endif

#include "dx11.h"
#include "FRPG_Common_SMP.fxh"

struct VS_OUT
{
	float4 Position : SV_Position;
	float4 CurPos : TEXCOORD0;
	float4 PrevPos : TEXCOORD1;
};

struct VS_OUT_ALP
{
	float4 Position : SV_Position;
	float4 Color : COLOR0;
	float2 TexCoord0 : TEXCOORD0;
	float4 CurPos : TEXCOORD1;
	float4 PrevPos : TEXCOORD2;
};

struct VEL_OUT
{
	float4 Color : SV_Target0;
};

VEL_OUT FragmentMain(VS_OUT In)
{
	VEL_OUT Out;

	float2 curUV = In.CurPos.xy / In.CurPos.w;
	curUV = curUV * 0.5f + 0.5f;
	float2 prevUV = In.PrevPos.xy / In.PrevPos.w;
	prevUV = prevUV * 0.5f + 0.5f;
	Out.Color.xy = curUV - prevUV;
	Out.Color.zw = float2(0, 1);

	return Out;
}

VEL_OUT FragmentMain_Alp(VS_OUT_ALP In)
{
	VEL_OUT Out;

	float alpha = gSMP_0.Sample(gSMP_0Sampler, In.TexCoord0.xy).a * In.Color.w;
	if (AlphaTest == 1 && AlphaTestRef.x >= alpha)
		discard;

	float2 curUV = In.CurPos.xy / In.CurPos.w;
	curUV = curUV * 0.5f + 0.5f;
	float2 prevUV = In.PrevPos.xy / In.PrevPos.w;
	prevUV = prevUV * 0.5f + 0.5f;
	Out.Color.xy = curUV - prevUV;
	Out.Color.z = 0;
	Out.Color.w = alpha;

	return Out;
}
