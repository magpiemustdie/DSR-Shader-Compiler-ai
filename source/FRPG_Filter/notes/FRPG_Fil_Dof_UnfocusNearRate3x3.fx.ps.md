# FRPG_Fil_Dof_UnfocusNearRate3x3 — Pseudocode

5-tap max-filter for near-field DOF rate: outputs white RGB + max of 5 alpha values.

## Inputs
- `t0` = source (s0, `.w` = near rate)
- UV1 = first two corner UVs, UV2 = next two, UV3 = center UV

## Output
- `o0.rgb` = 1
- `o0.a`   = `max(corner0.w, corner1.w, corner2.w, corner3.w, center.w)`

## Algorithm
```
r0.x = Sample(t0, UV1.xy).w
r0.y = Sample(t0, UV1.zw).w
r0.z = Sample(t0, UV2.xy).w
r0.w = Sample(t0, UV2.zw).w
c    = Sample(t0, centerUV).w

mx = max(max(max(r0.z, r0.w), max(r0.x, r0.y)), c)

Output = (1, 1, 1, mx)
```
