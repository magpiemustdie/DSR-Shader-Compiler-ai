# FRPG_Fil_Quad — Pseudocode

Standard fullscreen quad vertex shader: generates position + UV from `SV_VertexID`.

## Inputs
- `SV_VertexID` (0..3)

## Output
- `SV_Position` = screen-space clip position
- `TEXCOORD0` = UV

## Algorithm
```
yBit = vertexID >> 1
xBit = vertexID & 1

UV  = (xBit, yBit)
Pos = (xBit×2−1, (1−yBit)×2−1, 0, 1)
```
