# FRPG_Fil_HDR_VS — Pseudocode

Vertex shader for HDR/HDR_ColAdj/HDR_PBL/HDR_PBL_ColAdj family. Generates 2×2 grid, computes noise UV transform.

## Inputs
- `SV_VertexID` (0..3)
- `cb0[68]` = NoiseParam (`.xy` = scale, `.zw` = offset)

## Output
- `SV_Position` = clip space
- `TEXCOORD1`:
  - `.xy` = UV (pixel coordinate as float)
  - `.zw` = noise UV = UV × noiseScale + noiseOffset

## Algorithm
```
yBit = vertexID >> 1
xBit = vertexID & 1

Pos.xy = (xBit×2−1, (1−yBit)×2−1)
Pos.zw = (0, 1)

UV.x = xBit
UV.y = yBit
UV.z = xBit × NoiseParam.x + NoiseParam.z
UV.w = yBit × NoiseParam.y + NoiseParam.w
```
