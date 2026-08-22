# FRPG_Fil_SampleLumInitial — Pseudocode

9-tap log-luminance downsample: computes `ln(luminance)` at 9 sample points, averages them.

## Inputs
- `t0` = HDR scene (s0)
- `cb0[22..30]` = sample offsets
- `cb0[56].zw` = bloomScale, exposureScale

## Output
- `o0.xyz` = `mean(ln(lum))` (all 3 channels same)
- `o0.w` = 1

## Algorithm
```
for each of 9 taps:
    c   = Sample(t0, UV + offset)
    c  *= bloomScale × exposureScale
    lum = max(dot(c, (0.2125, 0.7154, 0.0721)), 0.0001)
    acc += log2(lum) × 0.693147     // = ln(lum)

Output.xyz = acc × (1/9)
Output.w   = 1
```
