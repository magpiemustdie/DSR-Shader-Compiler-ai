# FRPG_Fil_Dof_StretchAlphaX — Pseudocode

DOF horizontal alpha stretch: max-filters alpha across 8 taps, then `out.a = (maxA − center.a) × center.a + center.a`.

## Inputs
- `t0` = source (s0)
- UV1 = center, UV2..UV5 = offset pairs (8 taps total)

## Output
- `o0.rgb` = center.rgb
- `o0.a`   = stretched alpha

## Algorithm
```
// Gather 8 tap alphas + center alpha in specific order (DXBC trace order)
r0.x = Sample(t0, UV4.xy).w
r0.y = Sample(t0, UV3.zw).w
r0.z = Sample(t0, UV3.xy).w
r0.w = Sample(t0, UV2.zw).w
r1x  = Sample(t0, UV2.xy).w
r2   = Sample(t0, centerUV)          // center pixel

// Sequential max chain
r1x  = max(r1x,  r2.w)
r0.w = max(r0.w, r1x)
r0.z = max(r0.w, r0.z)
r0.y = max(r0.z, r0.y)
r0.x = max(r0.y, r0.x)
r0.x = max(r0.x, Sample(t0, UV4.zw).w)
r0.x = max(r0.x, Sample(t0, UV5.xy).w)
r0.x = max(r0.x, Sample(t0, UV5.zw).w)

// Blend: delta = maxA − center.a
// out.a = delta × center.a + center.a = center.a × (1 + delta)
maxA  = r0.x
delta = maxA − center.a
out.a = delta × center.a + center.a

Output.rgb = r2.rgb
Output.a   = out.a
```
