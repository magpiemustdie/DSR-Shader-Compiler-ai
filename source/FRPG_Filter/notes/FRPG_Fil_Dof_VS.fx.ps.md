# FRPG_Fil_Dof_VS — Pseudocode

Vertex shader for DOF Gaussian blur: generates fullscreen quad with 4 pairs of horizontal UV offsets at ±1.5/3.5/5.5/7.5 pixels.

## Inputs
- `SV_VertexID` (0..3)
- `cb0[12].x` = screenWidth

## Output
- `SV_Position` = clip-space position
- `TEXCOORD1` = center UV (xy, zw=0)
- `TEXCOORD2` = UV ± 1.5/width (xy=left, zw=right)
- `TEXCOORD3` = UV ± 3.5/width
- `TEXCOORD4` = UV ± 5.5/width
- `TEXCOORD5` = UV ± 7.5/width

## Algorithm
```
uv.x = vertexID & 1
uv.y = vertexID >> 1
Pos  = (uv.x×2−1, uv.y×−2+1, 0, 1)
UV1  = (uv, 0, 0)

off = {1.5, 3.5, 5.5, 7.5} / screenWidth
UV2 = uv.xyxy + (−off[0], 0, +off[0], 0)
UV3 = uv.xyxy + (−off[1], 0, +off[1], 0)
UV4 = uv.xyxy + (−off[2], 0, +off[2], 0)
UV5 = uv.xyxy + (−off[3], 0, +off[3], 0)
```
