# Dual-Grid Terrain Tiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 24 m cell-centred terrain kernel with corner-sampled 12 m tiles (heights on lattice points, per-tile case table) across the whole terrain pipeline, keeping storeys, slope profile, rounded cliff sheet and walkability.

**Architecture:** `TerrainTileField` (done, task 1) is the one kernel. `HeightfieldPlan`/`HeightfieldRegion` become keyed by 12 m lattice POINTS. Every wall lies on a dual-cell border (x = 12i + 6); a sample's owner is its nearest point, so the mesher's "pin a quad to its owner" design survives with owner = point. Coarse 24 m lattices that are NOT the terrain kernel (roads, settlements, grass tiles, tint lattice, 192 m chunks = 8 coarse cells) keep 24 m and get explicit names.

**Tech Stack:** Godot 4.5 typed GDScript, GUT tests (`tests/test_*.gd`), headless runs via `/Applications/Godot.app/Contents/MacOS/Godot`.

**Spec:** `docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md`

## Global Constraints

- Storey 4 m and level 1 m stay (`STOREY_HEIGHT`, `LEVEL_HEIGHT`, `LEVELS_PER_STOREY` = 4).
- Lattice points are 12 m apart; a 192 m chunk has 16 x 16 tiles / owns points `16k .. 16k+15`.
- Edge categories: same height flat; same storey level step (slope); one storey slope; two or more storeys cliff. Diagonals never define a category.
- Clamp at points: lowered to at most `MAX_CLIFF_STEP` (3) storeys above the lowest cardinal neighbour point; levels one above the lowest same-storey neighbour. Unique, order-independent fixpoint.
- Cliff-end rule default E2 (`TerrainTileField.cliff_end`), E1 kept selectable for the gallery.
- Walkability of a lattice edge = not a cliff edge. A 24 m route edge c -> c+d is walkable iff both point edges (2c -> 2c+d, 2c+d -> 2c+2d) are.
- Town grades write per-POINT overrides (`native_control_heights` keyed by point).
- Cliff sheet (`sheet_bedrock`) stays the art direction; native KayKit wall/lip pieces on WORLD terrain are removed (village turf rims keep their own lattice dressing).
- Worker purity: kernels/meshers return CPU data; no RenderingServer or resources on the worker.
- World seeds may change geography; historical height-pinning fixtures are re-frozen or retired, never silently weakened.
- RAM: at most 3 concurrent Godot processes; the isolated runner (`tests/tools/run_suite_isolated.sh`) gates launches on 35% free memory.

## Review Focus

1. Walls exactly on a sample line (x = 12i + 6 is on every 2 m / 6 m / 0.5 m grid): every consumer must resolve the side deterministically (surface_y rounds to the nearest point; on_side takes an explicit owner). Test: mesher boundary vertices on both sides of a wall weld to the skirt top/bottom.
2. Chunk borders: dual cells `16k..16k+15` span `[192k-6, 192k+186]`, not the 192 m sheet rectangle. Test: skirts and sheet of two adjacent chunks share border vertices exactly (seam test).
3. 24 m consumers silently reading 12 m data (paths, settlements, grass tiles, tint, LOD step, VillageWorldScale divisibility). Test: `VillageWorldScale.validate()` passes, path walkability across a cliff between point 2c+1 and 2c+2 is rejected.
4. Town pads: a flat pad must be flat over all its points (odd points too). Test: graded region flat across the pad interior at 1 m sampling.
5. Water carve on odd points: river channels must stay continuous at 12 m sampling (no bank points skipped). Test: carve continuity along a trace at 12 m.

---

## File Structure

- `scripts/terrain/field/TerrainTileField.gd` — THE kernel (task 1, done).
- `scripts/terrain/field/TerrainSurfaceField.gd` — reduced to a thin, point-semantics forwarding facade during migration; deleted and callers renamed in task 11.
- `scripts/terrain/heightfield/HeightfieldPlan.gd`, `HeightfieldRegion.gd` — point-keyed plan/region.
- `scripts/terrain/field/TerrainChunkMesher.gd` — point owners, skirts from dual borders, world lip-clip/aprons/native pieces removed.
- `scripts/terrain/field/FieldTerrainStreamer.gd`, `WorldFieldBlockCache.gd`, `scripts/terrain/tools/{TerrainCategoryOverlay,CoordOverlay}.gd`, `terrain/materials/debug/terrain_category_overlay.gdshader`.
- Cliff sheet: `CliffSlopeEnvelope.gd`, `CliffSlopeField.gd`, `CliffRockDressing.gd`, `scripts/terrain/dressing/RockSkirt.gd`; legacy-only cliff files deleted.
- `scripts/terrain/grass/GrassField.gd`.
- Features: `PathPlan.gd`, `FeatureGroundField.gd`, `NativeTerrainGrade.gd`, `TerrainGradePatch.gd`, village files, `LatticeTerrainSurfaceRegion.gd`.
- Water: `WaterPlan.gd`, `WaterField.gd`, `WaterSkin.gd`, `WaterFieldContext.gd`.
- Harness: `tests/harness/tile_gallery.gd` (+ `.tscn`), comparison captures via `tests/harness/cliff_site_review.tscn`.

