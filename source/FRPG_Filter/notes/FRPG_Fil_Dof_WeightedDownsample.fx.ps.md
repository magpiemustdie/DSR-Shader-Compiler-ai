# FRPG_Fil_Dof_WeightedDownsample — Pseudocode

5-sample weighted downsample with rotated grid offsets (poisson disc pattern).

## Inputs
- `t0` = source (s0)
- `cb0[12].zw` = 1/ScreenSize

## Output
- `o0` = `max(average of 5 weighted samples, 0)`

## Algorithm
```
Offsets[5] = {
    ( 0,       0),       // center
    ( 0.860,   0.500),
    (−0.500,   0.860),
    (−0.860,  −0.500),
    ( 0.500,  −0.860),
}

acc = 0
for i = 0..4:
    uv = Offsets[i] × 1/ScreenSize + In.UV
    acc += SampleLevel(t0, uv, 0)

Output = max(acc × 0.2, 0)
```
