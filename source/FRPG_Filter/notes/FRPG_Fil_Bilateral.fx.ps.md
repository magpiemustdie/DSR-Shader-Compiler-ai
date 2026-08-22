# FRPG_Fil_Bilateral — Pseudocode

4-tap bilateral filter: depth-weighted blend of center + horizontal + vertical + diagonal samples.

## Inputs
- `t0` = color (sampled via s0)
- `t1` = depth (sampled via s1)
- `t2` = reference buffer (sampled via s2, `.y` channel used as reference depth)
- `cb0[12]` = ScreenSize (`.xy` = size, `.zw` = 1/size)

## Output
- `o0` = depth-weighted blend of 4 color samples

## Algorithm
```
// Determine sub-pixel quadrant (−1 or +1 in each axis)
fracUV = frac(UV * ScreenSize.xy)
quad   = (0.5 < fracUV) ? 1 : -1        // −1 or +1 per axis

// Diagonal UV offset
diagUV = UV + quad * ScreenSize.zw

// Neighbor offsets (horiz = quad.x * 1/width, vert = quad.y * 1/height)
offH = quad.x * ScreenSize.z
offV = quad.y * ScreenSize.z              // note: both use .z (1/width)

// Reference depth at current pixel
refDepth = Sample(t2, UV).y

// Depth weight function: rcp(|depth − ref| + 0.0001) × coefficient
// 4 taps with fixed coefficients:
//   center    0.5625
//   horiz     0.1875
//   vert      0.1875
//   diagonal  0.0625

wCenter   = rcp(|Sample(t1, UV).x     − refDepth| + 0.0001) × 0.5625
wHoriz    = rcp(|Sample(t1, horizUV).x  − refDepth| + 0.0001) × 0.1875
wVert     = rcp(|Sample(t1, vertUV).x   − refDepth| + 0.0001) × 0.1875
wDiag     = rcp(|Sample(t1, diagUV).x   − refDepth| + 0.0001) × 0.0625

wTotal = wCenter + wHoriz + wVert + wDiag
wN = (wCenter, wHoriz, wVert, wDiag) / wTotal

// Blend colors
cCenter   = Sample(t0, UV)
cHoriz    = Sample(t0, horizUV)
cVert     = Sample(t0, vertUV)
cDiag     = Sample(t0, diagUV)

Output = cDiag × wN.w + cVert × wN.z + cCenter × wN.x + cHoriz × wN.y
```

## Notes
- 4 taps only (not a full 3×3 kernel) — optimized for performance
- Depth weight uses inverse absolute difference (not Gaussian), clamped by 0.0001 epsilon
- Sub-pixel quadrant determines which of 4 diagonal directions to sample
- References: [Tomasi & Manduchi 1998, "Bilateral Filtering for Gray and Color Images"]
