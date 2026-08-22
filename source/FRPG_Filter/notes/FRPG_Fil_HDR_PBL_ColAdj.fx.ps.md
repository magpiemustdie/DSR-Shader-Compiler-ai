# FRPG_Fil_HDR_PBL_ColAdj — Pseudocode

PBL HDR + color adjustment: 3 tonemapper modes (Hable, Reinhard, Reinhard2), color matrix, noise overlay.

## Inputs
- `t0` = HDR scene (s0, UV.xy)
- `t1` = bloom (s1, UV.xy)
- `t2` = noise (s2, UV.zw)
- `t3` = color adjust buffer (s3, UV.xy)
- `t5` = adapted luminance 1×1 (s5, `.y`)
- `cb0[54]` = ToneParam0 (`.x` = exposureKey, `.y` = whitePoint, `.z` = minLum, `.w` = maxLum)
- `cb0[55]` = ToneParam1 (`.x` = A, `.y` = B, `.z` = C, `.w` = D)
- `cb0[56]` = BloomParam2 (`.x` = bloomScale, `.y` = colAdjScale, `.z` = adaptedLumMin, `.w` = adaptedLumMax)
- `cb0[57].x` = tonemapper mode (uint: 0=Hable, 1=Reinhard, 2=Reinhard2)
- `cb0[62..64]` = color matrix rows (rgb)
- `cb0[68].x` = noise blend
- `cb0[71].y` = bloom lerp target

## Output
- `o0.rgb` = tonemapped + color-graded + noise-overlaid
- `o0.a`   = luminance of output (luma)

## Algorithm
```
hdr    = max(Sample(t0, UV.xy).rgb, 1e-6)
bloom  = Sample(t1, UV.xy).wxyz   // w=alpha, xyz=rgb
colAdj = Sample(t3, UV.xy).rgb

// Bloom lerp + color adjust
bloomLerp = bloom.x × (bloomLerpTarget − bloomScale) + bloomScale
col = bloomLerp × bloom.yzw + hdr
col = colAdjScale × colAdj + col

// Adapted luminance
adaptedLum = Sample(t5, (0.5, 0.5)).y
adaptedLum = clamp(adaptedLum, adaptedLumMin, adaptedLumMax) + 0.0001

switch (mode):
    case 0: // Hable (same as HDR_PBL)
        exposed = (exposureKey / adaptedLum) × col
        num = exposed × (A×exposed + B×C) + minLum×D
        den = exposed × (A×exposed + B)   + maxLum×D
        tonemapped = num / den
        result = (tonemapped − minLum/maxLum) / f(whitePoint)
    case 1: // Reinhard
        exposed = (exposureKey / adaptedLum) × col
        lum = max(dot(exposed, lumaWeights), 0.0001)
        result = (exposed / lum) × (lum / (lum+1))
    case 2: // Reinhard2 (with white point)
        exposed = (exposureKey / adaptedLum) × col
        lum = max(dot(exposed, lumaWeights), 0.0001)
        result = (exposed / lum) × (lum × (1 + lum/wp²) / (lum+1))

result = saturate(result)

// Gamma 2.2 + color matrix
result = exp2(log2(result) × 0.454545)
result = result × ColorMatrix

// Soft-light noise overlay (same as HDR_PBL)
noise = Sample(t2, UV.zw)
...

Output.rgb = final
Output.a   = dot(final, (0.299, 0.587, 0.114))  // luma
```
