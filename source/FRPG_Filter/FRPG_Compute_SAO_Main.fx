// FRPG_Compute_SAO_Main.fx
// Reconstructed from DSR DXBC cs_5_0 (Classic SSAO).
// t0=InputBuffer (Buffer<float4>: per-pixel (viewZ, depthHi*1/256, depthLo, 1), x used)
// u0=OutputTex (x,w = AO, y = depthHi*1/256, z = depthLo)
// cb0 Constants: screenSize.xy, projScale, radius, clipInfo, projInfo,
//                bias, intensity, axis(unused), offsets[6] (mip offsets)

Buffer<float> InputBuffer : register(t0);
RWTexture2D<float3> OutputTex : register(u0);

cbuffer Constants : register(b0)
{
    uint2  screenSize;
    float  projScale;
    float  radius;
    float4 clipInfo;
    float4 projInfo;
    float  bias;
    float  intensity;
    float2 axis;
    uint   offsets[6];
};

groupshared float3 g_Position[256][4];

[numthreads(256, 4, 1)]
void ComputeMain(
    uint3 groupThreadID : SV_GroupThreadID,
    uint3 groupID       : SV_GroupID)
{
    int2 vpos = (int2)(groupID.xy * uint2(256u, 4u)) + (int2)groupThreadID.xy;

    // Center pixel view-space position from InputBuffer
    int linearIdx = vpos.y * (int)screenSize.x + vpos.x;
    float3 centerPos;
    centerPos.z = InputBuffer[linearIdx];
    float2 uv = (float2(vpos) + 0.5f) * projInfo.xy + projInfo.zw;
    centerPos.xy = uv * centerPos.z;

    g_Position[groupThreadID.x][groupThreadID.y] = centerPos;

    GroupMemoryBarrierWithGroupSync();

    if (any((uint2)vpos >= screenSize)) return;

    // Right neighbor (x+1): from LDS, else from InputBuffer, else mirror last
    float3 delta1;
    if (groupThreadID.x < 255u)
    {
        delta1 = g_Position[groupThreadID.x + 1][groupThreadID.y] - centerPos;
    }
    else if ((uint)vpos.x < screenSize.x - 1u)
    {
        int2 np = vpos + int2(1, 0);
        float3 nPos;
        nPos.z = InputBuffer[np.y * (int)screenSize.x + np.x];
        float2 nuv = (float2(np) + 0.5f) * projInfo.xy + projInfo.zw;
        nPos.xy = nuv * nPos.z;
        delta1 = nPos - centerPos;
    }
    else
    {
        delta1 = centerPos - g_Position[254][groupThreadID.y];
    }

    // Up neighbor (y+1)
    float3 delta2;
    if (groupThreadID.y < 3u)
    {
        delta2 = g_Position[groupThreadID.x][groupThreadID.y + 1] - centerPos;
    }
    else if ((uint)vpos.y < screenSize.y - 1u)
    {
        int2 np = vpos + int2(0, 1);
        float3 nPos;
        nPos.z = InputBuffer[np.y * (int)screenSize.x + np.x];
        float2 nuv = (float2(np) + 0.5f) * projInfo.xy + projInfo.zw;
        nPos.xy = nuv * nPos.z;
        delta2 = nPos - centerPos;
    }
    else
    {
        delta2 = centerPos - g_Position[groupThreadID.x][2];
    }

    float3 normal = normalize(cross(delta2, delta1));

    // Pack viewZ into y/z output channels
    float depthNorm = saturate(centerPos.z * 0.00333333341f);
    float depthHi = floor(depthNorm * 256.0f);
    float depthHiFrac = depthHi * 0.00390625f;
    float depthLo = depthNorm * 256.0f - depthHi;

    // Random angle from pixel position
    uint randInt = (vpos.x * 3u) ^ ((vpos.x * vpos.y + vpos.y) & 0xFFFFu);
    randInt = randInt * 10u;
    float randAngle = (float)randInt;

    // Sample step and mip level
    float stepR = (projScale * radius) / centerPos.z;
    float mipLevel = log2(max(length(centerPos) * 0.5f, 10.0f)) * bias;

    // 11-tap AO
    float aoAcc = 0.0f;
    [loop]
    for (int i = 0; i < 11; i++)
    {
        float fi = (float)i + 0.5f;
        float step = stepR * fi * 0.0909090936f;
        float angle = fi * 3.99636364f + randAngle;

        float2 dir = float2(cos(angle), sin(angle));
        int2 sc = (int2)(dir * step) + vpos;

        bool inBounds = all(sc >= 0) && all(sc < (int2)screenSize);

        float sZ;
        if (inBounds)
        {
            int mip = (int)floor(log2(step)) - 3;
            mip = max(mip, 0);
            mip = min(mip, 5);
            uint2 msc = (uint2)sc >> mip;
            uint idx = msc.y * (screenSize.x >> mip) + offsets[mip] + msc.x;
            sZ = InputBuffer[idx];
        }
        else
        {
            sZ = clipInfo.y;
        }

        float2 sPix2D = (float2)sc + 0.5f;
        float3 sPos = float3(sZ * (sPix2D * projInfo.xy + projInfo.zw), sZ);

        float3 diff = sPos - centerPos;
        float r2 = dot(diff, diff);
        float vv = max(radius * radius - r2, 0.0f);
        float vv3 = vv * vv * vv;
        float vn = dot(diff, normal) - mipLevel * 0.301030f;
        float occTap = max(vn / (r2 + 0.01f), 0.0f);
        aoAcc += vv3 * occTap;
    }

    // Final occlusion: 1 - acc/radius^6 * intensity, scaled by 0.454545
    float rr = radius * radius;
    float occ = max(1.0f - aoAcc / ((rr * radius) * (rr * radius)) * intensity * 0.4545454680919647f, 0.0f);

    OutputTex[vpos] = float3(occ, depthHiFrac, depthLo);
}