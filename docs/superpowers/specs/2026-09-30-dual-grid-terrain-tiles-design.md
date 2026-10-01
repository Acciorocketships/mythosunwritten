# Dual-grid terrain tiles (corner-sampled 12 m tiles)

Status: IMPLEMENTED on branch `dual-grid-terrain` (September 30 - October 1; plan
`docs/superpowers/plans/2026-09-30-dual-grid-terrain-tiles.md`). E2 is the default cliff end
(E1 selectable via `TerrainTileField.cliff_end`); the low-pass knob `HeightfieldPlan.LOWPASS_M`
exists with default 0 (off). Open for the owner: the dome look of steep massifs (section 9,
risk 1). Review: `docs/qa/2026-09-30-dual-grid-terrain/result.md`.

## 1. Intent

The owner wants terrain whose shapes are predictable and explainable from a
few numbers, with the same slope and cliff types as today:

- Heights are sampled and discretised at grid POINTS (tile corners), 12 m
  apart.
- Each 12 m tile's shape is chosen from the relative heights of its four
  corners: one smooth slope family, one cliff family.
- A cliff is where neighbouring points differ by two or more storeys.

Success means: every piece of ground can be explained by "these four corner
heights, this rule"; tiles are seamless by construction; the look keeps
today's storeys, slope profile, rounded cliffs and walkability; the code
that decides terrain shape is smaller than today's kernel plus its special
cases.

Assumptions (correct me): storey 4 m and level 1 m stay; the cliff sheet
(rounded cliff dressing) stays as the art direction for cliffs; world seeds
may change their geography (this is a re-sampling of the world).

## 2. What exists today, in these terms

Cells are 24 m with one height at the centre. Each cell is split into four
12 m quarters, and each quarter is a smootherstep-bilinear blend of four
control heights: the cell centre, two edge midpoints and one corner
(`TerrainSurfaceField._natural_surface_y_in_cell`). Those four controls sit
on a 12 m lattice, so the surface already IS a 12 m corner-tiled surface.
What differs is where the lattice values come from: only the centres are
sampled; edge midpoints and corners are DERIVED (edge = lower of its two
cells, corner = lowest slope-connected cell of its ring). Cliffs are cell
borders where the two cells keep their own heights (a vertical wall).

The proposal samples every lattice point directly and replaces the
derivation rules with a per-tile case table.

## 3. Data

- **Points.** `P(i, j)` at world `(12 i, 12 j)`. Each point has a storey
  `s` and level `l` (0..3); height `h = 4 s + l`.
- **Sampling.** The existing continuous field `H(x, z)` of
  `HeightfieldPlan` (noise, landforms, river carve, spawn fade) is sampled
  at each point and quantised exactly as today (storey, then level).
- **Clamp.** Today's monotone clamps move from cells to points unchanged: a
  point is lowered to at most `MAX_CLIFF_STEP` (3) storeys above its lowest
  cardinal neighbour point; levels are clamped to one level above the
  lowest same-storey neighbour. Unique fixpoint, order independent.
- **Town grades** write per-point overrides (today: per-cell
  `native_control_heights`).

Points are 4x as many as today's cells (a 192 m chunk has 16 x 16 tiles
instead of 8 x 8 cells).

## 4. Edge categories

A lattice edge joins two cardinal neighbour points. Its category depends
only on those two points, as today:

| Endpoints | Category |
|---|---|
| same height | flat |
| same storey, 1-3 levels apart | level step (small slope) |
| one storey apart | slope |
| two or more storeys apart | cliff |

Diagonals never define a category.

## 5. Tile surface

Local tile coordinates `u, v` in [0, 1]; `S(t)` = smootherstep. Corner
heights `a (0,0)`, `b (1,0)`, `c (1,1)`, `d (0,1)`.

### 5.1 Layer decomposition

