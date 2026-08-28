// FRPG_VS_Sfx.fx — SFX vertex shaders of FRPG_SfxPBL_DX11 (29 VS)
// Reconstructed from DSR DXBC (FRPG_SfxPBL_DX11.shaderbnd.dcx)
//
// Compile: /E VSFragmentMain /T vs_5_0
// Defines:
//   SFX_VS_KIND   0=Blur 1=Line 2=Tracer 3=Distortion 4=PointSprite 5=SimpleSprite 6=Particle
//   SFX_VS_TYPE   per-kind variant (Blur 0/1, Tracer 0/1, SimpleSprite 0..8, Particle 0..3)
//   SFX_VS_DEPTH  SimpleSprite_Depth family (TYPE 0/1/4/5/7; 2/3/6/8 are binary equal to SimpleSprite)

#ifndef SFX_VS_KIND
#define SFX_VS_KIND 5
#endif
#ifndef SFX_VS_TYPE
#define SFX_VS_TYPE 0
#endif
#ifndef SFX_VS_DEPTH
#define SFX_VS_DEPTH 0
#endif

// rim output style: Type0/3/5/7 use mad/mul (no VR_21.z/w); others divide by VR_21.w
#if SFX_VS_KIND == 4
#define SFX_RIM_DIV 1
#elif SFX_VS_KIND == 5 || SFX_VS_KIND == 6
#if SFX_VS_TYPE == 0 || SFX_VS_TYPE == 3 || SFX_VS_TYPE == 5 || SFX_VS_TYPE == 7
#define SFX_RIM_DIV 0
#else
#define SFX_RIM_DIV 1
#endif
#else
#define SFX_RIM_DIV 0
#endif

// nearfar alpha: Type2/6/8 divide by size, Type3 does not
#if SFX_VS_KIND == 5 || SFX_VS_KIND == 6
#if SFX_VS_TYPE == 2 || SFX_VS_TYPE == 6 || SFX_VS_TYPE == 8
#define SFX_NEARFAR_DIVSIZE 1
#else
#define SFX_NEARFAR_DIVSIZE 0
#endif
#else
#define SFX_NEARFAR_DIVSIZE 0
#endif

// ---- $Globals (b0) ----
// Loose globals with explicit cN registers -> fxc emits implicit "$Globals"
// with RDEF variable order == declaration order below (matches reference).
// Blur VS (KIND 0) declare no constants at all.
#if SFX_VS_KIND == 6
ByteAddressBuffer g_particles : register(t5);
#endif
#if SFX_VS_KIND != 0
float4   g_vs_nearfarparam : register(c0);
float4   g_vs_light_0_dir  : register(c1);
float4x4 g_mWorldViewProj  : register(c4);
float4x4 g_mViewProj       : register(c8);
float4x4 g_mView           : register(c12);
float4x4 g_mProj           : register(c16);
#if SFX_VS_KIND == 4
float4   g_screenSize      : register(c30);
#endif
float4   g_fog_prm         : register(c2);
float4   VR_20 : register(c20);
float4   VR_21 : register(c21);
#if SFX_VS_KIND == 1 || SFX_VS_KIND == 2 || SFX_VS_KIND == 3
// Line/Tracer/Distortion name slots c22..c29 after the lighting LUT block
float4   gVC_LsBeta1PlusBeta2        : register(c22);
float4   gVC_LsTerrainReflectance    : register(c23);
float4   gVC_LsOneOverBeta1PlusBeta2 : register(c24);
float4   gVC_LsHGg                   : register(c25);
float4   gVC_LsBetaDash1             : register(c26);
float4   gVC_LsBetaDash2             : register(c27);
float4   gVC_LsSunColor              : register(c28);
float4   gVC_LsLightDir              : register(c29);
#define VR_22 gVC_LsBeta1PlusBeta2
#define VR_23 gVC_LsTerrainReflectance
#define VR_24 gVC_LsOneOverBeta1PlusBeta2
#define VR_25 gVC_LsHGg
#define VR_26 gVC_LsBetaDash1
#define VR_27 gVC_LsBetaDash2
#define VR_28 gVC_LsSunColor
#define VR_29 gVC_LsLightDir
#else
float4   VR_22 : register(c22);
float4   VR_23 : register(c23);
float4   VR_24 : register(c24);
float4   VR_25 : register(c25);
float4   VR_26 : register(c26);
float4   VR_27 : register(c27);
float4   VR_28 : register(c28);
float4   VR_29 : register(c29);
#endif
#if SFX_VS_KIND == 3
// Distortion tail (ref offsets: 480 xyz / 496 x)
float3   g_eye_pos               : register(c30);
float    g_UsingFrameBufTexture  : register(c31);
#endif
#if SFX_VS_KIND == 5 || SFX_VS_KIND == 6
// FormVertex / particle block (ref offsets 480..1504)
#if SFX_VS_KIND == 6
// particle path transforms axes via dot(row,...): keep rows in registers
row_major float4x3 gVC_PreTransformMatrix  : register(c30);
#else
float4x3 gVC_PreTransformMatrix            : register(c30);
#endif
float4x3 gVC_ParticleToWorldMat            : register(c34);
float4   gVC_PreScale            : register(c38);
float4   gVC_FormVertexPos[8]      : register(c40);
float4   gVC_FormVertexUV[8]       : register(c48);
float4   gVC_FormVertexNormal[8]   : register(c56);
float4   gVC_FormVertexTangent[8]  : register(c64);
float4   gVC_FormVertexBinormal[8] : register(c72);
float4   gVC_FormVertexColor[8]    : register(c80);
float4   gVC_Translucent         : register(c88);
float4   gVC_LightColor[4]       : register(c89);
float4   gVC_LightDir            : register(c93);
float4   gVC_DistanceFadeInfo    : register(c94);
#endif
#if SFX_VS_KIND == 4
#define g_screenSizeInvX (g_screenSize.w)
#endif
#endif // SFX_VS_KIND != 0

