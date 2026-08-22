# FRPG_Fil_HDR_ColAdj — Pseudocode

HDR composite + color adjustment matrix + star layer + soft-light noise overlay.

## Inputs
- `t0` = scene (s0)
- `t1` = bloom (s1)
- `t2` = noise (s2, UV.zw)
- `t3` = star layer (s3)
- `cb0[56]` = PostEffectScale (`.x` = bloomBase, `.y` = starScale, `.z` = sceneScale)
- `cb0[62..65]` = ColorAdj matrix (4 rows, 4 columns)
- `cb0[68].x` = noise blend
- `cb0[71].y` = bloom lerp target

## Output
- `o0` = color-adjusted, noise-overlaid HDR result

## Algorithm
```
scene = saturate(Sample(t0, UV).rgb × sceneScale)
bloom = Sample(t1, UV)
bloomBlend   = bloom.w × (bloomLerpTarget − bloomBase) + bloomBase
scene = bloomBlend × bloom.rgb + scene
star  = Sample(t3, UV).rgb
scene = starScale × star + scene

// Color adjustment matrix (4×4)
s4 = float4(scene, 1)
adjusted.x = dot(s4, ColorAdjRow0)
adjusted.y = dot(s4, ColorAdjRow1)
adjusted.z = dot(s4, ColorAdjRow2)
adjustedW  = dot(s4, ColorAdjRow3)

// Soft-light noise overlay (same as HDR.fx)
base = float4(adjusted, adjustedW)
noise = Sample(t2, UV.zw)
mul2   = base × noise × 2
inv2n  = (1−noise) × 2
inv1b  = 1 − base
screen = 1 − inv2n × inv1b
mask   = (noise < 0.5)
blended = mul2 × mask + screen × (1−mask)
delta = blended − base
result = noiseBlend × delta + base

Output = (result.xyz, result.w)
```
