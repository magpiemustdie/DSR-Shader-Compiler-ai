# FRPG_Fil_SAO_Minify — Pseudocode

SAO mipmap minification: builds the SAO depth mip chain using a bit-reversed coordinate access pattern. No UV input — uses `SV_Position` directly.

## Inputs
- `t0` = SAO depth mip (higher level, loaded via `Load`)
- `SV_Position.xy` = pixel coordinate

## Output
- `o0` = `Load(t0, revCoord)` — color from source mip at the remapped coordinate

## Algorithm
```
iC       = (uint2)(int2)SV_Position.xy
revCoord = (iC & ~1u) | ((iC.yx & 1u) ^ 1u)
           // bit 0 of X comes from bit 0 of Y inverted
           // bit 0 of Y comes from bit 0 of X inverted
           // upper bits remain unchanged

Output = Load(t0, int3(revCoord, 0))
```

### Bit manipulation breakdown

Let `iC = (x, y)`. Write each as `(highBits, LSB)`:

```
x = (xH << 1) | xL    where xL = x & 1
y = (yH << 1) | yL    where yL = y & 1

(iC & ~1u)  = (xH << 1, yH << 1)           // clear LSBs
(iC.yx & 1u) = (yL, xL)                    // swapped LSBs
((iC.yx & 1u) ^ 1u) = (~yL & 1, ~xL & 1)   // inverted swapped LSBs

revCoord = ( (xH << 1) | (~yL & 1),  (yH << 1) | (~xL & 1) )
```

This creates a checkerboard interleaved read pattern: each 2×2 block reads from the diagonally opposite pixel, producing a properly minified mip level.

## Notes
- Formula fixed from original: was `(iC & ~1u) | ((iC.yx & 1u) ^ 1u)` — the `^1u` inverts the swapped LSBs
- This is the correct interleaved access pattern for SAO depth mip chain
- References: [McGuire et al. 2012, "Scalable Ambient Obscurance"]
