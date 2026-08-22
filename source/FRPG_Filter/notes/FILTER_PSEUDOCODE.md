# FRPG Filter Shaders — Logical Pseudocode Overview

## 1. SAO (Scalable Ambient Obscurance) — Pixel Shaders [Ref 1–5]

### FRPG_Fil_SAO_Depth
Linearizes the hardware depth buffer to view-space Z.
```
Input:  t0 = raw depth buffer
Output: float4(viewZ, 1, 1, 1)
Logic:
  viewZ = near*far / (depth * (near-far) + far)
```

### FRPG_Fil_SAO_Main
5-tap screen-space AO inspired by "Scalable Ambient Obscurance" (McGuire et al.).
```
Input:  t0 = linearized depth (from SAO_Depth)
        cb0[72] = (radius, maxRadius, mipBias, intensity)
        cb0[73] = (projScale.xy, projOffset.zw)
Output: float4(ao, depthHi, depthLo, 1)

Algorithm:
  viewZ = Load(t0, iCoord).r
  vsPos = (pixCenter * projScale + projOffset) * viewZ  → view-space position
  normal = normalize(cross(ddx(vsPos), ddy(vsPos)))
  radiusPx = radius / viewZ * projScale.x
  mipOffset = log2(radiusPx) * mipBias

  aoAcc = 0
  for 5 directions:
    angle = i * 8.792 + hash(PixelPos)      // golden-angle spiral, randomized
    dir = (cos(angle), sin(angle))
    stepR = radiusPx / radius * i
    samplePos = dir * stepR * 0.2 + iCoord

    mipLevel = clamp(log2(stepR) - 3, 0, 5)
    sViewZ = Load(t0, samplePos >> mipLevel, mipLevel)

    sVsPos = (samplePix * projScale + projOffset) * sViewZ
    diff = sVsPos - vsPos
    r2 = dot(diff, diff)
    vv = max(maxRadius² - r2, 0)
    vn = dot(diff, normal) - mipOffset * 0.301
    ao = max(vn / (r2 + 0.01), 0)
    aoAcc += vv³ * ao

  ao = max(1 - aoAcc / (radius⁴) * intensity, 0)

  // Sub-pixel ddx/ddy correction at screen edges
  ao = ddx/ddy-corrected for pixels at screen borders

  // Pack depth into yz
  depthEncoded = viewZ * (1/300)
  Out = float4(ao, floor(depthEnc*256)/256, frac(depthEnc*256), 1)
```

### FRPG_Fil_SAO_Blur
9-tap bilateral blur of SAO, preserving depth edges.
```
Input:  t0 = (ao, depthHi, depthLo, _)
        cb0[72].xy = blur step direction
Output: float4(blurredAO, centerDepthHi, centerDepthLo, 1)

Algorithm:
  center = Load(t0, iCoord)
  centerDepth = decode(center.yz)  // dot(enc, (0.996109, 0.003891))

  if centerDepth == 1: early-out (no AO at far plane)

  aoAcc = center.x * 0.153170          // center gaussian weight
  wTotal = 0.153170

  for 8 taps at offsets [-4,-3,-2,+3,-1,+1,+2,+3,+4] × step:
    s = Load(t0, iCoord + offset * step)
    sDepth = decode(s.yz)
    diff = saturate(1 - abs(centerDepth - sDepth) * 2000)
    w = diff × gaussWeight[tap]
    aoAcc += s.x * w
    wTotal += w

  result = aoAcc / (wTotal + 0.0001)
  Output = (result, centerDepthEncoded, 1)
```

### FRPG_Fil_SAO_Minify
Mip-minification with interleaved access pattern for the SAO depth mip chain.
```
Input:  SV_Position (no UVs)
        t0 = SAO depth buffer
Output: float4(texel at revCoord)

Algorithm:
  revCoord.x = (pos.x & ~1) | ((pos.y & 1) ^ 1)   // flip LSB based on other axis parity
  revCoord.y = (pos.y & ~1) | ((pos.x & 1) ^ 1)
  Out = Load(t0, revCoord)
```

### FRPG_Fil_SAO_Combine
Moves AO value into alpha channel for compositing.
```
Input:  t0 = (ao, _, _, _)
Output: float4(0, 0, 0, ao)
```

---

## 2. SSAO (Screen-Space Ambient Occlusion) — Compute Shaders [Ref 27–29]

