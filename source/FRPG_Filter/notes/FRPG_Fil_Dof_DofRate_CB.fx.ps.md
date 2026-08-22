# FRPG_Fil_Dof_DofRate_CB — Pseudocode

DOF rate (checkerboard): computes scalar DOF rate from half-res MSAA depth + vignette.

## Inputs
- `t1` = half-res MSAA depth (`Texture2DMS<float>`)
- `cb0[81].y` = checkerboard frame offset
- (other params same as Dof_DofRate)

## Output
- `o0` = `vignette × strength + dofFar` (all 4 channels)

## Algorithm
```
sampleIdx = (pixCoord.x + pixCoord.y + frameOffset) & 1
halfX     = pixCoord.x >> 1
depth     = LoadMS(t1, uint2(halfX, pixCoord.y), sampleIdx).r

// Same linearization and DOF rate as non-CB variant
...
```
