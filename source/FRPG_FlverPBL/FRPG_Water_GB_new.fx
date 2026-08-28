// FRPG_Water_GB_new.fx — water GBuffer body (PntSS / PntSSSS), OLD_VERSION layout.
// Ported 1:1 from reference decompiles FRPG_Water_{Env,Reflect}____PntSS.hlsl
// and FRPG_Water_{Env,Reflect}_{Ncs,Csd}PntSS.hlsl.
// Define contract: WATER_ENV | WATER_REFLECT, WITH_ShadowMap=1|2, WITH_GBUFFER_4LIGHTS.
// Constants: FRPG_Water_GB_FC_new.fxh (auto-generated from reference RDEF).

#include "FRPG_Water_GB_FC_new.fxh"

SamplerState gSMP_1Sampler       : register(s1);
SamplerState gSMP_2Sampler       : register(s2);
SamplerState gSMP_12_CUBESampler : register(s12);
Texture2D    gSMP_1              : register(t1);
Texture2D    gSMP_2              : register(t2);
TextureCube  gSMP_12_CUBE        : register(t12);

#ifdef WATER_REFLECT
SamplerState gSMP_0Sampler       : register(s0);
Texture2D    gSMP_0              : register(t0);
#endif

#ifdef WITH_ShadowMap
// declared-but-unused in reference shadow variants (RDEF lists them)
Texture2D    gSMP_7              : register(t7);
SamplerState gSMP_7Sampler       : register(s7);
#endif

struct WATER_GB_OUT
{
    float4 Color : SV_Target0;
};

