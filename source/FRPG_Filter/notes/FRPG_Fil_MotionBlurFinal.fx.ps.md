# FRPG_Fil_MotionBlurFinal — Pseudocode

Motion blur final: 4-tap depth-weighted blur using tile-max velocity from prepass.

## Inputs
- `t0` = tile max velocity (s0, `.xy` = motion vector in UV)
- `t1` = HDR scene (s1, color)
- `t2` = per-pixel velocity (s2, `.yx` = (viewZ, 1/mvLen) — note yx swizzle!)
- `cb0[12].zw` = 1/ScreenSize
- `cb0[56].x` = blur scale

## Output
- `o0.xyz` = motion-blurred color (center + 4 weighted samples, normalized)
- `o0.w` = 1

## Algorithm
```
// === 1. Early-out: skip if motion too small ===
tileMV    = Sample(t0, UV).xy               // r0.xy = tile-max motion vector
scene     = Sample(t1, UV).xyz               // r1.xyz = center color
pixelArea = dot(1/ScreenSize, 1/ScreenSize)  // r0.z = threshold = area of 1 pixel

if (dot(tileMV, tileMV) ≤ pixelArea):        // r0.z = (r0.w > r0.z)
    Output = (scene, 1)
    return

// === 2. Sample positions along motion vector (4 taps, reverse direction) ===
scaledMV = tileMV × blurScale                 // r2.xyzw = (scaledMV, scaledMV)
vel = Sample(t2, UV).yx                       // r3.xy = (viewZ, 1/mvLen) from .yx swizzle
invMVLen = vel.y                              // r3.y = 1/mvLen
tapViewZ  = vel.x                             // r3.x = viewZ

// UV offsets for 4 tap positions (in reverse motion direction):
//   r0.xy   = UV − scaledMV                 → offset at t=1.0 (outer)
//   r0.zw   = UV − scaledMV                 → same (duplicated for register pair)
//   r4.xy   = saturate(UV)                  → t=0 (center — clamped)
//   r4.zw   = saturate(UV − scaledMV×0.667) → t=0.667 (inner)
//   (r0 after mad = UV − scaledMV×1.333)    → t=1.333 (middle)
//   (r0 after mad = UV − scaledMV×2)        → t=2.0 (outermost)
// Note: UVs are clamped to [0,1] via saturate

r0.xyzw = UV.xyxy − scaledMV.xyxy            // 4 positions at t=1
tileLen = sqrt(dot(scaledMV, scaledMV))       // r1.w = |scaledMV|

// Build 4 tap UVs with different temporal offsets:
// r4.xy = saturate(UV − scaledMV × 0)       = UV (center-ish, t=0)
// r4.zw = saturate(UV − scaledMV × 0.667)   = t=0.667
// r0.xy = saturate(UV − scaledMV × 1.333)   = t=1.333
// r0.zw = saturate(UV − scaledMV × 2.0)     = t=2.0
r4.xyzw = saturate(r2.zwzw × (0, 0, 0.667, 0.667) + r0.zwzw)
r0.xyzw = saturate(r2.xyzw × (1.333, 1.333, 2, 2) + r0.xyzw)

// === 3. Sample per-pixel velocity at all 4 tap positions ===
// Each sample: texel.yx = (viewZ, 1/mvLen)
r2.xy = Sample(t2, r4.xy).xy                 // tap0: (v0.z, v0.1/mvLen)
r2.zw = Sample(t2, r4.zw).xy                 // tap1: (v1.z, v1.1/mvLen)
r5.xy = Sample(t2, r0.xy).xy                 // tap2: (v2.z, v2.1/mvLen)
r5.zw = Sample(t2, r0.zw).xy                 // tap3: (v3.z, v3.1/mvLen)

// === 4. Compute sample weights from velocity magnitude ===
// Each weight = f(tileLen, abs(1/mvLen_sample), abs(1/mvLen_center))
// The weights are computed per-channel: 4 weights = r6.xyzw
//
// Weight structure:
//   Sample 0 (t=0):      w0 = f(A, B) where A/B from |r3.x| (center invMVLen)
//   Sample 1 (t=0.667):  w1 = f(A, B) where A/B from |r2.y/r2.w/r2.x/r2.z|
//   Sample 2 (t=1.333):  w2 = f(A, B) where A/B from |r5.w/r5.y/r5.z/r5.x|
//   Sample 3 (t=2.0):    w3 = f(A, B) where A/B from |r5.w/r5.y|
//
// Exact DXBC weight computation (for each of 4 samples):
//   Let d = tileLen (r1.w = sqrt(dot(scaledMV, scaledMV)))
//   Let v = velSample.yx = (viewZ, invMVLen)
//
//   For each sample pair (two samples per pair):
//     a = |invMVLen_sample|           // r7.y = |r3.x| (center), r7.xz from |r2.yywy|
//     b = |invMVLen_sample2|          // r7.xz from taps
//     sat1 = saturate((a+1) − b)      // r8.x = sat(r7.y+1 − r7.x)
//     sat2 = saturate((b+1) − a)      // r8.y = sat(r7.x+1 − r7.y)
//
//     // Weight = saturate(−d × v × conv + bias) product chain
//     // r9.xyzw = saturate(−|d × −1| × a/b + bias)
//     // where bias = (1, 1, 1.95, 1.95)
//     // d × −1 = r6.x (outermost, w0 factor)
//     // d × −0.333 = r6.y (w1 factor)
//     // d × 0.333 = r6.z (w2 factor)
//     // d × 1 = r6.w (w3 factor)
//
//   Final weight for this sample:
//     w = dot(saturants, saturate(−|d×factor| × vals + bias)) +
//         × (saturate(−|d×factor| × v3 + 1.95) × saturate(−|d×factor| × v4 + 1.95)) × 2
//
// Simplified conceptual formula:
//   weight(s) = proximity(s, center) × velocityConfidence(s)
//   where proximity penalizes |invMVLen(s) − invMVLen(center)|
//   and velocityConfidence = f(tileLen, invMVLen)

tileLen = sqrt(dot(scaledMV, scaledMV))          // r1.w
factors = tileLen × (−1, −0.333, 0.333, 1)       // r6.xyzw

// Weight for tap0 (r4.xy → r2.xy):
//   Uses center invMVLen (r3.x) and tap0 invMVLen (r2.y)
//   w0 = dot(sat1, sat2, f(-|d×(-1)| × ...), ...) + 2 × ...
w0 = dot(saturate(...), saturate(...)) + 2 × saturate(...) × saturate(...)   // r6.x

// Weight for tap1 (r4.zw → r2.zw):
w1 = dot(...) + 2 × ...                                                       // r6.y

// Weight for tap2 (r0.xy → r5.xy):
w2 = dot(...) + 2 × ...                                                       // r6.z

// Weight for tap3 (r0.zw → r5.zw):
w3 = dot(...) + 2 × ...                                                       // r6.w

// === 5. Sample colors at 4 tap positions ===
c0 = Sample(t1, r4.xy).xyz
c1 = Sample(t1, r4.zw).xyz
c2 = Sample(t1, r0.xy).xyz
c3 = Sample(t1, r0.zw).xyz

// === 6. Accumulate weighted colors ===
blurred = c0 × w0 + c1 × w1 + c2 × w2 + c3 × w3
totalW  = w0 + w1 + w2 + w3

result = (blurred + scene) / (totalW + 1)        // center color always included

Output = (result, 1)
```

## Notes
- Weight function penalizes samples whose 1/mvLen differs from center (depth-based rejection)
- Tile velocity from prepass ensures consistent blur radius across the tile
- References: [Underwood 2015, "Motion Blur in Call of Duty: Advanced Warfare"]
