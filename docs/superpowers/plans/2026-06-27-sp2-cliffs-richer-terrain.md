# SP2 — Cliffs + richer terrain — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Generate blocky vertical rock cliffs where the heightfield steps down ≥2 storeys, and tune the noise for a moderate rolling-hills-with-occasional-cliffs look.

**Architecture:** Relax the heightfield clamp so adjacent cells can differ by up to 3 storeys (was 1). `TerrainSurfaceField` keeps cliff-top cells flat to their edge (ramps only for ≤1-storey neighbours). `TerrainChunkMesher` emits vertical rock-faced wall quads (same atlas material, `SlopeAtlas.cliff_uv()`) into the surface mesh wherever a cardinal neighbour is ≥2 storeys lower. Gap-free because every wall connects two flat edges read from the same `surface_height`.

**Tech Stack:** Godot 4 / GDScript, GUT. Binary `/Applications/Godot.app/Contents/MacOS/Godot`. Run a test file: `… -s addons/gut/gut_cmdln.gd -gtest=res://tests/<f>.gd -gexit`. Branch `refactor/terrain-field-driven`.

**Spec:** `docs/superpowers/specs/2026-06-27-sp2-cliffs-richer-terrain-design.md`.

**Conventions:** stage only named files (never `git add -A`); never commit `*.uid`; commit messages end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. Godot prints harmless "RID allocations leaked at exit" lines on shutdown — not failures. Free any Node instanced in a test.

---

## Task 1: Relax the heightfield clamp (parameterized, default unchanged)

**Files:** Modify `scripts/terrain/heightfield/HeightfieldPlan.gd`; Test `tests/test_heightfield_clamp_step.gd` (new) + existing `tests/test_heightfield*` stay green.

- [ ] **Step 1: Failing test** `tests/test_heightfield_clamp_step.gd`:

```gdscript
extends GutTest
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

func test_default_step_is_one():
	# A spike of storey 9 surrounded by 0 clamps to 1 at the cardinal neighbour (step 1).
	var targets := {}
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			targets[Vector2i(dx, dz)] = 9 if (dx == 0 and dz == 0) else 0
	var out := Plan.clamp_field(targets)            # default max_step = 1
	assert_eq(out[Vector2i(0, 0)], 1, "centre clamped to neighbour+1")

func test_step_three_allows_taller_cliffs():
	var targets := {}
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			targets[Vector2i(dx, dz)] = 9 if (dx == 0 and dz == 0) else 0
	var out := Plan.clamp_field(targets, 3)         # max_step = 3
	assert_eq(out[Vector2i(0, 0)], 3, "centre clamped to neighbour+3 (a 12m cliff)")
	# never MORE than 3 above any cardinal neighbour
	for cell: Vector2i in out:
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if out.has(cell + d):
				assert_lte(out[cell] - out[cell + d], 3)
```

- [ ] **Step 2: Run; expect FAIL** (`clamp_field` takes 1 arg).

- [ ] **Step 3: Implement.** In `HeightfieldPlan.gd`:
  - Add an optional param to `clamp_field`:
    ```gdscript
    static func clamp_field(targets: Dictionary, max_step: int = 1) -> Dictionary:
    ```
    and change the cap line `var cap: int = out[nb] + 1` → `var cap: int = out[nb] + max_step`.
  - Add a member + constructor param (5th, default 1 so existing 4-arg callers are unchanged):
    ```gdscript
    var max_step: int = 1
    # in _init signature add:  p_max_step: int = 1
    # in _init body add:       max_step = p_max_step
    ```
  - In `storey_at`, change `clamp_field(targets)` → `clamp_field(targets, max_step)`.
  - In `compute_region`, change `clamp_field(targets)` → `clamp_field(targets, max_step)`.

- [ ] **Step 4: Run** the new test (PASS) AND the existing heightfield suite to confirm default behaviour is unchanged:
`… -gtest=res://tests/test_heightfield_clamp_step.gd -gexit` then `… -gdir=res://tests -gprefix=test_heightfield -gexit`. Expect all green.

- [ ] **Step 5: Commit** (`scripts/terrain/heightfield/HeightfieldPlan.gd`, `tests/test_heightfield_clamp_step.gd`):
`feat(terrain): parameterize heightfield clamp by max storey step (SP2 T1)`

