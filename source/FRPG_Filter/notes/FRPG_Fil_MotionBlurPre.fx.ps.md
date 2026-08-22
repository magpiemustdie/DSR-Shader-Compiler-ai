# FRPG_Fil_MotionBlurPre — Pseudocode

Motion blur prepass: computes per-pixel motion vector length and view-space depth for the final blur pass.

## Inputs
- `t0` = velocity buffer (s0, `.xy`)
- `t1` = depth buffer (s1, `.x`)
- `cb0[8]`  = CameraParam (`.y` = far, `.z` = near−far, `.w` = near×far)
- `cb0[57]` = MotionParam (`.x` = scaleX, `.y` = scaleY, `.z` = normScale)
- `cb0[58..61]` = InvViewProj matrix (rows 0..3)
- `cb0[74,75,77]` = PrevViewProj matrix (rows 0,1,3)
- `cb0[78]` = camera world offset

## Output
- `o0.x` = 1 / motionLength (used by MotionBlurFinal for tile max)
- `o0.y` = viewZ (linearized depth)

## Algorithm
```
depth  = Sample(t1, UV).x
viewZ  = CameraParam.w / (depth × CameraParam.z + CameraParam.y)

// Reproject to previous frame
ndc = UV × (2, −2) + (−1, 1)
worldPos = InvVP × float4(ndc, depth, 1)
worldPos.xyz /= worldPos.w
worldPos.xyz += camOffset

prevClip.xy = dot(worldPos, PrevVP0/1)
prevW       = dot(worldPos, PrevVP3)
prevUV = prevClip / prevW × (0.5, −0.5) + 0.5
mv = UV − prevUV

// Velocity override from t0
vel = Sample(t0, UV).xy
hasOverride = (vel.x < 1.0)
mvFinal = hasOverride ? vel × (1, −1) : mv

// Normalize + scale
norm = saturate(rsqrt(dot(mvFinal, mvFinal)) × normScale)
mvFinal = mvFinal × norm × scale.xy
mvLen = sqrt(dot(mvFinal, mvFinal))

Output.x = 1 / mvLen
Output.y = viewZ
```