// ---- helpers ----
#if SFX_VS_KIND != 0
float2 SfxFog2(float clipW)
{
    return saturate(VR_21.xy * ((clipW - g_fog_prm.x) * g_fog_prm.y));
}
#endif

#if SFX_VS_KIND == 4 || SFX_VS_KIND == 5 || SFX_VS_KIND == 6
void SfxRimLight(float3 worldPos, out float3 rim, out float3 light)
{
    float3 cam = VR_20.xyz - worldPos;
    float dist = length(cam);
    float3 viewDir = cam / dist;
    float ndl = dot(viewDir, VR_29.xyz);
    float3 rimExp = exp2(2.08136892f * (VR_29.w * (-VR_22.xyz * dist)));
    float3 rimT = rimExp * VR_23.xyz - 1.0f;
    float3 rimInv = 1.0f - rimExp;
    float rimK = VR_21.y * VR_28.w;
    rim = rimT * rimK + 1.0f;
    float denom = VR_25.z * (-ndl) + VR_25.y;
    float ndl2 = ndl * ndl + 1.0f;
    float rsqrtD = rsqrt(denom);
    float invD = 1.0f / denom;
    float att = (rsqrtD * invD) * VR_25.x;
    light = (VR_26.xyz * ndl2 + VR_27.xyz * att) * rimInv * VR_24.xyz * VR_23.w * VR_28.xyz * rimK;
#if SFX_RIM_DIV
    rim = rim * VR_21.z / VR_21.w;
    light = light * VR_21.z / VR_21.w;
#endif
}

void SfxRimLightParticle(float3 worldPos, out float3 rim, out float3 light)
{
    float3 cam = VR_20.xyz - worldPos;
    float dist = length(cam);
    float3 viewDir = cam / dist;
    float3 rimExp = exp2(2.08136892f * (VR_29.w * (-VR_22.xyz * dist)));
    float ndl = dot(viewDir, VR_29.xyz);
    float ndl2 = ndl * ndl + 1.0f;
    float denom = VR_25.z * (-ndl) + VR_25.y;
    float rsqrtD = rsqrt(denom);
    float invD = 1.0f / denom;
    float att = (rsqrtD * invD) * VR_25.x;
    light = (VR_26.xyz * ndl2 + VR_27.xyz * att) * (1.0f - rimExp) * VR_24.xyz * VR_23.w * VR_28.xyz;
    float rimK = VR_21.y * VR_28.w;
    rim = (rimExp * VR_23.xyz - 1.0f) * rimK + 1.0f;
#if SFX_RIM_DIV
    rim = rim * VR_21.z / VR_21.w;
#endif
    light = light * rimK;
#if SFX_RIM_DIV
    light = light * VR_21.z / VR_21.w;
#endif
}
#endif

#if SFX_VS_KIND == 5 || SFX_VS_KIND == 6
#if SFX_VS_TYPE == 2 || SFX_VS_TYPE == 3 || SFX_VS_TYPE == 6 || SFX_VS_TYPE == 8
float2 SfxNearFar(float clipW, float alphaSize, float size, out float z0)
{
    z0 = clipW - size * 0.5f;
    float invRange = 1.0f / (clipW - z0);
    float t = saturate(invRange * (g_vs_nearfarparam.w - z0));
    float fade = 1.0f - (t * t) * (-2.0f * t + 3.0f);
    float fadeA = fade * alphaSize;
    float zInv = clipW / z0;
    float2 nfRatio = g_vs_nearfarparam.zx / g_vs_nearfarparam.yy;
    float linDepth = (nfRatio.x * z0 - nfRatio.y) * zInv;
    bool inRange = (z0 < g_vs_nearfarparam.w) && (g_vs_nearfarparam.w < clipW);
    return inRange ? float2(0.0f, fadeA) : float2(linDepth, alphaSize);
}
#endif
#endif

#if SFX_VS_KIND == 6
// ---- particle loader (raw buffer stride 80) ----
struct SfxParticleData
{
    float3 worldPos;
    float3 nrm;
    float3 tan;
    float3 bin;
    float2 uv0;
    float2 uv1;
    float4 color;
    float sizeHalf;
    float posW;
};

