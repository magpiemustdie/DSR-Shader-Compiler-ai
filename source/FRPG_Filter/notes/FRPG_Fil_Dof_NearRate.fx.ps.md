# FRPG_Fil_Dof_NearRate — Pseudocode

Computes near-field DOF rate from depth. Outputs black RGB + near rate in alpha.

## Inputs
- `t1` = depth (s1)
- `cb0[8]`  = CameraParam (`.x` = near*far, `.y` = far)
- `cb0[10]` = DofNearParam (`.x` = start, `.y` = end, `.z` = scale)

## Output
- `o0.rgb` = 0
- `o0.a`   = `nearRate × scale`

## Algorithm
```
depth  = Sample(t1, UV).r
viewZ  = CameraParam.x / (depth × (CameraParam.x − far) + far)

nearRate = saturate((viewZ − nearStart) / (nearEnd − nearStart))

Output = (0, 0, 0, nearRate × scale)
```