---

### Task 1: TerrainTileField kernel (DONE, commit a14b04f4)

`TerrainTileField`: `SPACING`, `EdgeCategory {FLAT, LEVEL, SLOPE, CLIFF}`, `CliffEnd {E1, E2}`, `static var cliff_end`, `spacing(region)`, `point_of(v, region)`, `edge_category(region, p, d)`, `is_cliff_edge(region, p, d)`, `is_wall_edge(region, p, d)`, `is_walkable_edge(region, p, d)`, `tile_params(region, tile) -> PackedFloat32Array(8)`, `tile_y(region, tile, u, v, side)`, `eval_params(params, u, v, side)`, `surface_y(region, x, z)`, `surface_y_on_side(region, x, z, owner: Vector2i)`, `bake_point(region, p)`, `sample_baked(baked, p, x, z, region)`, `wall_segments(region, rect) -> Array[Dictionary]` (`a, b, high, low, top, bottom, normal`), `height_bounds(region, rect)`. Tests: `tests/test_terrain_tile_field.gd` (16 green).

### Task 2: Point-keyed heightfield plan and region

**Files:** Modify `scripts/terrain/heightfield/HeightfieldPlan.gd`, `HeightfieldRegion.gd`, `scripts/terrain/water/WaterPlan.gd` (carve entry only). Test: `tests/test_heightfield_plan.gd`, `test_heightfield_region.gd`, `test_heightfield_clamp_step.gd` (rewrite to point semantics).

**Interfaces — Produces:**
- `HeightfieldPlan.POINT := 12.0` (sampling pitch), `HeightfieldPlan.CELL := 24.0` (coarse route/settlement cell = 2 x 2 tiles). `TILE` is removed (callers move to POINT or CELL explicitly).
- `raw_height(i, j)`, `uncarved_height(i, j)`, `storey_at(i, j)`, `level_at(i, j)`, `surface_height(i, j)`, `compute_region(ci, cj, radius)`, `compute_rect_region(Rect2i points)` — all in POINT indices; sample world position `(12 i, 12 j)`.
- `WaterPlan.carve_at(x: float, z: float) -> float` (pure in position; bucket = nearest 24 m cell, whose AABB covers its Voronoi square). `HeightfieldPlan._sample` calls `carve_at(12 i, 12 j)`. `carve_at_cell(cx, cz)` is deleted.
- `HeightfieldRegion`: keyed by points; `terrain_tile_size() -> 12.0`; `has_surface_point(i, j)` (rename of `has_surface_cell`); `certified_cells` renamed `certified_points` (Rect2i of points); `native_control_heights` keyed by point.

- [ ] Step 1: rewrite the three heightfield tests so every override callable/dict is keyed by point index and world positions use 12 m (e.g. a raised point (0,0) at 4 m is a 12 m-wide feature). Keep the clamp fixpoint, order-independence, level clamp, cache-eviction and rectangular-region equality tests.
- [ ] Step 2: run them (`Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_plan.gd -gexit`) — expect failures.
- [ ] Step 3: implement: `_sample(i,j)` at `Vector3(12 i, 0, 12 j)`, carve via `carve_at`; margins unchanged in point units (`storey_margin`, `level_margin`); `carved` tag per point.
- [ ] Step 4: tests green; commit.

### Task 3: Kernel switch — forwarding facade and legacy predicate removal

**Files:** Rewrite `scripts/terrain/field/TerrainSurfaceField.gd` as a facade over `TerrainTileField` with POINT semantics: `TILE := 12.0`, `HALF := 6.0`, `STOREY`, `tile_size`, `_cell_of` (= point_of), `transition_weight`, `is_cliff_edge`, `is_wall_edge`, `is_walkable_edge(region, point, d)` (no half-width form), `surface_y`, `surface_y_in_cell(region, x, z, i, j)` (= on_side), `height_bounds`, `height_bounds_in_cell` (owner point dual cell), `bake_cell` (= bake_point), `sample_baked`, `edge_profile(region, i, j, d, samples)` / `own_edge_profile` (dual-border profiles via on_side, kept for village turf), `is_exposed_edge(region, i, j, d)` (own profile flat at the point height and neighbour profile at least `EXPOSE_EPS` below somewhere), `_apply_grade`. Removed: `_edge_control`, `_corner_control`, `_natural_surface_y_in_cell`, `is_flat_cell`, `own_edge_flat`, `is_higher_flat`, `has_inner_corner`, `_is_inner_corner`, `_is_cliff_top`, `cardinal_strip_is_walkable`, `height_bounds` quadrant proof. `tests/test_terrain_surface_field.gd` is replaced by the tile tests (delete it; any still-meaningful facade behaviour gets a small test in `tests/test_terrain_tile_field.gd`).

