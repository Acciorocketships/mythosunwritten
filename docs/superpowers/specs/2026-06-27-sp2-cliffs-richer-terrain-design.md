# SP2 — Blocky multi-storey cliffs + richer terrain — design

**Date:** 2026-06-27
**Status:** approved direction (forks answered); specs sub-project 2.
**Branch:** `refactor/terrain-field-driven`. Builds on SP1 (field mesher).
**Depends on:** `docs/superpowers/specs/2026-06-26-field-driven-terrain-mesh-design.md` (overall architecture).

## Goal

Let the terrain form **blocky vertical cliffs** where the heightfield steps down by
more than one storey, instead of turning every drop into a walkable slope. Tune the
shape for a **moderate** look: rolling hills with occasional 2–3 storey (8–12 m)
cliffs, plateaus, and shallow valleys.

## Decisions (from the owner)

- **Cliff faces:** rock-grey, reusing the existing KayKit "Color1" atlas (same
  `ground.tres` material the grass already uses) — sampled via a new
  `SlopeAtlas.cliff_uv()`. Cliff walls and grass tops can share one mesh/material.
- **Terrain drama:** moderate.
- **Max cliff height:** 3 storeys / 12 m (generated from scratch, so the 12 m option).

## The single rule (recap from the architecture doc)

Between two adjacent cells, by **storey** difference:
- **0–1 storeys** → walkable slope inside the continuous heightmap (SP1 behaviour, incl. 0.5 m level steps).
- **≥2 storeys** → the upper cell is **flat to its edge** (a cliff top) and a **vertical rock face** drops to the lower cell's surface. The wall is generated geometry, continuous with both flat surfaces.

This stays gap-free: the heightmap surface still shares boundary samples, and each wall connects the upper edge height to the lower edge height exactly.

## Components / changes (each isolated)

### 1. `HeightfieldPlan` — relax the clamp (parameterized)
- `clamp_field(targets, max_step := 1)`: change the cardinal cap from `out[nb] + 1`
  to `out[nb] + max_step`. Default 1 keeps every existing test unchanged.
- Add a `max_step: int` field (constructor param, default 1); `storey_at` and
  `compute_region` pass `self.max_step` to `clamp_field`.
- The existing window margin (`max_storeys`) stays correct — clamp influence now
  fans out `max_step` storeys/tile (fewer tiles to converge), so a margin of
  `max_storeys` remains conservative. No margin change.
- The world creates the plan with `max_step = 3` (≤3-storey adjacent jumps → cliffs
  up to 12 m; bounded, no stark 50 m walls).

### 2. `SlopeAtlas.cliff_uv()`
- Mirror `grass_uv()` but sample the **side-facing** (rock) texels from the cliff
  piece `terrain/gltf/hill/hill_cliff_tall_h_side_color_12.tscn` (average UVs of
  vertices whose normal is roughly horizontal). Gives the exact grey-rock swatch
  from the owner's atlas.

### 3. `TerrainSurfaceField` — flat cliff tops
- Gate each per-direction ramp by storey difference: ramp toward a lower neighbour
  only when `abs(storey_at(cell) - storey_at(neighbour)) <= 1`; for `>= 2`, the
  cell stays **flat to that edge** (cliff top). Reads `region.storey_at`.
- Result: cliff-top cells are flat plateaus to their edge; slopes (≤1 storey, incl.
  level steps) ramp exactly as in SP1. Still single-valued ⇒ gap-free.

### 4. `TerrainChunkMesher` — emit cliff walls
- After the surface grid, a per-cell pass: for each cell and each cardinal
  neighbour, if `storey_at` differs by `>= 2`, emit a **vertical quad** along the
  24 m shared edge from the upper surface height down to the lower neighbour's
  surface height, wound so the rock face points toward the lower (open) side, UV =
  `SlopeAtlas.cliff_uv()`.
- Emit walls into the **same `SurfaceTool`** as the grass surface (same atlas
  material) so it's one mesh / one draw call (grass UV on the heightmap, rock UV on
  walls). Weld+normals already applied; walls get their own near-horizontal normals.
- Collision: the existing trimesh from this combined mesh now includes the walls →
  the player can't walk through a cliff.
- Corners where two cliff edges meet: the two cardinal wall quads meet at the corner
  vertical line (sufficient to close the corner visually); refine in the visual pass
  only if a gap shows.

### 5. Richer terrain (noise tuning)
- With `max_step = 3` the existing noise already yields cliffs where the field is
  steep. "Moderate" = a readable mix of flat plateaus, gentle slopes, and occasional
  cliffs. Tune `HeightfieldPlan.raw_height` / `Helper.macro_density` octaves/ridges
  and `HEIGHTFIELD_AMPLITUDE` **in the visual pass** to hit that balance; no fixed
  numbers up front (it's iterative).

## Testing

- **Clamp:** `clamp_field` with `max_step=1` is byte-identical to today (regression);
  with `max_step=3`, adjacent cells may differ by up to 3 and never more; still
  deterministic & convergent.
- **Surface field:** a ≥2-storey neighbour leaves the cell flat to its edge (no
  ramp); a 1-storey neighbour still ramps (SP1 tests stay green).
- **`cliff_uv`:** returns a stable UV distinct from `grass_uv`.
- **Mesher walls:** a cell with a ≥2-storey-lower cardinal neighbour produces wall
  geometry spanning the storey gap; vertical extent equals the surface-height
  difference; the combined mesh's collision includes the wall.
- Full GUT suite green.

## Out of scope (SP3 / later)

Multi-elevation water + shorelines (SP3). `Plane*` authored level detail (SP4).
Cliff-corner pieces beyond the meeting cardinal quads (only if the visual pass needs
them).

## Risks

- **Surface/wall seam:** the wall top must exactly equal the heightmap edge height
  and the wall bottom the lower edge height — both read the same `surface_height`, so
  they coincide; assert in a test.
- **Terrain feel** is subjective — budget visual iteration (component 5).
- **Tall-wall collision** could trap the player against a 12 m face; acceptable
  (intended), and slopes elsewhere give routes up.