---

## Task 2: `SlopeAtlas.cliff_uv()` — rock texel

**Files:** Modify `scripts/terrain/tools/SlopeAtlas.gd`; Test `tests/test_slope_atlas.gd` (new).

- [ ] **Step 1: Failing test** `tests/test_slope_atlas.gd`:

```gdscript
extends GutTest
const Atlas := preload("res://scripts/terrain/tools/SlopeAtlas.gd")

func test_cliff_uv_differs_from_grass():
	var grass := Atlas.grass_uv()
	var cliff := Atlas.cliff_uv()
	assert_true(cliff is Vector2)
	assert_false(grass.is_equal_approx(cliff), "rock swatch is a different texel than grass")
```

- [ ] **Step 2: Run; expect FAIL** (`cliff_uv` undefined).

- [ ] **Step 3: Implement** in `SlopeAtlas.gd` — mirror `grass_uv()` but read the cliff piece and average **side-facing** vertices (|normal.y| small):

```gdscript
const CLIFF_PIECE := "res://terrain/gltf/hill/hill_cliff_tall_h_side_color_12.tscn"

static func cliff_uv() -> Vector2:
	var packed := load(CLIFF_PIECE) as PackedScene
	var inst := packed.instantiate()
	var mi := _first_mesh_instance(inst)
	assert(mi != null, "no MeshInstance3D in cliff piece")
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var sum := Vector2.ZERO
	var n := 0
	for i in verts.size():
		if normals.size() == verts.size() and uvs.size() == verts.size() and absf(normals[i].y) < 0.3:
			sum += uvs[i]
			n += 1
	var result := (sum / n) if n > 0 else (uvs[0] if uvs.size() > 0 else Vector2.ZERO)
	inst.free()
	return result
```

- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** (`scripts/terrain/tools/SlopeAtlas.gd`, `tests/test_slope_atlas.gd`):
`feat(terrain): sample rock cliff UV from the KayKit atlas (SP2 T2)`

---

## Task 3: `TerrainSurfaceField` — flat cliff tops (gate ramp by storey step)

**Files:** Modify `scripts/terrain/field/TerrainSurfaceField.gd`; Test `tests/test_terrain_surface_field.gd` (extend).

- [ ] **Step 1: Add failing test.** A ≥2-storey-lower neighbour must NOT pull the cell's edge down (flat cliff top), while a 1-storey neighbour still ramps:

```gdscript
func _region_cliff():
	# cell (0,0) at storey 3 (12m); +x neighbour at storey 0 (a 3-storey cliff). max_step=3.
	var plan := Plan.new(0, 32.0, 8, "mean", 3)
	plan.set_raw_height_override(func(cx, cz):
		return 12.0 if cx <= 0 else 0.0)
	return plan.compute_region(0, 0, 8)

func test_cliff_top_is_flat_to_edge():
	var r := _region_cliff()
	# Across the whole cell toward the +x cliff edge the top stays at 12.0 (no ramp).
	assert_almost_eq(Field.surface_y(r, 0.0, 0.0), 12.0, 0.01)
	assert_almost_eq(Field.surface_y(r, 11.9, 0.0), 12.0, 0.01, "flat right up to the cliff edge")

func test_one_storey_neighbour_still_ramps():
	# Reuse the existing 1-storey region: it must still slope (SP1 behaviour preserved).
	var r := _region()    # cell (0,0)=4.0, neighbours 0.0  (from earlier tests)
	assert_lt(Field.surface_y(r, 11.9, 0.0), 4.0, "1-storey drop still ramps")
```

- [ ] **Step 2: Run; expect FAIL** (`test_cliff_top_is_flat_to_edge`: currently it ramps a 12 m slope). Also update the `Plan.new(...)` calls in the new test to the 5-arg form; existing `_region()` stays 4-arg (default max_step=1).

- [ ] **Step 3: Implement.** In `surface_y`, gate each per-direction drop by the storey step. Read storeys from the region and only ramp when the storey difference is ≤1:

