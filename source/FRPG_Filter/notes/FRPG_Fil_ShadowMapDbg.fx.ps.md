# FRPG_Fil_ShadowMapDbg — Pseudocode

Shadow map debug visualizer: samples t1 with small offset, outputs swizzled depth.

## Inputs
- `t1` = shadow map (s1)

## Output
- `o0` = `(tex.w, tex.x, tex.y, 1)`

## Algorithm
```
uv = UV + (0.000260, 0.000463)
s  = Sample(t1, uv)
// s.xywz → (s.x, s.y, s.w, s.z), then o0.xyz = (s.w, s.x, s.y)
Output = (s.w, s.x, s.y, 1)
```
