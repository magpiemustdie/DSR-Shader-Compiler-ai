# FRPG_Fil_SAO_Combine — Pseudocode

SAO combine: extracts AO from input and writes it into alpha channel of a black color.

## Inputs
- `t0` = SAO result:
  - `.x` = AO value

## Output
- `o0` = `(0, 0, 0, ao)`

## Algorithm
```
ao = Sample(t0, UV).r
Output = (0, 0, 0, ao)
```

## Notes
- This is the final SAO compositing step: AO is placed in alpha for blending with the scene
- References: [McGuire et al. 2012, "Scalable Ambient Obscurance"]