```gdscript
# after computing cx, cz, h, lx, lz, dx_sign, dz_sign, a, b:
	var s := region.storey_at(cx, cz)
	# A neighbour only contributes a (walkable) ramp when it's at most 1 storey lower;
	# a ≥2-storey-lower neighbour is a CLIFF — this cell stays flat to that edge and the
	# mesher drops a vertical wall there instead.
	var step_x := s - region.storey_at(cx + dx_sign, cz)
	var step_z := s - region.storey_at(cx, cz + dz_sign)
	var step_d := s - region.storey_at(cx + dx_sign, cz + dz_sign)
	var d_x: float = (h - region.surface_height(cx + dx_sign, cz)) if (step_x >= 0 and step_x <= 1) else 0.0
	var d_z: float = (h - region.surface_height(cx, cz + dz_sign)) if (step_z >= 0 and step_z <= 1) else 0.0
	var d_d: float = (h - region.surface_height(cx + dx_sign, cz + dz_sign)) if (step_d >= 0 and step_d <= 1) else 0.0
	d_x = maxf(0.0, d_x); d_z = maxf(0.0, d_z); d_d = maxf(0.0, d_d)
```
Keep the existing convex/concave blend below (it already uses `d_x`, `d_z`, `d_d`, `a`, `b`). Remove the previous `d_x/d_z/d_d` definitions that used only `surface_height` (replace with the gated versions above).

- [ ] **Step 4: Run** `tests/test_terrain_surface_field.gd` — all green (new cliff tests + all SP1 tests).
- [ ] **Step 5: Commit** (`scripts/terrain/field/TerrainSurfaceField.gd`, `tests/test_terrain_surface_field.gd`):
`feat(terrain): surface field keeps cliff tops flat (≥2-storey edges) (SP2 T3)`

---

## Task 4: `TerrainChunkMesher` — emit cliff wall quads

**Files:** Modify `scripts/terrain/field/TerrainChunkMesher.gd`; Test `tests/test_terrain_chunk_mesher.gd` (extend).

- [ ] **Step 1: Add failing test.** Build a chunk over a region with a ≥2-storey cliff and assert wall geometry exists spanning the gap. Use a plan with an override + max_step 3, and a mesher seeded so no water interferes:

```gdscript
func test_chunk_emits_cliff_wall():
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 3 else 0.0)  # cliff between cell 3 and 4
	var m := Mesher.new()
	var node := m.build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var aabb := mi.mesh.get_aabb()
	# The surface mesh must span the full 12m vertical cliff (top 12 down to 0).
	assert_almost_eq(aabb.position.y, 0.0, 0.5, "mesh reaches the cliff base")
	assert_almost_eq(aabb.position.y + aabb.size.y, 12.0, 0.5, "mesh reaches the cliff top")
	# And there must be near-vertical faces (a wall), i.e. some triangles with |normal.y|<0.3.
	var normals: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var vertical := 0
	for nrm in normals:
		if absf(nrm.y) < 0.3: vertical += 1
	assert_gt(vertical, 0, "cliff wall produced near-vertical faces")
	node.free()
```

- [ ] **Step 2: Run; expect FAIL** (no vertical faces yet — the surface is all slopes/flats).

- [ ] **Step 3: Implement.** Add a per-cell wall pass into the SAME `SurfaceTool` (`st`) before `st.index()`. Add a `_cliff_uv` member and a wall emitter:

