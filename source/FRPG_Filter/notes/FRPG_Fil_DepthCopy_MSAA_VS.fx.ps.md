# FRPG_Fil_DepthCopy_MSAA_VS — Pseudocode

Vertex shader for DepthCopy_MSAA: generates 4 vertices (2×2 grid) from `SV_VertexID`, derives two UVs per vertex for MSAA depth sampling.

## Inputs
- `SV_VertexID` (0..3)
- `cb0[12].z` = 1 / ScreenSize.x

## Output
- `SV_Position` = screen-space position (clip space)
- `TEXCOORD0`:
  - `.xy` = UV pair 0
  - `.zw` = UV pair 1

## Algorithm
```
Pos.zw = (0, 1)

yBit = vertexID >> 1         // 0 or 1
xBit = vertexID & 1          // 0 or 1

// Position in [-1, 1]
Pos.x = xBit × 2 − 1
Pos.y = 1 − yBit × 2

// UV.x = UV.z = xBit (as float)
UV.x  = (float)xBit
UV.z  = (float)xBit

// UV.y = UV.w = yBit (as float)
UV.y  = (float)yBit
UV.w  = (float)yBit

// UV.z offset by -1/ScreenSize.x
UV.z  = UV.z − 1/ScreenSize.x
```
