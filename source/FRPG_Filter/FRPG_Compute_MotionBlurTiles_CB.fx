// FRPG_Compute_MotionBlurTiles_CB.fx
// Checkerboard variant — direct register-level translation of cpo.asm.
// Identical algorithm to MotionBlurTiles; same register layout.

cbuffer Constants : register(b0)
{
    float4 cb0[11];
}

Texture2D<float4> t0 : register(t0);
Texture2D<float4> t1 : register(t1);
RWTexture2D<float4> u0 : register(u0);

groupshared float2 g0[256];

[numthreads(16, 16, 1)]
void ComputeMain(
    uint3 vThreadGroupID   : SV_GroupID,
    uint3 vThreadIDInGroup : SV_GroupThreadID,
    uint3 vThreadID        : SV_DispatchThreadID)
{
    // ishl r0.xy, vThreadID.xyxx, l(2,2,0,0)
    // mov r0.zw, l(0,0,0,0)
    uint2 r0xy = vThreadID.xy << 2u;

    // ld t1.yzxw r1.z, r0.xyww
    float r1z = t1.Load(int3(r0xy, 0)).x;

    // utof r2.xy, r0.xyxx
    float2 r2xy = float2(r0xy);

    // mul r2.zw, r2.xxxy, cb0[9].zzzw; mad r2.zw, r2.zzzw, l(0,0,2,2), l(0,0,-1,-1)
    float2 r2zw = r2xy * cb0[9].zw * 2.0f - 1.0f;

    // mul r1.xy, r2.zwzz, l(1,-1,0,0); mov r1.w, l(1)
    float4 r1 = float4(r2zw.x, -r2zw.y, r1z, 1.0f);

    float3 r3;
    r3.x = dot(r1, cb0[0]); r3.y = dot(r1, cb0[1]); r3.z = dot(r1, cb0[2]);
    r1.x = dot(r1, cb0[3]);
    r1.xyz = r3.xyz / r1.x + cb0[8].xyz;
    r1.w = 1.0f;
    r3.x = dot(r1, cb0[4]); r3.y = dot(r1, cb0[5]);
    r1.x = dot(r1, cb0[7]);
    r1.xy = r3.xy / r1.x * float2(0.5f, -0.5f) + 0.5f;

    float2 vel0 = t0.Load(int3(r0xy, 0)).xy;
    bool ov0 = (vel0.x < 1.0f);
    vel0 *= float2(1.0f, -1.0f);
    float2 mv0 = ov0 ? vel0 : (r2xy * cb0[9].zw - r1.xy);
    mv0 *= saturate(rsqrt(dot(mv0, mv0)) * cb0[10].z);

    // imad r1.xyzw, vThreadID.xyxy, l(4,4,4,4), l(0,2,2,0)
    uint4 r1i = vThreadID.xyxy * 4u + uint4(0u, 2u, 2u, 0u);

    // --- Pixel 1: r1.zw = (base.x+2, base.y) ---
    float r3z = t1.Load(int3(r1i.zw, 0)).x;
    float4 r4f = float4(float2(r1i.zw), float2(r1i.xy));
    float4 r5f = r4f * cb0[9].zwzw * 2.0f - 1.0f;
    float4 r3f = float4(r5f.x, -r5f.y, r3z, 1.0f);
    float3 r6;
    r6.x = dot(r3f, cb0[0]); r6.y = dot(r3f, cb0[1]); r6.z = dot(r3f, cb0[2]);
    float r0z = dot(r3f, cb0[3]);
    r3f.xyz = r6.xyz / r0z + cb0[8].xyz;
    r3f.w = 1.0f;
    r5f.x = dot(r3f, cb0[4]); r5f.y = dot(r3f, cb0[5]);
    r0z = dot(r3f, cb0[7]);
    float2 r0zw = r5f.xy / r0z * float2(0.5f, -0.5f) + 0.5f;
    float2 vel1 = t0.Load(int3(r1i.zw, 0)).xy;
    bool ov1 = (vel1.x < 1.0f);
    vel1 *= float2(1.0f, -1.0f);
    float2 mv1 = ov1 ? vel1 : (float2(r4f.xy) * cb0[9].zw - r0zw);
    mv1 *= saturate(rsqrt(dot(mv1, mv1)) * cb0[10].z);
    mv0 *= cb0[10].xy;
    mv1 *= cb0[10].xy;
    float2 best01 = (dot(mv1, mv1) > dot(mv0, mv0)) ? mv1 : mv0;

    // --- Pixel 2: r1.xy = (base.x, base.y+2) ---
    float r2z = t1.Load(int3(r1i.xy, 0)).x;
    float4 r2f = float4(r5f.z, -r5f.w, r2z, 1.0f);
    r3f.x = dot(r2f, cb0[0]); r3f.y = dot(r2f, cb0[1]); r3f.z = dot(r2f, cb0[2]);
    r0z = dot(r2f, cb0[3]);
    r2f.xyz = r3f.xyz / r0z + cb0[8].xyz;
    r2f.w = 1.0f;
    r3f.x = dot(r2f, cb0[4]); r3f.y = dot(r2f, cb0[5]);
    r0z = dot(r2f, cb0[7]);
    r0zw = r3f.xy / r0z * float2(0.5f, -0.5f) + 0.5f;
    float2 vel2 = t0.Load(int3(r1i.xy, 0)).xy;
    bool ov2 = (vel2.x < 1.0f);
    vel2 *= float2(1.0f, -1.0f);
    float2 mv2 = ov2 ? vel2 : (float2(r4f.zw) * cb0[9].zw - r0zw);
    mv2 *= saturate(rsqrt(dot(mv2, mv2)) * cb0[10].z);
    mv2 *= cb0[10].xy;
    float2 best012 = (dot(mv2, mv2) > dot(best01, best01)) ? mv2 : best01;

    // --- Pixel 3: imad r1.xy, threadID.xy, 4, (2,2) ---
    uint2 p3 = uint2(r0xy.x + 2u, r0xy.y + 2u);
    float d3 = t1.Load(int3(p3, 0)).x;
    float2 f3 = float2(p3);
    float2 ndc3 = f3 * cb0[9].zw * 2.0f - 1.0f;
    r2f = float4(ndc3.x, -ndc3.y, d3, 1.0f);
    r3f.x = dot(r2f, cb0[0]); r3f.y = dot(r2f, cb0[1]); r3f.z = dot(r2f, cb0[2]);
    r2f.x = dot(r2f, cb0[3]);
    r2f.xyz = r3f.xyz / r2f.x + cb0[8].xyz;
    r2f.w = 1.0f;
    r3f.x = dot(r2f, cb0[4]); r3f.y = dot(r2f, cb0[5]);
    r2f.x = dot(r2f, cb0[7]);
    float2 prevUV3 = r3f.xy / r2f.x * float2(0.5f, -0.5f) + 0.5f;
    float2 vel3 = t0.Load(int3(p3, 0)).xy;
    bool ov3 = (vel3.x < 1.0f);
    vel3 *= float2(1.0f, -1.0f);
    float2 mv3 = ov3 ? vel3 : (f3 * cb0[9].zw - prevUV3);
    mv3 *= saturate(rsqrt(dot(mv3, mv3)) * cb0[10].z);
    mv3 *= cb0[10].xy;
    float2 best = (dot(mv3, mv3) > dot(best012, best012)) ? mv3 : best012;

    // --- Store to LDS ---
    uint ldsZ = vThreadIDInGroup.y << 4u;
    uint ldsW = ldsZ + vThreadIDInGroup.x;
    g0[ldsW] = best;
    GroupMemoryBarrierWithGroupSync();

    // --- Reduction 1: if (x & 3 == 0) ---
    uint andX = vThreadIDInGroup.x & 3u;
    uint andY = vThreadIDInGroup.y & 3u;
    bool ieqX = (andX == 0u);
    bool ieqY = (andY == 0u);
    if (andX == 0u)
    {
        float2 a = g0[ldsW];
        float2 b = g0[ldsW + 1u];
        float2 c = g0[ldsW + 2u];
        float2 d = g0[ldsW + 3u];
        if (dot(b, b) > dot(a, a)) a = b;
        if (dot(c, c) > dot(a, a)) a = c;
        if (dot(d, d) > dot(a, a)) a = d;
        g0[ldsW] = a;
    }
    GroupMemoryBarrierWithGroupSync();

    // --- Reduction 2: if (x&3==0 && y&3==0) ---
    if (ieqX && ieqY)
    {
        float2 best2 = g0[ldsW];
        float2 v1r = g0[ldsZ + 16u + vThreadIDInGroup.x];
        float2 v2r = g0[ldsZ + 32u + vThreadIDInGroup.x];
        float2 v3r = g0[ldsZ + 48u + vThreadIDInGroup.x];
        if (dot(v1r, v1r) > dot(best2, best2)) best2 = v1r;
        if (dot(v2r, v2r) > dot(best2, best2)) best2 = v2r;
        if (dot(v3r, v3r) > dot(best2, best2)) best2 = v3r;
        g0[ldsW] = best2;
    }
    GroupMemoryBarrierWithGroupSync();

    // --- Reduction 3: if (x == 0) ---
    bool xExact0 = (vThreadIDInGroup.x == 0u);
    bool yExact0 = (vThreadIDInGroup.y == 0u);
    if (xExact0)
    {
        float2 best3 = g0[ldsZ];
        float2 w1 = g0[ldsZ + 4u];
        float2 w2 = g0[ldsZ + 8u];
        float2 w3 = g0[ldsZ + 12u];
        if (dot(w1, w1) > dot(best3, best3)) best3 = w1;
        if (dot(w2, w2) > dot(best3, best3)) best3 = w2;
        if (dot(w3, w3) > dot(best3, best3)) best3 = w3;
        g0[ldsZ] = best3;
    }
    GroupMemoryBarrierWithGroupSync();

    // --- Final: if (x==0 && y==0) ---
    if (xExact0 && yExact0)
    {
        float2 final = g0[0];
        float2 f1r   = g0[64];
        float2 f2r   = g0[128];
        float2 f3r   = g0[192];
        if (dot(f1r, f1r) > dot(final, final)) final = f1r;
        if (dot(f2r, f2r) > dot(final, final)) final = f2r;
        if (dot(f3r, f3r) > dot(final, final)) final = f3r;
        u0[vThreadGroupID.xy] = float4(final, 0, 0);
    }
}
