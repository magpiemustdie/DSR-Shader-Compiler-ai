// FRPG_Water_All.fx — Master entry point for all water shader variants
// Reconstructed from DSR Windows DXBC

#define FC_REG(x) register(x)
#include "FRPG_Water_Common.fxh"
#ifdef WITH_ShadowMap
#include "FRPG_Water_Shadow.fxh"
#endif

// Select variant via preprocessor defines:
//   WATER_ENV       → FragmentMain_WaterEnv (t12 environment map)
//   WATER_REFLECT   → FragmentMain_WaterReflect (t0 screen-space reflection)
//   WATER_MASK      → FragmentMain_WaterMask (SV_Target1 = white)
//   WATER_HEIGHTMAP → FragmentMain_WaterHeightMap
//   WATER_WAVE      → FragmentMain_WaterWave (simple alpha mask)
//   WATER_WAVE_MUL  → FragmentMain_WaterWaveMul (multiply-blended alpha mask)

#ifdef WATER_ENV
    #include "FRPG_Water_Env.fx"
    WATER_OUT FragmentMain(WATER_IN_BASE In) { return FragmentMain_WaterEnv(In); }
#endif

#ifdef WATER_REFLECT
    #include "FRPG_Water_Reflect.fx"
    WATER_OUT FragmentMain(WATER_IN_BASE In) { return FragmentMain_WaterReflect(In); }
#endif

#ifdef WATER_MASK
    #include "FRPG_Water_Mask.fx"
    MASK_OUT FragmentMain(MASK_IN In) { return FragmentMain_WaterMask(In); }
#endif

#ifdef WATER_HEIGHTMAP
    #include "FRPG_Water_HeightMap.fx"
    HM_OUT FragmentMain(HM_IN In) { return FragmentMain_WaterHeightMap(In); }
#endif

#ifdef WATER_WAVE
    #include "FRPG_WWS_WaterWave.fx"
    WV_OUT FragmentMain(WV_IN In) { return FragmentMain_WaterWave(In); }
#endif

#ifdef WATER_WAVE_MUL
    #include "FRPG_WWS_WaterWave.fx"
    WV_OUT FragmentMain(WV_MUL_IN In) { return FragmentMain_WaterWaveMul(In); }
#endif
