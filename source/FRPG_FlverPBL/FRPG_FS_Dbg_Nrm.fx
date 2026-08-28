// Dbg Nrm — debug normal visualization (8 variants)

// Defines: WITH_BumpMap, WITH_MultiTexture, WITH_NrmErr

//-----------------------------------------------------------------------------
// Input struct — 3 flavors matching reference register layout
//-----------------------------------------------------------------------------
#if !defined(WITH_BumpMap)

struct PS_INPUT {
    float4 Pos   : SV_Position;
    float4 T0    : TEXCOORD0;
    float4 Nrm   : TEXCOORD2;
    float4 T3    : TEXCOORD3;
    float4 Col0  : COLOR0;
    float4 UV    : TEXCOORD6;
    uint   FFace : SV_IsFrontFace;
};

#elif !defined(WITH_MultiTexture)

struct PS_INPUT {
    float4 Pos   : SV_Position;
    float4 T0    : TEXCOORD0;
    float4 Nrm   : TEXCOORD2;
    float4 T3    : TEXCOORD3;
    float4 Tan   : TEXCOORD4;
    float4 T5    : TEXCOORD5;
    float4 Col0  : COLOR0;
    float4 UV    : TEXCOORD6;
    uint   FFace : SV_IsFrontFace;
};

#else

struct PS_INPUT {
    float4 Pos   : SV_Position;
    float4 T0    : TEXCOORD0;
    float4 Nrm   : TEXCOORD2;
    float4 T3    : TEXCOORD3;
    float4 Tan1  : TEXCOORD4;
    float4 Tan2  : TEXCOORD5;
    float4 T8    : TEXCOORD8;
    float4 T9    : TEXCOORD9;
    float4 Col0  : COLOR0;
    float4 UV    : TEXCOORD6;
    uint   FFace : SV_IsFrontFace;
};

#endif

//-----------------------------------------------------------------------------
// Constant buffers
//-----------------------------------------------------------------------------
cbuffer Globals : register(b0) {
    float4 gFC_ToneMap         : packoffset(c35);
    float4 gFC_DetailBumpParam : packoffset(c78);
}

#ifndef WITH_NrmErr
cbuffer AlphaTestBuffer : register(b1) {
    int   AlphaTest;
    float3 AlphaTestRef;
}
#endif

//-----------------------------------------------------------------------------
// Texture resources
//-----------------------------------------------------------------------------
Texture2D g_tDetailBumpTex : register(t15);
SamplerState g_sDetailBump : register(s15);
#if defined(WITH_BumpMap)
Texture2D g_tBumpTex0 : register(t2);
SamplerState g_sBump0 : register(s2);
#if defined(WITH_MultiTexture)
Texture2D g_tBumpTex1 : register(t5);
SamplerState g_sBump1 : register(s5);
#endif
#endif

//-----------------------------------------------------------------------------
// Helpers
//-----------------------------------------------------------------------------
float3 ProcessDetailBump(float2 uv)
{
    float2 d = g_tDetailBumpTex.Sample(g_sDetailBump, uv * gFC_DetailBumpParam.xx).rg;
    d = d * 2.0 - 1.0;
    float3 b;
    b.xy = d * gFC_DetailBumpParam.w;
    float z = sqrt(1.0 - saturate(dot(d, d)));
    float isZero = (dot(b.xy, b.xy) < 0.00001) ? 1.0 : 0.0;
    b.z = z + isZero;
    return normalize(b);
}

float3 SampleBump(float2 uv, Texture2D tex, SamplerState smp)
{
    float2 b = tex.Sample(smp, uv).rg * 2.0 - 1.0;
    return float3(b, sqrt(1.0 - saturate(dot(b, b))));
}

//-----------------------------------------------------------------------------
// NrmErr: visualize error (no vertex normal used)
//-----------------------------------------------------------------------------
#if defined(WITH_NrmErr)

#if defined(WITH_BumpMap)

#if defined(WITH_MultiTexture)
float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    float3 N1 = SampleBump(In.UV.xy, g_tBumpTex0, g_sBump0);
    float3 T1 = normalize(float3(In.Tan1.w * -1.0, 0, 0));
    N1 = normalize(float3(0, N1.y, 0) + T1 * N1.x + float3(0, 0, N1.z));

    float3 N2 = SampleBump(In.UV.zw, g_tBumpTex1, g_sBump1);
    float3 T2 = normalize(float3(In.Tan2.w * -1.0, 0, 0));
    N2 = normalize(float3(0, N2.y, 0) + T2 * N2.x + float3(0, 0, N2.z));

    float3 N = normalize(lerp(N1, N2, In.Col0.w));

    float3 Tx = normalize(float3(-N.z, 0, N.x));
    float3 B = cross(N, Tx) * In.Tan1.w;
    Tx = normalize(cross(B, N));

    float3 D = ProcessDetailBump(In.UV.xy);
    N = normalize(B * D.x + Tx * D.y + N * D.z);

    // ref error metric: (Nx+Ny, Ny, Nz); no early-out branch
    float3 e = float3(N.x + N.y, N.y, N.z);
    float nz = N.z * rsqrt(dot(e, e));
    return float4(nz * 0.5f, nz * 0.5f, nz * 0.5f, 0.5f);
}
#else
float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    float3 bump = SampleBump(In.UV.xy, g_tBumpTex0, g_sBump0);
    float3 T = normalize(float3(In.Tan.w * -1.0, 0, 0));
    float3 N = normalize(float3(0, bump.y, 0) + T * bump.x + float3(0, 0, bump.z));

    float3 Tx = normalize(float3(-N.z, 0, N.x));
    float3 B = cross(N, Tx) * In.Tan.w;
    Tx = normalize(cross(B, N));

    float3 D = ProcessDetailBump(In.UV.xy);
    N = normalize(B * D.x + Tx * D.y + N * D.z);

    // ref error metric: (Nx+Ny, Ny, Nz); no early-out branch
    float3 e = float3(N.x + N.y, N.y, N.z);
    float nz = N.z * rsqrt(dot(e, e));
    return float4(nz * 0.5f, nz * 0.5f, nz * 0.5f, 0.5f);
}
#endif