- [ ] Step 1: grep every caller of removed functions; record them in the task report (they are fixed in tasks 4-9).
- [ ] Step 2: write the facade; add facade tests (on_side equivalence, `is_exposed_edge` on a straight cliff, `edge_profile` ordering along `pdir = (d.y, d.x)`).
- [ ] Step 3: run tile + facade tests green; commit.

### Task 4: Mesher on point owners

**Files:** `scripts/terrain/field/TerrainChunkMesher.gd`; tests `tests/test_terrain_chunk_mesher.gd`, `tests/test_september28_ground_seams.gd`, `tests/test_terrain_tinting.gd`.

- `CELL := 24.0` (tint lattice, chunk = 8 cells), `CHUNK_WORLD := 192.0`, `POINTS_PER_CHUNK := 16`, `STEP := 2.0`. Remove `TILE`.
- Sheet quads: owner = `TerrainSurfaceField._cell_of(centre, region)` (point); `bake_cell`/`sample_baked` per point. Path lookups keep the 24 m road cell (`roundi(c / CELL)`) for `features.surface_at_cell`.
- Skirts: for each owned point p and each cardinal d where the dual border has a wall (`TerrainTileField.wall_segments` over the chunk rect, grouped by high owner), sample the 12 m border at STEP: top = on_side(high), bottom = on_side(low); emit visual + collision quads where top > bottom + 0.001 (both at the border plane; no recess). Collision faces unchanged in role (production wall collision).
- Remove world lip clipping and aprons (`TOP_CLIP`, `LIP_LIFT`, `_cell_clip_info` world use, `_slot_lipped`, `_corner_capped`, `_edge_w` world use, `_inner_corner_vertex` world use, `_clip_perp`, `_emit_aprons`, `_apron_edge_appearance`, `SKIRT_RECESS`, `_skirt_turns`, `is_higher_flat` extensions) and the world native-piece calls (`CliffDressing.compute`, `compute_graded_faces`, `sheet_cover.uncovered(cliffs)`). Keep the skirt/ground UV constants (read once from CliffDressing assets as today). Keep `field_ground_surface` + the prefilled-cache clip helpers it uses for village turf (task 8 adapts the village).
- `field_normals`/`_vertex_owner`: candidates `roundi(v / 12)`, tie at ±6.
- Tests: rewrite mesher tests to point fixtures; required: seam equality between adjacent chunks; skirt top welds the high-side sheet and bottom the low-side sheet along every wall; no sheet triangle straddles a wall; collision covers the sheet.
- [ ] Commit after tests green.

### Task 5: Streaming, block cache and overlays

**Files:** `FieldTerrainStreamer.gd`, `WorldFieldBlockCache.gd`, `TerrainCategoryOverlay.gd` + shader, `CoordOverlay.gd`; tests `test_field_streamer.gd`, `test_world_field_block_cache.gd`, `test_september28_category_overlay.gd`.

- Block regions: `compute_region(centre = key*16 + 8, radius = 16)` (same metre margin); coverage check over tile corners `floor(x0/12) .. ceil(x1/12)`; `has_surface_point`.
- Snapshots per point (16 x 16 per chunk, points `16k..16k+15`): `loaded_point_at(p) -> [height, graded]`, `loaded_storey_at(p)`.
- `PRIORITY_FOCUS_STEP := 8.0` literal.
- F9 overlay: `SIZE` 128 points; shader reimplements the tile kernel (layers, slope/cliff profiles, saddle, E2) from a point-height texture; edge colours by lattice-edge category; tile grid at 12i, wall lines at 12i+6; chunk border at 192.
- CoordOverlay: tile readout (tile index `floor(v/12)`, 2 x 2 corner storey/level, four edge categories).
- [ ] Commit after tests green.

### Task 6: Cliff sheet, rocks, cliff vegetation; delete world native pieces

