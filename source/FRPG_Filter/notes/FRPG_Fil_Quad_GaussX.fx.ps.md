# FRPG_Fil_Quad_GaussX — Pseudocode

Vertex shader for DOF horizontal Gauss blur: generates 4 pairs of horizontal UV offsets.

## Inputs
- `SV_VertexID` (0..3)
- `cb0[12].x` = screen width

## Output
- `TEXCOORD1` = center UV
- `TEXCOORD2..5` = UV pairs at ±1.5, ±3.5, ±5.5, ±7.5 pixels (horizontal)

## Algorithm
```
uv = (xBit, yBit)  // from SV_VertexID
Pos = standard fullscreen quad

off15 = (−1.5/W, 0, +1.5/W, 0)
off35 = (−3.5/W, 0, +3.5/W, 0)
off55 = (−5.5/W, 0, +5.5/W, 0)
off75 = (−7.5/W, 0, +7.5/W, 0)

UV2..5 = uv.xyxy + each offset
```
