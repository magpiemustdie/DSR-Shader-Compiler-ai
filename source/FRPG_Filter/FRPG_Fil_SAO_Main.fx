// FRPG_Fil_SAO_Main.fx
// Reconstructed from DSR DXBC.
// SAO (Scalable Ambient Obscurance) main pass.
// Samples 5 random directions, computes AO from view-space depth.
// t0=linearized depth (from SAO_Depth), loaded via Load + mip levels
// cb0[8]  = CameraParam (y:far)
// cb0[12] = ScreenSize
// cb0[72] = (radius, maxRadius, mipBias, intensity)
// cb0[73] = (projScale.xy, projOffset.xy)

#include "FRPG_Fil_Common.fxh"

float4 gFC_SAOParam  : register(c72); // x:radius, y:maxRadius, z:mipBias, w:intensity
float4 gFC_SAOProj   : register(c73); // xy:projScale, zw:projOffset

struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN In)
{
    FIL_OUT Out;

    int2  iCoord = int2((int)(In.UV.x * gFC_ScreenSize.x), (int)(In.UV.y * gFC_ScreenSize.y));
    float viewZ  = gSMP_0.Load(int3(iCoord, 0)).r;

    // Pack depth into yz channels early (ASM: before normal/AO)
    float  depthNorm = saturate(viewZ * 0.00333333341f);
    float  depthHi   = floor(depthNorm * 256.0f);
    Out.Color.y      = depthHi * 0.00390625f;
    Out.Color.z      = depthNorm * 256.0f - depthHi;

    // Reconstruct view-space position
    float2 pixCenter = trunc(In.UV * gFC_ScreenSize.xy) + 0.5f;
    float2 vsPos2D   = viewZ * (pixCenter * gFC_SAOProj.xy + gFC_SAOProj.zw);
    float3 vsPos     = float3(vsPos2D, viewZ);

    // Reconstruct view-space normal from depth derivatives
    float3 dPdx = ddx_coarse(vsPos);
    float3 dPdy = ddy_coarse(vsPos);
    float3 normal = normalize(cross(dPdy, dPdx));

    // mipOffset = log2(max(|vsPos| * 0.5, 10)) * mipBias
    float mipOffset = log2(max(length(vsPos) * 0.5f, 10.0f)) * gFC_SAOParam.z;

    // Random rotation angle (ASM: 16-bit truncation before xor, imul l(10))
    int   h   = (iCoord.x * iCoord.y + iCoord.y) & 0xFFFF;
    int   v   = iCoord.x * 3;
    float randAngle = (float)((h ^ v) * 10);

    // stepR base = (maxRadius * radius) / viewZ
    float stepRBase = (gFC_SAOParam.y * gFC_SAOParam.x) / viewZ;

    // Normalization divisor = maxRadius⁶
    float normDiv = gFC_SAOParam.y * gFC_SAOParam.y;
    normDiv = normDiv * gFC_SAOParam.y;
    normDiv = normDiv * normDiv;

    // 5-tap AO accumulation
    float aoAcc = 0.0f;
    int2  screenSize = (int2)gFC_ScreenSize.xy;

    [loop]
    for (int i = 0; i < 5; i++)
    {
        float fi     = (float)i + 0.5f;
        float stepR  = stepRBase * fi * 0.2f;
        float angle  = fi * 8.792f + randAngle;

        float2 dir   = float2(cos(angle), sin(angle));
        float2 sampleOffset = dir * stepR;
        int2   sc    = (int2)sampleOffset + iCoord;

        // Bounds check
        bool inBounds = all(sc >= 0) && all(sc < screenSize);

        float sViewZ;
        if (inBounds)
        {
            int mip = (int)floor(log2(stepR)) - 3;
            mip = max(mip, 0);
            mip = min(mip, 5);
            int2  mipCoord = sc >> mip;
            sViewZ = gSMP_0.Load(int3(mipCoord, mip)).r;
        }
        else
        {
            sViewZ = gFC_CameraParam.y; // far plane
        }

        // Sample view-space position
        float2 sPixCenter = (float2)sc + 0.5f;
        float2 sVsPos2D   = sViewZ * (sPixCenter * gFC_SAOProj.xy + gFC_SAOProj.zw);
        float3 sVsPos     = float3(sVsPos2D, sViewZ);

        // AO contribution
        float3 diff = sVsPos - vsPos;
        float  r2   = dot(diff, diff);
        float  vv   = max(gFC_SAOParam.y * gFC_SAOParam.y - r2, 0.0f);
        float  vv3  = vv * vv * vv;
        float  vn   = dot(diff, normal) - mipOffset * 0.301030f;
        float  ao   = max(vn / (r2 + 0.01f), 0.0f);
        aoAcc += vv3 * ao;
    }

    // Normalize
    float aoResult = aoAcc / normDiv;
    aoResult = max(1.0f - aoResult * gFC_SAOParam.w, 0.0f);

    // Sub-pixel correction (ASM: bit-test, recompute ddy after horiz correction)
    int2   subPixelInt = iCoord & 1;
    float2 subPixel    = float2(subPixelInt) - 0.5f;
    float  ddxViewZ    = ddx_coarse(viewZ);
    float  ddyViewZ    = ddy_coarse(viewZ);
    bool   nearHorizEdge = abs(ddxViewZ) < 0.02f;
    bool   nearVertEdge  = abs(ddyViewZ) < 0.02f;

    float ddxAO = ddx_coarse(aoResult);
    float corrX = -ddxAO * subPixel.x + aoResult;
    aoResult = nearHorizEdge ? corrX : aoResult;
    float ddyAO = ddy_coarse(aoResult);
    float corrY = -ddyAO * subPixel.y + aoResult;
    aoResult = nearVertEdge ? corrY : aoResult;

    Out.Color.x = aoResult;
    Out.Color.w = 1.0f;
    return Out;
}
