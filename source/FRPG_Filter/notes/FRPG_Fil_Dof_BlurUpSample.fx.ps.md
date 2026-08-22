# FRPG_Fil_Dof_BlurUpSample — Pseudocode

5-tap DOF blur upsample: 4 corners + center, corner weight = 0.25 if corner.alpha ≥ center.alpha.

## Inputs
- `t0` = source (s0)
- UV1.xy = corner0, UV1.zw = corner1, UV2.xy = corner2, UV2.zw = corner3, UV3 = center

## Output
- `o0` = alpha-weighted blend

## Algorithm
```
c0..c3 = Sample(t0, cornerUVs)
cc     = Sample(t0, centerUV)

weights = (cN.a < cc.a) ? 0 : 0.25

centerWeight = 1 − sum(weights)

result = c0×w0 + c1×w1 + c2×w2 + c3×w3 + cc×centerWeight
```
