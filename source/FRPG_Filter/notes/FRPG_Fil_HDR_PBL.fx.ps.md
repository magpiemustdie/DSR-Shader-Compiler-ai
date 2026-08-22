# FRPG_Fil_HDR_PBL — Pseudocode

PBL HDR tonemapper: Hable filmic curve (Uncharted 2) + soft-light noise overlay.

## Inputs
- `t0` = HDR scene (s0, UV.xy)
- `t1` = bloom (s1, UV.xy)
- `t2` = noise (s2, UV.zw)
- `cb0[54]` = ToneParam0 (`.x` = exposureKey, `.y` = whitePoint, `.z` = minLum, `.w` = maxLum)
- `cb0[55]` = ToneParam1 (`.x` = A, `.y` = B, `.z` = C, `.w` = D) — Hable curve params
- `cb0[56]` = BloomScale (`.x` = bloomScale, `.z` = adaptedLumMin)
- `cb0[68].x` = noise blend strength

## Output
- `o0` = tonemapped + noise-overlaid color

## Algorithm
```
hdr   = Sample(t0, UV.xy)
bloom = Sample(t1, UV.xy)
col   = bloomScale × bloom + hdr
col.a = saturate(col.a)

// Luminance + exposure
lum = dot(col.rgb, (0.212673, 0.715152, 0.072175))
lum = max(lum, 0.0001)
adaptedLum = 0.0001 + adaptedLumMin
scale = (lum × exposureKey / adaptedLum) / lum   // = exposureKey / adaptedLum
exposed = scale × col.rgb

// Hable filmic: num = exposed*(A*exposed + B*C) + minLum*D
//              den = exposed*(A*exposed + B) + maxLum*D
BC  = B×C
minD = minLum × D
maxD = maxLum × D
num = exposed × (A × exposed + BC) + minD
den = exposed × (A × exposed + B) + maxD
tonemapped = num / den

// White point scaling
wp = minLum / maxLum
wpCurve = f(whitePoint)   // same curve applied to whitePoint scalar
whiteScale = wpCurve − wp
result = saturate((tonemapped − wp) / whiteScale)

// Gamma 2.2
result = exp2(log2(result) × 0.454545)

// Soft-light noise overlay (same as HDR.fx)
noise = Sample(t2, UV.zw)
mul2    = noise × result × 2
inv2n   = (1−noise) × 2
inv1r   = 1 − result
screen  = 1 − inv2n × inv1r
mask    = (noise ≤ 0.5)
blended = screen × mask + mul2 × (1−mask)
delta   = blended − result
final   = noiseBlend × delta + result

Output = (final.rgb, col.a)
```
