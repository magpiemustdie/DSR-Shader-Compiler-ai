# FRPG_Fil_Dof_GaussX_Adv — Pseudocode

DOF horizontal advanced Gaussian blur: per-channel ratio-weighted blur.
Each sample weight = `saturate(sample / center) × gaussWeight`, preserving edge color ratios.

## Inputs
- same as GaussX

## Output
- `o0` = ratio-weighted blur = sum(sample × ratio × weight) / sum(ratio × weight)

## Algorithm
```
center = Sample(t0, centerUV)
acc    = center × GaussWeight0
wTotal = GaussWeight0

for each pair (leftUV, rightUV):
    for each sample UV in pair:
        s = Sample(t0, UV)
        ratio = div_sat(s / center)      // per-channel, 0 where center=0
        w = ratio × gaussWeight
        acc += s × w
        wTotal += w

Output = acc / wTotal
```

## Notes
- `div_sat` returns 0 when denominator=0 (hardware div_sat behavior)
- Preserves color ratios: avoids bleeding of bright pixels into dark areas
