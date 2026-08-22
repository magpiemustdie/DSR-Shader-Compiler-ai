# FRPG_Fil_HDR — Pseudocode

HDR composite: bloom + scene with soft-light noise overlay.

## Inputs
- `t0` = scene (s0)
- `t1` = bloom (s1)
- `t2` = noise (s2, UV.zw)
- `cb0[56].x` = bloomScale, `cb0[56].z` = sceneScale
- `cb0[68].x` = noise blend weight
- `In.UV.xy` = scene/bloom UV, `In.UV.zw` = noise UV

## Output
- `o0` = HDR-composited color

## Algorithm
```
bloom = Sample(t1, UV.xy)
scene = Sample(t0, UV.xy)
scene.rgb = saturate(scene.rgb × sceneScale)
scene.a   = saturate(scene.a)
hdr = bloomScale × bloom + scene

noise  = Sample(t2, UV.zw)

// Soft-light blend:
mul2    = hdr × noise × 2
inv2n   = (1−noise) × 2
inv1h   = 1 − hdr
screen  = 1 − inv2n × inv1h
mask    = (noise < 0.5)
blended = mul2 × mask + screen × (1−mask)

delta = blended − hdr
Output = noiseBlend × delta + hdr
```
