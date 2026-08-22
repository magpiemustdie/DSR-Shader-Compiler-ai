# FRPG_Fil_DepthCopy — Pseudocode

Copies depth texture to both color and depth output (passthrough).

## Inputs
- `t0` = source depth texture (s0)

## Output
- `o0` = sampled texel (color)
- `SV_Depth` = sampled texel `.x` (depth)

## Algorithm
```
s     = Sample(t0, UV)
Color = s
Depth = s.x
```