SfxParticleData SfxParticleLoad(uint vid)
{
    SfxParticleData p;
    uint pi = vid / uint(gVC_PreScale.y);
    uint vi = vid % uint(gVC_PreScale.y);
    uint base = pi * 80u;
    float4 pos = asfloat(g_particles.Load4(base + 0u));
    float4 col = asfloat(g_particles.Load4(base + 16u));
    uint4 pack = g_particles.Load4(base + 32u);
    float3 ang = asfloat(g_particles.Load3(base + 48u));
    float4 extra = asfloat(g_particles.Load4(base + 64u));

    float3 s, c;
    sincos(ang.zxy, s, c);
    float2 r1 = float2(s.x * s.y, s.x * s.z);
    float3 r7 = float3(c.x * s.y, c.y * s.x, c.y * s.z);
    float r0w = r1.x * c.z;
    float r1w = r7.x * s.z;
    float3 r8 = float3(c.x * c.z, c.x * c.y, c.y * c.z);
    float3 col0 = float3(r1.x * s.z + r8.x, r7.y, -c.x * s.z + r0w);
    float3 col1 = float3(-s.x * c.z + r1w, r8.y, r7.x * c.z + r1.y);
    float3 col2 = float3(-s.y, r7.z, r8.z);

    float2 swz = (gVC_PreScale.x != 0.0f) ? asfloat(pack.zw) : asfloat(pack.wz);
    float3 axisA = float3(col0.x * asfloat(pack.z), r7.y * swz.x, col0.z * asfloat(pack.z));
    float3 axisB = float3(col1.x * swz.y, col1.y * asfloat(pack.w), col1.z * asfloat(pack.w));

    float3 A_w = float3(dot(axisA, gVC_PreTransformMatrix[0]), dot(axisA, gVC_PreTransformMatrix[1]), dot(axisA, gVC_PreTransformMatrix[2]));
    float3 B_w = float3(dot(axisB, gVC_PreTransformMatrix[0]), dot(axisB, gVC_PreTransformMatrix[1]), dot(axisB, gVC_PreTransformMatrix[2]));
    float3 C_w = float3(dot(col0, gVC_PreTransformMatrix[0]), dot(col0, gVC_PreTransformMatrix[1]), dot(col0, gVC_PreTransformMatrix[2]));
    float3 D_w = float3(dot(col1, gVC_PreTransformMatrix[0]), dot(col1, gVC_PreTransformMatrix[1]), dot(col1, gVC_PreTransformMatrix[2]));
    float3 E_w = float3(dot(col2, gVC_PreTransformMatrix[0]), dot(col2, gVC_PreTransformMatrix[1]), dot(col2, gVC_PreTransformMatrix[2]));

    float3 vp = float3(gVC_FormVertexPos[vi].xy, 1.0f);
    float3 pw = mul(float4(pos.xyz, 1.0f), gVC_ParticleToWorldMat);
    p.worldPos = mul(vp, float3x3(A_w, B_w, pw));

    float3 n = gVC_FormVertexNormal[vi].xyz;
    float3 t = gVC_FormVertexTangent[vi].xyz;
    float3 b = gVC_FormVertexBinormal[vi].xyz;
    float3x3 basis = float3x3(C_w, D_w, E_w);
    p.nrm = mul(n, basis);
    p.tan = mul(t, basis);
    p.bin = mul(b, basis);

    const float k = 3.05185094e-05f;
    float2 uvBase = gVC_FormVertexUV[vi].xy * gVC_PreScale.zw;
    uint2 lo = uint2(pack.x & 0xffffu, pack.y & 0xffffu);
    uint2 hi = uint2(pack.x >> 16u, pack.y >> 16u);
    p.uv0 = uvBase + float2(lo.x, hi.x) * k;
    p.uv1 = uvBase + float2(lo.y, hi.y) * k;

    p.sizeHalf = 0.5f * (asfloat(pack.z) + asfloat(pack.w));
    p.posW = pos.w;

    float4 vcol = gVC_FormVertexColor[vi];
    float3 lit = (1.0f + p.nrm.y) * gVC_LightColor[0].xyz + gVC_LightColor[1].xyz;
    lit += saturate(dot(p.nrm, gVC_LightDir.xyz) * gVC_Translucent.y + gVC_Translucent.x) * gVC_LightColor[2].xyz;
    float4 color = (gVC_LightDir.w != 0.0f) ? float4(vcol.xyz * (lit * col.xyz), gVC_LightColor[3].w * (vcol.w * col.w)) : vcol * col;
    p.color = color * extra;
    return p;
}

