# FRPG_Fil_DepthCopy_MSAA — Pseudocode

MSAA depth copy: samples two depth values from UV pair, outputs min depth + white color.

## Inputs
- `t0` = MSAA depth texture (s0)
- `In.UV.xy` = UV0
- `In.UV.zw` = UV1

## Output
- `o0` = `(1, 1, 1, 1)` (white)
- `SV_Depth` = `min(depth0, depth1)`

## Algorithm
```
d0 = Sample(t0, UV.xy).r
d1 = Sample(t0, UV.zw).r

Color = (1, 1, 1, 1)
Depth = min(d0, d1)
```