### FRPG_Compute_SSAO_PrepareDepthBuffers1
Linearizes depth and builds a hierarchical depth buffer (DS2x, DS4x with atlas variants).
```
Thread group: 8×8, each thread processes 4 pixels (2×2 quad × 4 sub-blocks)
Outputs:
  u0 = full-res linearZ
  u1 = DS2x (half-res)
  u2 = DS2xAtlas (atlas-packed half-res)
  u3 = DS4x (quarter-res)
  u4 = DS4xAtlas

Algorithm:
  base = groupID × 16 + groupThreadID
  for each of 4 pixels in a 2×2 block at offsets (0,0), (0,8), (8,0), (8,8):
    depth = Load(t0, coord)
    viewZ = (ZNear+ZNear) / ((ZNear+ZFar) - depth × (ZFar-ZNear))
    Store to groupshared LDS[threadIdx + offset]
  Sync

  DS2x = LDS[stride 2]              // half-res sample
  Write u1, u2
  if (groupIndex & 9 == 0):          // every 9th thread
    DS4x = DS2x >> 1                // quarter-res sample
    Write u3, u4
```

### FRPG_Compute_SSAO_PrepareDepthBuffers2
Continues mip chain: downsamples DS4x → DS8x → DS16x.
```
Similar to pass 1 but reads from DS4x and builds DS8x/DS16x with atlas variants.
```

### FRPG_Compute_SSAO_Render1 (8×8) / FRPG_Compute_SSAO_Render2 (16×16)
Computes SSAO values from the depth array using groupshared-based sampling.
```
Thread group: 8×8 (Render1) or 16×16 (Render2)
Uses groupshared LDS[256] for depth samples

Algorithm:
  Gather 4 depth samples from t0 (Texture2DArray) into groupshared
  Sync

  For each direction (4–8 neighbors in LDS):
    s = neighborDepth × projScale.x - projOffset.x
    t = neighborDepth × projScale.y - projOffset.y
    ao += saturate(max(s,t) × normScale) + max(minV,maxV) - minV × saturate(minV × normScale)

  ao = ao × 0.5 × param3.w
  ao = 1 - ao × intensity × finalScale

  Write with interleaved addressing:
    outCoord = (threadID.xy << 2) | (threadID.z & 3, threadID.z >> 2)
```

### FRPG_Compute_SSAO_BlurUpsample (+ variants)
Bilateral upsample from half-res AO to full-res using depth-guided weights.
```
Thread group: 8×8

Algorithm:
  Gather 4 half-res depth+AO samples into groupshared LDS
  Sync

  For each of 4 output pixels:
    centerDepth = Gather(fullDepth, uvFull)[p]
    Gather 4 nearest AO samples from LDS
    Gather 4 corresponding depth samples from LDS

    weights[4] = (9, 3, 1, 3) / (abs(depth - centerDepth) + eps)
    wTotal = sum(weights) + baseWeight
    aoSum = dot(AO, weights) + baseWeight
    result = aoSum / wTotal
```

Variants:
- **BlendOut**: multiplies result by blend mask from t4
- **PreMin**: takes min of two AO layers before upsampling
- **PreMinBlendOut**: combines both

---

## 3. Depth of Field (DOF) — Pixel Shaders [Ref 30–33]

### FRPG_Fil_Dof_DofRate
Computes DOF rate from depth + vignette.
```
Input:  t1 = depth buffer
        cb0[7] = AimBloomParam (vignette start, invRange, strength)
        cb0[8] = CameraParam
        cb0[9] = DofFarParam (start, end, scale)
Output: float4(vignette×strength + dofRate)  [all 4 channels identical]

Algorithm:
  viewZ = near×far / (depth × (near-far) + far)
  farRate = saturate((viewZ - farStart/CameraY) / (farEnd/CameraY - farStart/CameraY))
  farRate = saturate(farRate × farScale)

  dist = length((UV - 0.5) × ScreenSize)
  vignette = saturate((dist - vignetteStart) × vignetteInvRange)

  result = vignette × strength + farRate
```

### FRPG_Fil_Dof_DofRate_CB
Checkerboard variant — same algorithm but reads MSAA depth at half-res with checkerboard sample index.

### FRPG_Fil_Dof_NearRate
Computes DOF near rate from depth.
```
Same linearization, outputs alpha = nearRate × scale, RGB = 0.
```

### FRPG_Fil_Dof_UnfocusNearRate3x3
3×3 max-filter for near rate: max of 5 taps (4 corners + center). RGB = 1, A = max near rate.

### FRPG_Fil_Dof_DownSample
Simple 4-sample box downsample: samples t0 at UV, weight 0.25.

### FRPG_Fil_Dof_WeightedDownsample
5-sample weighted downsample with rotated grid offsets.
```
5 taps with weights 0.2 each.
Tap positions from cbuffer (rotated grid pattern).
```

### FRPG_Fil_Dof_GaussX / GaussY
9-tap (4 symmetric pairs + center) Gaussian blur in one direction.
```
VS provides UV offsets for ±1.5, ±3.5, ±5.5, ±7.5 pixels.
Weights from cb0[13..17].

Algorithm:
  acc = Sample(center) × weight0
  for each pair (a, b):
    acc += (Sample(a) + Sample(b)) × weightN
  // GaussY is identical; direction from VS UVs
```

