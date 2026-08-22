# FRPG_Fil_DepthCopy_SingleFragment_VS — Pseudocode

Vertex shader for DepthCopy_SingleFragment: fullscreen triangle with ICB positions and UVs.

## Inputs
- `SV_VertexID` (0..5)

## Output
- `SV_Position` = `(ICB[vertexID].xy, 0, 1)`
- `TEXCOORD0`  = `ICB[vertexID].zw` (UV)

## Algorithm
```
ICB[6] = {
    ( 1,  1, 1, 0),   // vertex 0: pos (1,1), UV (1,0)
    ( 1, -1, 1, 1),   // vertex 1: pos (1,-1), UV (1,1)
    (-1, -1, 0, 1),   // vertex 2: pos (-1,-1), UV (0,1)
    (-1, -1, 0, 1),   // vertex 3: degenerate
    (-1,  1, 0, 0),   // vertex 4: pos (-1,1), UV (0,0)
    ( 1,  1, 1, 0)    // vertex 5: degenerate
}

Pos = (ICB[id].xy, 0, 1)
UV  = ICB[id].zw
```
