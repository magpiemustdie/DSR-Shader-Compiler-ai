// FRPG_Water_All.fx — Master entry point for all water shader variants
// Reconstructed from DSR Windows DXBC.
//
// ENV / REFLECT (forward family, incl. Ncs/Csd shadows and PntS) use the NEW
// reconstruction: FRPG_Water_Common_new.fxh + FRPG_Water_Forward_new.fx
// (standard forward FC layout, RDEF byte-equal — see AGENTS.md п.19).
// MASK / HEIGHTMAP / WWS still use the legacy path until ported.

#if defined(WATER_ENV)

#include "FRPG_Water_Common_new.fxh"
#include "FRPG_Water_Forward_new.fx"
WATER_OUT FragmentMain(WATER_IN_BASE In) { return FragmentMain_WaterBody(In); }

#elif defined(WATER_REFLECT)

#include "FRPG_Water_Common_new.fxh"
#include "FRPG_Water_Forward_new.fx"
WATER_OUT FragmentMain(WATER_IN_BASE In) { return FragmentMain_WaterBody(In); }

#elif defined(WATER_HEIGHTMAP)

#include "FRPG_Water_HeightMap.fx"
HM_OUT FragmentMain(HM_IN In) { return FragmentMain_WaterHeightMap(In); }

#else

#define FC_REG(x) register(x)
#include "FRPG_Water_Common.fxh"
#ifdef WITH_ShadowMap
#include "FRPG_Water_Shadow.fxh"
#endif

#ifdef WATER_MASK
    #include "FRPG_Water_Mask.fx"
    MASK_OUT FragmentMain(MASK_IN In) { return FragmentMain_WaterMask(In); }
#endif

#ifdef WATER_WAVE
    #include "FRPG_WWS_WaterWave.fx"
    WV_OUT FragmentMain(WATER_IN_BASE In) { return FragmentMain_WaterWave(In); }
#endif

#ifdef WATER_WAVE_MUL
    #include "FRPG_WWS_WaterWave.fx"
    WV_OUT FragmentMain(WATER_IN_BASE In) { return FragmentMain_WaterWaveMul(In); }
#endif

#endif
