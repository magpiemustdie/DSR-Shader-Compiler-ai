// Dbg Snow_Nrm - debug normal visualization for snow shader.
// Reconstructed 1:1 from the 3DMigoto decompile of FRPG_Dbg_Snow_Nrm.fpo.
// Body is written in register-transcription style (r0..r4) so retail fxc
// schedules it the same way as the FromSoft original.

struct SNOW_IN {
    float4 Pos      : SV_Position;   // v0
    float4 WorldPos : TEXCOORD0;     // v1
    float4 WorldNrm : TEXCOORD1;     // v2
    float4 VecEye   : TEXCOORD2;     // v3
    float4 WorldTan : TEXCOORD3;     // v4
    float4 Color    : COLOR0;        // v5
    float4 TexSnow  : TEXCOORD6;     // v6
    float4 TanFrame : TEXCOORD7;     // v7
    float4 ProjPos  : TEXCOORD8;     // v8
    float4 ProjW    : TEXCOORD9;     // v9
};

cbuffer Globals : register(b0) {
    float4 gFC_ToneMap                : packoffset(c35);
    float4 gFC_WaterHeightMapSize     : packoffset(c62);
    float4 gFC_WorldViewClipMtx0      : packoffset(c63);
    float4 gFC_WorldViewClipMtx1      : packoffset(c64);
    float4 gFC_WorldViewClipMtx3      : packoffset(c66);
    float4 gFC_SnowParam              : packoffset(c67);
    float4 gFC_SnowDetailParam        : packoffset(c70);
    float4 gFC_SnowSpecParam          : packoffset(c71);
    float4 gFC_SAOParams              : packoffset(c90);
}

cbuffer AlphaTestBuffer : register(b1) {
    int   AlphaTest;
    float3 AlphaTestRef;
}

Texture2D g_tBumpMap    : register(t2);
SamplerState g_sBump    : register(s2);
Texture2D g_tBumpMap2   : register(t5);
SamplerState g_sBump2   : register(s5);