### FRPG_Fil_Dof_GaussX_Adv / GaussY_Adv
Advanced variant with per-channel ratio weighting.
```
Same structure, but weights are modulated by:
  ratio = saturate(sample / center)
  sampleWeight = ratio × gaussWeight
```

### FRPG_Fil_Dof_StretchAlphaX / StretchAlphaY
Max-filters alpha across 8 taps to stretch DOF alpha in one direction.
```
for 8 taps:
  maxA = max(maxA, tap.a)
result = (maxA - center.a) × center.a + center.a
```

### FRPG_Fil_Dof_Unfocus3x3
5-tap unfocus with depth-aware corner weighting.
```
4 corners + center. Corner weight = 0.212121 if corner.a >= center.a, else 0.
Center weight = 1 - sum(cornerWeights).

Algorithm:
  for each corner:
    weight = (corner.a >= center.a) ? 0.212121 : 0
  centerWeight = 1 - sum(weights)
  result = sum(corners × weights) + center × centerWeight
```

### FRPG_Fil_Dof_BlurUpSample
5-tap upsample (4 corners + center), corner weight = 0.25.
```
Identical to Unfocus3x3 but weight = 0.25 instead of 0.212121.
```

### FRPG_Fil_Dof
Composite: blends 4 DOF layers (sharp, near, mid, far blur) based on DOF rate.
```
Input:  t0=sharp, t1=nearBlur, t2=midBlur, t3=farBlur,
        t4=DOFrateOverride, t5=depth
Output: blended result

Algorithm:
  viewZ = linearize(depth)
  dofFar = saturate((viewZ - farStart) / (farEnd - farStart)) × farScale
  dofRate = max(dofFar, Sample(t4).w)   // override from DOF rate texture

  weights = saturate(dofRate × blendRange + blendOffset)   // 4 blend factors
  // Convert to per-layer blend weights by computing differences
  diffs = weights.yzw - weights.xyz

  result = Sample(nearBlur) × diffs.x
         + Sample(sharp)   × weights.x
         + Sample(midBlur)  × diffs.y
         + Sample(farBlur)  × diffs.z
```

### FRPG_Fil_Dof_CB
Checkerboard variant — same composite but reads MSAA depth via `ld` (Load) at half-pixel coords.

### FRPG_Fil_Dof_VS
Vertex shader for DOF — generates 4 pairs of UV offsets at ±1.5/3.5/5.5/7.5 pixels for Gauss blur direction.

---

## 4. HDR / Tonemapping — Pixel Shaders [Ref 15–21]

### FRPG_Fil_SampleLumInitial
Log-luminance downsample: computes average log-luminance over 9 taps.
```
Algorithm:
  for 9 taps (3×3 with center):
    lum = max(dot(Sample(tap), luminanceWeights), 0.0001)
    sumLog += log2(lum) × log(2)   // = ln(lum)
  result = sumLog / 9
```

### FRPG_Fil_SampleLumFinal
Reads log-luminance texture (1/64 res) and computes geometric mean luminance.
```
16 fixed-UV samples of previous log-luminance result:
  mean = exp2(sum(logLumSamples) × 0.090168)   // exp2(sum × 1/16 × ln(2)?)
```

### FRPG_Fil_CalcAdaptedLum
Exponential smoothing of adapted luminance over time.
```
prevLum = Sample(t0)
adapted = prevLum + (currentLum - prevLum) × adaptSpeed
adapted = clamp(adapted, minLum, maxLum)
result = adapted × keyValue
```

### FRPG_Fil_CalcAdaptedLum_PBL
PBL variant — no min/max clamp, NaN-guarded output.

### FRPG_Fil_HDR
Basic HDR composite: bloom + scene with noise overlay.
```
Input:  t0=scene, t1=bloom, t2=noise
        cb0[56].x = bloomScale, cb0[56].z = sceneScale

Algorithm:
  scene = saturate(Sample(t0) × sceneScale)
  hdr = bloomScale × Sample(t1) + scene

  // Soft-light noise blend:
  noise = Sample(t2)
  mul2 = hdr × noise × 2
  screen = 1 - 2×(1-noise)×(1-hdr)
  blended = noise < 0.5 ? mul2 : screen
  result = lerp(hdr, blended, noiseBlend)
```

### FRPG_Fil_HDR_ColAdj
HDR + 4×4 color adjustment matrix + noise overlay + star texture.
```
Same as HDR but adds:
  col = colorMatrix × float4(result, 1)  // 4×4 color correction
  star = Sample(starTexture) blended in
```

### FRPG_Fil_HDR_Menu
Simple Reinhard-like filmic tonemapper for menus.
```
Input:  t0 = HDR scene (no cbuffer!)
Output: gamma-corrected LDR

Algorithm:
  // Filmic curve (shoulder + knee):
  numerator = x × (0.1x + 0.03) + 0.005
  denominator = x × (0.1x + 0.3) + 0.075
  tonemapped = numerator / denominator

  // Scale to [0,1]:
  tonemapped = (tonemapped - 0.066667) × 1.875

  // Gamma 2.2:
  result = exp2(log2(saturate(tonemapped)) × 0.454545)
```

