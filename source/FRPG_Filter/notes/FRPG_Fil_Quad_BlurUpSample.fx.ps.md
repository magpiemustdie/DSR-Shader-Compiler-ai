# FRPG_Fil_Quad_BlurUpSample — Pseudocode

Vertex shader for DOF blur upsample: generates 4 diagonal + 1 center UV offset pair.

## Inputs
- `SV_VertexID` (0..3)
- `cb0[12].zw` = 1/ScreenSize

## Output
- `TEXCOORD0` = corner0 (+0.5,+0.5), corner1 (−0.5,+0.5)
- `TEXCOORD1` = corner2 (+0.5,−0.5), corner3 (−0.5,−0.5)
- `TEXCOORD2` = center UV

## Algorithm
```
uv = (xBit, yBit)  // from SV_VertexID

UV1.xy = uv + ( 0.5,  0.5) × 1/ScreenSize
UV1.zw = uv + (−0.5,  0.5) × 1/ScreenSize.z   // note: .z only!
UV2.xy = uv + ( 0.5, −0.5) × 1/ScreenSize
UV2.zw = uv + (−0.5, −0.5) × 1/ScreenSize.z
UV3    = uv
```
