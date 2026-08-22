# FRPG_Fil_DepthCopy_Fragment_VS — Pseudocode

Vertex shader for DepthCopy_Fragment[01]: fullscreen triangle with 6 ICB positions.

## Inputs
- `SV_VertexID` (0..5)

## Output
- `SV_Position` = `(ICB[vertexID].xy, 0, 1)`

## Algorithm
```
Positions[6] = {
    ( 1,  1),
    ( 1, -1),
    (-1, -1),
    (-1, -1),    // degenerate
    (-1,  1),
    ( 1,  1)     // degenerate
}

Pos = (Positions[id], 0, 1)
```
