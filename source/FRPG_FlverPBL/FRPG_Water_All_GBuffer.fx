// FRPG_Water_All_GBuffer.fx — Entry point for water GBuffer (PntSS/PntSSSS) variants
// Uses DL_FREG cbuffer layout (cb0[196]) matching the reference .fpo exactly
// No structured buffers, no FRPG_Common dependencies — self-contained DL_FREG cbuffer

#define FC_REG(x) register(x)

// DL_FREG cbuffer block — matches the reference .fpo header exactly
cbuffer _Globals : register(b0)
{
    float4 DL_FREG_084 : packoffset(c84);
    float4 DL_FREG_085 : packoffset(c85);
    float4 DL_FREG_086 : packoffset(c86);
    float4 DL_FREG_087 : packoffset(c87);
    float4 DL_FREG_088 : packoffset(c88);
    float4 DL_FREG_089 : packoffset(c89);
    float4 DL_FREG_090 : packoffset(c90);
    float4 DL_FREG_091 : packoffset(c91);
    float4 DL_FREG_092 : packoffset(c92);
    float4 DL_FREG_093 : packoffset(c93);
    float4 DL_FREG_094 : packoffset(c94);
    float4 DL_FREG_095 : packoffset(c95);
    float4 DL_FREG_096 : packoffset(c96);
    float4 DL_FREG_097 : packoffset(c97);
    float4 DL_FREG_098 : packoffset(c98);
    float4 DL_FREG_099 : packoffset(c99);
    float4 DL_FREG_100 : packoffset(c100);
    float4 DL_FREG_101 : packoffset(c101);
    float4 DL_FREG_102 : packoffset(c102);
    float4 DL_FREG_103 : packoffset(c103);
    float4 DL_FREG_104 : packoffset(c104);
    float4 DL_FREG_105 : packoffset(c105);
    float4 DL_FREG_106 : packoffset(c106);
    float4 DL_FREG_107 : packoffset(c107);
    float4 DL_FREG_108 : packoffset(c108);
    float4 DL_FREG_109 : packoffset(c109);
    float4 DL_FREG_110 : packoffset(c110);
    float4 DL_FREG_111 : packoffset(c111);
    float4 DL_FREG_112 : packoffset(c112);
    float4 DL_FREG_113 : packoffset(c113);
    float4 DL_FREG_114 : packoffset(c114);
    float4 DL_FREG_115 : packoffset(c115);
    float4 DL_FREG_116 : packoffset(c116);
    float4 DL_FREG_117 : packoffset(c117);
    float4 DL_FREG_118 : packoffset(c118);
    float4 DL_FREG_119 : packoffset(c119);
    float  DL_FREG_120 : packoffset(c120);
    float4 DL_FREG_121 : packoffset(c121);
    float4 DL_FREG_122 : packoffset(c122);
    float4 DL_FREG_123 : packoffset(c123);
    float  DL_FREG_124 : packoffset(c124);
    float  DL_FREG_125 : packoffset(c125);
    float  DL_FREG_126 : packoffset(c126);
    float4 DL_FREG_127 : packoffset(c127);
    float2 DL_FREG_128 : packoffset(c128);
    float  DL_FREG_129 : packoffset(c129);
    float  DL_FREG_130 : packoffset(c130);
    float  DL_FREG_131 : packoffset(c131);
    float4 DL_FREG_132 : packoffset(c132);
    float4 DL_FREG_133 : packoffset(c133);
    float3 DL_FREG_134 : packoffset(c134);
    float4 DL_FREG_135 : packoffset(c135);
    float4 DL_FREG_136 : packoffset(c136);
    float4 DL_FREG_137 : packoffset(c137);
    float4 DL_FREG_138 : packoffset(c138);
    float4 DL_FREG_139 : packoffset(c139);
    float4x4 DL_FREG_140 : packoffset(c140);
    float4x4 DL_FREG_144 : packoffset(c144);
    float4x4 DL_FREG_148 : packoffset(c148);
    float4x4 DL_FREG_152 : packoffset(c152);
    float4 DL_FREG_156 : packoffset(c156);
    float4 DL_FREG_157 : packoffset(c157);
    float4 DL_FREG_158 : packoffset(c158);
    float4 DL_FREG_159 : packoffset(c159);
    float4 DL_FREG_160 : packoffset(c160);
    float4 DL_FREG_163 : packoffset(c163);
    float4 DL_FREG_164 : packoffset(c164);
    float4x4 DL_FREG_165 : packoffset(c165);
    float4 DL_FREG_169 : packoffset(c169);
    float4 DL_FREG_170 : packoffset(c170);
    float4 DL_FREG_171 : packoffset(c171);
    float4 DL_FREG_172 : packoffset(c172);
    float4 DL_FREG_173 : packoffset(c173);
    float4 DL_FREG_174 : packoffset(c174);
    float4 DL_FREG_175 : packoffset(c175);
    float4 DL_FREG_176 : packoffset(c176);
    float4 DL_FREG_177 : packoffset(c177);
    float4 DL_FREG_180 : packoffset(c180);
    float4 DL_FREG_181 : packoffset(c181);
    float4 DL_FREG_182 : packoffset(c182);
    float4 DL_FREG_184 : packoffset(c184);
    float4 DL_FREG_185 : packoffset(c185);
    float4 DL_FREG_186 : packoffset(c186);
    float  DL_FREG_187 : packoffset(c187);
    float4x4 DL_FREG_188 : packoffset(c188);
    float4 DL_FREG_192 : packoffset(c192);
    float  DL_FREG_193 : packoffset(c193);
    float4 DL_FREG_194 : packoffset(c194);
    float4 DL_FREG_195 : packoffset(c195);
}

// Samplers and textures
SamplerState s0 : register(s0);
SamplerState s1 : register(s1);
SamplerState s2 : register(s2);
SamplerState s12 : register(s12);
Texture2D    t0 : register(t0);
Texture2D    t1 : register(t1);
Texture2D    t2 : register(t2);
TextureCube  t12 : register(t12);

#if defined(WITH_ShadowMap)
SamplerState s7 : register(s7);
Texture2D    t7 : register(t7);
#include "FRPG_Water_Env_GB_Shadow.fxh"
#endif

#ifdef WATER_ENV
#include "FRPG_Water_Env_GBuffer.fx"
#endif

#ifdef WATER_REFLECT
#include "FRPG_Water_Reflect_GBuffer.fx"
#endif
