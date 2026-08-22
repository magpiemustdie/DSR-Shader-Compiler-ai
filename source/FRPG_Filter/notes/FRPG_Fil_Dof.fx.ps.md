# FRPG_Fil_Dof — Pseudocode

DOF composite (non-checkerboard): blends 4 DOF layers (sharp, near, mid, far) based on depth-driven DOF rate + vignette.

## Inputs
- `t0` = sharp layer (s0)
- `t1` = near blur (s1)
- `t2` = mid blur (s2)
- `t3` = far blur (s3)
- `t4` = DOF rate override (s4, `.w`)
- `t5` = depth (s5, `.r`)
- `cb0[7]`  = AimBloomParam (`.x` = vignetteStart, `.y` = 1/(end-start), `.z` = strength)
- `cb0[8]`  = CameraParam (`.x` = near*far, `.y` = far)
- `cb0[9]`  = DofFarParam (`.x` = start, `.y` = end, `.z` = scale)
- `cb0[12]` = ScreenSize
- `cb0[66]` = DOF blend range (xyzw)
- `cb0[67]` = DOF blend offset (xyzw)

## Output
- `o0` = layer-blended color

## Algorithm
```
depth = Sample(t5, UV).r
viewZ = CameraParam.x / (depth × (CameraParam.x − CameraParam.y) + CameraParam.y)

// Far DoF rate from view-space depth
dofFar = saturate((viewZ − DofFarParam.x/far) / (DofFarParam.y/far − DofFarParam.x/far))
dofFar = saturate(dofFar × DofFarParam.z)

// Vignette adds blur toward screen edges
vigDist = length((UV − 0.5) × ScreenSize.xy)
vignette = saturate((vigDist − vignetteStart) × invVignetteRange)
dofRate = vignette × strength + dofFar

// Override from precomputed DOF rate texture
dofRate = max(dofRate, Sample(t4, UV).w)

// Map to 4 blend weights, then compute differentials
r0 = saturate(dofRate × BlendRange + BlendOffset)
// r0 = (w0, w1, w2, w3)
// diffs: wNear = w1−w0, wMid = w2−w1, wFar = w3−w2

// Blend: w0×sharp + wNear×nearBlur + wMid×midBlur + wFar×farBlur
Output = Sample(t0, UV) × w0
       + Sample(t1, UV) × (w1−w0)
       + Sample(t2, UV) × (w2−w1)
       + Sample(t3, UV) × (w3−w2)
```
