# FRPG_Fil_Bloom_improved — Pseudocode

15-tap weighted Gaussian bloom. Sample offsets and weights are precomputed in CB.

## Inputs
- `t0` = scene (bright pass filtered or full scene)
- `cb0[22..36]` = `gFC_avSampleOffsets0..14` (`.xy` = UV offset per tap)
- `cb0[38..52]` = `gFC_avSampleWeights0..14` (`.x` = weight per tap)

## Output
- `o0` = weighted sum of 15 samples

## Algorithm
```
acc = 0
for i = 0..14:
    acc += Sample(t0, UV + Offsets[i].xy) × Weights[i].x

Output = acc
```

## Notes
- 15 symmetric Gaussian taps (center + 7 each side)
- Offsets and weights are pre-computed on CPU per frame (dependent on bloom radius)
- References: [Karis 2013, "Graphics Gems for Games" — separable Gaussian bloom]
