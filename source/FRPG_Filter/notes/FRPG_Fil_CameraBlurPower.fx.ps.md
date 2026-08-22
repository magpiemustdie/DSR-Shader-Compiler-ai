# FRPG_Fil_CameraBlurPower — Pseudocode

Computes camera blur power from depth (prepass for camera blur).

## Inputs
- `t0` = depth buffer (s0, `.r`)
- `cb0[8]` = CameraParam: (`.y` = bias, `.z` = scale, `.w` = key)

## Output
- `o0` = `key / (depth × scale + bias) × (1/32)`

## Algorithm
```
depth  = Sample(t0, UV).r
mapped = depth × scale + bias
power  = key / mapped
Output = power × (1/32)
```

## Notes
- Divides by 32 to scale power into a usable range for the blur shader
