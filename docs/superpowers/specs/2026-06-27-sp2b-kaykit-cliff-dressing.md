# SP2b — KayKit cliff dressing (real rock cliffs over the field mesh) — design + plan

**Date:** 2026-06-27. Branch `refactor/terrain-field-driven`. Supersedes SP2's flat-quad cliff walls.

## Why
SP2 emitted cliff faces as flat grey quads — no geometry, reads as "uniform". The owner's KayKit cliff pieces (rounded stone slabs + beveled grass lips) look far better and are already in the repo (`terrain/gltf/hill/*`). Use them.

## Agreed model (owner's design)
The **field mesh stays the base for ALL walkable surface** — flat tops, slopes, the auto grass-merge where a slope rises to a cliff top, and collision. On top of that, hang **real KayKit pieces only on true cliff edges**:
- **Cliff edge** (a cardinal neighbour ≥2 storeys lower): a beveled grass **lip** (`hill_top_h_side`) along the 24 m edge + **rock wall** pieces (`hill_cliff_tall_h_side`) below it, stacked 4 m per storey down to the neighbour's height.
- **Cliff corner** (two adjacent cliff edges): outer-corner lip + wall (`hill_top_*_outer_corner`, `hill_cliff_tall_i_outer_corner`); concave uses the inner-corner pieces.
- **Merge / non-cliff edge** (neighbour at a walkable ≤1-storey height): **no lip** — the field mesh already flows through continuously. This is the owner's "replace the lip with field mesh at the merge spot," achieved by simply not dressing that edge.

The flat interior grass + slopes remain field mesh (one green swatch, consistent with the lip grass).

## Piece facts (measured, raw gltf units; 1 cell = 24 u = 8 pieces of 3 u)
- `hill_top_e_center` 3×3 flat grass (field mesh replaces this).
- `hill_top_h_side` 3×0.7×2.75 — beveled grass lip edge.
- `hill_top_a_outer_corner` / `hill_top_i_outer_corner` ~2.75 — corner lips.
- `hill_cliff_tall_h_side` 3×4×0.75 — rock wall slab (4 u = one storey tall).
- `hill_cliff_tall_i_outer_corner` 2.5×4×2.5, `..._i_inner_corner` — corner walls.
Reference transforms: `CliffSide` lays 8 wall slabs across an edge (x = ±1.5,±4.5,±7.5,±10.5) at z=−10.5, basis = 180° Y, wall rows at y=−4 (storey 1), −8 (storey 2); lip row (`hill_top_h_side`) at y=0; `CliffCorner` adds a `CornerWall`/`CornerTop` at the −10.5,−10.5 corner. These give the exact local placement; per-edge direction is the same pattern rotated 90°×k.

## Components
1. **`CliffDressing` (new, `scripts/terrain/field/CliffDressing.gd`)** — pure-ish builder: given a region + a cell + the cell's cliff-edge set + storey count per edge, returns/builds a `Node3D` of instanced KayKit pieces (lips + stacked walls + corners) at the correct local transforms, parented under the chunk. No field/scene-tree globals beyond loading the gltf pieces.
2. **`TerrainChunkMesher` change** — split the cliff walls out of the *visible* surface mesh:
   - Visible surface mesh = grass tops + slopes only (no wall quads, no `_cliff_uv`).
   - Collision: keep the flat wall quads but emit them into a **collision-only** trimesh (so the player still can't walk through a cliff), separate from the visible mesh.
   - Per cliff-top cell, call `CliffDressing` and add its node under the chunk (evicted with the chunk).
3. **Streaming/eviction** unchanged (dressing nodes are chunk children).

## Tasks (TDD where unit-testable; visual iteration for placement)
- **T1 — Mesher: walls become collision-only.** Move wall-quad emission from the visible `SurfaceTool` into a separate collision `SurfaceTool`; the visible surface no longer has near-vertical faces. Test: visible surface mesh has no |normal.y|<0.3 faces over a cliff region, but the chunk still has a collision shape spanning the cliff height. Commit.
- **T2 — `CliffDressing` wall pieces.** For each cliff edge of a cell, instance 8 `hill_cliff_tall_h_side` slabs across the 24 u edge, stacked one row per storey of drop, rotated to face the drop direction (derive the 4 rotations from the `CliffSide` reference + a visual check). Unit test: N-storey edge yields 8×N wall instances positioned within the cell's edge band and spanning the right Y range. Commit.
- **T3 — `CliffDressing` lips + corners.** Add the `hill_top_h_side` lip row at the top of each cliff edge, and outer/inner corner wall+lip pieces where two cliff edges meet. Commit.
- **T4 — Wire into the mesher + streamer; visual pass.** Dress every cliff-top cell. Run the game; verify: rock cliffs look like the KayKit tiles, grass lips read at the top edge, merges (cliff-top → slope/ground at walkable height) flow continuously with no lip/seam, player can't walk through cliffs, FPS ok. Tune rotations/offsets/Y here. Commit.
- **T5 — Cleanup.** Re-delete the temporarily-restored `terrain/scenes/cliff/*` (we compose from the gltf pieces in code, not the scenes); drop the now-unused `SlopeAtlas.cliff_uv` if nothing else uses it. Full suite green. Commit.

## Collision note
The field flat tops give walkable collision; the collision-only wall quads (T1) stop the player at cliff faces. KayKit pieces are visual only (no added collision). One trimesh body per chunk.

## Iteration points (expected)
Per-direction rotation/offset of the wall+lip rows, the lip's overlap with the field top edge (both grass — minor overlap acceptable; inset later if needed), and corner piece alignment. All resolved in T4's visual pass, not up front.

## Out of scope
Multi-elevation water (kept as the simple sea-level shim). Ground texture variation (owner: field ground is fine).
