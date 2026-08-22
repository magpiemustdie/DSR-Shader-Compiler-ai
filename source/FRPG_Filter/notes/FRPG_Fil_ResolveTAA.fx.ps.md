# FRPG_Fil_ResolveTAA — Pseudocode

Temporal anti-aliasing resolve (Karis-style): motion-compensated history blend with AABB clamping, velocity output.

## Inputs
- `t0` = current frame color (s0, `Load`)
- `t1` = history buffer (s1, `SampleLevel`)
- `t2` = depth (s2, `GatherRed`)
- `t3` = motion/velocity (s3, `SampleLevel`, `.x < 1` = valid)
- `t4` = flicker detection (s4, `.g`)
- `cb0[56]` = MotionScale (`.x` = velocity weight scale)
- `cb0[57]` = MotionParam (`.xy` = output scale, `.z` = output normScale)
- `cb0[58..61]` = InvViewProj
- `cb0[74,75,77]` = PrevViewProj
- `cb0[78]` = camera offset

## Output
- `o0` = resolved color (RGBA)
- `o1.x` = 1 / output motion length
- `o1.y` = depth (negative if history pixel is valid)

## Algorithm
```
// === 1. Gather closest depth (not center — the min of the gather quad) ===
g = GatherRed(t2, UV)
// GatherRed returns: .x=u+1,v-1, .y=u-1,v-1, .z=u-1,v+1, .w=u+1,v+1
// DXBC reassigns: r3.x=g.x, r3.y=g.y, r3.z=g.w, r3.w=g.z
//   → r3.x=tr, r3.y=tl, r3.z=br, r3.w=bl
best = r3.x  (top-right)
dx = −1, dy = 1

if (r3.y < best): best = r3.y; dx = 1;  dy = 1   // top-left closer
if (r3.w < best): best = r3.w; dx = 1;  dy = −1  // bottom-left closer
if (r3.z < best): best = r3.z; dx = −1; dy = −1  // bottom-right closer

// Closest depth sample's UV
minUV = UV + float2(dx, dy) × 1/ScreenSize

// Linearize
linearDepth = near×far / (best × (near−far) + far)
depthZ = best

// === 2. Reproject closest depth to previous frame ===
ndc = minUV × 2 − 1
pos = (ndc.x, −ndc.y, depthZ, 1)

worldPos.x = dot(pos, InvVP0)
worldPos.y = dot(pos, InvVP1)
worldPos.z = dot(pos, InvVP2)
w          = dot(pos, InvVP3)
worldPos.xyz /= w
worldPos.xyz += camOffset

prevClip.x = dot(worldPos, PrevVP0)
prevClip.y = dot(worldPos, PrevVP1)
prevW      = dot(worldPos, PrevVP3)
prevUV = prevClip / prevW × (0.5, −0.5) + 0.5

mvCam = minUV − prevUV

// === 3. Object motion override ===
mvS = Sample(t3, minUV)
mvObj = mvS.xy × (1, −1)
mvValid = (mvS.x < 1)
mv = mvValid ? mvObj : mvCam

// === 4. Velocity weight ===
mvPix = mv × ScreenSize.xy
vel = min(sqrt(dot(mvPix, mvPix)), 1)
velW = MotionScale.x × vel + 1

// === 5. AABB from 3×3 neighborhood (cross + diagonal) ===
// Tonemap: T(c) = c / (dot(c, gLum) + 1)
// Load 5 cross taps (N, C, S, W, E) and 4 diagonal taps (NW, NE, SW, SE)
// Each: Load(t0, int2 offset), Load(t3, same offset).x → validity
// Tonemap each tap's color before min/max

crossMin = min over 5 cross taps
crossMax = max over 5 cross taps
diagMin  = min over 4 diagonal taps
diagMax  = max over 4 diagonal taps

motionConsistent = all 8 neighbors have same validity as center

// === 6. AABB clamp (extended Karis) ===
upper = (crossMax + max(crossMax, diagMax)) × 0.5
lower = (crossMin + min(crossMin, diagMin)) × 0.5

histUV = UV − mv
hist = Sample(t1, histUV)
histTM = Tonemap(hist)
clamped = clamp(histTM, lower, upper)

// === 7. Blend factor (Playdead-style) ===
lowerLum = dot(lower, lumWeights)
upperLum = dot(upper, lumWeights)
lumRange = upperLum − lowerLum
clampedLum = dot(clamped, lumWeights)
nearDist = min(|clampedLum − lowerLum|, |clampedLum − upperLum|)
blendX = 0.125 × velW × nearDist
blendFactor = blendX / (lumRange + blendX)

// === 8. Flicker + OOB override ===
// t4.g at history UV: negative = flicker candidate
flicker = (centerNotValid && t4.g < 0 && motionConsistent) ? 1 : 0
oob     = (histUV outside [0,1]) ? 1 : 0
blendFactor = saturate(blendFactor + flicker + oob)

// === 9. Blend + inverse tonemap ===
current = Load(t0, centerPix)     // current frame at integer pixel
resolved = lerp(clamped, Tonemap(current), blendFactor)
// Inverse tonemap: r' = r / (1 − dot(r, gLum))
lumR = min(dot(resolved, gLum), 0.9999)
resolved /= (1 − lumR)
Out.o0.xyz = max(resolved, 0)
Out.o0.w = 1

// === 10. Output motion (for motion blur prepass) ===
mvLen2 = dot(mv, mv)
mvScale = saturate(rsqrt(max(mvLen2, 1e-8)) × normScale)
outMV = mv × mvScale × scale.xy
outLen = sqrt(dot(outMV, outMV))
Out.o1.x = 1 / max(outLen, 1e-8)
Out.o1.y = centerValid ? −linearDepth : linearDepth
```

## Notes
- Karis-style TAA: AABB computed in tonemapped space
- Extended AABB: `upper = (cross + max(cross, diag)) × 0.5` — more aggressive than vanilla Karis
- `Tonemap(c) = c / (dot(c, gLum) + 1)` — Reinhard-style per-component
- References: [Karis 2014, "High-Quality Temporal Supersampling"]; [Playdead 2016, "Temporal Reprojection"]
