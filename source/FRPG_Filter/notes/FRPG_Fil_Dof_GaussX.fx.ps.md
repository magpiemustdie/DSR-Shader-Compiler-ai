# FRPG_Fil_Dof_GaussX — Pseudocode

DOF horizontal Gaussian blur (9-tap, symmetric pairs via vertex shader UVs).

## Inputs
- `t0` = source (s0)
- UV offsets from VS (4 pairs: ±1.5, ±3.5, ±5.5, ±7.5 px)
- `cb0[13..17]` = GaussWeights0..4 (`.x` per weight)

## Output
- `o0` = Gaussian-blurred color

## Algorithm
```
acc  = Sample(t0, centerUV) × GaussWeight0
acc += (Sample(t0, UV_left1) + Sample(t0, UV_right1)) × GaussWeight1
acc += (Sample(t0, UV_left2) + Sample(t0, UV_right2)) × GaussWeight2
acc += (Sample(t0, UV_left3) + Sample(t0, UV_right3)) × GaussWeight3
acc += (Sample(t0, UV_left4) + Sample(t0, UV_right4)) × GaussWeight4
```