Sort the tile's distinct corner heights `t0 < t1 < ... < tk` (k <= 3).
The tile is the lowest height plus one LAYER per gap `[t(n-1), t(n)]`:

```
height(u, v) = t0 + sum over n of (t(n) - t(n-1)) * layer_n(u, v)
```

Each layer sees a BINARY tile: a corner is 1 if its height >= `t(n)`,
else 0. A binary tile has 16 patterns, 6 up to rotation:

```
 flat      outer corner   straight    saddle     inner corner   full
 0 0         1 0           1 1         1 0          1 1          1 1
 0 0         0 0           0 0         0 1          0 1          1 1
```

`layer_n` is in [0, 1]. Every layer crossing (a tile edge whose endpoints
differ in that layer) is a SLOPE crossing or a CLIFF crossing, taken from
that edge's category (section 4). All layers crossing a cliff edge are
cliff crossings, so a three-storey cliff is three coincident steps: one
12 m wall.

### 5.2 Slope layers (all crossings are slopes)

`layer = bilinear(corners, S(u), S(v))`.

Because bilinear is linear in the corner values, a tile whose layers are all
slopes is exactly `bilinear(a, b, c, d, S(u), S(v))`, the same formula as
today's quarter-cell patch. One formula covers flat, straight, outer and
inner corners. A one-storey step always spans one 12 m tile with the
smootherstep profile, as today.

### 5.3 Cliff layers (all crossings are cliffs)

`layer = 1` on the high side of the layer's outline, `0` on the low side.
The outline is the marching-squares outline with its crossings at the tile
edge MIDPOINTS (6 m), so walls run along tile midlines:

```
 outer corner     straight       inner corner
 +-----+-----+    +-----------+  +-----+-----+
 | HHH |     |    | HHHHHHHHH |  | HHH | HHH |
 +--+--+     |    +-----------+  +--+--+ HHH |
 |           |    |           |  |     | HHH |
 +-----------+    +-----------+  +-----+-----+
```

