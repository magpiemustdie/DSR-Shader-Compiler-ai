# FRPG_Fil_DepthCopy_Fragment1 — Pseudocode

MSAA depth copy, sample 1: loads from `Texture2DMS<float>` at integer pixel coordinate.

## Inputs
- `t0` = `Texture2DMS<float>` depth (MSAA)

## Output
- `SV_Depth` = `LoadMS(t0, (uint2)SV_Position.xy, 1)`

## Algorithm
```
iCoord = (uint2)SV_Position.xy
Depth  = LoadMS(t0, iCoord, 1)
```