WATER_GB_OUT FragmentMain_WaterGB(
    float4 v0  : SV_Position0,
    float4 v1  : TEXCOORD0,
    float4 v2  : TEXCOORD1,
    float4 v3  : TEXCOORD2,
    float4 v4  : TEXCOORD3,
    float4 v5  : COLOR0,
    float4 v6  : TEXCOORD5,
    float4 v7  : TEXCOORD6,
    float4 v8  : TEXCOORD7,
    float4 v9  : TEXCOORD8,
    float4 v10 : TEXCOORD9)
{
    WATER_GB_OUT Out;
    float4 o0;
    float4 r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12;

    // ===== layer A: parallax height from packed RGBA (v9/v10 pairs) =====
    r0.yz = float2(0.5f, 0.5f);
    r1.xy = v9.xy / v9.ww;
    r2.xy = float2(0.5f, -0.5f) * r1.xy;
    r2.zw = r1.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r1.xy = r1.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r3.xy = v10.xy / v10.ww;
    r1.zw = r3.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r4.xyzw = DL_FREG_164.xyxy * r1.xyzw;
    r4.xyzw = frac(r4.xyzw);
    r5.xyzw = (float4(0.5f, 0.5f, 0.5f, 0.5f) < r4.xyzw) ? float4(1, 1, 1, 1) : float4(-1, -1, -1, -1);
    r4.xyzw = float4(-0.5f, -0.5f, -0.5f, -0.5f) + r4.xyzw;
    r6.xyzw = DL_FREG_164.zzww * r5.zxyw;
    r0.xw = r6.yz;
    r0.xyzw = r2.zyxw + r0.xyzw;
    r2.xyzw = gSMP_2.Sample(gSMP_2Sampler, r0.zw).xyzw;
    r0.xyzw = gSMP_2.Sample(gSMP_2Sampler, r0.xy).xyzw;
    r7.xyzw = r5.xyzw * DL_FREG_164.zwzw + r1.xyzw;
    r4.xyzw = r5.xyzw * r4.xyzw;
    r5.xyzw = gSMP_2.Sample(gSMP_2Sampler, r7.xy).xyzw;
    r7.xyzw = gSMP_2.Sample(gSMP_2Sampler, r7.zw).xyzw;
    r5.xyzw = r5.xyzw + -r2.xyzw;
    r2.xyzw = r4.xxxx * r5.xyzw + r2.xyzw;
    r5.xyzw = gSMP_2.Sample(gSMP_2Sampler, r1.xy).xyzw;
    r0.xyzw = -r5.xyzw + r0.xyzw;
    r0.xyzw = r4.xxxx * r0.xyzw + r5.xyzw;
    r2.xyzw = r2.xyzw + -r0.xyzw;
    r0.xyzw = r4.yyyy * r2.xyzw + r0.xyzw;
    r0.x = dot(r0.xyzw, float4(1044480, 65280, 4080, 255));

    // ===== layer B (v6 pair) =====
    r2.yz = float2(0, 0);
    r0.yz = v6.xy / v6.ww;
    r0.yz = r0.yz * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r5.xyzw = r0.yzyz * float4(2, 2, 2, 2) + -r1.xyzw;
    r1.xyzw = gSMP_2.Sample(gSMP_2Sampler, r1.zw).xyzw;
    r8.xyzw = DL_FREG_164.xyxy * r5.xyzw;
    r8.xyzw = frac(r8.xyzw);
    r9.xyzw = (float4(0.5f, 0.5f, 0.5f, 0.5f) < r8.xyzw) ? float4(1, 1, 1, 1) : float4(-1, -1, -1, -1);
    r8.xyzw = float4(-0.5f, -0.5f, -0.5f, -0.5f) + r8.xyzw;
    r10.xyzw = DL_FREG_164.zzww * r9.zxyw;
    r2.xw = r10.yz;
    r2.xyzw = r5.xyxy + r2.xyzw;
    r11.xyzw = gSMP_2.Sample(gSMP_2Sampler, r2.zw).xyzw;
    r2.xyzw = gSMP_2.Sample(gSMP_2Sampler, r2.xy).xyzw;
    r12.xyzw = r9.xyzw * DL_FREG_164.zwzw + r5.xyzw;
    r8.xyzw = r9.xyzw * r8.xyzw;
    r9.xyzw = gSMP_2.Sample(gSMP_2Sampler, r12.xy).xyzw;
    r12.xyzw = gSMP_2.Sample(gSMP_2Sampler, r12.zw).xyzw;
    r9.xyzw = r9.xyzw + -r11.xyzw;
    r9.xyzw = r8.xxxx * r9.xyzw + r11.xyzw;
    r11.xyzw = gSMP_2.Sample(gSMP_2Sampler, r5.xy).xyzw;
    r2.xyzw = -r11.xyzw + r2.xyzw;
    r2.xyzw = r8.xxxx * r2.xyzw + r11.xyzw;
    r9.xyzw = r9.xyzw + -r2.xyzw;
    r2.xyzw = r8.yyyy * r9.xyzw + r2.xyzw;
    r0.w = dot(r2.xyzw, float4(1044480, 65280, 4080, 255));
    r0.w = 1.52590219e-005f * r0.w;
    r0.x = r0.x * 1.52590219e-005f + -r0.w;

    // ===== normal A (v7) =====
    r0.w = v7.y + v7.y;
    r2.x = r0.x * DL_FREG_126 + r0.w;
    r2.yz = float2(2, 2) * v7.zx;
    r0.x = dot(r2.xyz, r2.xyz);
    r0.x = rsqrt(r0.x);
    r2.xyz = r2.xyz * r0.xxx;

    // ===== bilinear merge with layer B samples (v10-based) =====
    r9.xy = float2(0.5f, -0.5f) * r3.xy;
    r9.zw = r3.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
    r6.yz = float2(0.5f, 0.5f);
    r3.xyzw = r9.zyxw + r6.xyzw;
    r6.xyzw = gSMP_2.Sample(gSMP_2Sampler, r3.xy).xyzw;
    r3.xyzw = gSMP_2.Sample(gSMP_2Sampler, r3.zw).xyzw;
    r6.xyzw = r6.xyzw + -r1.xyzw;
    r1.xyzw = r4.zzzz * r6.xyzw + r1.xyzw;
    r6.xyzw = r7.xyzw + -r3.xyzw;
    r3.xyzw = r4.zzzz * r6.xyzw + r3.xyzw;
    r3.xyzw = r3.xyzw + -r1.xyzw;
    r1.xyzw = r4.wwww * r3.xyzw + r1.xyzw;
    r0.x = dot(r1.xyzw, float4(1044480, 65280, 4080, 255));

    // ===== normal B (v8) =====
    r10.yz = float2(0, 0);
    r1.xyzw = r10.xyzw + r5.zwzw;
    r3.xyzw = gSMP_2.Sample(gSMP_2Sampler, r5.zw).xyzw;
    r4.xyzw = gSMP_2.Sample(gSMP_2Sampler, r1.zw).xyzw;
    r1.xyzw = gSMP_2.Sample(gSMP_2Sampler, r1.xy).xyzw;
    r1.xyzw = r1.xyzw + -r3.xyzw;
    r1.xyzw = r8.zzzz * r1.xyzw + r3.xyzw;
    r3.xyzw = r12.xyzw + -r4.xyzw;
    r3.xyzw = r8.zzzz * r3.xyzw + r4.xyzw;
    r3.xyzw = r3.xyzw + -r1.xyzw;
    r1.xyzw = r8.wwww * r3.xyzw + r1.xyzw;
    r0.w = dot(r1.xyzw, float4(1044480, 65280, 4080, 255));
    r0.w = 1.52590219e-005f * r0.w;
    r0.x = r0.x * 1.52590219e-005f + -r0.w;
    float hShadow = r0.x + r0.w;   // pre-difference height sum (shadow lookup)

    // ===== tangent frame =====
    r0.w = v8.y + v8.y;
    r1.z = r0.x * DL_FREG_126 + r0.w;
    r1.xy = float2(2, 2) * v8.zx;
    r0.x = dot(r1.xyz, r1.xyz);
    r0.x = rsqrt(r0.x);
    r1.xyz = r1.xyz * r0.xxx;
    r3.xyz = r1.xyz * r2.xyz;
    r1.xyz = r1.zxy * r2.yzx + -r3.xyz;
    float3 nCross = r1.xyz;

    // ===== water color linearize (DL_FREG_127) =====
    float3 wcLin = log2(DL_FREG_127.xyz);
    wcLin = float3(2.20000005f, 2.20000005f, 2.20000005f) * wcLin;
    wcLin = exp2(wcLin);
    float wA = DL_FREG_127.w * v5.w;

#ifdef WATER_REFLECT
    // ---- screen-space reflection through t0 ----
    float2 ruv = r0.xz * DL_FREG_124 + r5.zw;
    float3 reflCol = gSMP_0.Sample(gSMP_0Sampler, ruv).xyz;
#endif

    // ===== refraction bands (mask lives in t1 channels) =====
    r2.xyzw = DL_FREG_125 * r1.xzxz;
    r0.xw = r2.zw * v5.ww + r0.yz;
    r2.xyzw = v5.wwww * r2.xyzw;
    r2.xyzw = r2.xyzw * float4(1.02999997f, 1.02999997f, 1.05999994f, 1.05999994f) + r0.yzyz;
    r3.xyz = gSMP_1.Sample(gSMP_1Sampler, r0.yz).xyz;
    r0.xw = gSMP_1.Sample(gSMP_1Sampler, r0.xw).xw;
    r4.x = r0.w;
    r4.yz = gSMP_1.Sample(gSMP_1Sampler, r2.xy).wy;
    r0.zw = gSMP_1.Sample(gSMP_1Sampler, r2.zw).zw;
    r0.y = r4.z;
    r4.z = r0.w;
    float3 sceneBase = r0.xyz + -r3.xyz;
    float3 maskC = float3(r4.x, r0.y, r4.z);
    bool maskHit = !(maskC.x == 1 && maskC.y == 1 && maskC.z == 1);
    r0.xyz = maskHit ? sceneBase : r3.xyz;

    // ===== world normal =====
    float nLen = dot(v3.xyz, v3.xyz);
    nLen = sqrt(nLen);
    float3 N = v3.xyz / nLen;

    // ===== scattering prep (DL_FREG_104/111) =====
    float3 scat = -DL_FREG_104.xyz * nLen;
    scat = DL_FREG_111.www * scat;
    scat = float3(2.08136892f, 2.08136892f, 2.08136892f) * scat;
    scat = exp2(scat);

    // ===== reflect dir via cross & pseudo-fresnel (DL_FREG_129) =====
    float dCN = dot(nCross, N);
    float dd2 = dCN + dCN;
    float fr = max(0, dCN);
    fr = 1 + -fr;
    fr = max(0, fr);
    fr = log2(fr);
    fr = DL_FREG_129 * fr;
    fr = exp2(fr);
    float3 reflDir = dd2 * nCross + -N;
    float sunN = dot(N, DL_FREG_111.xyz);

#ifdef WITH_ShadowMap
    // ---- 16-tap RGB8-decoded PCF on t7 ----
    float hWv = hShadow * DL_FREG_126;
    float shPosY = hWv * 0.25f + v1.y;
    float4 shPos = float4(v1.x, shPosY, v1.z, 1);
#if WITH_ShadowMap == 2
    float4 ends = float4(DL_FREG_123.yzw, 65535);
    float4 mIn = (ends >= v1.wwww) ? float4(1,1,1,1) : float4(0,0,0,0);
    float4 mOut = (DL_FREG_123.xyzw < v1.wwww) ? float4(1,1,1,1) : float4(0,0,0,0);
    float4 cw = mIn * mOut;
    float4 bw = DL_FREG_144._m03_m13_m23_m33 * cw.yyyy;
    bw = DL_FREG_140._m03_m13_m23_m33 * cw.xxxx + bw;
    bw = DL_FREG_148._m03_m13_m23_m33 * cw.zzzz + bw;
    bw = DL_FREG_152._m03_m13_m23_m33 * cw.wwww + bw;
    float swC = dot(shPos, bw);
    float4 clw = DL_FREG_158.xyzw * cw.yyyy;
    clw = DL_FREG_157.xyzw * cw.xxxx + clw;
    clw = DL_FREG_159.xyzw * cw.zzzz + clw;
    clw = DL_FREG_160.xyzw * cw.wwww + clw;
    float4 clC = clw * swC;
    float4 rw = DL_FREG_144._m00_m10_m20_m30 * cw.yyyy;
    rw = DL_FREG_140._m00_m10_m20_m30 * cw.xxxx + rw;
    rw = DL_FREG_148._m00_m10_m20_m30 * cw.zzzz + rw;
    rw = DL_FREG_152._m00_m10_m20_m30 * cw.wwww + rw;
    float suC = dot(shPos, rw);
    float4 q1 = DL_FREG_144._m01_m11_m21_m31 * cw.yyyy;
    q1 = DL_FREG_140._m01_m11_m21_m31 * cw.xxxx + q1;
    q1 = DL_FREG_148._m01_m11_m21_m31 * cw.zzzz + q1;
    q1 = DL_FREG_152._m01_m11_m21_m31 * cw.wwww + q1;
    float svC = dot(shPos, q1);
    float4 q2 = DL_FREG_144._m02_m12_m22_m32 * cw.yyyy;
    q2 = DL_FREG_140._m02_m12_m22_m32 * cw.xxxx + q2;
    q2 = DL_FREG_148._m02_m12_m22_m32 * cw.zzzz + q2;
    q2 = DL_FREG_152._m02_m12_m22_m32 * cw.wwww + q2;
    float sdC = dot(shPos, q2);
#else
    float suC = dot(shPos, DL_FREG_140._m00_m10_m20_m30);
    float svC = dot(shPos, DL_FREG_140._m01_m11_m21_m31);
    float sdC = dot(shPos, DL_FREG_140._m02_m12_m22_m32);
    float swC = dot(shPos, DL_FREG_140._m03_m13_m23_m33);
    float4 clC = DL_FREG_157.xyzw * swC;
#endif
    float2 loM = (suC < clC.x && svC < clC.y) ? float2(1,1) : float2(0,0);
    float2 uva = -loM * swC + float2(suC, svC);
    float2 hiM = (clC.z < uva.x && clC.w < uva.y) ? float2(1,1) : float2(0,0);
    float2 uvb = hiM * swC + uva;
    float depthN = sdC / swC;
    const float3 DEC = float3(0.99609375f, 0.00389099121f, 1.51991844e-005f);
    float acc = 0;
    float4 a4; float4 cmp4;
    a4.x = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2(-0.000732421875f, -0.000732421875f)).xyz, DEC);
    a4.y = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2(-0.000244140625f, -0.000732421875f)).xyz, DEC);
    a4.z = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2( 0.000244140625f, -0.000732421875f)).xyz, DEC);
    a4.w = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2( 0.000732421875f, -0.000732421875f)).xyz, DEC);
    cmp4 = (a4 < depthN) ? float4(1,1,1,1) : float4(0,0,0,0);
    acc += dot(cmp4, float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));
    a4.x = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2(-0.000732421875f, -0.000244140625f)).xyz, DEC);
    a4.y = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2(-0.000244140625f, -0.000244140625f)).xyz, DEC);
    a4.z = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2( 0.000244140625f, -0.000244140625f)).xyz, DEC);
    a4.w = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2( 0.000732421875f, -0.000244140625f)).xyz, DEC);
    cmp4 = (a4 < depthN) ? float4(1,1,1,1) : float4(0,0,0,0);
    acc += dot(cmp4, float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));
    a4.x = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2(-0.000732421875f,  0.000244140625f)).xyz, DEC);
    a4.y = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2(-0.000244140625f,  0.000244140625f)).xyz, DEC);
    a4.z = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2( 0.000244140625f,  0.000244140625f)).xyz, DEC);
    a4.w = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2( 0.000732421875f,  0.000244140625f)).xyz, DEC);
    cmp4 = (a4 < depthN) ? float4(1,1,1,1) : float4(0,0,0,0);
    acc += dot(cmp4, float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));
    a4.x = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2(-0.000732421875f,  0.000732421875f)).xyz, DEC);
    a4.y = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2(-0.000244140625f,  0.000732421875f)).xyz, DEC);
    a4.z = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2( 0.000244140625f,  0.000732421875f)).xyz, DEC);
    a4.w = dot(gSMP_7.Sample(gSMP_7Sampler, uvb + float2( 0.000732421875f,  0.000732421875f)).xyz, DEC);
    cmp4 = (a4 < depthN) ? float4(1,1,1,1) : float4(0,0,0,0);
    acc += dot(cmp4, float4(0.0625f, 0.0625f, 0.0625f, 0.0625f));
    float ndlS = dot(DL_FREG_175.xyz, nCross);
    float biasS = DL_FREG_121.x + ndlS;
    biasS = saturate(DL_FREG_121.w * biasS);
    acc = biasS + acc;
    acc = min(1, acc);
    float dfadeL = length(v3.xyz);
    dfadeL = saturate(DL_FREG_121.z * (DL_FREG_121.y + -dfadeL));
    float3 stint = DL_FREG_122.xyz * dfadeL;
    float3 shTintGB = exp2(DL_FREG_186.zzz * log2(-stint * acc + float3(1, 1, 1)));
