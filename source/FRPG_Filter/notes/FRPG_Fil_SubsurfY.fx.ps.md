# FRPG_Fil_SubsurfY — Pseudocode

Vertical subsurface scattering blur. Differs from SubsurfX: vertical step direction, no aspect-ratio correction.

## Inputs
Same as SubsurfX

## Output
Same as SubsurfX

## Algorithm
```
coord = UV × ScreenSize
sssMask = Load(t2, coord).x
if (sssMask == 0) discard

center   = Load(t0, coord).xyz
depth0   = Load(t1, coord).x
viewZ    = CameraParam.w / (depth0 × CameraParam.z + CameraParam.y)
invViewZ = 1 / viewZ

stepY = invViewZ × sssMask × 0.06
step  = (0, stepY)

// Rest identical to SubsurfX (same kernel, depth test, mask fallback)
// NOTE: no ScreenSize.y scaling in step — differs from SubsurfX which multiplies by aspect ratio
```
