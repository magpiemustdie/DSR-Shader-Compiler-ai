# FRPG_Fil_SAO_Depth — Pseudocode

SAO depth prepass: linearizes hardware depth buffer to view-space Z.

## Inputs
- `t0` = raw hardware depth buffer (sampled via s0)
- `cb0[8]` = CameraParam:
  - `x` = near * far
  - `y` = far
  - `z` = near - far
  - `w` = near * far  (duplicate of x for some reason; both hold the same value)

## Output
- `o0` = `float4(viewZ, 1, 1, 1)`

## Algorithm
```
depth = Sample(t0, UV).r
viewZ = CameraParam.w / (depth * CameraParam.z + CameraParam.y)
       = (near * far) / (depth * (near - far) + far)
```

## Derivation
Standard reversed-Z linearization:
```
Z_ndc = depth * 2 - 1           // unmap [0,1] → [-1,1]
viewZ = 2 * near * far / (far + near - Z_ndc * (far - near))
       = near * far / (depth * (near - far) + far)   // after simplification
```
Matches the code: `gFC_CameraParam.w / (depth * gFC_CameraParam.z + gFC_CameraParam.y)`.

## Notes
- The `(1, 1, 1)` in `.yzw` are unused padding — only `.x` (viewZ) is consumed by SAO_Main.
- References: [McGuire et al. 2012, "Scalable Ambient Obscurance"]