#else
    float3 shTintGB = float3(1, 1, 1);
#endif

    // ===== two/four static point lights =====
    float3 lit = shTintGB;
    float3 nd1 = 0, nd2 = 0, nd3 = 0, nd4 = 0;
    {
        float3 Ld = DL_FREG_112.xyz + -v1.xyz;
        float dist = sqrt(dot(Ld, Ld));
        float3 Ln = Ld / dist;
        nd1 = Ln;
        float att = DL_FREG_116.w + -dist;
        att = saturate(DL_FREG_112.w * att);
        float3 lc = DL_FREG_116.xyz * att;
        float ndl = max(0, dot(Ln, r1.xyz));
        lit = lc * ndl + lit;

        Ld = DL_FREG_113.xyz + -v1.xyz;
        dist = sqrt(dot(Ld, Ld));
        Ln = Ld / dist;
        nd2 = Ln;
        att = DL_FREG_117.w + -dist;
        att = saturate(DL_FREG_113.w * att);
        lc = DL_FREG_117.xyz * att;
        ndl = max(0, dot(Ln, r1.xyz));
        lit = lc * ndl + lit;

#if defined(WITH_GBUFFER_4LIGHTS)
        Ld = DL_FREG_114.xyz + -v1.xyz;
        dist = sqrt(dot(Ld, Ld));
        Ln = Ld / dist;
        nd3 = Ln;
        att = DL_FREG_118.w + -dist;
        att = saturate(DL_FREG_114.w * att);
        lc = DL_FREG_118.xyz * att;
        ndl = max(0, dot(Ln, r1.xyz));
        lit = lc * ndl + lit;

        Ld = DL_FREG_115.xyz + -v1.xyz;
        dist = sqrt(dot(Ld, Ld));
        Ln = Ld / dist;
        nd4 = Ln;
        att = DL_FREG_119.w + -dist;
        att = saturate(DL_FREG_115.w * att);
        lc = DL_FREG_119.xyz * att;
        ndl = max(0, dot(Ln, r1.xyz));
        lit = lc * ndl + lit;
#endif
    }

    // ===== water-color blend into scene base =====
    float3 blended = wcLin * lit + -r0.xyz;
    r0.xyz = wA * blended + r0.xyz;

    // ===== spec (DL_FREG_088/089, power 102.x) + per-light spec + env =====
    float sp1 = max(0, dot(reflDir, r2.xyz));
    sp1 = log2(sp1);
    sp1 = DL_FREG_102.x * sp1;
    sp1 = exp2(sp1);
    float3 specAcc = r3.xyz * sp1;
    float sp2 = dot(reflDir, DL_FREG_088.xyz);
    sp2 = max(0, -sp2);
    sp2 = log2(sp2);
    sp2 = DL_FREG_102.x * sp2;
    sp2 = exp2(sp2);
    specAcc = DL_FREG_089.xyz * sp2 + specAcc;
    float spR = dot(reflDir, nd1);
    spR = max(0, spR);
    spR = log2(spR);
    spR = DL_FREG_102.x * spR;
    spR = exp2(spR);