void SfxParticleFadeIn(float3 worldPos, inout float4 color)
{
    [branch] if (gVC_DistanceFadeInfo.x != -1.0f)
    {
        float2 inv = 1.0f / gVC_DistanceFadeInfo.wy;
        float2 sums = gVC_DistanceFadeInfo.yw + gVC_DistanceFadeInfo.xz;
        float dist = length(VR_20.xyz - worldPos);
        float farFade = (sums.y < dist) ? 0.0f : 1.0f - (dist - gVC_DistanceFadeInfo.z) * inv.x;
        float nearFade = (dist < gVC_DistanceFadeInfo.x) ? 0.0f
                       : (((dist < sums.x) && (gVC_DistanceFadeInfo.y > 0.0f)) ? inv.y * (dist - gVC_DistanceFadeInfo.x) : 1.0f);
        float mid = ((gVC_DistanceFadeInfo.x > 0.0f) || (gVC_DistanceFadeInfo.y > 0.0f)) ? nearFade : 1.0f;
        float fade = (gVC_DistanceFadeInfo.z < dist) ? farFade : mid;
        color.w = saturate(color.w * fade);
    }
}
#endif

// =====================================================================
// KIND 0: Blur (0/1)
// =====================================================================
#if SFX_VS_KIND == 0
struct SfxBlurIn
{
    float2 Pos : POSITION;
#if SFX_VS_TYPE == 1
    float2 UV0 : TEXCOORD0;
    float2 UV1 : TEXCOORD1;
#else
    float2 UV0 : TEXCOORD0;
#endif
};
struct SfxBlurOut
{
    float4 Pos : SV_Position;
    float2 UV0 : TEXCOORD0;
#if SFX_VS_TYPE == 1
    float2 UV1 : TEXCOORD1;
#endif
};
SfxBlurOut VSFragmentMain(SfxBlurIn In)
{
    SfxBlurOut o;
    o.Pos = float4(In.Pos.xy, 0.0f, 1.0f);
    o.UV0 = In.UV0.xy;
#if SFX_VS_TYPE == 1
    o.UV1 = In.UV1;
#endif
    return o;
}
#endif

// =====================================================================
// KIND 1: Line
// =====================================================================
#if SFX_VS_KIND == 1
struct SfxLineIn
{
    float4 Pos : POSITION;
    float4 ColorA : COLOR0;
    float4 ColorB : COLOR1;
};
struct SfxLineOut
{
    float4 Pos : SV_Position;
    float4 Color : COLOR0;
    float2 Fog : COLOR1;
};
SfxLineOut VSFragmentMain(SfxLineIn In)
{
    SfxLineOut o;
    float4 clp = mul(In.Pos, g_mViewProj);
    o.Pos = clp;
    o.Color = In.ColorA * In.ColorB;
    o.Fog = SfxFog2(clp.w);
    return o;
}
#endif

// =====================================================================
// KIND 2: Tracer (0/1)
// =====================================================================
#if SFX_VS_KIND == 2
struct SfxTracerIn
{
    float3 Pos : POSITION;
    float3 N : NORMAL;
    float3 T : TANGENT;
    float3 B : BINORMAL;
    float4 Color : COLOR0;
    float2 UV : TEXCOORD0;
    float U1 : TEXCOORD1;
};
#if SFX_VS_TYPE == 0
struct SfxTracerOut
{
    float4 Pos : SV_Position;
    float3 N : TEXCOORD0;
    float3 T : TEXCOORD1;
    float3 B : TEXCOORD2;
    float2 UV : TEXCOORD3;
    float U1 : TEXCOORD4;
    float4 Color : COLOR0;
    float2 Fog : COLOR1;
};
SfxTracerOut VSFragmentMain(SfxTracerIn In)
{
    SfxTracerOut o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.N.xyz = In.N;
    o.T.xyz = In.T;
    o.B.xyz = In.B;
    o.UV = In.UV.xy;
    o.U1 = In.U1;
    o.Color = In.Color;
    o.Fog = SfxFog2(clp.w);
    return o;
}
#else
struct SfxTracerOut
{
    float4 Pos : SV_Position;
    float2 UV : TEXCOORD0;
    float2 ClipXY : TEXCOORD1;
    float3 FogW : TEXCOORD2;
    float4 Color : COLOR0;
};
SfxTracerOut VSFragmentMain(SfxTracerIn In)
{
    SfxTracerOut o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.UV = In.UV.xy;
    o.ClipXY = clp.xy * float2(1.0f, -1.0f);
    o.FogW = float3(SfxFog2(clp.w), clp.w);
    o.Color = In.Color;
    return o;
}
#endif
#endif

// =====================================================================
// KIND 3: Distortion
// =====================================================================
#if SFX_VS_KIND == 3
struct SfxDistIn
{
    float3 Pos : POSITION;
    float2 UV : TEXCOORD0;
};
struct SfxDistOut
{
    float4 Pos : SV_Position;
    float2 UV : TEXCOORD0;
    float2 ClipXY : TEXCOORD1;
    float3 EyePos : TEXCOORD2;
    float4 Flags : TEXCOORD3;
};
SfxDistOut VSFragmentMain(SfxDistIn In)
{
    SfxDistOut o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mWorldViewProj);
    o.Pos = clp;
    float invUF = 1.0f - g_UsingFrameBufTexture;
    float2 suv = In.UV * 2.0f - 1.0f;
    o.UV = In.UV;
    o.ClipXY.x = g_UsingFrameBufTexture * clp.x + suv.x * invUF;
    o.ClipXY.y = g_UsingFrameBufTexture * (-clp.y) + suv.y * invUF;
    o.EyePos.xyz = g_eye_pos - In.Pos.xyz;
    o.Flags.x = (In.Pos.z < -0.1f) ? 1.0f : 0.0f;
    o.Flags.y = g_UsingFrameBufTexture * clp.w + invUF;
    o.Flags.zw = g_UsingFrameBufTexture * float2(1.0f, -1.0f) + float2(0.0f, 1.0f);
    return o;
}
#endif

