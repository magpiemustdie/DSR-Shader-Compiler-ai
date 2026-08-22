# FRPG_Fil_Star — Pseudocode

8-tap weighted star/streak filter for anamorphic flare effect.

## Inputs
- `t0` = source (s0)
- `cb0[22..29]` = offsets 0..7
- `cb0[38..45]` = weights 0..7

## Output
- `o0` = weighted sum

## Algorithm
```
acc = Σ(Sample(t0, UV + offset[i]) × weight[i] for i=0..7)
Output = acc
```
