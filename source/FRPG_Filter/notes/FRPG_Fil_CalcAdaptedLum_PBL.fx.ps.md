# FRPG_Fil_CalcAdaptedLum_PBL — Pseudocode

PBL variant of adapted luminance — no min/max clamp, adds NaN guard.

## Inputs
- `t0` = current adapted luminance (1×1 texture, `.r`)
- `t1` = new measured luminance (1×1 texture, `.r`)
- `cb0[54].x` = deltaTime

## Output
- `o0.rgb` = adapted luminance (or 0.25 if NaN)
- `o0.a` = 1

## Algorithm
```
adaptSpeed = 1 − exp2(−0.029146 × deltaTime)

newLum  = Sample(t1, (0.5, 0.5)).r
curLum  = Sample(t0, (0.5, 0.5)).r
adapted = adaptSpeed × (newLum − curLum) + curLum

// NaN detection (self-comparison — true only if NaN)
adapted = (adapted != adapted) ? 0.25 : adapted

Output = (adapted, adapted, adapted, 1)
```

## Notes
- Differs from non-PBL variant: no min/max clamp on newLum, no keyValue division
- NaN guard prevents temporal fireflies
