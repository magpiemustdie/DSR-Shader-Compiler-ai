# FRPG_Fil_BlackBars — Pseudocode

Letterbox bars: outputs pure black (transparent) for cinematic aspect ratio masking.

## Inputs
None (uses `SV_Position` only, no samplers, no textures)

## Output
- `o0` = `(0, 0, 0, 0)`

## Algorithm
```
Output = (0, 0, 0, 0)
```

## Notes
- Used as a fullscreen clear for letterbox bar regions
- No UV input — uses `FIL_IN_NOUV` struct