// =====================================================================
// KIND 4: PointSprite
// =====================================================================
#if SFX_VS_KIND == 4
struct SfxPSpriteIn
{
    float3 Pos : POSITION;
    float4 ColorA : COLOR0;
    float4 ColorB : COLOR1;
    float4 Sprite : TEXCOORD0;
};
struct SfxPSpriteOut
{
    float4 Pos : SV_Position;
    float4 Color : COLOR0;
    float4 FogUV : COLOR1;
    float3 Rim : TEXCOORD0;
    float3 Light : TEXCOORD1;
};
SfxPSpriteOut VSFragmentMain(SfxPSpriteIn In)
{
    SfxPSpriteOut o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    o.Pos.x = clp.x + clp.w * (In.Sprite.z * g_screenSizeInvX);
    o.Pos.y = clp.y + clp.w * In.Sprite.w;
    o.Pos.z = clp.z;
    o.Pos.w = clp.w;
    o.Color = In.ColorA * In.ColorB;
    o.FogUV.xy = SfxFog2(clp.w);
    o.FogUV.zw = In.Sprite.xy;
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim.xyz = rim;
    o.Light = light;
    return o;
}
#endif

// =====================================================================
// KIND 5: SimpleSprite (0..8) + Depth (0/1/4/5/7)
// =====================================================================
#if SFX_VS_KIND == 5

#if SFX_VS_TYPE >= 0 && SFX_VS_TYPE <= 3
struct SfxIn
{
    float4 Pos : POSITION;
    float3 N : NORMAL;
    float3 T : TANGENT;
    float3 B : BINORMAL;
    float Ramp : TEXCOORD0;
    float4 Color : COLOR;
    float4 Extra : TEXCOORD1;
    float Size : TEXCOORD2;
};
#endif

#if SFX_VS_TYPE == 0
struct SfxOut_0
{
    float4 Pos : SV_Position;
    float4 UVFog : TEXCOORD0;
    float4 Color : TEXCOORD1;
    float4 Rim : TEXCOORD2;
    float4 Light : TEXCOORD3;
#if SFX_VS_DEPTH
    float PosW : TEXCOORD4;
    float2 ClipZW : TEXCOORD5;
#else
    float PosW : TEXCOORD4;
#endif
};
SfxOut_0 VSFragmentMain(SfxIn In)
{
    SfxOut_0 o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.UVFog = float4(In.Extra.xy, SfxFog2(clp.w));
    o.Color = In.Color;
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim = float4(rim, In.Extra.z);
    o.Light = float4(light, In.Extra.w);
#if SFX_VS_DEPTH
    o.PosW = In.Pos.w;
    o.ClipZW = clp.zw;
#else
    o.PosW = In.Pos.w;
#endif
    return o;
}
#endif

