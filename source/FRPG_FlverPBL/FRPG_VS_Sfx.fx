/***************************************************************************//**

	@file		FRPG_VS_Sfx.fx
	@brief		Sfx (old sprite) vertex mini-shader — PIN_D / PINT_D variants
	@par		Reconstructed from DXBC references:
	            FRPG_Sfx_PIN_D.vpo  (14 instr)
	            FRPG_Sfx_PINT_D.vpo (14 instr)

	@note		Sfx VS is a mini-shader: single bone transform + UV only.
	            Globals use OLD_VERSION layout ($Globals RDEF): VR block with
	            register(cN), DL block packed by fxc after c254.
	            PINT adds unused TANGENT input (ISGN only).

	Copyright &copy; @YEAR@ FromSoftware, Inc.

*//****************************************************************************/
/*!
	@par
*/

// ============================================================================
// Globals (OLD_VERSION layout, no cbuffer -> $Globals RDEF)
// ============================================================================
uniform float4x4 VR_000 : register(c0);
uniform float4x4 VR_004 : register(c4);
uniform row_major float3x4 VR_008 : register(c8);
uniform row_major float3x4 VR_008A[38] : register(c8);
uniform float4 VR_128 : register(c128);
uniform float4 VR_129 : register(c129);
uniform float4 VR_130 : register(c130);
uniform float4 VR_131 : register(c131);
uniform float4 VR_132 : register(c132);
uniform float4 VR_133 : register(c133);
uniform float4 VR_134 : register(c134);
uniform float4 VR_135 : register(c135);
uniform float4 VR_136 : register(c136);
uniform float4x4 VR_137 : register(c137);
uniform float4 VR_141 : register(c141);
uniform float4 VR_142 : register(c142);
uniform float4 gVC_SnowTileScale : register(c143);
uniform float4 VR_144 : register(c144);
uniform float4 VR_145 : register(c145);
uniform float4 VR_122 : register(c122);
uniform float4 VR_123 : register(c123);
uniform float4 VR_246 : register(c246);
uniform float4 VR_247 : register(c247);
uniform float4 VR_248 : register(c248);
uniform float4 VR_249A[6] : register(c249);

uniform float4 DL_FREG_084;
uniform float4 DL_FREG_085;
uniform float4 DL_FREG_086;
uniform float4 DL_FREG_087;
uniform float4 DL_FREG_088;
uniform float4 DL_FREG_089;
uniform float4 DL_FREG_090;
uniform float4 DL_FREG_091;
uniform float4 gFC_DirLightVec[3];
uniform float4 gFC_DirLightCol[3];
uniform float4 DL_FREG_098;
uniform float4 DL_FREG_099;
uniform float4 DL_FREG_100;
uniform float4 DL_FREG_101;
uniform float4 DL_FREG_102;
uniform float4 DL_FREG_103;
uniform float4 DL_FREG_104;
uniform float4 DL_FREG_105;
uniform float4 DL_FREG_106;
uniform float4 DL_FREG_107;
uniform float4 DL_FREG_108;
uniform float4 DL_FREG_109;
uniform float4 DL_FREG_110;
uniform float4 DL_FREG_111;
uniform float4 gFC_PntLightPos[4];
uniform float4 gFC_PntLightCol[4];
uniform float DL_FREG_120;
uniform float4 DL_FREG_121;
uniform float4 DL_FREG_122;
uniform float4 DL_FREG_123;
uniform float DL_FREG_124;
uniform float DL_FREG_125;
uniform float DL_FREG_126;
uniform float4 DL_FREG_127;
uniform float2 DL_FREG_128;
uniform float DL_FREG_129;
uniform float DL_FREG_130;
uniform float DL_FREG_131;
uniform float4 DL_FREG_132;
uniform float4 DL_FREG_133;
uniform float3 DL_FREG_134;
uniform float4 DL_FREG_135;
uniform float4 DL_FREG_136;
uniform float4 DL_FREG_137;
uniform float4 DL_FREG_138;
uniform float4 DL_FREG_139;
uniform float4x4 DL_FREG_140A[4];
uniform float4 DL_FREG_156;
uniform float4 DL_FREG_157A[4];
uniform float4 DL_FREG_163;
uniform float4 DL_FREG_164;
uniform float4x4 DL_FREG_165;
uniform float4 DL_FREG_169;
uniform float4 DL_FREG_170;
uniform float4 DL_FREG_171;
uniform float4 DL_FREG_172;
uniform float4 DL_FREG_173;
uniform float4 DL_FREG_174;
uniform float4 DL_FREG_175;
uniform float4 DL_FREG_176;
uniform float4 DL_FREG_177;
uniform float4 DL_FREG_180;
uniform float4 DL_FREG_181;
uniform float4 DL_FREG_182;
uniform float4 DL_FREG_184;
uniform float4 DL_FREG_185;
uniform float4 DL_FREG_186;
uniform float DL_FREG_187;
uniform float4x4 DL_FREG_188;
uniform float4 DL_FREG_192;
uniform float DL_FREG_193;
uniform float4 DL_FREG_194;
uniform float4 DL_FREG_195;
uniform uint4 DL_FREG_196;
uniform float4 DL_FREG_197;
uniform uint4 DL_FREG_198;
uniform float4 DL_FREG_199;
uniform float4 DL_FREG_200;

// ============================================================================
// Vertex shader
// ============================================================================
struct VTX_IN_SFX
{
    float3 VecPos : POSITION0;
    int4 BlendIdx : BLENDINDICES0;
    float3 VecNrm : NORMAL0;       // slot v2 — always declared (unused, fixes ISGN)
#ifdef WITH_Tangent
    float4 VecTan : TANGENT0;      // slot v3 — PINT variant only (shifts TEXCOORD to v5)
#endif
    float4 ColVtx : COLOR0;        // always declared (unused, fixes ISGN)
    int2 TexDif_int_qloc : TEXCOORD0;  // v4 (PIN) or v5 (PINT)
};

struct VTX_OUT_SFX
{
    float4 VtxClp : SV_Position;
    float4 TEXCOORD0 : TEXCOORD0;
    float4 TEXCOORD2 : TEXCOORD2;
    float4 TEXCOORD3 : TEXCOORD3;
    float4 COLOR0 : COLOR0;
    float2 TexDif : TEXCOORD6;
};

VTX_OUT_SFX VertexMain(VTX_IN_SFX In)
{
    VTX_OUT_SFX Out;

    int boneIdx = (int)In.BlendIdx.x;

    float4 localPos;
    localPos.xyz = In.VecPos.xyz;
    localPos.w   = 1.0f;

    float4 worldPos;
    worldPos.x = dot(VR_008A[boneIdx][0], localPos);
    worldPos.y = dot(VR_008A[boneIdx][1], localPos);
    worldPos.z = dot(VR_008A[boneIdx][2], localPos);
    worldPos.w = 1.0f;

    Out.VtxClp = mul(worldPos, VR_000);

    Out.TexDif.xy = (float2)In.TexDif_int_qloc * 0.0009765625f;

    return Out;
}