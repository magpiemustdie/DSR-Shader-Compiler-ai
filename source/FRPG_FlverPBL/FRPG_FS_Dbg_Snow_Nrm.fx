// Dbg Snow_Nrm — debug normal visualization for snow shader (1 variant)

struct SNOW_IN {
    float4 Pos      : SV_Position;
    float4 WorldPos : TEXCOORD0;
    float4 WorldNrm : TEXCOORD1;
    float4 VecEye   : TEXCOORD2;
    float4 WorldTan : TEXCOORD3;
    float4 Color    : COLOR0;
    float4 TexSnow  : TEXCOORD6;
    float4 TanFrame : TEXCOORD7;
    float4 ProjPos  : TEXCOORD8;
    float4 ProjW    : TEXCOORD9;
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

    float2 screenUV = In.Pos.xy * gFC_SAOParams.xy;
    float  snowCov  = In.Color.w * gFC_SnowParam.x;

    float hInv = 1.0 - g_tBumpMap.Sample(g_sBump, screenUV).x;
    float hWeight = snowCov * hInv;

    float3 N = normalize(In.WorldNrm.xyz);
    float3 T = normalize(In.WorldTan.xyz);
    float3 B = normalize(cross(N, T)) * In.WorldTan.w;
    T = normalize(cross(B, N));

    float3 V = normalize(In.VecEye.xyz);
    float3 dispDir = T * dot(T, V) + B * dot(B, V);

    float3 dispPos = hWeight * dispDir * gFC_SnowParam.w + In.WorldPos.xyz;

    float4 disp4 = float4(dispPos, 1);
    float clipX = dot(disp4, gFC_WorldViewClipMtx0);
    float clipY = dot(disp4, gFC_WorldViewClipMtx1);
    float clipW = dot(disp4, gFC_WorldViewClipMtx3);
    float2 clipUV = float2(clipX, clipY) / clipW;
    float4 parUV_off = float4(clipUV * 0.5 + 0.5, clipUV * 0.5 + 0.5);
    parUV_off -= In.Pos.xyxy * gFC_SAOParams.xyxy;

    float4 perspUV;
    perspUV.x = In.ProjPos.x / In.ProjW.x;
    perspUV.y = In.ProjPos.y / In.ProjW.x;
    perspUV.z = In.ProjPos.z / In.ProjW.y;
    perspUV.w = In.ProjPos.w / In.ProjW.y;
    perspUV = perspUV * float4(0.5, -0.5, 0.5, -0.5) + 0.5;

    float4 uvB = screenUV.xyxy * 2.0 - perspUV;
    float4 uvA = perspUV + parUV_off;
    uvB = uvB + parUV_off;

    float h_uvB_xy = g_tBumpMap.Sample(g_sBump, uvB.xy).x;
    float h_uvB_zw = g_tBumpMap.Sample(g_sBump, uvB.zw).x;
    float h_uvA_xy = g_tBumpMap.Sample(g_sBump, uvA.xy).x;
    float h_uvA_zw = g_tBumpMap.Sample(g_sBump, uvA.zw).x;

    float2 parUV;
    parUV.x = snowCov * h_uvA_xy - snowCov * h_uvB_xy;
    parUV.y = snowCov * h_uvA_zw - snowCov * h_uvB_zw;
    parUV = clamp(parUV, -gFC_SnowSpecParam.z, gFC_SnowSpecParam.z);

    float3 tf1;
    tf1.x = T.x * In.TanFrame.w;
    tf1.y = T.y * In.TanFrame.w + parUV.x;
    tf1.z = T.z * In.TanFrame.w;
    tf1 = normalize(tf1);

    float3 tf2 = float3(In.TanFrame.x, parUV.y + In.TanFrame.y, In.TanFrame.z);
    tf2 = normalize(tf2);

    float3 tf3;
    tf3.x = tf2.y * tf1.z - tf1.y * tf2.z;
    tf3.y = tf2.z * tf1.x - tf1.z * tf2.x;
    tf3.z = tf2.x * tf1.y - tf1.x * tf2.y;

    float2 snS = g_tBumpMap2.Sample(g_sBump2, In.TexSnow.xy).xy;
    float2 snNorm = (snS * 2.0 - 1.0) * gFC_SnowDetailParam.x;
    float3 snowN = tf1 * snNorm.y + tf2 * snNorm.x + tf3;
    snowN = normalize(snowN);

    snowN = snowN * 0.25 + 0.5;
    snowN *= gFC_ToneMap.xxx;
    return float4(saturate(snowN / gFC_ToneMap.yyy), 1);
}
