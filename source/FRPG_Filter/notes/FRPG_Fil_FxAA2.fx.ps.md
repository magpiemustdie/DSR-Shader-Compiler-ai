# FRPG_Fil_FxAA2 — Pseudocode

Full FXAA 2.0 (Lottes 2011) with iterative 4-pass edge search at step sizes 1.5, 2, 4, 12.

## Inputs
- `t0` = scene color (s0, luma via `.y` = green channel)
- `cb0[12]` = ScreenSize (`.zw` = 1/size)

## Output
- `o0` = anti-aliased color (or passthrough if no edge detected)

## Algorithm
```
// === 1. Gather 5 luma samples (center + 4 corners) ===
center  = Sample(t0, UV)                       // r0 = full color
lumaC   = center.g

// GatherGreen returns .y channel from 4 texels in 2×2 block:
// gather4 at UV → (lumaNE=top-right, lumaNW ???)
g = GatherGreen(t0, UV)                        // returns (g.x, g.y, g.z, g.w) = ?
lumaNE = g.x         // top-right (from gather4 default)
lumaNW = g.y         // after some swizzle
lumaSE = g.w
lumaSW = g.z

// gather4 at UV with offset (-1,-1) → shifted 2×2
g2 = GatherGreen(t0, UV, int2(-1,-1))          // returns swizzled xzw
lumaNW2 = g2.x
lumaN2  = g2.z        // top-center, offset block
lumaW2  = g2.w        // center-left

// Full 5-sample min/max (center + 4 corners)
lumaMin = min(lumaC, lumaNE, lumaSE, lumaNW2, lumaSW)
lumaMax = max(lumaC, lumaNE, lumaSE, lumaNW2, lumaSW)
lumaRange = lumaMax − lumaMin

// Early out threshold: 0.166 × max or 0.0833 absolute
if (lumaRange < max(lumaMax × 0.166, 0.0833)):
    Output = center
    return

// === 2. Edge direction detection (horizontal vs vertical) ===
// Additional samples at (1,-1) and (-1,1) offsets
lumaNE2 = Sample(t0, UV, int2(1,-1)).g       // .x from xzwy swizzle = green
lumaSW2 = Sample(t0, UV, int2(-1,1)).y       // .y from yxzw swizzle = green

// Horizontal gradient sum of absolute differences:
//   |NW-C| + |C-NE| + |SW-C| + |C-SE|
//   using effective taps: top row = (NW2, NE), bottom row = (SW, SE2)
gradH = |lumaNW2 − lumaNE| × 2 + |lumaSW − lumaSE| × 2    // approximated
//   actually: topRow = NW2 + NE, bottomRow = SW + SE
//   gradH = |(NW2+NE) − 2×lumaC| × 2 + |(SW+SE) − 2×lumaC| × 2
// Simplified from DXBC: r3.x = abs(NW2+NE-2*lumaC)*2 + abs(SW+SE-2*lumaC)*2
//   in code: r3.x = abs(r3.y)*2 + abs(r4.y) where r3.y = r1.x+r2.y - 2*lumaC, r4.y = r1.z* -2 + r1.y+r2.w

// Vertical gradient (similar computation with swapped axes)
gradV = (same structure, vertical pairs)
//   r1.y = gradV magnitude

isHorizontal = (gradH >= gradV)

// Select min/max endpoints based on edge direction
lumaMinEnd = isHorizontal ? lumaNW2 : lumaNE
lumaMaxEnd = isHorizontal ? lumaNE2 : lumaSW2
t stepSign = isHorizontal ? ScreenSize.w : ScreenSize.z   // pixel step (1/height or 1/width)
stepSign = isHorizontal ? -stepSign : stepSign             // direction

// === 3. Sub-pixel offset estimation ===
// Average of 8 neighbor luma → averageLuma
// lumaOffset = (averageLuma − lumaC) / lumaRange
// blendFactor = clamp(lumaOffset × 1/lumaRange, 0, 1)
//   r2.y = sumAllNeighborLuma * 0.083333 − lumaC
//   r1.w = saturate(1/lumaRange * abs(r2.y))
// r1.w = sub-pixel blend factor (0..1)

// === 4. Compute initial edge endpoints ===
// Starting from current UV, step in both directions along edge
// Endpoint A: UV + (−stepSign × 0.5, +stepSign × 0.5) ?   (depends on direction)
// Endpoint B: UV + (+stepSign × 0.5, −stepSign × 0.5) ?
// More precisely from DXBC:
//   r3.yz = stepSign × 0.5 + UV          // initial search positions
//   r3.y = isHorizontal ? r3.y : UV.x     // clamp to axis based on direction
//   r3.z = isHorizontal ? UV.y : r3.z
//   r4.xy = r3.yz − (stepPixel, 0)        // endpoint A start
//   r5.xy = r3.yz + (stepPixel, 0)        // endpoint B start
// where stepPixel = (isHorizontal ? 1/width : 1/height) or 0

// Initial sample of endpoint A luma
lumaA_sample = Sample(t0, r4.xy).b         // .z from xzyw = green
lumaB_sample = Sample(t0, r5.xy).w         // .w from xzwy = green

// Threshold for edge endpoints:
// mid = lumaCenter + (lumaMaxEnd − lumaCenter) × 0.5
//   or equivalently: (lumaMaxEnd + lumaCenter) × 0.5
// Accept if: |sampleLuma − lumaCenter| ≥ threshold × 0.25 × lumaRange
threshold = lumaRange × 0.25        // r2.x

// === 5. Four-pass iterative edge search ===
// Steps: [1.5, 2.0, 4.0, 12.0] pixels per iteration
continueSearch = true

for step in [1.5, 2.0, 4.0, 12.0]:
    if !continueSearch: break

    if endpointA_not_done:
        sampleA = Sample(t0, r4.xy).g      // green at endpoint A
        diffA = lumaDiff = (lumaMaxEnd − lumaC) × 0.5 − (sampleA − lumaC)
        if |diffA| ≥ threshold:
            endpointA_done = true          // found edge boundary
        else:
            r4.x -= stepSign × step        // march further along edge

    if endpointB_not_done:
        sampleB = Sample(t0, r5.xy).g
        diffB = ...
        if |diffB| ≥ threshold:
            endpointB_done = true
        else:
            r5.x += stepSign × step

    if both_done: continueSearch = false

// === 6. Compute final sub-pixel offset ===
// Distance from center to each endpoint
distA = r4.x − UV.x                        // for horizontal edge
distB = r5.x − UV.x
// (or the appropriate axis)
distA = isHorizontal ? distA : r4.z − UV.y
distB = isHorizontal ? distB : r5.z − UV.y

// Convert to offset fraction (0..1 from center to edge)
span = distA + distB
invSpan = 1 / span
offset = min(distA, distB) × (−invSpan) + 0.5
       = 0.5 − min(distA, distB) / span

// Blend with sub-pixel factor
finalOffset = max(subPixelBlend, offset)
// offsetSign/select based on which side is closer
// Apply sign from direction
finalUV = UV + finalOffset × stepSign        // for horizontal case
//   = isHorizontal ? (finalUV.x, UV.y) : (UV.x, finalUV.y)

// === 7. Sample at final position ===
result = Sample(t0, finalUV)
Output = (result.xyz, center.g)               // preserve center luma in alpha
```

## Notes
- Green-channel-only luma detection matches original FXAA 2.0 (Lottes 2011)
- 4-pass iterative search with growing step sizes is characteristic of FXAA 2.0 (FXAA 3.x uses different end-search)
- Sub-pixel blend reduces aliasing on near-horizontal/vertical lines
- References: [Lottes 2011, "FXAA"]
