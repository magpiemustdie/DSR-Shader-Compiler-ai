/***************************************************************************//**

	@file		FRPG_FS_Dep.fx
	@brief		Depth-only pass pixel shader

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
	float4 Position  : SV_Position;
	// v1: TEXCOORD0.xy (unused) + TEXCOORD7.zw (diffuse UV for alpha sample)
	// packed into one register by VS — match VS output signature exactly
	float2 TexCoord0 : TEXCOORD0;  // xy — unused in PS
	float2 TexCoord7 : TEXCOORD7;  // zw — diffuse UV
	// v2: TEXCOORD6.xyzw (w = vertex alpha weight)
	float4 TexCoord6 : TEXCOORD6;
};

struct DEP_OUT
{
	float4 Color : SV_Target0;
};

void FragmentMain(VS_OUT In)
{
}

void FragmentMain_Alp(VS_OUT In)
{
	float alpha = gSMP_0.Sample(gSMP_0Sampler, In.TexCoord7.xy).a * In.TexCoord6.w;
	if (AlphaTest == 1 && AlphaTestRef.x >= alpha)
		discard;
}