Walls are vertical. Both owners of a wall see the same outline (it depends
only on the edge's endpoints), so the terrain mesh places its rock skirt
there exactly as it does at today's cell borders. The 2 m mesh sampling
already has a sample line at the 6 m midline.

### 5.4 Saddles

A saddle pattern (diagonal corners high) connects the LOW diagonal: the two
high corners are separate bumps. This matches today, where two diagonally
touching high cells never join.

- Slope layer: `layer = max(bump_a, bump_c)`, where
  `bump_a = (1 - S(u)) (1 - S(v))` and `bump_c = S(u) S(v)`. On every tile
  edge this equals the ordinary slope profile, so neighbours still match.
- Cliff layer: two 6 x 6 m high squares touching at the tile centre.

### 5.5 Cliff ends (mixed layers: some crossings cliff, some slope)

This is the case the September 27 "dying cliff" patched. Here it is one
explicit, local rule inside one tile. Two candidates are to be rendered
side by side in the tile gallery (section 8) for the owner to pick:

- **E1: blend inside the tile.** `layer = lerp(slope_layer, cliff_layer, k)`,
  where `k` is 1 on cliff edges and 0 on slope edges, filled across the tile
  by a Coons patch of its four edge values. Along each tile edge `k` is
  constant, so the edge profile still depends only on its two endpoints
  (seamless). The wall shortens across at most one 12 m tile. The high side
  dips slightly inside that one tile.
- **E2: wall to the tile centre, then the slope rule.** The wall runs from
  its cliff crossing to the tile centre. Beyond the centre the layer is the
  slope layer. The high side stays level; the end is a compact ramp inside
  half a tile (today's standard end).

Recommendation: E2 (no dip, most predictable); E1 if the owner prefers a
longer fade.

### 5.6 Levels

Level steps (same storey) are slope crossings: a 1-3 m smootherstep ramp.

## 6. Properties (tested)

1. **Pure.** A tile's surface is a function of its four corner values
   (and, for cliffs, its four edge categories, themselves functions of the
   corners).
2. **Seamless.** Along any tile edge the surface depends only on that
   edge's two endpoints: slope profile, cliff midpoint, and `k`. Two
   neighbours compute the identical boundary curve; walls are the only
   double-valued places, and both owners agree where they are.
3. **Slope equivalence.** A slope-only tile equals today's quarter-cell
   formula for the same four values.
4. **Bounded.** Inside a tile the surface stays within [min, max] of its
   corners. There are no pits or bumps beyond the corners: this replaces
   today's `height_bounds` proof with a trivially exact one.
5. **Walkability** of a lattice edge = not a cliff edge. Roads use the same
   fact.

## 7. Interfaces and migration

New pure module `terrain/field/TerrainTileField.gd`, replacing the kernel
functions of `TerrainSurfaceField`:

- `surface_y(region, x, z)`: height anywhere (used by 46 files today).
- `surface_y_on_side(region, x, z, side)`: height on a chosen side of a wall
  (today `surface_y_in_cell`, used by the mesher for skirts).
- `edge_category(region, p, dir)`, `is_walkable_edge(...)`.
- `wall_segments(region, rect)`: the exact wall outline with top and bottom
  heights, replacing each consumer's own "where do owners differ" search.
- `height_bounds(region, rect)`: min/max over tile corners.
- A per-tile bake, like today's `bake_cell`/`sample_baked`, for speed.

`HeightfieldRegion` keeps its read API but is keyed by points
(`storey_at(i, j)` etc. at 12 m).

Consumers, in migration order:

| Phase | Consumers | Change |
|---|---|---|
| 0 | none | `TerrainTileField` plus a tile-gallery harness and photo-site review, behind a style switch. The owner signs off the look (including 5.5). |
| 1 | `TerrainChunkMesher`, collision, grass, F9 overlay, CoordOverlay, water sampling of ground | Read the new field through the same functions; chunk mesh at 2 m unchanged; skirts from `wall_segments`. |
| 2 | Cliff sheet (`CliffSlopeEnvelope`/`CliffSlopeField`), rocks, cliff vegetation | Walls come from `wall_segments` instead of cell borders. |
| 3 | `PathPlan` (routes stay on the 24 m lattice, walkability sampled on points), `NativeTerrainGrade` and villages (per-point controls; 24 m = 2 tiles = 3 village macro cells), `WaterPlan` carve and `WaterField` | Re-key from cells to points. |
| 4 | `CliffDressing` native KayKit pieces, the old kernel, tile-era fixtures | Remove. Native wall/lip pieces are already hidden under the sheet. |

Each phase keeps the game runnable. Phase 0 changes nothing outside new
files.

## 8. Testing

- **Unit:** the six binary patterns per layer type; saddles; a three-storey
  cliff is one wall; seam equality along shared edges over random corner
  fields; property 3 against today's formula; bounds; clamp fixpoint and
  order independence at points.
- **Tile gallery harness:** renders every corner case (slope, cliff, mixed,
  saddle, level) in a grid with F9 on, plus E1/E2 side by side.
- **Photo sites:** the September 28-30 owner photo cameras, before/after.
- **Corpus:** road walkability and town grade probes re-run after phase 3.

## 9. Risks and open questions

1. **Finer noise.** Sampling at 12 m shows 4x more of the noise field, so
   terraces become more organic but may look busier. Mitigation: low-pass
   the field before sampling (a tuning knob, decided in phase 0 renders).
2. **Cliff-end rule (5.5):** owner choice between E1 and E2.
3. **Cost:** 4x points to clamp per region; the clamp is iterative. Profile
   in phase 0 with `tests/harness/profile_terrain.gd`.
4. **Geography changes** for every seed; historical screenshot fixtures
   that pin exact heights need re-freezing or retiring.
5. **Scope:** phases 2-3 touch towns and water, which are under active
   development in the same tree; schedule them when that work settles.
