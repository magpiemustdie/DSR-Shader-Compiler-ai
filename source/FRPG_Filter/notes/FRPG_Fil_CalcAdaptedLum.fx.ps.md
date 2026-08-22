# FRPG_Fil_CalcAdaptedLum — Pseudocode

Adapts luminance over time using exponential smoothing (first-order IIR).

## Inputs
- `t0` = current adapted luminance (1×1 texture, `.r`)
- `t1` = new measured luminance (1×1 texture, `.r`)
- `cb0[54]` = AdaptParam2:
  - `.x` = deltaTime (seconds since last frame)
  - `.y` = minLum
  - `.z` = maxLum
  - `.w` = keyValue (middle-grey)

## Output
- `o0.rgb` = adapted luminance
- `o0.a` = 1

## Algorithm
```
adaptSpeed = 1 − exp2(−0.029146 × deltaTime)

newLum = Sample(t1, (0.5, 0.5)).r
newLum = max(min(newLum, maxLum), minLum)   // clamp to [min, max]
newLum = keyValue / (newLum + 0.001)          // exposure = key / lum

curLum  = Sample(t0, (0.5, 0.5)).r
adapted = adaptSpeed × (newLum − curLum) + curLum   // lerp

Output = (adapted, adapted, adapted, 1)
```

## Notes
- Time constant: 0.029146 ≈ ln(2)/23.78 → half-life of ~24 frames at 60fps
- References: [Karis 2013, "Graphics Gems for Games"] / [Reinhard 2002, "Photographic Tone Reproduction"]
