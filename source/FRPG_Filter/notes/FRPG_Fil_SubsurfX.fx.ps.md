# FRPG_Fil_SubsurfX — Pseudocode

Horizontal subsurface scattering blur: 10-tap screen-space SSS with mask and depth-aware rejection.

## Inputs
- `t0` = scene color (s0, `Load`)
- `t1` = depth buffer (s1, `Load`, `.x` = depth, `.y` = sample depth)
- `t2` = SSS mask (s2, `Load`, `.x` = sssMask, `.y` = sampleMask)
- `cb0[8]`  = CameraParam
- `cb0[12]` = ScreenSize

## Output
- `o0.xyz` = SSS-blurred color
- `o0.w` = 1

## Algorithm
```
coord = UV × ScreenSize
sssMask = Load(t2, coord).x
if (sssMask == 0) discard             // no SSS on this pixel

center   = Load(t0, coord).xyz
depth0   = Load(t1, coord).x
viewZ    = CameraParam.w / (depth0 × CameraParam.z + CameraParam.y)
invViewZ = 1 / viewZ
aspectW  = 1/ScreenSize.x × ScreenSize.y

stepX = invViewZ × sssMask × 0.06 × aspectW
step  = (stepX, 0)

// Center pixel weighted sum (R, G, B weights different)
acc = center × (0.560479, 0.669086, 0.784728)

// 10 symmetric taps (±2, ±1.28, ±0.72, ±0.32, ±0.08)
for i = 1..10:
    tapUV     = UV + step × tapOffset[i]
    tapCoord  = tapUV × ScreenSize
    sampleMask = Load(t2, tapCoord).y
    noSSS      = (sampleMask == 0)

    tapColor = Load(t0, tapCoord).xyz
    tapColor = noSSS ? center : tapColor       // fallback to center if no SSS

    tapDepth = Load(t1, tapCoord).y
    tapViewZ = CameraParam.w / (tapDepth × CameraParam.z + CameraParam.y)
    depthW   = saturate(sssMask × abs(viewZ − tapViewZ) × 36)
    tapColor = depthW × (center − tapColor) + tapColor  // blend toward center

    acc += weight[i] × tapColor

Output = (acc, 1)
```
