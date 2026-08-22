# FRPG_Fil_LightShaft — Pseudocode

Radial blur (light shaft) toward screen-space light position, 10 samples with exponential decay.

## Inputs
- `t0` = scene (s0)
- `cb0[12]` = ScreenSize
- `cb0[69]` = ScreenLightPos (`.xy` = light UV)
- `cb0[70]` = LightShaftParam (`.x` = maxLength, `.y` = colorScale, `.z` = decay)

## Output
- `o0.xyz` = accumulated light shaft color
- `o0.w` = 1

## Algorithm
```
dir = (UV − lightUV) × ScreenSize.xy
len = max(length(dir), 0.0001)
clampedLen = min(len, maxLength)
dir = (clampedLen / len) × dir × 1/ScreenSize

uv  = UV
acc = (0, 0, 0, 1)     // w = sample weight

for i = 0..9:
    s       = Sample(t0, uv).rgb
    acc.xyz += s × acc.w
    uv      −= dir × 0.1
    acc.w   ×= decay

Output.xyz = acc.xyz × colorScale
Output.w   = 1
```
