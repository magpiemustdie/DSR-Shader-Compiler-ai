# FRPG_Fil_SAO_Main — Pseudocode

Main SAO pass: 5-tap screen-space ambient obscurance with mipmapped depth.

## Inputs
- `t0` = linearized depth from SAO_Depth (loaded via `Load` with mip levels)
- `cb0[8]`  = CameraParam (`.y` = far plane)
- `cb0[12]` = ScreenSize (`.xy` = size in pixels, `.zw` = 1/size)
- `cb0[72]` = SAOParam:
  - `x` = radius (world-space)
  - `y` = maxRadius² (pre-squared)
  - `z` = mipBias
  - `w` = intensity
- `cb0[73]` = SAOProj:
  - `xy` = projScale (pixels-to-view-space factor)
  - `zw` = projOffset

## Output
- `o0.x` = AO (ambient obscurance, 0=occluded, 1=open)
- `o0.y` = depthHi (encoded: floor(viewZ * 0.003333 * 256) / 256)
- `o0.z` = depthLo (fractional part of encoded depth)
- `o0.w` = 1

## Algorithm
```
iCoord = UV * ScreenSize.xy                     // integer pixel coordinate
viewZ  = Load(t0, iCoord).r

// Reconstruct view-space position
pixCenter = floor(UV * ScreenSize.xy) + 0.5
vsPos.xy  = viewZ * (pixCenter * projScale.xy + projOffset.zw)
vsPos.z   = viewZ

// Reconstruct normal from depth derivatives
dPdx = ddx_coarse(vsPos)
dPdy = ddy_coarse(vsPos)
normal = normalize(cross(dPdy, dPdx))

// Radius in pixels for mip selection
radiusPixels = radius / viewZ * projScale.x
mipOffset    = log2(radiusPixels) * mipBias

// Random rotation per pixel
randAngle  = ((iCoord.x*3) ^ (iCoord.x*iCoord.y + iCoord.y)) * 10

aoAcc = 0
for i = 0..4:
    fi     = i + 0.5
    stepR  = radiusPixels / radius * fi          // step radius in pixels
    angle  = fi * 8.792 + randAngle              // golden-angle spiral
    dir    = (cos(angle), sin(angle))

    sc     = iCoord + dir * stepR * 0.2          // screen-space sample coord
    inBounds = all(sc >= 0) && all(sc < ScreenSize.xy)

    if inBounds:
        mipLevel = max(log2(stepR) - 3, 0)
        mip      = min((int)mipLevel, 5)
        sViewZ   = Load(t0, sc >> mip, mip).r
    else:
        sViewZ   = farPlane                       // out-of-bounds → far plane

    // Reconstruct sample view-space position
    sPixCenter  = (float2)sc + 0.5
    sVsPos.xy   = sViewZ * (sPixCenter * projScale.xy + projOffset.zw)
    sVsPos.z    = sViewZ

    // AO contribution (McGuire12 eq.3)
    diff = sVsPos - vsPos
    r2   = dot(diff, diff)
    vv   = max(maxRadius² - r2, 0)
    vv³  = vv * vv * vv
    vn   = dot(diff, normal) - mipOffset * 0.30103   // 0.30103 = log2(1.23)?
    ao   = max(vn / (r2 + 0.01), 0)
    aoAcc += vv³ * ao

// Normalize
aoResult = max(1 - aoAcc / (radius⁴) * intensity, 0)

// Sub-pixel ddx/ddy correction at screen edges
subPixel = frac(iCoord * 0.5) - 0.5
ddxAO = ddx_coarse(aoResult)
ddyAO = ddy_coarse(aoResult)
corrX = -ddxAO * subPixel.x + aoResult
corrY = -ddyAO * subPixel.y + corrX

nearHorizEdge = abs(ScreenSize.y - iCoord.y) < 0.02
nearVertEdge  = abs(ScreenSize.x - iCoord.x) < 0.02
aoFinal = nearHorizEdge ? corrX : aoResult
aoFinal = nearVertEdge  ? corrY : aoFinal

// Encode depth for blur pass
depthNorm = saturate(viewZ * 0.003333)
depthHi   = floor(depthNorm * 256) / 256       // stored in .y
depthLo   = depthNorm * 256 - depthHi * 256    // stored in .z

Output = (aoFinal, depthHi, depthLo, 1)
```

## Notes
- 5-tap golden-angle spiral matches McGuire12 algorithm
- Depth is two-component encoded (y=coarse, z=fine) for bilateral weight calc in SAO_Blur
- References: [McGuire et al. 2012, "Scalable Ambient Obscurance"]
