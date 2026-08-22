# FRPG_Fil_MotionBlurPre_CB — Pseudocode

Checkboard motion blur prepass: computes motion from velocity texture samples + reprojection, with alternating sample pattern.

## Inputs
- `t0` = velocity texture (s0, 4 channels at half-res)
- `t1` = MSAA depth (`Texture2DMS<float4>`, sample `.g`)
- `cb0[8]`  = CameraParam
- `cb0[57]` = MotionParam
- `cb0[58..61]` = InvViewProj
- `cb0[74,75,77]` = PrevViewProj
- `cb0[78]` = camera offset
- `cb0[81].y` = checkerboard frame offset

## Output
- `o0.x` = 1 / motionLength
- `o0.y` = viewZ

## Algorithm
```
// Checkerboard sample selection
r3x = (pixCoord.x + pixCoord.y + frameOffset) & 1
halfX = pixCoord.x >> 1

// 4 velocity samples at half-res offsets
// Sample pattern alternates based on checkerboard bit
uv3  = UV + (r3x ? (−0.5/W, 0) : (−0.5/W, −1/H))
uv0xw = UV + (r3x ? (0, 0) : (−0.5/W, 1/H))
uv0yz = UV + (r3x ? (0, 1/H) : (0.5/W, 1/H))
uv2  = UV + (r3x ? (0.5/W, 0) : (0.5/W, −1/H))

mvSum = average of 4 velocity samples
useMV = (mvSum.x < 4.0)

// Depth from MSAA at checkerboard sample
depth = LoadMS(t1, (halfX, pixCoord.y), r3x).g
viewZ = CameraParam.w / (depth × CameraParam.z + CameraParam.y)

// Reprojection (same as MotionBlurPre)
mvReproj = UV − prevUV

// Choose: velocity texture override or reprojection
mvFinal = useMV ? mvSum × 0.25 × (1, −1) : mvReproj

// Normalize + scale
mvLen = sqrt(dot(normalized mvFinal, mvFinal))
Output.x = 1 / mvLen
Output.y = viewZ
```
