# FRPG_Fil_Dbg_LogTex — Pseudocode

Debug log-space texture visualizer: decodes log-encoded texture to linear for display.

## Inputs
- `t0` = log-encoded texture (s0)

## Output
- `o0` = `min(e^sample, 1)` — linearized, clamped to 1

## Algorithm
```
s      = Sample(t0, UV)
result = exp2(s × log2(e))                // = e^sample
Output = min(result, 1)
```