#else
float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    // ref: decompiled ASM-faithful (float4 r0/r1 with vector masks, see FRPG_Dbg_Dif________________NrmErr.hlsl)
    float4 r0, r1;
    r0.xy = gFC_DetailBumpParam.xx * In.UV.xy;
    r0.xy = g_tDetailBumpTex.Sample(g_sDetailBump, r0.xy).xy;
    r0.xy = r0.xy * float2(2,2) + float2(-1,-1);
    r0.z = dot(r0.xy, r0.xy);
    r1.xy = gFC_DetailBumpParam.ww * r0.xy;
    r0.x = min(1, r0.z);
    r0.x = 1 - r0.x;
    r0.x = sqrt(r0.x);
    r0.y = dot(r1.xy, r1.xy);
    r0.y = (r0.y < 9.99999975e-006) ? 1 : 0;
    r1.z = r0.x + r0.y;
    r0.x = dot(r1.xyz, r1.xyz);
    r0.x = rsqrt(r0.x);
    r0.xyz = r1.xyz * r0.xxx;
    r1.xyzw = float4(1,0,0,1) * r0.xxyy;
    r0.xyw = r1.xyy + r1.zwz;
    r0.xyz = r0.zzz * float3(0,0,1) + r0.xyw;
    r0.x = dot(r0.xyz, r0.xyz);
    r0.x = rsqrt(r0.x);
    r0.x = r0.z * r0.x;
    return float4(r0.xxx * 0.5, 0.5);
}
#endif

//-----------------------------------------------------------------------------
// Nrm: encode normal * 0.25 + 0.5
//-----------------------------------------------------------------------------
#else // !WITH_NrmErr

#if defined(WITH_BumpMap)

#if defined(WITH_MultiTexture)
float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    if (AlphaTest == 1 && AlphaTestRef.x >= 1.0) discard;

    float3 N = normalize(In.Nrm.xyz);
    // ref: tangent is normalized ONCE and reused directly in N1/N2 (no re-cross)
    float3 T1 = normalize(In.Tan1.xyz);
    float3 B1 = normalize(cross(N, T1)) * In.Tan1.w;

    float3 b0 = SampleBump(In.UV.xy, g_tBumpTex0, g_sBump0);
    float3 N1 = normalize(B1 * b0.x + T1 * b0.y + N * b0.z);

    float3 T2 = normalize(In.Tan2.xyz);
    float3 B2 = normalize(cross(N, T2)) * In.Tan2.w;

    float3 b1 = SampleBump(In.UV.zw, g_tBumpTex1, g_sBump1);
    float3 N2 = normalize(B2 * b1.x + T2 * b1.y + N * b1.z);

    N = normalize(lerp(N1, N2, In.Col0.w));

    float3 B = normalize(cross(N, T1)) * In.Tan1.w;
    T1 = normalize(cross(B, N));

    float3 D = ProcessDetailBump(In.UV.xy);
    N = normalize(B * D.x + T1 * D.y + N * D.z);

    N = N * 0.25 + 0.5;
    N *= gFC_ToneMap.x;
    return float4(saturate(N / gFC_ToneMap.y), 1);
}
#else
float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    if (AlphaTest == 1 && AlphaTestRef.x >= 1.0) discard;

    float3 N = normalize(In.Nrm.xyz);
    // ref: bump is applied with the ORIGINAL normalized tangent (no re-cross)
    float3 T = normalize(In.Tan.xyz);
    float3 B = normalize(cross(N, T)) * In.Tan.w;

    float3 bump = SampleBump(In.UV.xy, g_tBumpTex0, g_sBump0);
    N = normalize(B * bump.x + T * bump.y + N * bump.z);

    B = normalize(cross(N, T)) * In.Tan.w;
    T = normalize(cross(B, N));

    float3 D = ProcessDetailBump(In.UV.xy);
    N = normalize(B * D.x + T * D.y + N * D.z);

    N = N * 0.25 + 0.5;
    N *= gFC_ToneMap.x;
    return float4(saturate(N / gFC_ToneMap.y), 1);
}
#endif

#else
float4 FragmentMain(PS_INPUT In) : SV_Target0
{
    if (AlphaTest == 1 && AlphaTestRef.x >= 1.0) discard;

    float3 D = ProcessDetailBump(In.UV.xy);
    float3 N = normalize(In.Nrm.xyz);

    float3 t = D.y * N.xzy;
    float3 nt;
    nt.x = N.z * D.x + t.x;
    nt.y = N.y * D.x + t.y;
    nt.z = N.z * D.x + t.z;
    N = N * D.z + nt;
    N = normalize(N);

    N = N * 0.25 + 0.5;
    N *= gFC_ToneMap.x;
    return float4(saturate(N / gFC_ToneMap.y), 1);
}
#endif

#endif
