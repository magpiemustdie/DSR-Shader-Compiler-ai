# FRPG_Fil_BlackBars_VS — Pseudocode

Vertex shader for letterbox bars: passes 2D position through, sets Z=0, W=1.

## Inputs
- `POSITION` (`v0.xy`) — 2D vertex position

## Output
- `SV_Position` = `(pos.x, pos.y, 0, 1)`

## Algorithm
```
Out.Pos = float4(In.Pos, 0.0f, 1.0f)
```
