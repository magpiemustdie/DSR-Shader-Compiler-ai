# FRPG_Fil_ThruWithDepth — Pseudocode

Passthrough: copies color from t0 and depth from t1 to output.

## Inputs
- `t0` = color (s0)
- `t1` = depth (s1)

## Output
- `o0` = color sample
- `SV_Depth` = depth sample

## Algorithm
```
Color = Sample(t0, UV)
Depth = Sample(t1, UV).r
```