**Files:** `CliffSlopeEnvelope.gd` (`CELL := 12.0` scan lines at 12b+6; `_on_seam` 12 m pitch offset 6), `CliffSlopeField.gd` (`_ground_sampler`/`_mesh_height` via point bake; new constructor path from `wall_segments`), `CliffRockDressing.gd` (sheet branch no longer calls `CliffDressing.compute`/formations/corners/inner connections; reservations from wall segments), `RockSkirt.gd` (on_side owner = point), `CliffVegetation.gd` (vines removed with native walls), `NaturalArches.gd` (point-keyed flat test). Delete legacy-only files and their tests: `CliffTerraces.gd`, `NativeTerrainCap.gd`, `CliffKitDressing.gd`, `CliffInnerSurface.gd`, `CliffStepSurface.gd`, `CliffLedgeJoin.gd`, `CliffSiding.gd`, `CliffRockEndCaps.gd`, `CliffInnerConnections.gd`, crag/corner/relief builders used only for non-sheet styles, and `CliffDressing` world placement (keep only what village rims and UV lookup use). `CliffRockStyle` keeps only sheet styles.
- Tests: envelope/sheet tests that consume rasters stay; tests of deleted legacy code are deleted with it (list them in the report); rock foot lines on a synthetic straight wall and an outer corner from `wall_segments`.
- [ ] Commit after tests green.

### Task 7: Grass

**Files:** `scripts/terrain/grass/GrassField.gd`; tests `test_grass_field.gd` and grass-related september tests.
- `TILE_WORLD := 24.0` literal (grass tile identity unchanged).
- Wall facts from `TerrainTileField.wall_segments` over the tile rect (+ margin): distance from an anchor to high-side / low-side walls; gradient stencil one-sided when it crosses a wall; surface via point bake.
- [ ] Commit after tests green.

### Task 8: Paths, features, town grades, villages

**Files:** `PathPlan.gd` (`ROUTE_CELL := 24.0` constant in `PathProgram`; walkability = both point edges; ground samples unchanged), `FeatureGroundField.gd`, `SettlementPlan.gd`, `WorldFeaturePlan.gd`, `VillageFrame.gd`, `VillageOutskirtsConstruction.gd`, `VillageWorldScale.gd` (`TERRAIN_FIELD_CELL_M = HeightfieldPlan.CELL`), `VillageOutskirtsProgram.gd`, `NativeTerrainGrade.gd` (per-point controls: pitch 12, road edges expanded to point edges, relax/support on points), `TerrainGradePatch.gd` (its Controls lattice through `TerrainTileField`), `LatticeTerrainSurfaceRegion.gd` + `SettlementFabricAssembler.gd` turf (village cells are points on the village lattice; exposed edges via facade `is_exposed_edge`).
- Tests: `test_path_*`, `test_september27_road_grade`, `test_september29_terrain_review` (re-freeze fixtures with `tests/harness/road_grade_freeze.gd`), `test_september15_grade_topology`, village terrain tests; required new: a flat pad is flat at every point inside it; route edge across an odd-point cliff is not walkable.
- [ ] Commit after tests green.

### Task 9: Water

**Files:** `WaterPlan.gd` (pond/bank safety sampling at 12 m, `FEATHER` < 6 m guarantee revisited), `WaterField.gd` (region rects in points, per-point bake, crest owners via on_side/wall_segments, `ctx` chunk span 192 literal), `WaterSkin.gd` (`RIM_WALL_REACH` without native recess, `LIP_LIFT` removed), `WaterFieldContext.gd`.
- Tests: water suite files (compare against baseline list; geography-pinned water tests are re-pinned to current seed sites or retired with a note).
- [ ] Commit after tests green.

### Task 10: Suite triage

Run `tests/tools/run_suite_isolated.sh` on the branch; compare with the baseline copy (`/Users/ryko/story-dualgrid-base`, commit 7871fca4) results. Every new failure is either fixed in code, updated because its semantics intentionally changed (the report states why the new expectation is right), or retired as pinning retired geography / deleted code. No assertion weakened to pass.

### Task 11: Visual review, gallery, performance, cleanup

- `tests/harness/tile_gallery.gd`: every corner case (flat, slope straight/outer/inner, saddle slope/cliff, cliff straight/outer/inner, 3-storey wall, mixed cliff ends E1 vs E2 side by side, level steps) rendered through the real mesher + sheet, plus F9 overlay variant.
- Photo sites (seed 2697992464): before (baseline copy) / after (branch) with identical cameras via `cliff_site_review.tscn --shot`; side-by-side composites.
- Low-pass knob decision from renders (spec risk 1); cliff-end default decision (E2 unless renders say otherwise).
- `tests/harness/profile_terrain.gd` before/after.
- Rename `TerrainSurfaceField` callers to `TerrainTileField`, delete the facade.
- AGENTS.md: replace the TerrainSurfaceField/mesher/CliffDressing descriptions with the tile model; add a dated summary entry.
- Merge back: apply `git diff 7871fca4 dual-grid-terrain` onto main's working tree.