### FRPG_Fil_HDR_PBL
Hable filmic tonemapper (PBL variant).
```
Input:  t0=scene, t1=bloom, t2=noise, t5=adaptedLum
        cb0[54] = (exposureKey, whitePoint, minLum, maxLum)
        cb0[55] = (A, B, C, D) — Hable curve params

Algorithm:
  exposed = (exposureKey / adaptedLum) × (bloom × bloomScale + scene)
  // Hable curve:
  num = exposed × (A×exposed + B×C) + minLum×D
  den = exposed × (A×exposed + B)   + maxLum×D
  tonemapped = num / den
  whiteScale = f(whitePoint) - minLum/maxLum
  result = (tonemapped - minLum/maxLum) / whiteScale

  // Gamma + noise overlay (same soft-light as HDR)
```

### FRPG_Fil_HDR_PBL_ColAdj
PBL HDR + color adjustment — supports 3 tonemapper modes.
```
Modes (cb0[57].x):
  0: Hable filmic (same as HDR_PBL)
  1: Reinhard — lumTM = lum / (lum + 1)
  2: Reinhard2 — lumTM = lum × (1 + lum/wp²) / (lum + 1)

Then: color matrix, gamma 2.2, noise soft-light overlay, alpha = luminance.
```

### FRPG_Fil_BrightPassFilter
Bloom bright-pass with depth-based distance rate.
```
Input:  t0=scene, t1=depth
Output: max(scene - threshold, 0) × depthDistanceFalloff
```

### FRPG_Fil_HDR_VS
Vertex shader for HDR variants — outputs TEXCOORD1 with noise UV transform.

---

## 5. Motion Blur — Pixel + Compute Shaders [Ref 22–24]

### FRPG_Fil_MotionBlurPre
Motion blur prepass: computes per-pixel motion vector length and view-space depth.
```
Input:  t0=velocity buffer, t1=depth buffer
        cb0[57] = (scaleX, scaleY, normScale)
        cb0[58..61] = InvViewProj
        cb0[74,75,77] = PrevViewProj
        cb0[78] = camera world offset
Output: float2(1/mvLen, viewZ)

Algorithm:
  depth = SampleDepth(uv)
  viewZ = near×far / (depth × (near-far) + far)

  // Reprojection:
  ndc = uv × (2, -2) + (-1, 1)
  worldPos = InvViewProj × float4(ndc, depth, 1)
  worldPos /= w
  worldPos += cameraOffset

  prevUV = PrevViewProj × float4(worldPos, 1)
  prevUV = prevUV.xy / prevUV.w × (0.5, -0.5) + 0.5
  mv = uv - prevUV

  // Velocity override from t0:
  velOverride = Sample(velocity).xy × (1, -1)
  mv = (velOverride.x < 1) ? velOverride : mv

  // Normalize and scale:
  mv *= saturate(rsqrt(dot(mv, mv)) × normScale)
  mv *= (scaleX, scaleY)
  mvLen = length(mv)
  Output = (1/mvLen, viewZ)
```

### FRPG_Fil_MotionBlurPre_CB
Checkerboard variant — MSAA depth with checkerboard frame offset.

### FRPG_Compute_MotionBlurTiles
Compute shader: finds max-velocity tile vector for 16×16 tile.
```
Thread group: 16×16, each thread processes 4 pixels (4×4 quad)

Algorithm:
  For each of 4 pixels in 4×4 block:
    depth = Load(t1)
    Reproject: ndc → world → prevUV → mv (same as MotionBlurPre)
    velOverride = Load(t0).xy × (1, -1)
    mv = (velOverride.x < 1) ? velOverride : mv
    mv *= saturate(rsqrt(mv²) × normScale) × (scaleX, scaleY)
    Keep max(mv²) across 4 pixels

  Store to LDS, then hierarchical reduction (×4, ×4, ×4):
    Thread 0 writes final max-velocity tile vector to u0[groupID.xy]
```

### FRPG_Compute_MotionBlurTiles_CB
Checkerboard variant — identical algorithm.

### FRPG_Fil_MotionBlurFinal
Tile-based motion blur: reads tile max velocity and applies directional blur.
```
Input:  t0 = tile max velocity, t1 = HDR scene, t2 = per-pixel velocity (1/mvLen, viewZ)
Output: blurred result

Algorithm:
  tileMV = Sample(t0, uv)
  sceneColor = Sample(t1, uv)
  perPixelVel = Sample(t2, uv) → (1/mvLen, viewZ)

  tileLen² = dot(tileMV, tileMV)
  pixelSize² = dot(1/ScreenSize, 1/ScreenSize)

  if tileLen² > pixelSize²:
    blurVector = tileMV × blurScale

    // Compute 4 sample positions along blur direction:
    // 1/3, 2/3, 4/3, 5/3 of the blur vector, in both directions
    // (forward and backward from center)

    For each of 4 sample pairs (forward/backward):
      Sample(t2) for per-pixel velocity weight
      Compute bilateral weight from velocity match
      Accumulate weighted color samples

    result = (accumulated + centerColor) / (totalWeight + 1)
  else:
    result = sceneColor

  Output = result
```

