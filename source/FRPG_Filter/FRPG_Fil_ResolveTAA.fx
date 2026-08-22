#include "FRPG_Fil_Common.fxh"
Texture2D    gSMP_2        : register(t2); SamplerState gSMP_2Sampler : register(s2);
Texture2D    gSMP_3        : register(t3); SamplerState gSMP_3Sampler : register(s3);
Texture2D    gSMP_4        : register(t4); SamplerState gSMP_4Sampler : register(s4);
float4 gFC_MotionScale : register(c56);
float4 gFC_MotionParam : register(c57);
float4 gFC_InvVP0      : register(c58);
float4 gFC_InvVP1      : register(c59);
float4 gFC_InvVP2      : register(c60);
float4 gFC_InvVP3      : register(c61);
float4 gFC_PrevVP0     : register(c74);
float4 gFC_PrevVP1     : register(c75);
float4 gFC_PrevVP3     : register(c77);
float4 gFC_CamOffset   : register(c78);

static const float3 gLum = float3(0.212599993f, 0.715200007f, 0.0722000003f);
float3 Tonemap(float3 c) { return c / (dot(c, gLum) + 1); }

struct FIL_OUT_TAA { float4 o0 : SV_Target0; float2 o1 : SV_Target1; };

FIL_OUT_TAA FragmentMain(FIL_IN In) {
    FIL_OUT_TAA Out;
    float2 uv = In.UV;

    // === 1. Find closest depth via Gather (reference movc chain, gather4 .xywz) ===
    int2 pix = (int2)(uv * gFC_ScreenSize.xy);
    float4 g = gSMP_2.Gather(gSMP_2Sampler, uv).xywz;
    float3 r1 = (g.y < g.x) ? float3(1.0f, 1.0f, g.y) : float3(-1.0f, 1.0f, g.x);
    float3 r0 = (g.w < r1.z) ? float3(1.0f, -1.0f, g.w) : r1;
    r0 = (g.z < r0.z) ? float3(-1.0f, -1.0f, g.z) : r0;

    float2 minUV = uv + r0.xy * gFC_ScreenSize.zw;
    float linZ = r0.z * gFC_CameraParam.z + gFC_CameraParam.y;
    float exposure = gFC_CameraParam.w / linZ;

    // === 2. Reproject closest depth to prev frame ===
    float2 ndc = minUV * 2 - 1;
    float4 pos = float4(ndc.x, -ndc.y, r0.z, 1);
    float4 worldPos;
    worldPos.x = dot(pos, gFC_InvVP0);
    worldPos.y = dot(pos, gFC_InvVP1);
    worldPos.z = dot(pos, gFC_InvVP2);
    float w = dot(pos, gFC_InvVP3);
    worldPos.xyz = worldPos.xyz / w + gFC_CamOffset.xyz;
    worldPos.w = 1;
    float2 pc = float2(dot(worldPos, gFC_PrevVP0), dot(worldPos, gFC_PrevVP1));
    float pw = dot(worldPos, gFC_PrevVP3);
    float2 prevUV = pc / pw;
    prevUV = prevUV * float2(0.5f, -0.5f) + 0.5f;
    float2 mvCam = minUV - prevUV;

    // === 3. Object motion ===
    float4 mvRaw = gSMP_3.SampleLevel(gSMP_3Sampler, minUV, 0);
    float2 mvObj = mvRaw.xy * float2(1, -1);
    float mvValid = mvRaw.x < 1;
    float2 mv = mvValid ? mvObj : mvCam;

    // === 4. Velocity weight ===
    float2 mvPix = mv * gFC_ScreenSize.xy;
    float vel = min(sqrt(dot(mvPix, mvPix)), 1);
    float velW = gFC_MotionScale.x * vel + 1;

    // === 5. Load neighbor pixels ===
    float3 tN = Tonemap(gSMP_0.Load(int3(pix.x,     pix.y - 1, 0)).xyz);
    float vN = gSMP_3.Load(int3(pix.x,     pix.y - 1, 0)).x;
    float3 tC = Tonemap(gSMP_0.Load(int3(pix.x,     pix.y,     0)).xyz);
    float vC = gSMP_3.Load(int3(pix.x,     pix.y,     0)).x;
    float3 tS = Tonemap(gSMP_0.Load(int3(pix.x,     pix.y + 1, 0)).xyz);
    float vS = gSMP_3.Load(int3(pix.x,     pix.y + 1, 0)).x;
    float3 tW = Tonemap(gSMP_0.Load(int3(pix.x - 1, pix.y,     0)).xyz);
    float vW = gSMP_3.Load(int3(pix.x - 1, pix.y,     0)).x;
    float3 tE = Tonemap(gSMP_0.Load(int3(pix.x + 1, pix.y,     0)).xyz);
    float vE = gSMP_3.Load(int3(pix.x + 1, pix.y,     0)).x;

    float3 crossMin = min(min(min(min(tN, tC), tS), tW), tE);
    float3 crossMax = max(max(max(max(tN, tC), tS), tW), tE);

    float3 tNW = Tonemap(gSMP_0.Load(int3(pix.x - 1, pix.y - 1, 0)).xyz); // deviation: vanilla reads alpha (A,R,G) -> red ghosting
    float vNW = gSMP_3.Load(int3(pix.x - 1, pix.y - 1, 0)).x;
    float3 tNE = Tonemap(gSMP_0.Load(int3(pix.x + 1, pix.y - 1, 0)).xyz);
    float vNE = gSMP_3.Load(int3(pix.x + 1, pix.y - 1, 0)).x;
    float3 tSW = Tonemap(gSMP_0.Load(int3(pix.x - 1, pix.y + 1, 0)).xyz);
    float vSW = gSMP_3.Load(int3(pix.x - 1, pix.y + 1, 0)).x;
    float3 tSE = Tonemap(gSMP_0.Load(int3(pix.x + 1, pix.y + 1, 0)).xyz);
    float vSE = gSMP_3.Load(int3(pix.x + 1, pix.y + 1, 0)).x;

    float3 diagMin = min(min(min(tNW, tNE), tSW), tSE);
    float3 diagMax = max(max(max(tNW, tNE), tSW), tSE);

    // === 6. Motion consistency ===
    float crossDiff = ((vN < 1) != (vC < 1)) | ((vS < 1) != (vC < 1)) |
                      ((vW < 1) != (vC < 1)) | ((vE < 1) != (vC < 1));
    float diagDiff = ((vNW < 1) != (vC < 1)) | ((vNE < 1) != (vC < 1)) |
                     ((vSW < 1) != (vC < 1)) | ((vSE < 1) != (vC < 1));
    float motionConsistent = !(crossDiff || diagDiff);

    // === 7. AABB (matches decompiled original) ===
    float3 upper = max(crossMax, diagMax);
    float3 lower = min(crossMin, diagMin);
    float3 mid = (crossMax + upper) * 0.5f;
    float3 lower2 = (crossMin + lower) * 0.5f;

    // === 8. History sample (ref reads .xyz only, no w-clamp) ===
    float2 histUV = uv - mv;
    float3 hist = gSMP_1.SampleLevel(gSMP_1Sampler, histUV, 0).xyz;
    float3 histTM = Tonemap(hist);

    // === 9. Per-channel blend result ===
    float3 delta = mid - histTM;
    float3 range = mid - lower2;
    float3 blendPerChannel = saturate(delta / range);
    float3 blendResult = lerp(mid, lower2, blendPerChannel);

    // === 10. Blend factor ===
    float midLum = dot(mid, gLum);
    float lowerLum = dot(lower2, gLum);
    float blendLum = dot(blendResult, gLum);
    float nearDist = min(abs(blendLum - lowerLum), abs(blendLum - midLum));
    float blendX = 0.125f * velW * nearDist;
    float blendFactor = blendX / (blendX + midLum - lowerLum);

    // === 11. Flicker + OOB ===
    float t4g = gSMP_4.SampleLevel(gSMP_4Sampler, histUV, 0).g;
    float flicker = (!(vC < 1) && t4g < 0 && motionConsistent) ? 1.0f : 0.0f;
    float oob = (histUV.x < 0 || histUV.y < 0 || histUV.x > 1 || histUV.y > 1) ? 1.0f : 0.0f;
    Out.o1.y = (vC < 1) ? -exposure : exposure;
    blendFactor = saturate(blendFactor + flicker + oob);

    // === 12. Final blend + inverse tonemap ===
    float3 current = gSMP_0.Load(int3(pix, 0)).xyz;
    float3 currentTM = Tonemap(current);
    float3 resolved = lerp(blendResult, currentTM, blendFactor);
    float lumR = min(dot(resolved, gLum), 0.999899983f);
    resolved /= (1 - lumR);
    Out.o0.xyz = max(resolved, 0.0f);
    Out.o0.w = 1.0f;

    // === 13. Output velocity ===
    float mvLen2 = dot(mv, mv);
    float mvScale = saturate(rsqrt(mvLen2) * gFC_MotionParam.z);
    mv = mv * mvScale * gFC_MotionParam.xy;
    Out.o1.x = 1.0f / sqrt(dot(mv, mv));

    return Out;
}
