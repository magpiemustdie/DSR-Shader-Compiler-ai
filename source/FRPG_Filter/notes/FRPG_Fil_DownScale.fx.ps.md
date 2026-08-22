# FRPG_Fil_DownScale — Pseudocode

Two entry points: 2×2 (4 samples) and 4×4 (16 samples) box downsample.

## Inputs
- `t0` = source (s0)
- `cb0[22..37]` = sample offsets (0..15)

## Output
- `o0` = averaged color

## Algorithm (2×2)
```
acc = Σ(Sample(t0, UV + offset[i]) for i=0..3)
Output = acc × 0.25
```

## Algorithm (4×4)
```
acc = Σ(Sample(t0, UV + offset[i]) for i=0..15)
Output = acc × 0.0625
```
