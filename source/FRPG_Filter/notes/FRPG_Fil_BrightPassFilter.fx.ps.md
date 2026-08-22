# FRPG_Fil_BrightPassFilter — Pseudocode

Distance-based bright pass: extracts bright regions for bloom with depth-dependent threshold.

## Inputs
- `t0` = HDR scene color (s0)
- `t2` = depth/luminance buffer (s2, `.r` = linearized depth)
- `cb0[8]`  = CameraParam (`.x` = near*far, `.y` = far)
- `cb0[11]` = BloomParam (`.x` = bloom threshold low)
- `cb0[71]` = BloomDistParam (`.x` = bloom threshold high, `.z` = dist start, `.w` = dist end)

## Output
- `o0.rgb` = `max(hdr − bloomScale, 0) / (1 − bloomScale)`
- `o0.a`   = bloomRate (distance fade factor)

## Algorithm
```
depth = Sample(t2, UV).r

// Linearize depth → exposure factor
linDepth = depth * (near*far − far) + far
exposure = (near*far) / linDepth

// Distance-based bloom rate
distStartN = distStart / far          // normalized to [0,1]
distEndN   = distEnd / far
bloomRate  = saturate((exposure − distStartN) / (distEndN − distStartN))

// Threshold interpolation: low at near, high at far
bloomScale = bloomRate × (bloomThresholdHigh − bloomThresholdLow) + bloomThresholdLow

// Extract bright pixels
hdr   = Sample(t0, UV)
bright = max(hdr.rgb − bloomScale, 0)
denom  = 1 − bloomScale
Output.rgb = bright / denom
Output.a   = bloomRate
```

## Notes
- Depth-dependent threshold reduces bloom on distant objects (atmospheric perspective)
- Output alpha carries distance factor for compositing
- References: [Karis 2013, "Graphics Gems for Games"]
