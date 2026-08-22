# FRPG_Fil_Sfx_Glow_Blur — Pseudocode

SFX glow blur: 15-tap weighted blur (same structure as Bloom_improved).

## Inputs
- `t0` = source (s0)
- `cb0[22..36]` = offsets 0..14
- `cb0[38..52]` = weights 0..14

## Output
- `o0` = weighted sum

## Algorithm
```
acc = Σ(Sample(t0, UV + offset[i]) × weight[i] for i=0..14)
Output = acc
```