float4 FragmentMain(SNOW_IN In) : SV_Target0
{
    if (AlphaTest == 1 && AlphaTestRef.x >= 1.0) discard;

    float4 r0, r1, r2, r3, r4;

    // --- tile-jitter height block ---
    r0.z = 0;
    r1.xy = gFC_SAOParams.xy * In.Pos.xy;
    r1.zw = gFC_WaterHeightMapSize.xy * r1.xy;
    r1.zw = frac(r1.zw);
    r2.xy = ((float4(0.5, 0.5, 0, 0) < r1).xy) ? float2(1, 1) : float2(0, 0);
    r1.zw = r1.zw + float2(-0.5, -0.5);
    r2.xy = r2.xy * float2(2, 2) + float2(-1, -1);
    r0.xy = gFC_WaterHeightMapSize.zw * r2.xy;
    r1.zw = r2.xy * r1.zw;
    r2.xyzw = In.Pos.xyxy * gFC_SAOParams.xyxy + r0.xzzy;
    r0.xy = In.Pos.xy * gFC_SAOParams.xy + r0.xy;

    r0.xy = g_tBumpMap.Sample(g_sBump, r0.xy).xw;
    r0.zw = g_tBumpMap.Sample(g_sBump, r2.xy).xw;
    r2.xy = g_tBumpMap.Sample(g_sBump, r2.zw).xw;
    r3.xy = g_tBumpMap.Sample(g_sBump, r1.xy).wx;

    r2.z = r3.y - r0.z;
    r3.z = r2.y;
    r3.yw = r0.wy;
    float4 valid = (float4(0.00390625, 0.00390625, 0.00390625, 0.00390625) < r3.xyzw) ? 1 : 0;

    r0.y = valid.x * r2.z + r0.z;
    r0.y = r0.y - r2.x;
    r0.y = valid.x * r0.y + r2.x;
    r0.y = r0.y - r0.x;
    r0.y = valid.x * r0.y + r0.x;
    float2 d2 = float2(r0.x, r0.z) - r0.yy;
    r0.x = valid.w * d2.x + r0.y;
    r0.w = r2.x - r0.y;
    r0.w = valid.z * r0.w + r0.y;
    r0.x = r0.x - r0.w;
    r0.x = r1.z * r0.x + r0.w;
    r0.z = r0.z * valid.y;
    r0.y = r1.z * r0.z + r0.y;
    r0.x = r0.x - r0.y;
    r0.x = r1.w * r0.x + r0.y;

    r0.y = gFC_SnowParam.x * In.Color.w;
    r0.x = r0.x * r0.y;

    // --- tangent frame / parallax direction ---
    r2.xyz = In.WorldTan.yzx * In.WorldNrm.zxy;
    r2.xyz = In.WorldNrm.yzx * In.WorldTan.zxy - r2.xyz;
    r2.xyz = In.WorldTan.www * r2.xyz;
    r0.z = dot(r2.xyz, r2.xyz);
    r0.z = rsqrt(r0.z);
    r2.xyz = r2.xyz * r0.zzz;

    r0.z = dot(In.VecEye.xyz, In.VecEye.xyz);
    r0.z = sqrt(r0.z);
    r3.xyz = In.VecEye.xyz / r0.zzz;

    r0.z = dot(r2.xyz, r3.xyz);
    r2.xyz = r0.zzz * r2.xyz;

    r0.z = dot(In.WorldTan.xyz, In.WorldTan.xyz);
    r0.z = rsqrt(r0.z);
    r4.xyz = In.WorldTan.xyz * r0.zzz;

    r0.z = dot(r4.xyz, r3.xyz);
    r2.xyz = r0.zzz * r4.xyz + r2.xyz;

    r0.xzw = r2.xyz * r0.xxx;
    r2.xyz = r0.xzw * gFC_SnowParam.www + In.WorldPos.xyz;

    // --- reprojection ---
    r2.w = 1;
    r3.x = dot(r2.xyzw, gFC_WorldViewClipMtx0);
    r3.y = dot(r2.xyzw, gFC_WorldViewClipMtx1);
    r0.x = dot(r2.xyzw, gFC_WorldViewClipMtx3);
    r2.xyzw = r3.xyxy / r0.xxxx;
    r2.xyzw = r2.xyzw * float4(0.5, -0.5, 0.5, -0.5) + float4(0.5, 0.5, 0.5, 0.5);
    r2.xyzw = -(In.Pos.xyxy * gFC_SAOParams.xyxy) + r2.xyzw;

    r3.xyzw = In.ProjPos.xyzw / In.ProjW.xxyy;
    r3.xyzw = r3.xyzw * float4(0.5, -0.5, 0.5, -0.5) + float4(0.5, 0.5, 0.5, 0.5);

    r1.xyzw = r1.xyxy * float4(2, 2, 2, 2) + (-r3.xyzw);
    r3.xyzw = r3.xyzw + r2.xyzw;
    r1.xyzw = r1.xyzw + r2.xyzw;

    r2.z = g_tBumpMap.Sample(g_sBump, r1.xy).x;
    r2.w = g_tBumpMap.Sample(g_sBump, r1.zw).x;
    r0.xz = r2.zw * r0.yy;
    r2.x = g_tBumpMap.Sample(g_sBump, r3.xy).x;
    r2.y = g_tBumpMap.Sample(g_sBump, r3.zw).x;
    r0.xy = r2.xy * r0.yy + (-r0.xz);
    r0.xy = min(gFC_SnowSpecParam.zz, r0.xy);
    r0.xy = max(-gFC_SnowSpecParam.zz, r0.xy);

    // --- TanFrame normal blend ---
    r0.w = r4.y * In.TanFrame.w + r0.x;
    r1.y = In.TanFrame.y + r0.y;
    r0.xz = In.TanFrame.ww * r4.xz;
    r0.y = dot(r0.xzw, r0.xzw);
    r0.y = rsqrt(r0.y);
    r0.xyz = r0.xwz * r0.yyy;

    r1.xz = In.TanFrame.xz;
    r0.w = dot(r1.xyz, r1.xyz);
    r0.w = rsqrt(r0.w);
    r1.xyz = r1.xyz * r0.www;

    r2.xyz = r1.zxy * r0.yzx;
    r2.xyz = r1.yzx * r0.zxy - r2.xyz;

    r3.xy = g_tBumpMap2.Sample(g_sBump2, In.TexSnow.xy).xy;
    r3.xy = r3.xy * float2(2, 2) + float2(-1, -1);
    r3.xy = gFC_SnowDetailParam.xx * r3.xy;

    r0.xyz = r3.yyy * r0.xyz;
    r0.xyz = r1.xyz * r3.xxx + r0.xyz;
    r0.xyz = r2.xyz + r0.xyz;

    r0.w = dot(r0.xyz, r0.xyz);
    r0.w = rsqrt(r0.w);
    r0.xyz = r0.xyz * r0.www;

    r0.xyz = r0.xyz * float3(0.25, 0.25, 0.25) + float3(0.5, 0.5, 0.5);
    r0.xyz = gFC_ToneMap.xxx * r0.xyz;
    return float4(saturate(r0.xyz / gFC_ToneMap.yyy), 1);
}
