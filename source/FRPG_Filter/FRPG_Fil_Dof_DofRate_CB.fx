// FRPG_Fil_Dof_DofRate_CB.fx
// Reconstructed from DSR DXBC ps_5_0.
// DOF rate checkerboard: computes DOF rate from half-res depth + vignette.
// Outputs scalar DOF rate to all 4 channels.
// t1=depth buffer (half-res, loaded via Load at half pixel coord)
// cb0[7]  = AimBloomParam (x:vignette start[pix], y:1/(end-start), z:strength)
// cb0[8]  = CameraParam (x:near*far, y:far, z:unused, w:near*far)
// cb0[9]  = DofFarParam (x:start, y:end, z:scale)
// cb0[12] = ScreenSize
// cb0[81].y = checkerboard frame offset
//
// Original DXBC linearization:
//   add r0.y, -cb0[8].y, cb0[8].x
//   mad r0.x, r0.x, r0.y, cb0[8].y
//   div r0.x, cb0[8].x, r0.x

#include "FRPG_Fil_Common.fxh"

Texture2DMS<float> gSMP_Depth1MS : register(t1);

uint4 gFC_CBParam_uint : register(c81); // y:checkerboard frame offset (uint)

struct FIL_IN_POS { float4 Pos : SV_Position; float2 UV : TEXCOORD0; };
struct FIL_OUT { float4 Color : SV_Target0; };

FIL_OUT FragmentMain(FIL_IN_POS In)
{
    FIL_OUT Out;

    uint2 pixCoord = (uint2)In.Pos.xy;
    uint  sampleIdx = (pixCoord.x + pixCoord.y + gFC_CBParam_uint.y) & 1u;
    uint  halfX = pixCoord.x >> 1u;
    float depth = gSMP_Depth1MS.Load(uint2(halfX, pixCoord.y), sampleIdx).r;

    // Linearize depth — exact DXBC:
    //   add r0.y, -cb0[8].y, cb0[8].x
    //   mad r0.x, r0.x, r0.y, cb0[8].y
    //   div r0.x, cb0[8].x, r0.x
    float r0y = gFC_CameraParam.x - gFC_CameraParam.y;
    float viewZ = gFC_CameraParam.x / (depth * r0y + gFC_CameraParam.y);

    float dofStartN = gFC_DofFarParam.x / gFC_CameraParam.y;
    float dofEndN   = gFC_DofFarParam.y / gFC_CameraParam.y;
    float dofFar    = saturate((viewZ - dofStartN) / (dofEndN - dofStartN));
    dofFar = saturate(dofFar * gFC_DofFarParam.z);

    float2 vigUV = (In.UV - 0.5f) * gFC_ScreenSize.xy;
    float  vigDist = sqrt(dot(vigUV, vigUV));
    float  vignette = saturate((vigDist - gFC_AimBloomParam.x) * gFC_AimBloomParam.y);

    Out.Color = vignette * gFC_AimBloomParam.z + dofFar;
    return Out;
}
