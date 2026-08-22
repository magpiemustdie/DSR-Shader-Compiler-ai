# FRPG_Fil_Dof_CB — Pseudocode

DOF composite (checkerboard): blends 4 DOF layers with half-res MSAA depth, alternating sample per pixel based on checkerboard pattern.

## Inputs
- identical to `Dof.fx` except:
- `t5` = half-res MSAA depth (`Texture2DMS<float>`, ldms sample)
- `cb0[81].y` = checkerboard frame offset (uint)

## Output
- `o0` = layer-blended color

## Algorithm
```
pixCoord  = (uint2)SV_Position.xy
sampleIdx = (pixCoord.x + pixCoord.y + frameOffset) & 1    // checkerboard alternating sample
halfX     = pixCoord.x >> 1
depth     = LoadMS(t5, uint2(halfX, pixCoord.y), sampleIdx).r

// Rest identical to Dof.fx: linearize, compute dofRate, blend 4 layers
...
```