```gdscript
var _cliff_uv: Vector2 = SlopeAtlas.cliff_uv()

# inside build_chunk, AFTER the grass-surface sample loop and BEFORE st.index():
	var lo_cx := chunk.x * CELLS_PER_CHUNK
	var lo_cz := chunk.y * CELLS_PER_CHUNK
	for cz in range(lo_cz, lo_cz + CELLS_PER_CHUNK):
		for cx in range(lo_cx, lo_cx + CELLS_PER_CHUNK):
			var s := region.storey_at(cx, cz)
			var h_hi := region.surface_height(cx, cz)
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if s - region.storey_at(cx + dir.x, cz + dir.y) >= 2:
					_emit_wall(st, cx, cz, dir, h_hi, region.surface_height(cx + dir.x, cz + dir.y))

# new helper — a vertical quad along the shared edge, rock UV, normal toward `dir`:
func _emit_wall(st: SurfaceTool, cx: int, cz: int, dir: Vector2i, y_hi: float, y_lo: float) -> void:
	var ccx := float(cx) * TILE
	var ccz := float(cz) * TILE
	# Edge endpoints (the boundary line perpendicular to dir), at the cell's +dir edge.
	var ex := ccx + float(dir.x) * (TILE * 0.5)
	var ez := ccz + float(dir.y) * (TILE * 0.5)
	# Perp axis along the edge:
	var perp := Vector2(float(dir.y), float(dir.x)) * (TILE * 0.5)   # half-edge offset
	var p0 := Vector2(ex - perp.x, ez - perp.y)
	var p1 := Vector2(ex + perp.x, ez + perp.y)
	var t0 := Vector3(p0.x, y_hi, p0.y)
	var t1 := Vector3(p1.x, y_hi, p1.y)
	var b0 := Vector3(p0.x, y_lo, p0.y)
	var b1 := Vector3(p1.x, y_lo, p1.y)
	# Wind both triangles so the face points outward (+dir). Try (t0,t1,b1)+(t0,b1,b0);
	# if the visual pass shows the wall inside-out, swap to the reverse winding.
	for v in [t0, t1, b1, t0, b1, b0]:
		st.set_uv(_cliff_uv); st.add_vertex(v)
```

Note: walls go into `st` BEFORE `st.index()`/`generate_normals()` so they get welded + normalled with the surface (one mesh, one material, one trimesh collision).

- [ ] **Step 4: Run** `tests/test_terrain_chunk_mesher.gd` — all green (new wall test + prior tests). Confirm the prior `test_adjacent_chunks_share_boundary_height` etc. still pass.

- [ ] **Step 5: Commit** (`scripts/terrain/field/TerrainChunkMesher.gd`, `tests/test_terrain_chunk_mesher.gd`):
`feat(terrain): emit rock cliff-face walls where storeys step ≥2 (SP2 T4)`

---

## Task 5: Wire max_step=3; visual verification + noise tuning

**Files:** `scripts/terrain/field/FieldTerrainStreamer.gd`; tuning in `HeightfieldPlan.gd` / `Helper.gd` as needed.

- [ ] **Step 1:** In `FieldTerrainStreamer._ready`, create the plan with the cliff step:
  `_plan = HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)` and add `@export var MAX_CLIFF_STEP: int = 3`.

- [ ] **Step 2: Run the game** (godot MCP `run_project` or `… scenes/world.tscn`). Walk/teleport across the world. Capture frames at: a cliff face, a plateau edge, a valley, a slope-up-to-cliff transition.

- [ ] **Step 3: Verify** against the spec's "moderate" target and the owner's decisions:
  - Cliffs are vertical grey rock faces (≤12 m), reading as blocky cliffs, not slopes.
  - Cliff tops are flat plateaus; ≤1-storey drops are still smooth walkable slopes.
  - The player can't walk through a cliff; collision works; player doesn't fall through.
  - No gaps/lips/missing geometry at cliff↔surface seams.
  - Wall faces are not inside-out (if they are, swap the `_emit_wall` winding).
  Tune `HEIGHTFIELD_AMPLITUDE` / noise (octaves/ridges in `HeightfieldPlan.raw_height`) for a readable moderate mix of plateaus, slopes, valleys, occasional cliffs. Keep unit tests green after each tweak.

- [ ] **Step 4: Benchmark** FPS; if the extra wall geometry stutters, note it (walls are sparse, so unlikely).

- [ ] **Step 5: Commit** the wiring + tuning:
`feat(terrain): enable 3-storey cliffs in the world; tune moderate terrain (SP2 T5)`

---

## Self-review

- Spec coverage: clamp relaxation (T1), cliff UV (T2), flat cliff tops (T3), wall emission (T4), wiring + moderate tuning + visual (T5). ✔
- Gap-free preserved: walls read the same `surface_height` as the flat edges they connect (asserted in T4's AABB span). ✔
- Type consistency: `clamp_field(targets, max_step)`, `Plan.new(seed, amp, max_storeys, agg, max_step)`, `SlopeAtlas.cliff_uv()`, `region.storey_at`, `_emit_wall(st, cx, cz, dir, y_hi, y_lo)`. ✔
- Iteration points (flagged): the `_emit_wall` winding (T4/T5) and the noise feel (T5) are the visual-tuning knobs.
