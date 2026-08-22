# FRPG_Fil_Dof_DofRate — Pseudocode

Computes DOF far rate from depth + vignette. Output scalar value to all 4 channels.

## Inputs
- `t1` = depth (s1)
- `cb0[7]`  = AimBloomParam (`.x` = vignetteStart, `.y` = 1/(end-start), `.z` = strength)
- `cb0[8]`  = CameraParam (`.x` = near*far, `.y` = far)
- `cb0[9]`  = DofFarParam (`.x` = start, `.y` = end, `.z` = scale)
- `cb0[12]` = ScreenSize

## Output
- `o0` = `vignette × strength + dofFar` (all 4 channels)

## Algorithm
```
depth  = Sample(t1, UV).r
viewZ  = CameraParam.x / (depth × (CameraParam.x − far) + far)

dofFar = saturate((viewZ − farStart) / (farEnd − farStart)) × scale

vigDist = length((UV − 0.5) × ScreenSize.xy)
vignette = saturate((vigDist − vignetteStart) × invRange)

Output = vignette × strength + dofFar
```