#if SFX_VS_TYPE == 1
struct SfxOut_1
{
    float4 Pos : SV_Position;
    float4 Dirs : TEXCOORD0;
    float3 LightY : TEXCOORD1;
    float4 UVFog : TEXCOORD2;
    float4 Color : TEXCOORD3;
#if SFX_VS_DEPTH
    float2 Ramp : TEXCOORD4;
    float2 ClipZW : TEXCOORD7;
#else
    float2 Ramp : TEXCOORD4;
#endif
    float4 Rim : TEXCOORD5;
    float4 Light : TEXCOORD6;
};
SfxOut_1 VSFragmentMain(SfxIn In)
{
    SfxOut_1 o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.Dirs.x = dot(In.B * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.y = dot(In.T * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.z = dot(In.N * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.w = In.Pos.w;
    o.LightY.x = In.B.y * 2.0f - 1.0f;
    o.LightY.y = In.T.y * 2.0f - 1.0f;
    o.LightY.z = In.N.y * 2.0f - 1.0f;
    o.UVFog = float4(In.Extra.xy, SfxFog2(clp.w));
    o.Color = In.Color;
    o.Ramp = In.Ramp.x * float2(1.0f, -1.0f) + float2(0.0f, 1.0f);
#if SFX_VS_DEPTH
    o.ClipZW = clp.zw;
#endif
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim = float4(rim, In.Extra.z);
    o.Light = float4(light, In.Extra.w);
    return o;
}
#endif

#if SFX_VS_TYPE == 2
struct SfxOut_2
{
    float4 Pos : SV_Position;
    float4 UVFog : TEXCOORD0;
    float4 Color : TEXCOORD1;
    float4 NDC : TEXCOORD2;
    float4 Rim : TEXCOORD3;
    float4 Light : TEXCOORD4;
    float PosW : TEXCOORD5;
};
SfxOut_2 VSFragmentMain(SfxIn In)
{
    SfxOut_2 o;
    float alphaSize = In.Color.w / In.Size;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    float z0;
    float2 nf = SfxNearFar(clp.w, alphaSize, In.Size, z0);
    o.Pos = clp;
    o.Pos.z = nf.x;
    o.UVFog = float4(In.Extra.xy, SfxFog2(clp.w));
    o.Color = float4(In.Color.xyz, nf.y);
    o.NDC = float4(clp.xy / clp.w * float2(0.5f, -0.5f) + float2(0.5f, 0.5f), z0, In.Size);
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim = float4(rim, In.Extra.z);
    o.Light = float4(light, In.Extra.w);
    o.PosW = In.Pos.w;
    return o;
}
#endif

#if SFX_VS_TYPE == 3
struct SfxOut_3
{
    float4 Pos : SV_Position;
    float4 Dirs : TEXCOORD0;
    float3 LightY : TEXCOORD1;
    float4 UVFog : TEXCOORD2;
    float4 Color : TEXCOORD3;
    float4 Size : TEXCOORD4;
    float3 NDC : TEXCOORD5;
    float4 Rim : TEXCOORD6;
    float4 Light : TEXCOORD7;
};
SfxOut_3 VSFragmentMain(SfxIn In)
{
    SfxOut_3 o;
    float alphaSize = In.Color.w;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    float z0;
    float2 nf = SfxNearFar(clp.w, alphaSize, In.Size, z0);
    o.Pos = clp;
    o.Pos.z = nf.x;
    o.Dirs.x = dot(In.B * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.y = dot(In.T * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.z = dot(In.N * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.w = In.Pos.w;
    o.LightY.x = In.B.y * 2.0f - 1.0f;
    o.LightY.y = In.T.y * 2.0f - 1.0f;
    o.LightY.z = In.N.y * 2.0f - 1.0f;
    o.UVFog = float4(In.Extra.xy, SfxFog2(clp.w));
    o.Color = float4(In.Color.xyz, nf.y);
    o.Size.xy = In.Ramp.x * float2(1.0f, -1.0f) + float2(0.0f, 1.0f);
    o.Size.z = In.Size;
    o.Size.w = 1.0f / In.Size;
    o.NDC.xy = clp.xy / clp.w * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    o.NDC.z = z0;
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim = float4(rim, In.Extra.z);
    o.Light = float4(light, In.Extra.w);
    return o;
}
#endif

#if SFX_VS_TYPE == 4
struct SfxIn_4
{
    float3 Pos : POSITION;
    float4 Color : COLOR0;
    float4 UV01 : TEXCOORD0;
};
struct SfxOut_4
{
    float4 Pos : SV_Position;
    float4 UVFog : TEXCOORD0;
    float2 UV1 : TEXCOORD1;
#if SFX_VS_DEPTH
    float2 ClipZW : TEXCOORD5;
#endif
    float4 Color : TEXCOORD2;
    float3 Rim : TEXCOORD3;
    float3 Light : TEXCOORD4;
};
SfxOut_4 VSFragmentMain(SfxIn_4 In)
{
    SfxOut_4 o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.UVFog = float4(In.UV01.xy, SfxFog2(clp.w));
    o.UV1 = In.UV01.zw;
#if SFX_VS_DEPTH
    o.ClipZW = clp.zw;
#endif
    o.Color = In.Color;
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim.xyz = rim;
    o.Light = light;
    return o;
}
#endif

#if SFX_VS_TYPE == 5
struct SfxIn_5
{
    float3 Pos : POSITION;
    float4 Color : COLOR0;
    float4 UV0 : TEXCOORD0;
    float2 UV1 : TEXCOORD1;
    float2 T2dead : TEXCOORD2;   // declared-unread in reference ISGN
};
struct SfxOut_5
{
    float4 Pos : SV_Position;
    float4 UV0 : TEXCOORD0;
    float4 UVFog : TEXCOORD1;
    float4 Color : TEXCOORD2;
    float3 Rim : TEXCOORD3;
#if SFX_VS_DEPTH
    float3 Light : TEXCOORD4;
    float2 Depth : TEXCOORD5;
#else
    float3 Light : TEXCOORD4;
#endif
};
SfxOut_5 VSFragmentMain(SfxIn_5 In)
{
    SfxOut_5 o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.UV0 = In.UV0;
    o.UVFog = float4(In.UV1.xy, SfxFog2(clp.w));
    o.Color = In.Color;
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim.xyz = rim;
#if SFX_VS_DEPTH
    o.Light = light;
    o.Depth = clp.zw;
#else
    o.Light = light;
#endif
    return o;
}
#endif

#if SFX_VS_TYPE == 6
struct SfxIn_6
{
    float3 Pos : POSITION;
    float4 Color : COLOR0;
    float4 UV0 : TEXCOORD0;
    float2 UV1 : TEXCOORD1;
    float2 Size2 : TEXCOORD2;   // .y = size
};
struct SfxOut_6
{
    float4 Pos : SV_Position;
    float4 UV0 : TEXCOORD0;
    float4 UVFog : TEXCOORD1;
    float4 Color : TEXCOORD2;
    float4 NDC : TEXCOORD3;
    float3 Rim : TEXCOORD4;
    float3 Light : TEXCOORD5;
};
SfxOut_6 VSFragmentMain(SfxIn_6 In)
{
    SfxOut_6 o;
    float alphaSize = In.Color.w / In.Size2.y;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    float z0;
    float2 nf = SfxNearFar(clp.w, alphaSize, In.Size2.y, z0);
    o.Pos = clp;
    o.Pos.z = nf.x;
    o.UV0 = In.UV0;
    o.UVFog = float4(In.UV1.xy, SfxFog2(clp.w));
    o.Color = float4(In.Color.xyz, nf.y);
    o.NDC = float4(clp.xy / clp.w * float2(0.5f, -0.5f) + float2(0.5f, 0.5f), z0, In.Size2.y);
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim.xyz = rim;
    o.Light = light;
    return o;
}
#endif

#if SFX_VS_TYPE == 7
struct SfxIn_7
{
    float3 Pos : POSITION;
    float4 Color : COLOR0;
    float4 UV0 : TEXCOORD0;
    float2 T1dead : TEXCOORD1;   // declared-unread in reference ISGN
    float2 T2dead : TEXCOORD2;
};
struct SfxOut_7
{
    float4 Pos : SV_Position;
    float4 UV0 : TEXCOORD0;
#if SFX_VS_DEPTH
    float2 Fog : TEXCOORD1;
    float2 ClipZW : TEXCOORD5;
#else
    float2 Fog : TEXCOORD1;
#endif
    float4 Color : TEXCOORD2;
    float3 Rim : TEXCOORD3;
    float3 Light : TEXCOORD4;
};
SfxOut_7 VSFragmentMain(SfxIn_7 In)
{
    SfxOut_7 o;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.UV0 = In.UV0;
#if SFX_VS_DEPTH
    o.Fog = SfxFog2(clp.w);
    o.ClipZW = clp.zw;
#else
    o.Fog.xy = SfxFog2(clp.w);
#endif
    o.Color = In.Color;
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim.xyz = rim;
    o.Light = light;
    return o;
}
#endif

#if SFX_VS_TYPE == 8
struct SfxIn_8
{
    float3 Pos : POSITION;
    float4 Color : COLOR0;
    float4 UV0 : TEXCOORD0;
    float2 T1dead : TEXCOORD1;   // declared-unread in reference ISGN
    float2 Size2 : TEXCOORD2;   // .y = size
};
struct SfxOut_8
{
    float4 Pos : SV_Position;
    float4 UV0 : TEXCOORD0;
    float4 Fog : TEXCOORD1;
    float4 Color : TEXCOORD2;
    float4 NDC : TEXCOORD3;
    float3 Rim : TEXCOORD4;
    float3 Light : TEXCOORD5;
};
SfxOut_8 VSFragmentMain(SfxIn_8 In)
{
    SfxOut_8 o;
    float alphaSize = In.Color.w / In.Size2.y;
    float4 clp = mul(float4(In.Pos.xyz, 1.0f), g_mViewProj);
    float z0;
    float2 nf = SfxNearFar(clp.w, alphaSize, In.Size2.y, z0);
    o.Pos = clp;
    o.Pos.z = nf.x;
    o.UV0 = In.UV0;
    o.Fog.xy = SfxFog2(clp.w);
    o.Color = float4(In.Color.xyz, nf.y);
    o.NDC = float4(clp.xy / clp.w * float2(0.5f, -0.5f) + float2(0.5f, 0.5f), z0, In.Size2.y);
    float3 rim, light;
    SfxRimLight(In.Pos.xyz, rim, light);
    o.Rim.xyz = rim;
    o.Light = light;
    return o;
}
#endif

#endif // KIND 5

// =====================================================================
// KIND 6: Particle (0..3)
// =====================================================================
#if SFX_VS_KIND == 6

#if SFX_VS_TYPE == 0
struct SfxPOut_0
{
    float4 Pos : SV_Position;
    float4 UVFog : TEXCOORD0;
    float4 Color : TEXCOORD1;
    float4 Rim : TEXCOORD2;
    float4 Light : TEXCOORD3;
    float PosW : TEXCOORD4;
};
SfxPOut_0 VSFragmentMain(uint vid : SV_VertexID)
{
    SfxPOut_0 o;
    SfxParticleData p = SfxParticleLoad(vid);
    SfxParticleFadeIn(p.worldPos, p.color);
    float4 clp = mul(float4(p.worldPos, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.UVFog = float4(p.uv0, SfxFog2(clp.w));
    o.Color = p.color;
    float3 rim, light;
    SfxRimLightParticle(p.worldPos, rim, light);
    o.Rim = float4(rim, p.uv1.x);
    o.Light = float4(light, p.uv1.y);
    o.PosW = p.posW;
    return o;
}
#endif

#if SFX_VS_TYPE == 1
struct SfxPOut_1
{
    float4 Pos : SV_Position;
    float4 Dirs : TEXCOORD0;
    float3 LightY : TEXCOORD1;
    float4 UVFog : TEXCOORD2;
    float4 Color : TEXCOORD3;
    float4 Ramp : TEXCOORD4;
    float4 Rim : TEXCOORD5;
    float4 Light : TEXCOORD6;
};
SfxPOut_1 VSFragmentMain(uint vid : SV_VertexID)
{
    SfxPOut_1 o;
    SfxParticleData p = SfxParticleLoad(vid);
    SfxParticleFadeIn(p.worldPos, p.color);
    float4 clp = mul(float4(p.worldPos, 1.0f), g_mViewProj);
    o.Pos = clp;
    o.Dirs.x = dot(p.bin * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.y = dot(p.tan * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.z = dot(p.nrm * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.w = p.posW;
    o.LightY.x = p.bin.y * 2.0f - 1.0f;
    o.LightY.y = p.tan.y * 2.0f - 1.0f;
    o.LightY.z = p.nrm.y * 2.0f - 1.0f;
    o.UVFog = float4(p.uv0, SfxFog2(clp.w));
    o.Color = p.color;
    o.Ramp.xy = gVC_Translucent.x * float2(1.0f, -1.0f) + float2(0.0f, 1.0f);
    float3 rim, light;
    SfxRimLightParticle(p.worldPos, rim, light);
    o.Rim = float4(rim, p.uv1.x);
    o.Light = float4(light, p.uv1.y);
    return o;
}
#endif

#if SFX_VS_TYPE == 2
struct SfxPOut_2
{
    float4 Pos : SV_Position;
    float4 UVFog : TEXCOORD0;
    float4 Color : TEXCOORD1;
    float4 NDC : TEXCOORD2;
    float4 Rim : TEXCOORD3;
    float4 Light : TEXCOORD4;
    float PosW : TEXCOORD5;
};
SfxPOut_2 VSFragmentMain(uint vid : SV_VertexID)
{
    SfxPOut_2 o;
    SfxParticleData p = SfxParticleLoad(vid);
    SfxParticleFadeIn(p.worldPos, p.color);
    float4 clp = mul(float4(p.worldPos, 1.0f), g_mViewProj);
    float z0;
    float alphaSize = p.color.w / p.sizeHalf;
    float2 nf = SfxNearFar(clp.w, alphaSize, p.sizeHalf, z0);
    o.Pos = clp;
    o.Pos.z = nf.x;
    o.UVFog = float4(p.uv0, SfxFog2(clp.w));
    o.Color = float4(p.color.xyz, nf.y);
    o.NDC = float4(clp.xy / clp.w * float2(0.5f, -0.5f) + float2(0.5f, 0.5f), z0, p.sizeHalf);
    float3 rim, light;
    SfxRimLightParticle(p.worldPos, rim, light);
    o.Rim = float4(rim, p.uv1.x);
    o.Light = float4(light, p.uv1.y);
    o.PosW = p.posW;
    return o;
}
#endif

#if SFX_VS_TYPE == 3
struct SfxPOut_3
{
    float4 Pos : SV_Position;
    float4 Dirs : TEXCOORD0;
    float3 LightY : TEXCOORD1;
    float4 UVFog : TEXCOORD2;
    float4 Color : TEXCOORD3;
    float4 Size : TEXCOORD4;
    float3 NDC : TEXCOORD5;
    float4 Rim : TEXCOORD6;
    float4 Light : TEXCOORD7;
};
SfxPOut_3 VSFragmentMain(uint vid : SV_VertexID)
{
    SfxPOut_3 o;
    SfxParticleData p = SfxParticleLoad(vid);
    SfxParticleFadeIn(p.worldPos, p.color);
    float4 clp = mul(float4(p.worldPos, 1.0f), g_mViewProj);
    float z0;
    float alphaSize = p.color.w;
    float2 nf = SfxNearFar(clp.w, alphaSize, p.sizeHalf, z0);
    o.Pos = clp;
    o.Pos.z = nf.x;
    o.Dirs.x = dot(p.bin * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.y = dot(p.tan * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.z = dot(p.nrm * 2.0f - 1.0f, g_vs_light_0_dir.xyz);
    o.Dirs.w = p.posW;
    o.LightY.x = p.bin.y * 2.0f - 1.0f;
    o.LightY.y = p.tan.y * 2.0f - 1.0f;
    o.LightY.z = p.nrm.y * 2.0f - 1.0f;
    o.UVFog = float4(p.uv0, SfxFog2(clp.w));
    o.Color = float4(p.color.xyz, nf.y);
    o.Size.xy = gVC_Translucent.x * float2(1.0f, -1.0f) + float2(0.0f, 1.0f);
    o.Size.z = p.sizeHalf;
    o.Size.w = 1.0f / p.sizeHalf;
    o.NDC.xy = clp.xy / clp.w * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    o.NDC.z = z0;
    float3 rim, light;
    SfxRimLightParticle(p.worldPos, rim, light);
    o.Rim = float4(rim, p.uv1.x);
    o.Light = float4(light, p.uv1.y);
    return o;
}
#endif

#endif // KIND 6
