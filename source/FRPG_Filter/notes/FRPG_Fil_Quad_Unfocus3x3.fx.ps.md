# FRPG_Fil_Quad_Unfocus3x3 — Pseudocode

Vertex shader for DOF unfocus: generates 4 cross-pattern UV offsets + center UV.

## Inputs
- `SV_VertexID` (0..3)
- `cb0[12].zw` = 1/ScreenSize

## Output
- `TEXCOORD0` = corner0 (+1,+0.28), corner1 (−1,+0.28)
- `TEXCOORD1` = corner2 (+0.28,−1), corner3 (−0.28,−1)
- `TEXCOORD2` = center UV

## Algorithm
```
uv = (xBit, yBit)  // from SV_VertexID

UV1.xy = uv + ( 1.0,  0.28) × 1/ScreenSize
UV1.zw = uv + (−1.0,  0.28) × 1/ScreenSize.z    // note: .z only!
UV2.xy = uv + ( 0.28, −1.0) × 1/ScreenSize
UV2.zw = uv + (−0.28, −1.0) × 1/ScreenSize.z
UV3    = uv
```
