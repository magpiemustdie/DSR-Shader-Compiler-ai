# FRPG_Fil_HDR_Menu — Pseudocode

Menu tone mapper: filmic Reinhard-like curve + gamma 2.2. No cbuffer parameters.

## Inputs
- `t0` = HDR scene (s0)
- UV from TEXCOORD1 (index 1, not 0)

## Output
- `o0` = tonemapped, gamma-corrected color

## Algorithm
```
hdr = Sample(t0, UV)

// Filmic curve: (x*(0.1x+0.03)+0.005) / (x*(0.1x+0.3)+0.075)
num = hdr.rgb × (0.1 × hdr.rgb + 0.03) + 0.005
den = hdr.rgb × (0.1 × hdr.rgb + 0.3) + 0.075
tonemapped = num / den

// Offset and scale to fit [0,1]
tonemapped = saturate((tonemapped − 0.066667) × 1.875)

// Gamma 2.2
output.rgb = exp2(log2(tonemapped) × 0.454545)
output.a   = saturate(hdr.a)
```