#ifdef WITH_GBUFFER_4LIGHTS
    float spL3 = max(0, dot(reflDir, nd3));
    spL3 = log2(spL3);
    spL3 = DL_FREG_102.x * spL3;
    spL3 = exp2(spL3);
    float spL4 = max(0, dot(reflDir, nd4));
    spL4 = log2(spL4);
    spL4 = DL_FREG_102.x * spL4;
    spL4 = exp2(spL4);
#endif

    float3 envG = log2(DL_FREG_132.xyz);
    envG = float3(2.20000005f, 2.20000005f, 2.20000005f) * envG;
    envG = exp2(envG);
#ifdef WATER_ENV
    float3 env = gSMP_12_CUBE.Sample(gSMP_12_CUBESampler, reflDir).xyz;
    float3 col = env * envG + specAcc;
#else
    float3 col = reflCol * envG + specAcc;
#endif
    float3 specTot = lit * spR + col;
#ifdef WITH_GBUFFER_4LIGHTS
    specTot = DL_FREG_118.xyz * spL3 + specTot;
    specTot = DL_FREG_119.xyz * spL4 + specTot;
#endif

    // ===== fade (DL_FREG_129/130/131) =====
    float fInv = 1 + -fr;
    float fadeK = DL_FREG_130 * fInv + fr;
    fadeK = DL_FREG_131 * fadeK;
    float3 colB = fadeK * specTot + r0.xyz;

    // ===== vertex tint + fog (DL_FREG_103) =====
    float3 tinted = v5.xyz * colB;
    float3 fogd = -colB * v5.xyz + DL_FREG_103.xyz;
    float fw = saturate(v2.w);
    fw = saturate(DL_FREG_103.w * fw);
    float3 outc = fw * fogd + tinted;

    // ===== gamma round trip #1 (conditional DL_FREG_195.x) =====
    float3 g1 = log2(abs(outc));
    g1 = float3(0.454545468f, 0.454545468f, 0.454545468f) * g1;
    g1 = exp2(g1);
    outc = (0.5f < DL_FREG_195.x) ? g1 : outc;

    // ===== sun/scatter block (DL_FREG_105-110) =====
    float hg = DL_FREG_107.z * -sunN + DL_FREG_107.y;
    float hn = sunN * sunN + 1;
    float rsq = rsqrt(hg);
    float inv = 1 / hg;
    float hgg = rsq * inv;
    hgg = DL_FREG_107.x * hgg;
    float3 betaD2 = DL_FREG_109.xyz * hgg;
    float3 beta = DL_FREG_108.xyz * hn + betaD2;
    float3 oneMinus = float3(1, 1, 1) + -scat;
    float3 terr = DL_FREG_105.xyz * scat;
    beta = oneMinus * beta;
    beta = DL_FREG_106.xyz * beta;
    beta = DL_FREG_105.www * beta;
    beta = DL_FREG_110.xyz * beta;
    beta = outc * terr + beta;
    beta = beta + -outc;
    outc = DL_FREG_110.www * beta + outc;

    // ===== gamma round trip #2 =====
    float3 g2 = log2(abs(outc));
    g2 = float3(2.20000005f, 2.20000005f, 2.20000005f) * g2;
    g2 = exp2(g2);
    outc = (0.5f < DL_FREG_195.x) ? g2 : outc;

    // ===== final fresnel-blend to base + fade (DL_FREG_128) =====
    outc = outc + -r0.xyz;
    float fade = min(DL_FREG_128.x, v5.w);
    fade = DL_FREG_128.y * fade;
    o0 = float4(fade * outc + r0.xyz, 1);

    Out.Color = o0;
    return Out;
}
