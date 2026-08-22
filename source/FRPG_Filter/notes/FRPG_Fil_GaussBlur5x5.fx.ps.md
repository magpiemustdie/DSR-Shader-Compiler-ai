# FRPG_Fil_GaussBlur5x5 — Pseudocode

13-tap weighted Gaussian blur (5×5 kernel approximated as separable).

## Inputs
- `t0` = source (s0)
- `cb0[22..34]` = sample offsets 0..12 (`.xy`)
- `cb0[38..50]` = sample weights 0..12 (`.x`)

## Output
- `o0` = weighted sum of 13 samples

## Algorithm
```
acc = Σ(Sample(t0, UV + offset[i]) × weight[i] for i=0..12)
Output = acc
```