### FRPG_Fil_CameraBlur
Camera motion blur: 7 samples along motion vector with depth testing.
```
Uses reprojection matrix for motion vector, 7 samples with depth comparison.
```

### FRPG_Fil_CameraBlurPower
Computes camera blur power from depth.
```
blurPower = key / (depth × scale + bias) × 1/32
```

---

## 6. TAA (Temporal Anti-Aliasing) [Ref 6–10]

### FRPG_Fil_ResolveTAA
Full TAA resolve with motion vector clip, neighborhood clamping, and tonemapped blend.
```
Input:  t0 = current frame color
        t1 = history buffer (previous resolved frame)
        t2 = depth buffer
        t3 = motion vectors
        t4 = misc (flicker detection)
        cb0[56] = MotionScale
        cb0[57] = MotionParam
        cb0[58..61] = InvViewProj
        cb0[74,75,77] = PrevViewProj
        cb0[78] = camera offset
Output: float4(resolvedColor, 1), float2(1/mvLen, linearDepth)

Algorithm:
  // 1. Gather 4 depth samples at pixel corners, pick closest
  depths = GatherRed(t2, uv)
  bestDepth = min(depths)
  minUV = uv + offsetTo(depths, bestDepth) × 1/ScreenSize

  // 2. Reprojection (cam-era motion vector)
  linearDepth = near×far / (bestDepth × (near-far) + far)
  ndc = minUV × 2 - 1
  worldPos = InvViewProj × float4(ndc.x, -ndc.y, bestDepth, 1)
  worldPos.xyz /= w; worldPos += cameraOffset
  prevUV = PrevViewProj × float4(worldPos, 1)
  prevUV = prevUV.xy / prevUV.w × (0.5, -0.5) + 0.5
  mvCam = minUV - prevUV

  // 3. Object motion vector override
  mvObj = Sample(t3, minUV).xy × (1, -1)
  mv = (mvObj.x < 1) ? mvObj : mvCam  // object MV has priority

  // 4. Velocity-based blend weight
  vel = min(length(mv × ScreenSize), 1)
  velW = MotionScale.x × vel + 1

  // 5. AABB construction (3×3 neighborhood, cross + diagonal)
  Sample 9 pixels in 3×3 cross (+) and diagonal (×) pattern
  For each:
    color = Sample(t0, pixel)
    tonemapped = color / (luminance(color) + 1)  // Reinhard tonemap
    mvValid = Sample(t3, pixel).x < 1

  crossMin = min(tonemapped over cross neighbors)
  crossMax = max(tonemapped over cross neighbors)
  diagMin  = min(tonemapped over diagonal neighbors)
  diagMax  = max(tonemapped over diagonal neighbors)

  // 6. Expanded AABB
  upper = (crossMax + max(crossMax, diagMax)) × 0.5
  lower = (crossMin + min(crossMin, diagMin)) × 0.5

  // 7. Fetch and clamp history
  histUV = uv - mv
  history = Sample(t1, histUV)
  histTM = Tonemap(history)
  clamped = clamp(histTM, lower, upper)

  // 8. Blend factor from luminance distance
  lumRange = dot(upper - lower, luminanceWeights)
  nearDist = min(|clampedLum - lowerLum|, |clampedLum - upperLum|)
  blend = (0.125 × velW × nearDist) / (lumRange + 0.125 × velW × nearDist)

  // 9. Flicker / out-of-bounds override
  flicker = !centerHasObjectMV && Sample(t4, histUV).g < 0 && motionConsistent
  oob = histUV outside [0,1]
  blend = saturate(blend + flicker + oob)

  // 10. Blend and untonemap
  resolved = lerp(clamped, Tonemap(currentColor), blend)
  result = resolved / (1 - dot(resolved, lumWeight))

  // 11. Output motion vector for next frame
  mvOut = mv × scale × saturate(rsqrt(mv²) × MotionParam.z)
  Output = (result, 1, 1/length(mvOut), vC ? -linearDepth : linearDepth)
```

### FRPG_Compute_ResolveCB
Checkerboard resolve — no-op (actual resolve in ResolveTAA).

---

## 7. Bloom / Star / Lens Effects [Ref 34–35]

### FRPG_Fil_Bloom_improved (→ Bloom.fpo)
15-tap weighted Gaussian bloom.
```
Input:  t0 = HDR scene
        cb0[22..36] = 15 sample offsets
        cb0[38..52] = 15 sample weights
Output: bloom accumlation

Algorithm:
  acc = 0
  for 15 taps:
    acc += Sample(t0, uv + offset[i]) × weight[i]
```

