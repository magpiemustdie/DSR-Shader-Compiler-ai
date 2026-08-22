# FRPG_Fil_DepthCopy_SingleFragment — Pseudocode

Copies depth from MSAA `Texture2DMS<float>` to depth output (sample 0).

## Inputs
- `t0` = `Texture2DMS<float>` depth (MSAA)
- `cb0[12]` = ScreenSize

## Output
- `SV_Depth` = depth sample at `(UV * ScreenSize, 0)`

## Algorithm
```
coord = (uint2)(UV × ScreenSize.xy)
Depth = LoadMS(t0, coord, 0)
```
