# FRPG_Fil_SampleLumFinal — Pseudocode

Final luminance sample: 16 fixed-UV log-luminance reads → geometric mean.

## Inputs
- `t0` = log-luminance texture from SampleLumInitial (s0)

## Output
- `o0.xyz` = `exp2(mean(ln(lum)) × ln(2)/16)` = geometric mean luminance
- `o0.w` = 1

## Algorithm
```
acc = Σ(Sample(t0, fixedUV[i]).r for i=0..15)
     // fixedUVs = 4×4 grid at (0, 0.25, 0.5, 0.75)²

// SampleLumInitial writes ln(lum) = log2(lum) × ln(2)
// 0.090168 = ln(2) / 16
// exp2(acc × ln(2)/16) = exp(acc/16) = geometric mean
Output.xyz = exp2(acc × 0.090168)
Output.w   = 1
```