### FRPG_Fil_Star
8-tap directional star/streak filter.
```
Same structure as GaussBlur5x5 but 8 taps.
```

### FRPG_Fil_Sfx_Glow_Blur
15-tap glow blur for special effects — same structure as Bloom_improved.

### FRPG_Fil_LightShaft
Radial blur toward screen-space light position (10 samples).
```
Input:  t0 = scene
        cb0[69] = screen-space light UV
        cb0[70] = (maxLength, colorScale, decay)

Algorithm:
  dir = (uv - lightUV) × ScreenSize
  len = max(length(dir), 0.0001)
  clampedLen = min(len, maxLength)
  dir = (clampedLen/len) × dir × 1/ScreenSize

  uv = In.UV
  acc = (0,0,0,1)
  for 10 steps:
    acc.rgb += Sample(t0, uv).rgb × acc.a
    uv -= dir × 0.1
    acc.a *= decay

  result = acc.rgb × colorScale
```

---

## 8. Screen-Space Effects (SSS, FxAA, Bilateral, Blur) [Ref 11–14, 26]

### FRPG_Fil_FxAA2 (and FxAA2_High)
Full FXAA 2.0 with iterative edge search (4 passes: 1.5, 2, 4, 12 steps).
```
Input:  t0 = scene (uses green channel for luma)
Output: anti-aliased result

Algorithm:
  // 1. Luma edge detection
  centerLuma = Sample(t0, uv).g
  Gather green at 4 corners
  lumaMax = max(all 5 luma values)
  lumaMin = min(all 5 luma values)
  contrast = lumaMax - lumaMin

  threshold = max(lumaMax × 0.166, 0.0833)
  if contrast >= threshold:
    // 2. Determine edge direction
    Sample luma at (+1,-1) and (-1,+1)
    Compute horizontal vs vertical gradient
    Pick major axis (direction of strongest contrast)

    // 3. Iterative edge search (4 passes)
    pos = uv + offset × 0.5  // start at half-pixel
    for each pass with step sizes [1.5, 2, 4, 12]:
      Sample luma at extended positions along edge
      Check if still on edge (luma within contrast range)
      Extend search if still on edge

    // 4. Compute sub-pixel blend
    blend = min(subPixelBlend, contrast-based blend)
    outputPos = uv + blend × offset
    result = Sample(t0, outputPos)
  else:
    result = Sample(t0, uv)  // no AA needed
```

### FRPG_Fil_Bilateral
4-tap depth-weighted bilateral filter.
```
4 samples with depth-based weights:
  weight = 1 / |depthDiff|
Normalized accumulation.
```

### FRPG_Fil_GaussBlur5x5
13-tap weighted Gaussian blur (symmetric pairs from cbuffer).
```
Same structure as DOF Gauss but weights/offsets from cb0[22..34] / cb0[38..50].
```

### FRPG_Fil_SubsurfX

### FRPG_Fil_SubsurfY
Subsurface scattering — 10-tap horizontal/vertical SSS with mask gating.
```
Input:  t0 = scene, t1 = depth, t2 = SSS mask
        UV step = (invViewZ × 0.06, 0) for X, (0, invViewZ × 0.06) for Y

Algorithm:
  if Mask(uv).x == 0: discard

  center = Load(t0, coord)
  centerDepth = linearize(Load(t1, coord))
  invDepth = 1/centerDepth

  // step.x = (ScreenSize.y/ScreenSize.x) × mask / viewZ × 0.06
  // step.y = 0
  step.x = ScreenSize.z × ScreenSize.y × invDepth × mask.x × 0.06

  acc = center × RGBWeights(0.560, 0.669, 0.785)  // center contribution

  for 10 taps (±0.08, ±0.32, ±0.72, ±1.28, ±2.00):
    pos = uv + tapOffset × step.x  // horizontal only (SubsurfX)
    mask = Sample(t2, pos).y
    sample = Load(t0, pos)
    sample = (mask == 0) ? center : sample  // clamp to center if no SSS

    depth = linearize(Load(t1, pos).y)
    depthWeight = saturate(mask.x × abs(centerDepth - depth) × 36)
    sample = lerp(sample, center, depthWeight)  // depth-aware blend

    acc += tapWeight × sample

  result = acc
```

### FRPG_Fil_SubsurfY
Vertical SSS — same as SubsurfX but step is purely vertical, no aspect ratio correction.
```
Same weight table, center accumulation, and depth-aware blend.

Differences from SubsurfX:
  step = (0, invViewZ × mask × 0.06)           // Y-only, no ScreenSize.y/ScreenSize.x factor
  taps sample in Y direction only
```

---

## 9. Compute Shaders (Standalone) [Ref 36]

