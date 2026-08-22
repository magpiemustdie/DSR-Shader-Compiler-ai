# FRPG_Fil_SAO_Blur — Pseudocode

SAO bilateral blur: 9-tap depth-aware blur of AO value. Blurs along diagonal (or axis) determined by blur step.

## Inputs
- `t0` = SAO result from SAO_Main:
  - `.x` = AO value
  - `.y` = depthHi (coarse depth)
  - `.z` = depthLo (fine depth)
- `cb0[72]` = SAOParam:
  - `xy` = blur step (pixel offset per tap, can be diagonal like (1,1))
- `cb0[12]` = ScreenSize

## Output
- `o0.x` = blurred AO
- `o0.yz` = center depth channels (passthrough)
- `o0.w` = 1

## Algorithm
```
DecodeDepth(enc):
    return dot(enc, (0.996109, 0.003891))

BilateralWeight(centerDepth, sDepth, gaussW):
    diff = -abs(centerDepth - sDepth) * 2000 + 1
    return max(diff, 0) * gaussW

iCoord    = UV * ScreenSize.xy
pixPos    = floor(UV * ScreenSize.xy)
center    = Load(t0, iCoord).xyz
centerDepth = DecodeDepth(center.yz)

if centerDepth == 1:                        // far plane — skip blur
    Output = (center.x, center.yz, 1)
    return

aoAcc  = center.x * 0.153170                // center weight
wTotal = 0.153170

// Asymmetric 9-tap pattern (DXBC-exact order and weights):
// tap offset   gauss weight
//   -4, -4      0.362970
//   -3, -3      0.392902
//   -2, -2      0.422649
//   +3, +3      0.422649     ← note: +3, not -1
//   -1, -1      0.444893
//   +1, +1      0.444893
//   +2, +2      0.422649
//   +3, +3      0.392902     ← +3 again (different r2 source register)
//   +4, +4      0.362970

for each tap (offset, gaussW):
    sc = pixPos + blurStep * offset
    s  = Load(t0, sc).xyz
    w  = BilateralWeight(centerDepth, DecodeDepth(s.yz), gaussW)
    aoAcc += s.x * w
    wTotal += w

ao = aoAcc / (wTotal + 0.0001)

Output = (ao, center.yz, 1)
```

## Notes
- 9-tap pattern is intentionally asymmetric (DXBC matches original PS3/X360 assembly)
- Bilateral weight: exponential falloff with depth difference scaled by 2000
- Far plane (depth=1) bypass: early-out preserves background AO=1
- References: [McGuire et al. 2012, "Scalable Ambient Obscurance"]
