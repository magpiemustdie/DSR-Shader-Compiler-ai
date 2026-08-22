# FRPG_Fil_FxAA2_VS — Pseudocode

Vertex shader for FxAA2/FxAA2_High: generates 2×2 grid from `SV_VertexID`, produces clip-space positions and UV pair.

## Inputs
- `SV_VertexID` (0..3)
- `cb0[12].z` = 1/ScreenSize.x

## Output
- `SV_Position` = clip-space position
- `TEXCOORD1`:
  - `.x` = xBit (as float)
  - `.y` = yBit (as float)
  - `.z` = xBit + 1/ScreenSize.x
  - `.w` = yBit (as float)

## Algorithm
```
yBit = vertexID >> 1
xBit = vertexID & 1

Pos.xy = (xBit×2−1, (1−yBit)×2−1)
Pos.zw = (0, 1)

UV.x = xBit
UV.y = yBit
UV.z = xBit + 1/ScreenSize.x
UV.w = yBit
```