### FRPG_Compute_CopyExpandedHTile
Copies HTile data, ORing 0xF to mark all 4 sub-tiles as valid.
```
Used after depth resolve for HTILE expansion.
```

---

## 10. Utility Shaders [Ref 36]

### FRPG_Fil_Quad.fx (Vertex Shader)
Standard fullscreen quad VS generated from SV_VertexID.
```
2 triangles (6 vertices) forming a fullscreen quad.
UV = (0,0)→(1,0)→(0,1)→(1,0)→(0,1)→(1,1) or similar.
Used by most post-process filters.
```

### FRPG_Fil_Quad_GaussX / GaussY
VS for DOF Gauss: generates 4 pairs of UV offsets at ±1.5, ±3.5, ±5.5, ±7.5 pixels in X/Y.

### FRPG_Fil_Quad_BlurUpSample
VS for DOF BlurUpSample: 4 diagonal offsets (half-pixel) + center UV.

### FRPG_Fil_Quad_Unfocus3x3
VS for DOF Unfocus3x3: 4 cross-offset corners + center.

### FRPG_Fil_DepthCopy
Copies depth buffer: samples t0, outputs to SV_Target0 and SV_Depth.
```
Color = Sample(t0, uv)
Depth = Color.r  // write same value to depth buffer
```

### FRPG_Fil_DepthCopy_Fragment0 / Fragment1
MSAA depth copy for individual fragments (sample 0 / sample 1).
```
Loads MSAA depth at integer pixel coord. No color output.
```

### FRPG_Fil_DepthCopy_MSAA
MSAA depth copy: min of 2 depth samples, color = white.

### FRPG_Fil_DepthCopy_SingleFragment
Single fragment depth copy from MSAA (Texture2DMS Load at computed coord).

### FRPG_Fil_ThruWithDepth
Passthrough color + copy depth from separate buffer.
```
Color = Sample(t0, uv)
Depth = Sample(t1, uv).r  // write to SV_Depth
```

### FRPG_Fil_BlackBars
Solid black output for letterbox bars.

### FRPG_Fil_CubeBlend
Stub — outputs black. (Cube blend is handled elsewhere.)

### FRPG_Fil_ShadowMapDbg
Debug visualizer: samples t1 with offset, outputs .zxy swizzle.

### FRPG_Fil_Dbg_LogTex
Debug log-space texture visualizer: exp2(sample × log2(e)) = e^sample, clamped.

### FRPG_Fil_DownScale
Dual entry point:
  - FragmentMain_2x2: 4 samples, weight 0.25
  - FragmentMain_4x4: 16 samples, weight 1/16

---

## References

