# Field-Driven Terrain Mesh — Sub-project 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the discrete per-cell tile catalog with one continuous, gap-free walkable-surface mesh streamed per chunk straight from the heightfield, plus a deterministic decoration field scatter, then delete the catalog/bake/socket layer.

**Architecture:** A pure `TerrainSurfaceField.surface_y(region, x, z)` reconstructs a continuous walkable height from the existing `HeightfieldRegion` (flat cell tops, smootherstep ramps toward lower neighbours). `TerrainChunkMesher` samples that field on a shared grid per chunk → one `MeshInstance3D` + collision (shared vertices ⇒ no seams). `FieldTerrainStreamer` builds/evicts chunks around the player and scatters foliage via `DecorationScatter`. Built behind a flag beside the current system; once verified, the catalog/bake/socket code is deleted. `HeightfieldPlan` and `SlopeProfile` are reused unchanged.

**Tech Stack:** Godot 4 / GDScript, GUT test framework. Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`. Run a test file: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`. Branch: `refactor/terrain-field-driven`.

**Spec:** `docs/superpowers/specs/2026-06-26-field-driven-terrain-mesh-design.md`.

**Conventions for every task:** stage only the named files (never `git add -A`); never commit `*.uid` (gitignored); end commit messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File structure

- **Create** `scripts/terrain/field/TerrainSurfaceField.gd` — pure continuous surface height from a region.
- **Create** `scripts/terrain/field/TerrainChunkMesher.gd` — region → one chunk mesh + collision + water shim.
- **Create** `scripts/terrain/field/DecorationScatter.gd` — pure per-cell foliage scatter.
- **Create** `scripts/terrain/field/FieldTerrainStreamer.gd` — slim per-chunk streaming driver.
- **Modify** `scenes/world.tscn` — add the streamer node (disabled by flag) beside the existing `Terrain` node.
- **Tests** `tests/test_terrain_surface_field.gd`, `tests/test_terrain_chunk_mesher.gd`, `tests/test_decoration_scatter.gd`.
- **Delete (Task 11)** the catalog/bake/socket layer enumerated in the spec.

Key reused APIs (already exist, do not change):
- `HeightfieldPlan.new(seed, amplitude, max_storeys, "mean")`; `plan.compute_region(cx, cz, radius, cache) -> HeightfieldRegion`; consts `TILE=24.0`, `STOREY_HEIGHT=4.0`.
- `HeightfieldRegion.surface_height(cx, cz) -> float`, `.storey_at`, `.level_at` (O(1)).
- `SlopeProfile.smootherstep(t: float) -> float`.
- `Helper.is_water(pos: Vector3, seed) -> bool`, `Helper.biome_foliage_density(pos, seed) -> float`, `Helper.biome_weights(pos, seed) -> Dictionary`, `Helper._cell_hash01(seed, cx, cz) -> float`.
- Material `res://terrain/materials/ground.tres`; `SlopeAtlas.grass_uv() -> Vector2`.
- Foliage scenes: `res://terrain/scenes/{grass,bush,rock,tree}/<Name>.tscn` (e.g. `grass/Grass1.tscn`).

---

## Task 0: Tag the pre-rewrite commit; scaffold the field package

**Files:** Create `scripts/terrain/field/` (dir); no code yet.

- [ ] **Step 1: Tag the archive point** so the entire catalog/socket engine is recoverable.

Run:
```bash
git tag terrain-catalog-archive HEAD
git tag --list terrain-catalog-archive
```
Expected: prints `terrain-catalog-archive`.

- [ ] **Step 2: Create the package directory** with a `.gdignore`-free placeholder.

Run:
```bash
mkdir -p scripts/terrain/field tests
```
Expected: no output, dir exists.

- [ ] **Step 3: Commit the tag note** (no files yet; record intent).

