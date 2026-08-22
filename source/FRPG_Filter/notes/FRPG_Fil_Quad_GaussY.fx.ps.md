# FRPG_Fil_Quad_GaussY — Pseudocode

Vertex shader for DOF vertical Gauss blur: generates 4 pairs of vertical UV offsets.

## Inputs
- `SV_VertexID` (0..3)
- `cb0[12].y` = screen height

## Output
- `TEXCOORD1` = center UV
- `TEXCOORD2..5` = UV pairs at ±1.5, ±3.5, ±5.5, ±7.5 pixels (vertical)

## Algorithm
```
uv = (xBit, yBit)  // from SV_VertexID
Pos = standard fullscreen quad

off15 = (0, −1.5/H, 0, +1.5/H)
off35 = (0, −3.5/H, 0, +3.5/H)
off55 = (0, −5.5/H, 0, +5.5/H)
off75 = (0, −7.5/H, 0, +7.5/H)

UV2..5 = uv.xyxy + each offset
```