| # | Shader | Algorithm | Paper / Source |
|---|--------|-----------|----------------|
| 1 | SAO_Depth, SAO_Main, SAO_Blur, SAO_Minify | **Scalable Ambient Obscurance** | McGuire, Mara, Luebke. *Scalable Ambient Obscurance*. HPG 2012. [PDF](http://casual-effects.com/research/McGuire2012SAO/) |
| 2 | SAO_Main (spiral sampling) | Golden-angle spiral: θᵢ = 2πτ(i+0.5)/s + φ, τ=7, s=5 | Eq.(6-7) in [McGuire12]. DSR uses 5 samples (paper uses 9) with same τ=7 spiral. |
| 3 | SAO_Main (XOR hash) | Per-pixel random rotation: φ via XOR hash | Eq.(8) in [McGuire12]. DSR uses different hash: `(x*3)^(x*y+y)` vs paper's `30·(x^y)+10·xy`. |
| 4 | SAO_Main (mip selection) | mᵢ = max(⌊log₂(hᵢ)⌋ - 3, 0) | Eq.(9) in [McGuire12]. DSR adds -3 bias. |
| 5 | SAO_Blur | Bilateral reconstruction (9-tap diagonal) | §2.4 in [McGuire12]. Paper uses 1D 7-tap × 2 passes; DSR uses 2D 9-tap single pass. |
| 6 | ResolveTAA | **Temporal Anti-Aliasing** | Karis. *High Quality Temporal Supersampling*. SIGGRAPH 2014. [Slides](http://advances.realtimerendering.com/s2014/epic/TemporalAA.pptx) |
| 7 | ResolveTAA (AABB) | Rounded 3×3 neighborhood: cross+diagonal min/max blended | Karis 2014 (rounded neighborhood). DSR uses RGB space (not YCoCg). |
| 8 | ResolveTAA (clamp vs clip) | History clamped to AABB (not clipped) | Playdead *Temporal Reprojection AA in INSIDE*. [GitHub](https://github.com/playdeadgames/temporal). DSR uses older clamp (not clip/intersect). |
| 9 | ResolveTAA (tonemapped blend) | Reinhard tonemap → lerp → inverse-Reinhard | Karis 2014. Inverse: T⁻¹(y) = y/(1-y). |
| 10 | ResolveTAA (motion vector override) | Per-object MV via velocity buffer, `vel.x < 1` check | Playdead/INSIDE convention. |
| 11 | FxAA2 | **FXAA 2.0 (Quality preset)** | Lottes. *FXAA Whitepaper*. NVIDIA 2011. [PDF](https://developer.download.nvidia.com/assets/gamedev/files/sdk/11/FXAA_WhitePaper.pdf) |
| 12 | FxAA2 (threshold) | `max(edgeThresholdMin, lumaMax * edgeThresholdMax)` where `edgeThresholdMax=0.166`, `edgeThresholdMin=0.0833` | FXAA 3.11 defaults: `FXAA_QUALITY__EDGE_THRESHOLD = 1/6`, `FXAA_QUALITY__EDGE_THRESHOLD_MIN = 1/12`. |
| 13 | FxAA2 (luma) | Green channel as luma (`FXAA_GREEN_AS_LUMA = 1`) | FXAA 3.11 convention for D3D11 without alpha channel luma. |
| 14 | FxAA2 (search steps) | 4 passes at [1.5, 2, 4, 12] with anisotropic acceleration | FXAA Quality preset 3 (12 steps × acceleration). |
| 15 | HDR_PBL_ColAdj (mode 0) | **Hable filmic tonemapper** | Hable. *Filmic Tonemapping Operators*. 2010. [Blog](http://filmicworlds.com/blog/filmic-tonemapping-operators/). Used in Uncharted 2. |
| 16 | HDR_PBL_ColAdj (mode 0) | Hable formula: `((x·(A·x+C·B)+D·E)/(x·(A·x+B)+D·F))-E/F`, divide by `f(whitePoint)` | Standard Hable UC2. DSR bakes E/F into `minLum·D` / `maxLum·D`. |
| 17 | HDR_PBL_ColAdj (mode 1) | Reinhard: `L/(L+1)` | Reinhard et al. *Photographic Tone Reproduction*. 2002. |
| 18 | HDR_PBL_ColAdj (mode 2) | Reinhard2 (with white point): `L·(1+L/W²)/(L+1)` | Extended Reinhard. |
| 19 | HDR_Menu | Lightweight filmic curve: `(0.1x²+0.03x+0.005)/(0.1x²+0.3x+0.075)` → shift → scale → gamma | Simplified Reinhard-like with shoulder. Hardcoded constants approximate Hable curve. |
| 20 | SampleLumInitial/ Final | Log-luminance downsample → geometric mean | Standard HDR adaptation pipeline. |
| 21 | CalcAdaptedLum | Exponential smoothing: `L₊ = L₋ + (Lₜ - L₋)·Δt/τ` | Standard temporal adaptation. |
| 22 | MotionBlurPre | Reprojection-based velocity via InvVP / PrevVP | Standard GPU reprojection. |
| 23 | MotionBlurTiles | 16×16 tile reduction, hierarchical LDS max-velocity | Standard tile-based motion blur. |
| 24 | MotionBlurFinal | Directional blur with velocity-constrained sampling | McGuire et al. *A Reconstruction Filter for Plausible Motion Blur*. HPG 2012. |
| 25 | LightShaft | Radial blur toward light with exponential decay | Standard volumetric light shaft. |
| 26 | SubsurfX/Y | Separable SSS with depth-aware bilateral weight | Jimenez et al. *Separable Subsurface Scattering*. GPU Pro 2, 2011. |
| 27 | SSAO_Render1 | Horizon-based AO: `ao += saturate(max·σ) + max - min·saturate(min·σ)` | Bavoil & Sainz. *Image-Space Horizon-Based Ambient Occlusion*. SIGGRAPH 2009. |
| 28 | SSAO_PrepareDepthBuffers | Hierarchical depth buffer (DS2x → DS4x → DS8x → DS16x) | Standard SAO/SSAO depth mip chain. |
| 29 | SSAO_BlurUpsample | Bilateral upsample with groupshared (9/3/1/3 weights + depth denominator) | Standard depth-guided bilateral upsample. |
| 30 | Dof_DofRate | Vignette-based DOF rate from linearized depth | Standard post-process DOF. |
| 31 | Dof | 4-layer composite (sharp/near/mid/far) with blend weights | Standard split-DOF compositing. |
| 32 | GaussX/Y, GaussX/Y_Adv | 9-tap separable Gaussian blur via VS UV offsets | Standard separable blur. |
| 33 | BlurUpSample, Unfocus3x3 | Depth-aware corner weighting with center fallback | Standard DOF upsample. |
| 34 | BrightPassFilter | `max(scene - threshold, 0)` with depth distance falloff | Standard bloom bright-pass. |
| 35 | Bloom_improved | 15-tap weighted Gaussian via cbuffer offsets | Standard bloom implementation. |
| 36 | FxAA2_VS, Quad_VS, etc. | Fullscreen triangle from SV_VertexID | Standard VS with no inputs (ICB). |