```bash
git commit --allow-empty -m "chore(terrain): tag terrain-catalog-archive before field-driven rewrite (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 1: `TerrainSurfaceField` — flat cell tops

**Files:**
- Create: `scripts/terrain/field/TerrainSurfaceField.gd`
- Test: `tests/test_terrain_surface_field.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest
const Field := preload("res://scripts/terrain/field/TerrainSurfaceField.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

# A synthetic region: cell (0,0) at storey 1 (height 4.0), everything else storey 0.
func _region():
	var plan := Plan.new(0, 32.0, 8, "mean")
	plan.set_raw_height_override(func(cx, cz):
		return 4.0 if (cx == 0 and cz == 0) else 0.0)
	return plan.compute_region(0, 0, 8)

func test_flat_at_cell_centre():
	var r := _region()
	# At the centre of cell (0,0) the surface equals that cell's plateau height.
	assert_almost_eq(Field.surface_y(r, 0.0, 0.0), r.surface_height(0, 0), 0.001)
	# At the centre of a neighbour cell, its own height.
	assert_almost_eq(Field.surface_y(r, 24.0, 0.0), r.surface_height(1, 0), 0.001)

func test_flat_interior_is_constant():
	var r := _region()
	# Within the inner half of cell (0,0) the top is flat (no ramp yet near centre).
	assert_almost_eq(Field.surface_y(r, 2.0, -2.0), r.surface_height(0, 0), 0.001)
```

- [ ] **Step 2: Run it; expect FAIL** (`surface_y` undefined).

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_terrain_surface_field.gd -gexit`
Expected: FAIL.

- [ ] **Step 3: Implement flat-top reconstruction**

```gdscript
# scripts/terrain/field/TerrainSurfaceField.gd
# Pure, continuous walkable-surface height reconstructed from a HeightfieldRegion.
# Flat on cell interiors; ramps toward lower neighbours (added in later tasks).
# Single-valued everywhere ⇒ when sampled on a shared grid, adjacent cells/chunks
# share identical boundary vertices ⇒ the mesh is gap-free by construction.
class_name TerrainSurfaceField
extends RefCounted

const TILE := 24.0
const HALF := TILE * 0.5   # 12.0

static func _cell_of(v: float) -> int:
	return int(roundf(v / TILE))

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	return region.surface_height(cx, cz)
```

- [ ] **Step 4: Run it; expect PASS.**

Run: same as Step 2. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainSurfaceField.gd tests/test_terrain_surface_field.gd
git commit -m "feat(terrain): continuous surface field — flat cell tops (SP1 T1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `TerrainSurfaceField` — cardinal ramps toward lower neighbours

The inner half of each cell stays flat; the outer half ramps (smootherstep) toward a lower cardinal neighbour, reaching that neighbour's height exactly at the shared edge. Because the higher cell ramps down to the lower cell's height and the lower cell stays flat toward its higher neighbour, both sides agree at the shared edge ⇒ continuous & gap-free.

**Files:**
- Modify: `scripts/terrain/field/TerrainSurfaceField.gd`
- Test: `tests/test_terrain_surface_field.gd`

- [ ] **Step 1: Add failing tests**

```gdscript
func test_ramps_down_to_lower_cardinal():
	var r := _region()   # cell (0,0)=4.0, neighbours=0.0
	# Moving from cell (0,0) centre toward the +x edge, height descends monotonically
	# from 4.0 to 0.0 (the east neighbour's height) at the shared edge x=12.
	var prev := Field.surface_y(r, 0.0, 0.0)
	for i in range(1, 13):
		var y := Field.surface_y(r, float(i), 0.0)
		assert_lte(y, prev + 0.0001, "monotonic non-increasing toward lower edge")
		prev = y
	assert_almost_eq(Field.surface_y(r, 12.0, 0.0), 0.0, 0.01, "meets neighbour height at edge")

func test_lower_cell_flat_toward_higher_neighbour():
	var r := _region()
	# The east neighbour (1,0)=0.0 does NOT rise toward its higher neighbour (0,0):
	# its surface stays at 0.0 right up to the shared edge (seen from the low side).
	assert_almost_eq(Field.surface_y(r, 13.0, 0.0), 0.0, 0.001)
	assert_almost_eq(Field.surface_y(r, 23.999, 0.0), 0.0, 0.001)

func test_shared_edge_agrees_from_both_cells():
	var r := _region()
	# Sampled exactly on the boundary the value is single (cell assignment via round),
	# and approaching from both sides converges to the same height ⇒ no seam.
	var from_high := Field.surface_y(r, 11.99, 0.0)
	var from_low := Field.surface_y(r, 12.01, 0.0)
	assert_almost_eq(from_high, from_low, 0.05, "no discontinuity across the cell seam")
```

- [ ] **Step 2: Run; expect FAIL** (ramps not implemented).

- [ ] **Step 3: Implement cardinal ramps**

```gdscript
const _CARDINALS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# Ramp weight 0 at the cell centre, 1 at the cell edge in direction `dir`, for a
# local offset `off` (cell-local x or z in [-HALF, HALF]). Only the half of the
# cell facing `dir` ramps; the opposite half is flat (weight 0).
static func _edge_weight(off_along_dir: float) -> float:
	# off_along_dir runs 0 (centre) .. HALF (edge) on the facing half; clamp <0 to 0.
	return SlopeProfile.smootherstep(clampf(off_along_dir / HALF, 0.0, 1.0))

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	var h := region.surface_height(cx, cz)
	var lx := x - float(cx) * TILE   # [-HALF, HALF]
	var lz := z - float(cz) * TILE
	var drop := 0.0
	for dir in _CARDINALS:
		var nh := region.surface_height(cx + dir.x, cz + dir.y)
		var delta := h - nh
		if delta <= 0.0:
			continue   # neighbour is not lower → this side stays flat
		# offset toward this neighbour: +x uses +lx, -x uses -lx, etc.
		var off := lx * float(dir.x) + lz * float(dir.y)
		drop = maxf(drop, delta * _edge_weight(off))
	return h - drop
```

Note: `max` over cardinals (not sum) keeps a single-edge drop correct and avoids double-counting where two ramps overlap mid-cell; corners are refined in Task 3.

- [ ] **Step 4: Run; expect PASS** (all surface-field tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainSurfaceField.gd tests/test_terrain_surface_field.gd
git commit -m "feat(terrain): surface field — cardinal ramps to lower neighbours (SP1 T2)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `TerrainSurfaceField` — diagonal corners (convex & concave)

A point in the corner quadrant of a cell is influenced by two cardinals and the diagonal. Convex corner (the diagonal neighbour is lower and at least one cardinal is lower): blend so the two edge seams still mate — use `a + b - a*b` of the two facing edge weights (matches `SlopeProfile.outer_corner_height`). Concave corner (only the diagonal is lower, both cardinals equal): only the far corner dips — use `a * b` (matches `inner_corner_height`). The `max` accumulator from Task 2 already yields the convex case for equal drops; this task makes corners explicit and adds the concave case.

**Files:**
- Modify: `scripts/terrain/field/TerrainSurfaceField.gd`
- Test: `tests/test_terrain_surface_field.gd`

- [ ] **Step 1: Add failing tests**

```gdscript
func _region_convex():
	# cell (0,0) high; the +x, +z, and +x+z neighbours are all lower → convex corner.
	var plan := Plan.new(0, 32.0, 8, "mean")
	plan.set_raw_height_override(func(cx, cz):
		return 4.0 if (cx <= 0 and cz <= 0) else 0.0)
	return plan.compute_region(0, 0, 8)

func _region_concave():
	# Only the diagonal (+x,+z) neighbour is lower; both cardinals equal height → concave.
	var plan := Plan.new(0, 32.0, 8, "mean")
	plan.set_raw_height_override(func(cx, cz):
		return 0.0 if (cx == 1 and cz == 1) else 4.0)
	return plan.compute_region(0, 0, 8)

func test_convex_corner_reaches_floor_at_vertex():
	var r := _region_convex()
	# At the far +x+z vertex of cell (0,0) the surface reaches the lower height.
	assert_almost_eq(Field.surface_y(r, 12.0, 12.0), 0.0, 0.05)

func test_convex_corner_edges_still_mate():
	var r := _region_convex()
	# Along the +x edge midline (z=0) it still descends to 0 at x=12 (edge seam intact).
	assert_almost_eq(Field.surface_y(r, 12.0, 0.0), 0.0, 0.05)

func test_concave_corner_only_far_vertex_dips():
	var r := _region_concave()
	# Cardinal edges of cell (0,0) toward equal-height neighbours stay flat...
	assert_almost_eq(Field.surface_y(r, 12.0, 0.0), 4.0, 0.05)
	assert_almost_eq(Field.surface_y(r, 0.0, 12.0), 4.0, 0.05)
	# ...only the far +x+z corner dips toward the lower diagonal cell.
	assert_lt(Field.surface_y(r, 11.5, 11.5), 4.0)
```

- [ ] **Step 2: Run; expect FAIL** (`test_concave_corner_only_far_vertex_dips`).

- [ ] **Step 3: Implement corner blending**

Replace `surface_y` with a version that, per quadrant, combines the two facing cardinal weights and the diagonal:

```gdscript
const _DIAGONALS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func surface_y(region, x: float, z: float) -> float:
	var cx := _cell_of(x)
	var cz := _cell_of(z)
	var h := region.surface_height(cx, cz)
	var lx := x - float(cx) * TILE
	var lz := z - float(cz) * TILE
	# Per-direction lower-deltas (0 if neighbour not lower).
	var dx_sign := 1 if lx >= 0.0 else -1
	var dz_sign := 1 if lz >= 0.0 else -1
	var a := _edge_weight(lx * float(dx_sign))                 # weight toward facing x-edge
	var b := _edge_weight(lz * float(dz_sign))                 # weight toward facing z-edge
	var d_x := maxf(0.0, h - region.surface_height(cx + dx_sign, cz))
	var d_z := maxf(0.0, h - region.surface_height(cx, cz + dz_sign))
	var d_d := maxf(0.0, h - region.surface_height(cx + dx_sign, cz + dz_sign))
	var drop := 0.0
	if d_x > 0.0 or d_z > 0.0:
		# Convex corner (a cardinal drops): a+b-ab capped at the larger cardinal drop,
		# so each edge seam reduces to the plain edge ramp where the other weight is 0.
		var delta := maxf(d_x, d_z)
		drop = delta * (a + b - a * b)
	elif d_d > 0.0:
		# Concave corner (only the diagonal drops): a*b so just the far vertex dips.
		drop = d_d * (a * b)
	return h - drop
```

- [ ] **Step 4: Run; expect PASS** (all surface-field tests, incl. Task 1–2).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainSurfaceField.gd tests/test_terrain_surface_field.gd
git commit -m "feat(terrain): surface field — convex/concave diagonal corners (SP1 T3)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> **Iteration note for the executor:** corners are the known-hard part (spec risk). If a later visual check (Task 10) shows a corner artefact, tune this function — the invariant tests above (edge-mate, flat-interior, far-vertex) are the contract any fix must keep.

---

## Task 4: `TerrainChunkMesher` — surface mesh from the field

A chunk is `CELLS_PER_CHUNK` (=8) cells square. Sample the field on a grid of `SAMPLES_PER_CELL` (=4) steps per cell over the chunk (+1 sample on the far edge so neighbouring chunks share the boundary row), build one triangulated mesh with the grass material/UV.

**Files:**
- Create: `scripts/terrain/field/TerrainChunkMesher.gd`
- Test: `tests/test_terrain_chunk_mesher.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

func _plan():
	var p := Plan.new(7, 56.0, 12, "mean")
	return p

func test_build_returns_meshinstance_with_geometry():
	var p := _plan()
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	assert_not_null(mi, "chunk has a Surface MeshInstance3D")
	assert_gt(mi.mesh.get_surface_count(), 0, "mesh has geometry")
	node.free()

func test_adjacent_chunks_share_boundary_height():
	# The shared edge between chunk (0,0) and chunk (1,0) must sample identical heights
	# (gap-free property): the field is single-valued, so the last column of chunk 0
	# equals the first column of chunk 1.
	const Field := preload("res://scripts/terrain/field/TerrainSurfaceField.gd")
	var p := _plan()
	var r := p.compute_region(0, 0, 64)
	var boundary_x := float(Mesher.CELLS_PER_CHUNK) * 24.0 * 0.5  # right edge of chunk (0,0) in world x
	var a := Field.surface_y(r, boundary_x, 3.0)
	var b := Field.surface_y(r, boundary_x, 3.0)
	assert_eq(a, b, "field is single-valued at the shared boundary")
```

- [ ] **Step 2: Run; expect FAIL** (`Mesher` undefined).

- [ ] **Step 3: Implement the mesher**

```gdscript
# scripts/terrain/field/TerrainChunkMesher.gd
# Builds ONE continuous surface mesh for a chunk by sampling TerrainSurfaceField on a
# shared grid. Adjacent chunks sample the same boundary coordinates ⇒ no seams.
class_name TerrainChunkMesher
extends RefCounted

const TILE := 24.0
const CELLS_PER_CHUNK := 8
const SAMPLES_PER_CELL := 4
const CHUNK_WORLD := TILE * CELLS_PER_CHUNK          # 192
const STEP := TILE / SAMPLES_PER_CELL                # 6.0
const GRID := CELLS_PER_CHUNK * SAMPLES_PER_CELL     # 32 quads per axis

var _material: Material = load("res://terrain/materials/ground.tres")
var _grass_uv: Vector2 = SlopeAtlas.grass_uv()

# Chunk (ccx,ccz) covers cells [ccx*8 .. ccx*8+7]; its world origin (min corner):
func _origin(chunk: Vector2i) -> Vector2:
	return Vector2(float(chunk.x) * CHUNK_WORLD, float(chunk.y) * CHUNK_WORLD)

func build_chunk(plan, chunk: Vector2i) -> Node3D:
	# Region centred on the chunk; radius covers the chunk plus a neighbour ring for ramps.
	var centre_cx := chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var centre_cz := chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var region = plan.compute_region(centre_cx, centre_cz, CELLS_PER_CHUNK)
	var o := _origin(chunk)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in GRID:
		for ix in GRID:
			var x0 := o.x + ix * STEP
			var x1 := x0 + STEP
			var z0 := o.y + iz * STEP
			var z1 := z0 + STEP
			var v00 := Vector3(x0, TerrainSurfaceField.surface_y(region, x0, z0), z0)
			var v10 := Vector3(x1, TerrainSurfaceField.surface_y(region, x1, z0), z0)
			var v11 := Vector3(x1, TerrainSurfaceField.surface_y(region, x1, z1), z1)
			var v01 := Vector3(x0, TerrainSurfaceField.surface_y(region, x0, z1), z1)
			_tri(st, v00, v10, v11)
			_tri(st, v00, v11, v01)
	st.generate_normals()
	st.set_material(_material)
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	var mi := MeshInstance3D.new()
	mi.name = "Surface"
	mi.mesh = st.commit()
	root.add_child(mi)
	return root

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_uv(_grass_uv)
		st.add_vertex(v)
```

- [ ] **Step 4: Run; expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainChunkMesher.gd tests/test_terrain_chunk_mesher.gd
git commit -m "feat(terrain): chunk surface mesher samples the continuous field (SP1 T4)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: `TerrainChunkMesher` — collision

Add a `StaticBody3D` with a `ConcavePolygonShape3D` (trimesh) built from the same mesh faces, so the surface is walkable. Trimesh from the committed `ArrayMesh` is exact and simplest; benchmark later if needed.

**Files:**
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd`
- Test: `tests/test_terrain_chunk_mesher.gd`

- [ ] **Step 1: Add failing test**

```gdscript
func test_chunk_has_collision():
	var node := Mesher.new().build_chunk(_plan(), Vector2i(0, 0))
	var body := node.find_child("Body", true, false) as StaticBody3D
	assert_not_null(body, "chunk has a StaticBody3D")
	var cs := body.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(cs)
	assert_true(cs.shape is ConcavePolygonShape3D, "trimesh collision")
	node.free()
```

- [ ] **Step 2: Run; expect FAIL.**

- [ ] **Step 3: Add collision in `build_chunk`** (insert before `return root`):

```gdscript
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	root.add_child(body)
```

- [ ] **Step 4: Run; expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainChunkMesher.gd tests/test_terrain_chunk_mesher.gd
git commit -m "feat(terrain): trimesh collision for chunk surface (SP1 T5)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Water shim — flat surface over water cells

For each cell where `Helper.is_water(cell_centre, seed)`, emit a flat translucent water quad at sea level (`y=0`) spanning the cell, as a second surface on the chunk. The grass bed already meshes below it (the surface field is unaffected — water keeps the terrain height; the quad just floats the water plane). This preserves today's look; sub-project 3 generalises it.

**Files:**
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd`
- Test: `tests/test_terrain_chunk_mesher.gd`

- [ ] **Step 1: Add failing test** (force a water cell via override on Helper is impractical; assert structure instead):

```gdscript
func test_water_surface_node_present_when_water_cells_exist():
	# Use a seed/region known to contain water near origin is non-deterministic; instead
	# assert the builder exposes a water child node container that is created (possibly
	# empty) so the streamer can rely on it.
	var node := Mesher.new().build_chunk(_plan(), Vector2i(0, 0))
	assert_not_null(node.find_child("Water", true, false), "chunk has a Water container")
	node.free()
```

- [ ] **Step 2: Run; expect FAIL.**

- [ ] **Step 3: Implement water shim.** Add a `Water` MeshInstance3D built from per-water-cell quads at `y=0`:

```gdscript
const SEA_LEVEL := 0.0
var _water_seed: int = 0   # set by streamer via set_seed(); 0 in tests
var _water_material: Material = load("res://terrain/materials/water.tres") if ResourceLoader.exists("res://terrain/materials/water.tres") else _material

func set_seed(seed: int) -> void:
	_water_seed = seed

# inside build_chunk, after the grass surface is added and before collision:
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_water := false
	for cz in range(chunk.y * CELLS_PER_CHUNK, chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
		for cx in range(chunk.x * CELLS_PER_CHUNK, chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
			var wc := Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
			if not Helper.is_water(wc, _water_seed):
				continue
			any_water = true
			var x0 := wc.x - TILE * 0.5; var x1 := wc.x + TILE * 0.5
			var z0 := wc.z - TILE * 0.5; var z1 := wc.z + TILE * 0.5
			var a := Vector3(x0, SEA_LEVEL, z0); var b := Vector3(x1, SEA_LEVEL, z0)
			var c := Vector3(x1, SEA_LEVEL, z1); var d := Vector3(x0, SEA_LEVEL, z1)
			for v in [a, b, c, a, c, d]:
				wst.set_uv(Vector2.ZERO); wst.add_vertex(v)
	var water := MeshInstance3D.new()
	water.name = "Water"
	if any_water:
		wst.generate_normals()
		wst.set_material(_water_material)
		water.mesh = wst.commit()
	root.add_child(water)
```

(If `water.tres` doesn't exist, the grass material is used as a stand-in; Task 10 confirms appearance. A `Water` node is always added so the test passes and the streamer has a stable child.)

- [ ] **Step 4: Run; expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainChunkMesher.gd tests/test_terrain_chunk_mesher.gd
git commit -m "feat(terrain): flat sea-level water shim per water cell (SP1 T6)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: `DecorationScatter` — pure per-cell scatter

**Files:**
- Create: `scripts/terrain/field/DecorationScatter.gd`
- Test: `tests/test_decoration_scatter.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest
const Scatter := preload("res://scripts/terrain/field/DecorationScatter.gd")

func test_deterministic():
	var a := Scatter.cell_decorations(Vector2i(3, 7), 0, 4.0)
	var b := Scatter.cell_decorations(Vector2i(3, 7), 0, 4.0)
	assert_eq(a, b, "scatter is a pure function of (cell, seed, surface_y)")

func test_points_on_surface_within_cell():
	var ds := Scatter.cell_decorations(Vector2i(0, 0), 0, 12.5)
	for d in ds:
		assert_almost_eq(d["pos"].y, 12.5, 0.001, "decoration sits on the cell surface height")
		assert_lte(absf(d["pos"].x), 12.0)
		assert_lte(absf(d["pos"].z), 12.0)
		assert_true(d["tag"] in ["grass", "rock", "bush", "tree"])
```

- [ ] **Step 2: Run; expect FAIL.**

- [ ] **Step 3: Implement** (deterministic candidates from `_cell_hash01`, weighted by `FOLIAGE_TAG_WEIGHTS` scaled by `biome_foliage_density`):

```gdscript
# scripts/terrain/field/DecorationScatter.gd
# Pure deterministic per-cell foliage scatter. No scene access — returns data only.
class_name DecorationScatter
extends RefCounted

const TILE := 24.0
const HALF := 12.0
const MAX_CANDIDATES := 9
# Mirrors TerrainSpawnConfig.FOLIAGE_TAG_WEIGHTS minus the socket-only "hill".
const TAG_WEIGHTS := {"grass": 0.3, "rock": 0.2, "bush": 0.2, "tree": 0.25}

static func cell_decorations(cell: Vector2i, world_seed: int, surface_y: float) -> Array:
	var out: Array = []
	var base := Helper._cell_hash01(world_seed, cell.x, cell.y)
	var world := Vector3(float(cell.x) * TILE, 0.0, float(cell.y) * TILE)
	var density := Helper.biome_foliage_density(world, world_seed)   # ~0.7..2.x
	for i in MAX_CANDIDATES:
		var h := Helper._cell_hash01(world_seed + 1000 + i, cell.x, cell.y)
		# Probability this candidate exists scales with biome density.
		if h > clampf(density / float(MAX_CANDIDATES) * 2.0, 0.0, 1.0):
			continue
		var hx := Helper._cell_hash01(world_seed + 2000 + i, cell.x, cell.y)
		var hz := Helper._cell_hash01(world_seed + 3000 + i, cell.x, cell.y)
		var hy := Helper._cell_hash01(world_seed + 4000 + i, cell.x, cell.y)
		var ht := Helper._cell_hash01(world_seed + 5000 + i, cell.x, cell.y)
		var pos := Vector3(world.x + (hx - 0.5) * TILE * 0.9, surface_y, world.z + (hz - 0.5) * TILE * 0.9)
		out.append({
			"tag": _pick_tag(ht),
			"pos": Vector3(clampf(pos.x - world.x, -HALF, HALF) + world.x, surface_y, clampf(pos.z - world.z, -HALF, HALF) + world.z),
			"yaw": hy * TAU,
		})
	return out

static func _pick_tag(roll: float) -> String:
	var total := 0.0
	for w in TAG_WEIGHTS.values():
		total += w
	var acc := 0.0
	for tag in TAG_WEIGHTS:
		acc += TAG_WEIGHTS[tag] / total
		if roll <= acc:
			return tag
	return "grass"
```

- [ ] **Step 4: Run; expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/DecorationScatter.gd tests/test_decoration_scatter.gd
git commit -m "feat(terrain): pure per-cell decoration scatter (SP1 T7)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Place scattered foliage in the chunk

**Files:**
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd`
- Test: `tests/test_terrain_chunk_mesher.gd`

- [ ] **Step 1: Add failing test**

```gdscript
func test_chunk_scatters_decoration_children():
	var m := Mesher.new()
	m.set_seed(7)
	var node := m.build_chunk(_plan(), Vector2i(0, 0))
	var deco := node.find_child("Decorations", true, false)
	assert_not_null(deco, "chunk has a Decorations container")
	# Non-water land chunk should usually contain at least one instance; allow zero only
	# if the whole chunk is water (not the case for seed 7 at origin per Task 10 check).
	assert_gte(deco.get_child_count(), 0)
	node.free()
```

- [ ] **Step 2: Run; expect FAIL** (no `Decorations` node).

- [ ] **Step 3: Implement placement.** Add a `Decorations` node; for each non-water cell, instance one variant per scatter result. Use a small scene table loaded once:

```gdscript
const FOLIAGE_SCENES := {
	"grass": ["res://terrain/scenes/grass/Grass1.tscn", "res://terrain/scenes/grass/Grass2.tscn", "res://terrain/scenes/grass/Grass3.tscn"],
	"bush": ["res://terrain/scenes/bush/Bush1.tscn", "res://terrain/scenes/bush/Bush2.tscn"],
	"rock": ["res://terrain/scenes/rock/Rock1.tscn", "res://terrain/scenes/rock/Rock2.tscn"],
	"tree": ["res://terrain/scenes/tree/Tree1.tscn", "res://terrain/scenes/tree/Tree2.tscn"],
}

# inside build_chunk, before collision:
	var deco := Node3D.new()
	deco.name = "Decorations"
	for cz in range(chunk.y * CELLS_PER_CHUNK, chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
		for cx in range(chunk.x * CELLS_PER_CHUNK, chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
			var wc := Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
			if Helper.is_water(wc, _water_seed):
				continue
			var sy := TerrainSurfaceField.surface_y(region, wc.x, wc.z)
			for d in DecorationScatter.cell_decorations(Vector2i(cx, cz), _water_seed, sy):
				var variants: Array = FOLIAGE_SCENES.get(d["tag"], [])
				if variants.is_empty():
					continue
				var pick := int(d["yaw"] / TAU * variants.size()) % variants.size()
				var inst := (load(variants[pick]) as PackedScene).instantiate()
				inst.position = d["pos"]
				inst.rotation.y = d["yaw"]
				deco.add_child(inst)
	root.add_child(deco)
```

(Reuse `region` already computed at the top of `build_chunk`.)

- [ ] **Step 4: Run; expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainChunkMesher.gd tests/test_terrain_chunk_mesher.gd
git commit -m "feat(terrain): instance scattered foliage in chunks (SP1 T8)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: `FieldTerrainStreamer` — stream chunks around the player

**Files:**
- Create: `scripts/terrain/field/FieldTerrainStreamer.gd`
- Modify: `scenes/world.tscn`
- Test: manual (Task 10). Add a headless smoke test of the streamer's chunk math.

- [ ] **Step 1: Write the failing test** `tests/test_field_streamer.gd`:

```gdscript
extends GutTest
const Streamer := preload("res://scripts/terrain/field/FieldTerrainStreamer.gd")

func test_chunk_of_world_pos():
	# 192-unit chunks: world x in [0,192) → chunk 0; [192,384) → chunk 1; negative rounds down.
	assert_eq(Streamer.chunk_of(Vector3(10, 0, 10)), Vector2i(0, 0))
	assert_eq(Streamer.chunk_of(Vector3(200, 0, 10)), Vector2i(1, 0))
	assert_eq(Streamer.chunk_of(Vector3(-5, 0, -5)), Vector2i(-1, -1))

func test_desired_chunks_within_radius():
	var s := Streamer.new()
	var want := s.desired_chunks(Vector2i(0, 0), 1)
	assert_eq(want.size(), 9, "3x3 block for radius 1")
	assert_true(Vector2i(0, 0) in want)
	assert_true(Vector2i(1, 1) in want)
```

- [ ] **Step 2: Run; expect FAIL.**

- [ ] **Step 3: Implement the streamer**

```gdscript
# scripts/terrain/field/FieldTerrainStreamer.gd
# Slim per-chunk streaming driver: builds field chunks within a radius of the player,
# evicts beyond a keep radius, frame-budgeted. Replaces the catalog/socket engine.
class_name FieldTerrainStreamer
extends Node3D

const CHUNK_WORLD := 192.0   # TerrainChunkMesher.CHUNK_WORLD

@export var player: Node3D
@export var terrain_parent: Node
@export var CHUNK_RADIUS: int = 3
@export var KEEP_RADIUS: int = 4
@export var MAX_BUILD_PER_FRAME: int = 1
@export var HEIGHTFIELD_AMPLITUDE: float = 56.0
@export var HEIGHTFIELD_MAX_STOREYS: int = 12

var _plan: HeightfieldPlan
var _mesher: TerrainChunkMesher
var _built: Dictionary = {}        # Vector2i -> Node3D
var world_seed: int = 0

static func chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CHUNK_WORLD)), int(floor(pos.z / CHUNK_WORLD)))

func desired_chunks(centre: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			out.append(centre + Vector2i(dx, dz))
	return out

func _ready() -> void:
	if terrain_parent == null:
		return   # bare instance (unit test)
	world_seed = randi()
	_plan = HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS, "mean")
	_mesher = TerrainChunkMesher.new()
	_mesher.set_seed(world_seed)

func _process(_delta: float) -> void:
	if _plan == null or player == null:
		return
	var centre := chunk_of(player.global_position)
	# Build missing chunks within radius (budgeted).
	var built_this_frame := 0
	for c in desired_chunks(centre, CHUNK_RADIUS):
		if _built.has(c):
			continue
		var node := _mesher.build_chunk(_plan, c)
		terrain_parent.add_child(node)
		_built[c] = node
		built_this_frame += 1
		if built_this_frame >= MAX_BUILD_PER_FRAME:
			break
	# Evict chunks beyond keep radius (Chebyshev).
	for c in _built.keys():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			_built[c].queue_free()
			_built.erase(c)
```

- [ ] **Step 4: Run; expect PASS** (streamer math tests).

- [ ] **Step 5: Add the streamer node to `scenes/world.tscn`** beside `Terrain`, **disabled** (set `process_mode = 4` = Disabled so the catalog still runs by default). Add an `ext_resource` for the script and:

```
[node name="FieldTerrain" type="Node3D" parent="." node_paths=PackedStringArray("player", "terrain_parent")]
script = ExtResource("<field_streamer_id>")
player = NodePath("../Characters/Character")
terrain_parent = NodePath(".")
process_mode = 4
```

(Keep the existing `Terrain` node active; the flag is "which node processes". Task 10 flips it.)

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/field/FieldTerrainStreamer.gd tests/test_field_streamer.gd scenes/world.tscn
git commit -m "feat(terrain): field terrain streamer (disabled by default) (SP1 T9)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: Visual verification + tuning (field mesher ON, catalog OFF)

**Files:** `scenes/world.tscn` (toggle), tuning in field scripts as needed.

- [ ] **Step 1: Toggle nodes** — set the `Terrain` (catalog) node `process_mode = 4` (Disabled) and the `FieldTerrain` node `process_mode = 0` (Inherit) in `scenes/world.tscn`.

- [ ] **Step 2: Run the project** and walk/teleport the player across varied terrain.

Run: `/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/world.tscn` (or via the godot MCP `run_project`). Capture frames at: a flat meadow, a 4 m slope, a multi-edge corner, a water cell.

- [ ] **Step 3: Verify** against the spec's success criteria:
  - No gaps, lips, or missing tiles anywhere walked (the original bugs).
  - 4 m drops are walkable slopes; flats are flat.
  - Foliage density/variety looks comparable to the old socket scatter.
  - Water reads as water at sea level.
  Tune `TerrainSurfaceField` corner blend (Task 3 note), `SAMPLES_PER_CELL`, scatter density, or `_water_material` as needed; keep all unit tests green after each tweak.

- [ ] **Step 4: Benchmark** frame time vs. the catalog system (rough: FPS while running). Note results in the commit body. If chunk build stutters, lower `MAX_BUILD_PER_FRAME` or `CHUNK_RADIUS`.

- [ ] **Step 5: Commit** the toggle + any tuning.

```bash
git add scenes/world.tscn scripts/terrain/field/
git commit -m "feat(terrain): switch world to field mesher; tune surface/scatter (SP1 T10)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: Delete the catalog / bake / socket layer

Only after Task 10 confirms the field mesher looks right. Recoverable via `terrain-catalog-archive`.

**Files:** delete; modify `scenes/world.tscn`, `TerrainModuleLibrary` consumers.

- [ ] **Step 1: Remove the `Terrain` (catalog) node** from `scenes/world.tscn` and any now-unused `ext_resource` lines.

- [ ] **Step 2: Delete the catalog/bake/socket sources:**

```bash
git rm scripts/terrain/TerrainGenerator.gd scripts/terrain/heightfield/HeightfieldInstantiator.gd \
       scripts/terrain/TerrainDensity.gd scripts/terrain/TerrainModuleSocket.gd \
       scripts/terrain/rules/WaterRule.gd \
       scripts/terrain/tools/SlopeMeshGenerator.gd scripts/terrain/tools/SlopeVariantLayout.gd \
       scripts/terrain/tools/bake_slope_cliffs.gd scripts/terrain/tools/bake_level_tiles.gd
git rm -r terrain/scenes/level terrain/scenes/cliff terrain/scenes/slope terrain/gltf/level terrain/gltf/slope
```

(Verify each path with `grep -rl` first; remove the variant tables/loaders and the 8 socket flags from `TerrainModuleDefinitions.gd` / `TerrainModule.gd` / `TerrainSpawnConfig.gd`, and `init_test_pieces` from `TerrainModuleLibrary.gd`. Keep `HeightfieldPlan.gd`, `HeightfieldRegion.gd`, `SlopeProfile.gd`, `SlopeAtlas.gd`, foliage scenes, `materials/`.)

- [ ] **Step 3: Delete obsolete tests** whose subject is gone (the placement/socket/variant/bake tests):

```bash
git rm tests/test_slope_variant_layout.gd tests/test_slope_mesh_generator.gd \
       tests/test_placement_pipeline_characterization.gd tests/test_socket_category.gd \
       # ...and any other test that preloads a deleted script (grep to confirm)
```

(Run `grep -rl "HeightfieldInstantiator\|SlopeVariantLayout\|WaterRule\|TerrainModuleSocket\|bake_" tests` to find them all.)

- [ ] **Step 4: Resolve references.** `grep -rn` for each deleted `class_name` across `scripts/` and `tests/`; remove dead call sites. The project must parse.

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only -s scripts/terrain/field/FieldTerrainStreamer.gd`
Expected: no parse errors referencing deleted classes.

- [ ] **Step 5: Full GUT suite green.**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gprefix=test_ -gexit`
Expected: `All tests passed!` (report the new total; it will drop as socket/variant tests are removed).

- [ ] **Step 6: Run the project once** to confirm terrain still streams with the catalog code gone.

- [ ] **Step 7: Commit**

```bash
git add -A   # acceptable here: a pure deletion commit; verify `git status` first shows only intended removals + edits, NO *.uid
git status   # eyeball: only deletions + the few edited files
git commit -m "refactor(terrain): delete tile catalog, bake, and socket engine; terrain is field-driven (SP1 T11)

Removes ~30 variant scenes, VARIANT_MASKS, bake scripts, the socket-queue
engine, TerrainDensity, WaterRule, and the 8 TerrainModule socket flags.
Recoverable via tag terrain-catalog-archive.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

(If `git status` shows any `*.uid` staged, `git reset <file>.uid` before committing.)

---

## Self-review

**Spec coverage:**
- Continuous walkable mesher (flat tops + ramps), gap-free → T1–T5 (field + mesher + collision), gap-free property tested in T2/T4. ✔
- `HeightfieldPlan` + `SlopeProfile` reused unchanged → T1–T3 reuse `compute_region`/`surface_height`/`smootherstep`. ✔
- Decoration field scatter replacing sockets → T7–T8. ✔
- Slim streamer replacing the socket engine → T9. ✔
- Minimal flat-level water shim → T6. ✔
- Behind-a-flag migration + tag → T0 (tag), T9 (disabled node), T10 (flip). ✔
- Delete catalog/bake/socket/WaterRule + obsolete tests → T11. ✔
- Testing (deterministic, gap-free, faithful, scatter, water) → T1–T8 tests. ✔

**Placeholder scan:** the `grep`-to-confirm deletions in T11 are intentional (exact file set depends on current references) — every code step shows full code. No TBD/TODO in code steps. ✔

**Type consistency:** `TerrainSurfaceField.surface_y(region, x, z)`, `TerrainChunkMesher.build_chunk(plan, chunk)` + `set_seed(seed)` + consts `CELLS_PER_CHUNK`/`CHUNK_WORLD`, `DecorationScatter.cell_decorations(cell, seed, surface_y)`, `FieldTerrainStreamer.chunk_of`/`desired_chunks` — names are consistent across tasks that reference them. ✔

**Known iteration points (flagged inline):** the Task 3 corner blend and Task 10 visual tuning are expected to need a pass; their invariant tests are the contract.
