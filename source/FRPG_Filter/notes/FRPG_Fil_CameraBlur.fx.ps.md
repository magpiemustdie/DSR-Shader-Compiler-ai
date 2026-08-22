# FRPG_Fil_CameraBlur — Pseudocode

Camera motion blur: 7-tap depth-tested blur along motion vector.

## Inputs
- `t0` = scene color (s0)
- `t1` = depth buffer (s1, `.y` = center depth via yzxw swizzle, `.r` = sample depth)
- `t2` = velocity buffer (s2, `.xy` = encoded velocity)
- `cb0[38].yzw` + `cb0[39].xyzw` = 7 sample weights
- `cb0[57].x` = blur scale
- `cb0[58..61]` = reprojection matrix (rows 0, 1, 3)

## Output
- `o0.rgb` = depth-tested motion-blurred color
- `o0.a` = 1

## Algorithm
```
centerDepth = Sample(t1, UV).y                    // swizzle yzxw → .y

// Reproject to previous frame
r0 = (UV.x, UV.y, centerDepth, 1)
prevXY = (dot(r0, ReprojectRow0), dot(r0, ReprojectRow1))
prevW   = dot(r0, ReprojectRow3)
prevUV  = prevXY / prevW

// Motion vector
motion = UV − prevUV

// Add decoded velocity from velocity buffer
vel          = Sample(t2, UV).xy
velDecoded   = vel − 0.498040                     // decode from [0,1] to [-0.5,0.5]
motion       = velDecoded × 2 + motion            // combine reprojection + velocity

motion *= blurScale

// 7 samples along motion vector
weights = [cb0[38].y, .z, .w, cb0[39].x, .y, .z, .w]
tvals   = [0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]

acc    = (0, 0, 0, 0)
totalW = 0

for i = 0..6:
    sUV  = motion × tvals[i] + UV
    s    = Sample(t0, sUV)
    sd   = Sample(t1, sUV).r
    w    = (sd >= centerDepth) × weights[i]       // depth test: reject foreground
    acc += (s.rgb × w, w)
    totalW += w

center = Sample(t0, UV).rgb
Output.rgb = center × (1 − totalW) + acc.rgb
Output.a = 1
```

## Notes
- Depth test prevents foreground pixels from blurring into background
- Motion computed from both reprojection matrix AND velocity buffer (combined)
- References: [Underwood 2015, "Motion Blur in Call of Duty"]
