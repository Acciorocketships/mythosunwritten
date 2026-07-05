# Terrain Generation Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Worktree:** Execute this plan in a separate worktree (superpowers:using-git-worktrees), branched from `feat/water-rivers-lakes` (commit or stash the WIP there first). All commands below assume the worktree root is the CWD.

**Goal:** Eliminate the ~30 s startup stall and per-chunk frame hitches in terrain streaming, and cut steady-state overhead, without changing any generated terrain (bit-identical output for a given seed).

**Architecture:** Three phases. Phase 1 removes redundant computation inside the pure pipeline (lazy water-carve gating, a per-cell sample memo on `HeightfieldPlan`, a baked per-cell sampler for the mesher's hot grid loop, and direct collision-face construction). Phase 2 moves whole-chunk builds onto a single background thread owned by `FieldTerrainStreamer` — the pipeline is already scene-free `RefCounted`, so `build_chunk` runs off-thread as-is and the main thread only does `add_child`. Phase 3 batches decorations into MultiMeshes (like `CliffDressing` already does).

**Tech Stack:** Godot 4.5, typed GDScript, GUT 9.5 (`godot-test`), headless profiling harness.

**Prime directive: terrain output must not change.** Every optimization is a pure refactor guarded by equivalence tests plus the existing suite. If a harness number improves but a test fails, the task is not done.

---

## Baseline (measured 2026-07-05, seed 3046246887, M-series Mac, headless)

49-chunk startup sweep (what `FieldTerrainStreamer` does at `CHUNK_RADIUS = 3`):

| Metric | Value |
|---|---|
| Total main-thread build time, 49 chunks | **30.2 s** |
| Per chunk (avg / worst) | 615 ms / 716 ms |
| `compute_region` per chunk (warm water caches) | ~210 ms |
| Grid height sampling (36,864 `surface_y_in_cell` calls) | ~195 ms |
| Mesh emission + clip + walls + aprons | ~180 ms |
| Decorations (~50 scene instantiations) | ~35 ms |
| Trimesh cooking (3 shapes) | ~20 ms |
| `CliffDressing` | ~15 ms |
| `raw_height` ×4489, noise only | 62 ms |
| `raw_height` ×4489, water attached (warm) | 132 ms |
| First `carve_at_cell` in a new water super-cell (river tracing) | **~800 ms spike** |
| `clamp_field` 67×67 | 7.5 ms |

Root causes: (1) `WaterPlan.carve_at_cell` runs a full `noise_h` for every cell even where no water exists, and `compute_region` re-samples its whole 67×67 window per chunk (77 % of which overlaps the neighbour chunk's window) up to three times per cell; (2) the mesher pays dictionary lookups + cliff-classification per *vertex* for values constant per *cell*; (3) everything runs synchronously in `_process`.

Rough per-task expectations (measure, don't trust): Task 2 → ~550 ms/chunk; Task 3 → ~400 ms; Task 4 → ~250 ms; Task 5 → ~200 ms; Phase 2 → main thread ≤ ~15 ms/frame regardless of build cost; Phase 3 → ~5 ms less per build and far fewer draw calls / nodes at runtime.

**Non-goals (explicitly out of scope — do not do these):** adaptive tessellation of flat cells, changing `SAMPLES_PER_CELL`, porting anything to C#/GDExtension, optimizing river-trace internals (Phase 2 moves the spike off the main thread, which is enough), multi-threaded build *pools* (one worker thread only — it keeps the plan/water caches lock-free).

## Measurement protocol (applies to every task)

After each task's implementation step:

1. Run the full suite: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json` — expect **0 failures**.
2. Run the profiler: `godot --headless --path . -s res://tests/harness/profile_terrain.gd` — paste the summary lines (TOTAL + worst chunk) into the commit message body.

`godot` is `/Applications/Godot.app/Contents/MacOS/Godot` (shell alias may not exist in the worktree shell).

---

## File map

| File | Change |
|---|---|
| `tests/harness/profile_terrain.gd` | **Create** — end-to-end profiler harness (Task 1) |
| `scripts/terrain/water/WaterPlan.gd` | Modify `_region_for` + `carve_at_cell` (Task 2) |
| `tests/test_water_plan.gd` | Add equivalence test (Task 2) |
| `scripts/terrain/heightfield/HeightfieldPlan.gd` | Add `_sample` memo; rewrite `compute_region`; drop `target_cache` param (Task 3) |
| `tests/test_heightfield_plan.gd` | Add memo-consistency tests (Task 3) |
| `tests/harness/hf_profile.gd` | Update for removed `target_cache` param (Task 3) |
| `scripts/terrain/field/TerrainSurfaceField.gd` | Add `bake_cell` / `sample_baked` (Task 4) |
| `tests/test_terrain_surface_field.gd` | Add baked-sampler equivalence test (Task 4) |
| `scripts/terrain/field/TerrainChunkMesher.gd` | Grid loop uses baked samplers (Task 4); collision sheet via `ConcavePolygonShape3D.set_faces` (Task 5); decorations → MultiMesh (Task 8) |
| `tests/test_terrain_chunk_mesher.gd` | Add collision-faces + MultiMesh-deco tests (Tasks 5, 8) |
| `scripts/terrain/field/FieldTerrainStreamer.gd` | **Rewrite** — background builder thread (Task 6) |
| `tests/test_field_streamer.gd` | Add threaded integration test (Task 6) |
| `AGENTS.md` | Update streamer/pipeline description + quick commands (Task 9) |

---

## Phase 1 — eliminate redundant work

### Task 1: Commit the profiling harness + record the baseline

**Files:**
- Create: `tests/harness/profile_terrain.gd`

- [ ] **Step 1: Create the harness**

```gdscript
# tests/harness/profile_terrain.gd
# End-to-end terrain-generation profiler: replays the streamer's startup
# (49 chunks at radius 3) and prints per-phase timings. Run:
#   godot --headless --path . -s res://tests/harness/profile_terrain.gd
# Numbers are the acceptance metric for the 2026-07-05 performance plan —
# paste the summary into each perf commit message.
extends SceneTree

const SEED := 3046246887   # pinned in world.tscn; known water beyond the spawn ring
const AMP := 22.0
const MAX_STOREYS := 8
const MAX_STEP := 3

var _acc := 0.0   # defeat dead-code elimination / accidental laziness

func _ms(us: int) -> String:
	return "%.1f ms" % (float(us) / 1000.0)

func _init() -> void:
	print("=== terrain profile, seed %d ===" % SEED)
	var cells: int = TerrainChunkMesher.CELLS_PER_CHUNK
	var grid: int = TerrainChunkMesher.GRID
	var step: float = TerrainChunkMesher.STEP

	var plan := HeightfieldPlan.new(SEED, AMP, MAX_STOREYS, "mean", MAX_STEP)
	var water := WaterPlan.new(SEED, AMP, MAX_STOREYS)
	plan.set_water_plan(water)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(SEED)
	var wb := WaterSurfaceBuilder.new()

	# --- micro: noise cost, dry vs water-attached ---
	var plan_dry := HeightfieldPlan.new(SEED, AMP, MAX_STOREYS, "mean", MAX_STEP)
	var t0 := Time.get_ticks_usec()
	for i in 4489:
		_acc += plan_dry.raw_height(i % 67 + 20, i / 67 + 20)
	print("raw_height x4489 (no water):        %s" % _ms(Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	for i in 4489:
		_acc += plan.raw_height(i % 67 + 20, i / 67 + 20)
	print("raw_height x4489 (water, cold):     %s" % _ms(Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	for i in 4489:
		_acc += plan.raw_height(i % 67 + 20, i / 67 + 20)
	print("raw_height x4489 (water, warm):     %s" % _ms(Time.get_ticks_usec() - t0))

	# --- micro: compute_region cold/warm ---
	t0 = Time.get_ticks_usec()
	var region = plan.compute_region(100, 100, cells)
	print("compute_region (cold area):         %s" % _ms(Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	region = plan.compute_region(100 + cells, 100, cells)   # neighbour chunk: overlapping window
	print("compute_region (overlapping):       %s" % _ms(Time.get_ticks_usec() - t0))

	# --- startup sweep: 49 chunks in streamer order ---
	print("\n=== startup: 49 chunks (radius 3) ===")
	var total := 0
	var worst := 0
	var worst_c := Vector2i.ZERO
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var c := Vector2i(dx, dz)
			t0 = Time.get_ticks_usec()
			var node := mesher.build_chunk(plan, c)
			var wnode := wb.build_chunk(water, c)
			var dt := Time.get_ticks_usec() - t0
			total += dt
			if dt > worst:
				worst = dt
				worst_c = c
			node.free()
			if wnode != null:
				wnode.free()
	print("TOTAL 49 chunks: %s   avg: %s   worst: %s at %s"
		% [_ms(total), _ms(total / 49), _ms(worst), str(worst_c)])

	# --- phase attribution on the worst chunk (all caches warm) ---
	print("\n=== phase attribution, chunk %s ===" % str(worst_c))
	var ccx := worst_c.x * cells + cells / 2
	var ccz := worst_c.y * cells + cells / 2
	t0 = Time.get_ticks_usec()
	var reg2 = plan.compute_region(ccx, ccz, cells)
	print("  compute_region:        %s" % _ms(Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	var o := Vector2(float(worst_c.x) * 192.0, float(worst_c.y) * 192.0)
	for iz in grid:
		for ix in grid:
			var x0 := o.x + float(ix) * step
			var z0 := o.y + float(iz) * step
			var qcx := TerrainSurfaceField._cell_of(x0 + step * 0.5)
			var qcz := TerrainSurfaceField._cell_of(z0 + step * 0.5)
			_acc += TerrainSurfaceField.surface_y_in_cell(reg2, x0, z0, qcx, qcz)
			_acc += TerrainSurfaceField.surface_y_in_cell(reg2, x0 + step, z0, qcx, qcz)
			_acc += TerrainSurfaceField.surface_y_in_cell(reg2, x0 + step, z0 + step, qcx, qcz)
			_acc += TerrainSurfaceField.surface_y_in_cell(reg2, x0, z0 + step, qcx, qcz)
	print("  grid sampling (4x%dx%d): %s" % [grid, grid, _ms(Time.get_ticks_usec() - t0)])
	t0 = Time.get_ticks_usec()
	var dd := CliffDressing.compute(reg2, worst_c.x * cells, worst_c.y * cells, cells)
	print("  CliffDressing.compute:  %s (pieces: %d)" % [_ms(Time.get_ticks_usec() - t0), dd["wall"].size() + dd["lip"].size()])
	t0 = Time.get_ticks_usec()
	var node2 := mesher.build_chunk(plan, worst_c)
	print("  build_chunk TOTAL:      %s" % _ms(Time.get_ticks_usec() - t0))
	node2.free()
	print("(acc %f)" % _acc)
	quit()
```

- [ ] **Step 2: Run it and capture the baseline**

Run: `godot --headless --path . -s res://tests/harness/profile_terrain.gd`
Expected: output resembling the Baseline table above (TOTAL ≈ 25–35 s). Save the full output — it goes in this commit's message body.

- [ ] **Step 3: Commit**

```bash
git add tests/harness/profile_terrain.gd
git commit -m "test(terrain): add end-to-end generation profiler harness

Baseline (seed 3046246887):
<paste harness output summary here>"
```

---

### Task 2: `WaterPlan.carve_at_cell` — lazy ground eval + pond pre-check

`carve_at_cell` runs for every cell of every region window. Today it unconditionally evaluates `noise_h(p)` (a full 6-noise landform sample — the single most expensive line in the water path) and calls `carve_at` on every pond of the super-cell region, even when the cell is nowhere near water. The fix: index the region's ponds once, gate everything behind cheap squared-distance / bucket checks, and only evaluate `noise_h` when something actually carves. Ponds beyond `bound_radius()` contribute exactly 0 (`footprint_t ≥ 1` ⇒ `carve_at` returns 0), so gating is lossless.

**Files:**
- Modify: `scripts/terrain/water/WaterPlan.gd:288-348` (`_region_for`, `carve_at_cell`)
- Test: `tests/test_water_plan.gd`

- [ ] **Step 1: Write the failing equivalence test**

Append to `tests/test_water_plan.gd`:

```gdscript
# The lazy-gated carve must equal the exhaustive reference for every cell —
# gated-out terms all contribute exactly 0. Sweeps a band far enough out to
# cross rivers/ponds for this seed; the wet-count guard keeps the sweep honest.
func test_carve_lazy_gates_match_reference():
	var w := WaterPlan.new(991177, 22.0, 8)
	var checked := 0
	var wet := 0
	for cz in range(-90, 91, 3):
		for cx in range(-90, 91, 3):
			var expect := _carve_reference(w, cx, cz)
			var got: float = w.carve_at_cell(cx, cz)
			assert_almost_eq(got, expect, 0.0001, "cell (%d,%d)" % [cx, cz])
			checked += 1
			if expect > 0.05:
				wet += 1
	assert_gt(wet, 5, "sweep found only %d/%d carved cells - widen it or change seed" % [wet, checked])

# Pre-optimization carve logic, kept verbatim as the reference oracle.
func _carve_reference(w: WaterPlan, cx: int, cz: int) -> float:
	var p := Vector2(float(cx) * WaterPlan.TILE, float(cz) * WaterPlan.TILE)
	if p.length() < WaterPlan.SPAWN_WATER_RADIUS:
		return 0.0
	var rc := Vector2i(int(floor(p.x / WaterPlan.SUPER)), int(floor(p.y / WaterPlan.SUPER)))
	var region: Dictionary = w._region_for(rc)
	var ground: float = w.noise_h(p)
	var best := 0.0
	for t in region.rivers:
		if t.source_pool != null:
			best = maxf(best, t.source_pool.carve_at(p, ground))
		if t.pond != null:
			best = maxf(best, t.pond.carve_at(p, ground))
	var key := Vector2i(cx, cz)
	if region.buckets.has(key):
		for entry in region.buckets[key]:
			var t: RiverTrace = entry[0]
			var i: int = entry[1]
			var d: float = p.distance_to(t.points[i])
			var infl: float = t.widths[i] + WaterPlan.FEATHER
			if d >= infl:
				continue
			var wgt: float = SlopeProfile.smootherstep(clampf((infl - d) / WaterPlan.FEATHER, 0.0, 1.0))
			best = maxf(best, maxf(0.0, ground - t.beds[i]) * wgt)
	return best
```

- [ ] **Step 2: Run it — must PASS against current code (it's an oracle test)**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_water_plan.gd`
Expected: PASS (the reference *is* the current logic). If the `wet > 5` guard fails, widen the sweep range (e.g. `range(-150, 151, 3)`) until it passes — the test is worthless on an all-dry sweep. This test now pins behavior for the refactor.

- [ ] **Step 3: Implement the lazy carve**

In `_region_for` (WaterPlan.gd:288), add a flat pond list. After the `rivers.append(t)` loop finishes, change the return-value construction:

```gdscript
	# Flat pond index (source pools + terminal ponds) so carve_at_cell can
	# distance-gate without re-walking every river per cell.
	var ponds: Array = []
	for t in rivers:
		if t.source_pool != null:
			ponds.append(t.source_pool)
		if t.pond != null:
			ponds.append(t.pond)
	var out: Dictionary = {"rivers": rivers, "buckets": buckets, "ponds": ponds}
	_region_cache[rc] = out
	return out
```

Replace `carve_at_cell` (WaterPlan.gd:323-348) with:

```gdscript
## Metres to subtract from the raw noise height at tile cell (cx, cz).
## Max over every pond bowl and channel sample that reaches the cell — pure
## function of (world_seed, cell); the caches never change the value.
## HOT PATH: called for every cell of every region window. Most cells have no
## water in reach, so the expensive part — noise_h, a full landform sample —
## is evaluated lazily, only once a pond footprint or channel bucket actually
## covers the cell. Ponds beyond bound_radius contribute exactly 0
## (footprint_t >= 1), so the distance gate never changes the result.
func carve_at_cell(cx: int, cz: int) -> float:
	var p: Vector2 = Vector2(float(cx) * TILE, float(cz) * TILE)
	if p.length() < SPAWN_WATER_RADIUS:
		return 0.0
	var rc: Vector2i = Vector2i(int(floor(p.x / SUPER)), int(floor(p.y / SUPER)))
	var region: Dictionary = _region_for(rc)
	var ground: float = -INF   # evaluated on first real hit
	var best: float = 0.0
	for pond: PondStamp in region.ponds:
		var bound: float = pond.bound_radius()
		if p.distance_squared_to(pond.center) > bound * bound:
			continue
		if ground == -INF:
			ground = noise_h(p)
		best = maxf(best, pond.carve_at(p, ground))
	var key: Vector2i = Vector2i(cx, cz)
	if region.buckets.has(key):
		for entry in region.buckets[key]:
			var t: RiverTrace = entry[0]
			var i: int = entry[1]
			var d: float = p.distance_to(t.points[i])
			var infl: float = t.widths[i] + FEATHER
			if d >= infl:
				continue
			if ground == -INF:
				ground = noise_h(p)
			# Full carve to the bed inside the width; smootherstep feather out.
			var w: float = SlopeProfile.smootherstep(clampf((infl - d) / FEATHER, 0.0, 1.0))
			best = maxf(best, maxf(0.0, ground - t.beds[i]) * w)
	return best
```

- [ ] **Step 4: Run the water tests, then the full suite**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_water_plan.gd`
Expected: PASS (equivalence test proves output unchanged).
Then the full suite per the measurement protocol. Expected: 0 failures.

- [ ] **Step 5: Profile**

Run the harness. Expected: `raw_height x4489 (water, warm)` drops from ~130 ms toward the dry ~62 ms; per-chunk average drops to roughly 500–560 ms.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/water/WaterPlan.gd tests/test_water_plan.gd
git commit -m "perf(water): lazy ground eval + pond distance gate in carve_at_cell

Output proven identical by oracle test. Harness:
<paste summary>"
```

---

### Task 3: `HeightfieldPlan` per-cell sample memo (persistent across chunks)

`compute_region` samples `raw_height` for 4,489 cells per chunk, then re-samples 1,225 of them in the level loop, then calls `carve_at_cell` for the same 1,225 again for the carved map — and throws all of it away, even though the next chunk's window overlaps 77 %. The existing `target_cache` parameter was built for this but no caller passes it. Root-cause fix: memoize `(raw_height, carved)` per cell *inside the plan instance*, funnel every reader through it, and delete the parameter.

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd:71-80` (`raw_height`), `:381-423` (`compute_region`), `:59-67` (setters)
- Modify: `tests/harness/hf_profile.gd:46-52` (drop `target_cache` usage)
- Test: `tests/test_heightfield_plan.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_heightfield_plan.gd`:

```gdscript
# The sample memo persists across compute_region calls; a warm plan must give
# byte-identical regions to a cold one (memo is performance-only).
func test_sample_memo_consistent_across_overlapping_regions():
	var warm := HeightfieldPlan.new(4242, 40.0, 8, "mean", 3)
	warm.compute_region(0, 0, 4)                      # fills the memo
	var r2: HeightfieldRegion = warm.compute_region(3, 2, 4)   # overlapping window, warm memo
	var cold := HeightfieldPlan.new(4242, 40.0, 8, "mean", 3)
	var f2: HeightfieldRegion = cold.compute_region(3, 2, 4)
	for dz in range(-5, 6):
		for dx in range(-5, 6):
			assert_eq(r2.storey_at(3 + dx, 2 + dz), f2.storey_at(3 + dx, 2 + dz),
				"storey (%d,%d)" % [3 + dx, 2 + dz])
			assert_eq(r2.level_at(3 + dx, 2 + dz), f2.level_at(3 + dx, 2 + dz),
				"level (%d,%d)" % [3 + dx, 2 + dz])

# Setting a raw override (or water plan) after sampling must not leak stale
# memo entries.
func test_raw_override_invalidates_sample_memo():
	var p := HeightfieldPlan.new(7, 40.0, 8, "mean")
	var _warmup := p.raw_height(5, 5)
	p.set_raw_height_override(func(_cx, _cz): return 12.0)
	assert_almost_eq(p.raw_height(5, 5), 12.0, 0.0001, "stale memo entry leaked past the override")
```

- [ ] **Step 2: Run to verify the second test fails**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_plan.gd`
Expected: `test_raw_override_invalidates_sample_memo` FAILS once the memo exists — but since the memo doesn't exist yet, both tests currently PASS (raw_height is computed fresh each call). That's fine: these tests pin the *contract* the memo must keep. Confirm they pass now; they must still pass after Step 3.

- [ ] **Step 3: Implement the memo**

In `HeightfieldPlan.gd`, add below the `_water_plan` declaration (line 35):

```gdscript
# Per-cell sample memo: Vector2i(cx,cz) -> [height_after_carve: float, carved: bool].
# Purely a performance cache — raw_height is a pure function of (seed, cell) —
# persisted across compute_region calls so the ~77%-overlapping windows of
# neighbouring chunks are sampled once. Capped so an endless walk can't grow
# it forever (a full clear is always safe: pure function).
const _SAMPLE_CACHE_MAX := 200_000
var _samples: Dictionary = {}


func _sample(cx: int, cz: int) -> Array:
	var key := Vector2i(cx, cz)
	var s = _samples.get(key)
	if s == null:
		var h: float
		if _raw_override.is_valid():
			h = _raw_override.call(cx, cz)
		else:
			h = _height01(Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)) * height_amplitude
		var carve: float = 0.0
		if _water_plan != null:
			carve = _water_plan.carve_at_cell(cx, cz)
		s = [h - carve, carve > 0.05]
		if _samples.size() >= _SAMPLE_CACHE_MAX:
			_samples.clear()
		_samples[key] = s
	return s
```

Replace `raw_height` (lines 71-80) with:

```gdscript
## Continuous height (metres) at a tile cell, after the water carve. Memoized.
func raw_height(cx: int, cz: int) -> float:
	return _sample(cx, cz)[0]
```

Add memo invalidation to both setters (lines 59-67):

```gdscript
## Replace the noise source with a synthetic field for tests. fn(cx, cz) -> float.
func set_raw_height_override(fn: Callable) -> void:
	_raw_override = fn
	_samples.clear()


## Attach the water network: raw_height subtracts its carve BEFORE storey
## quantization, so banks/cliffs/slopes around water come from the existing
## clamp + surface-field machinery with no downstream changes.
func set_water_plan(p_water_plan) -> void:
	_water_plan = p_water_plan
	_samples.clear()
```

Replace `compute_region` (lines 381-423) entirely — the `target_cache` parameter goes away, the separate carved loop folds into the level loop, and every sample comes from the memo:

```gdscript
## Batched region computation (storey clamp + level clamp once). All noise /
## water sampling goes through the per-cell _sample memo, so the overlapping
## windows of successive chunk builds are sampled once per cell per session.
## Cliff distances use one BFS field. Returns values equal to the per-cell
## reference.
func compute_region(center_cx: int, center_cz: int, radius: int) -> HeightfieldRegion:
	var place_r: int = radius + 1
	var level_r: int = place_r + LEVELS_PER_STOREY
	var storey_final_r: int = level_r + _CLIFF_SEARCH_MAX
	var storey_outer: int = storey_final_r + max_storeys

	var targets: Dictionary = {}
	for dz in range(-storey_outer, storey_outer + 1):
		for dx in range(-storey_outer, storey_outer + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			targets[cell] = quantize_storey(_sample(cell.x, cell.y)[0])
	var storeys: Dictionary = clamp_field(targets, max_step)

	var cliff_field: Dictionary = _cliff_distance_field(storeys, _CLIFF_SEARCH_MAX)
	var l0: Dictionary = {}
	# Water-carved cells are marked so the surface field can wall dry banks
	# against them (crisp dressed shorelines instead of bare ramps).
	var carved: Dictionary = {}
	for dz in range(-level_r, level_r + 1):
		for dx in range(-level_r, level_r + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			var s: int = int(storeys[cell])
			var smp: Array = _sample(cell.x, cell.y)
			var residual: float = smp[0] - float(s) * STOREY_HEIGHT
			var detail: int = clampi(_round_mode(residual / LEVEL_HEIGHT), 0, LEVELS_PER_STOREY - 1)
			var cliff_cap: int = int(cliff_field.get(cell, _NO_CLIFF)) - 1
			if _has_diagonal_cliff(storeys, cell):
				cliff_cap = 0
			l0[cell] = clampi(mini(detail, cliff_cap), 0, LEVELS_PER_STOREY - 1)
			if smp[1]:
				carved[cell] = true

	var levels: Dictionary = _clamp_levels(l0, storeys)
	return HeightfieldRegion.new(storeys, levels, carved)
```

- [ ] **Step 4: Update `tests/harness/hf_profile.gd`**

Replace lines 46-52 (the `cache` block) with:

```gdscript
	var w0: int = Time.get_ticks_usec()
	plan.compute_region(100, 100, 8)   # cold: fills the plan's sample memo
	var w1: int = Time.get_ticks_usec()
	plan.compute_region(101, 100, 8)   # warm: shifted one tile, ~98% memo hits
	var w2: int = Time.get_ticks_usec()
	print("[prof] compute_region cold: %.1f ms ; warm (shifted 1 tile): %.1f ms" % [float(w1 - w0) / 1000.0, float(w2 - w1) / 1000.0])
```

- [ ] **Step 5: Run the full suite**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json`
Expected: 0 failures. `test_heightfield_plan`, `test_heightfield_region`, `test_heightfield_clamp_step`, `test_terrain_surface_field`, `test_water_plan` are the key guards — they compare `compute_region` against the per-cell reference paths.

- [ ] **Step 6: Profile**

Run the harness. Expected: `compute_region (overlapping)` well under half of the cold number; per-chunk average roughly 350–450 ms.

- [ ] **Step 7: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd tests/harness/hf_profile.gd
git commit -m "perf(terrain): per-cell sample memo on HeightfieldPlan, shared across chunk windows

Folds the carved-map pass into the level loop; drops the never-used
target_cache parameter. Region output unchanged (existing reference tests).
Harness:
<paste summary>"
```

---

### Task 4: Baked per-cell sampler for the mesher's grid loop

The grid loop makes 36,864 `surface_y_in_cell` calls per chunk; each re-derives the cell's classification (`_is_cliff_top` = 8 neighbour dictionary lookups) and neighbour heights — all constant per cell. Bake them once per cell into a flat `PackedFloat32Array`; per-sample work becomes pure float math. On flat cells (most of the map) it collapses to returning a constant.

**Files:**
- Modify: `scripts/terrain/field/TerrainSurfaceField.gd` (add two static funcs at the end)
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd:94-111` (grid loop)
- Test: `tests/test_terrain_surface_field.gd`

- [ ] **Step 1: Write the failing equivalence test**

Append to `tests/test_terrain_surface_field.gd`:

```gdscript
# sample_baked(bake_cell(...)) must equal surface_y_in_cell(...) for every
# point, including pinned points past the cell edge (the mesher evaluates
# quad corners as-if belonging to the quad's own cell).
func test_baked_sampler_matches_surface_y_in_cell():
	var plan := HeightfieldPlan.new(4242, 40.0, 8, "mean", 3)
	var region: HeightfieldRegion = plan.compute_region(0, 0, 8)
	seed(12345)
	for cell_x in range(-6, 7):
		for cell_z in range(-6, 7):
			var baked := TerrainSurfaceField.bake_cell(region, cell_x, cell_z)
			for k in 8:
				var x := float(cell_x) * 24.0 + randf_range(-14.0, 14.0)
				var z := float(cell_z) * 24.0 + randf_range(-14.0, 14.0)
				assert_almost_eq(
					TerrainSurfaceField.sample_baked(baked, cell_x, cell_z, x, z),
					TerrainSurfaceField.surface_y_in_cell(region, x, z, cell_x, cell_z),
					0.0001,
					"cell (%d,%d) at (%.2f,%.2f)" % [cell_x, cell_z, x, z])
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_terrain_surface_field.gd`
Expected: FAIL — `bake_cell` not found.

- [ ] **Step 3: Implement `bake_cell` / `sample_baked`**

Append to `scripts/terrain/field/TerrainSurfaceField.gd`:

```gdscript
# --- baked per-cell sampler --------------------------------------------------
# The mesher evaluates ~37k surface points per chunk; surface_y_in_cell
# re-derives the cell's classification and neighbour heights from the region
# dictionaries on EVERY call. bake_cell does that derivation once per cell;
# sample_baked is then pure float math (and a single constant on flat cells).
# sample_baked(bake_cell(r, cx, cz), cx, cz, x, z) == surface_y_in_cell(r, x, z, cx, cz)
# for every point — guarded by test_baked_sampler_matches_surface_y_in_cell.
#
# Layout (PackedFloat32Array, 14 floats):
#   [0]      1.0 = cliff top (surface is the constant [1])
#   [1]      h, the cell surface height
#   [2..3]   drop toward the x neighbour, sign - / +   (>= 0)
#   [4..5]   drop toward the z neighbour, sign - / +
#   [6..9]   drop toward the diagonal, (x,z) sign order --, -+, +-, ++
#   [10..13] 1.0 = diagonal dip enabled (both arms level, no inner corner), same order

static func bake_cell(region, cx: int, cz: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(14)
	var h: float = region.surface_height(cx, cz)
	out[1] = h
	if _is_cliff_top(region, cx, cz):
		out[0] = 1.0
		return out
	var s_here := int(region.storey_at(cx, cz))
	for i in 2:
		var sgn := -1 if i == 0 else 1
		out[2 + i] = maxf(0.0, h - region.surface_height(cx + sgn, cz))
		out[4 + i] = maxf(0.0, h - region.surface_height(cx, cz + sgn))
	for ix in 2:
		for iz in 2:
			var k := ix * 2 + iz
			var dxs := -1 if ix == 0 else 1
			var dzs := -1 if iz == 0 else 1
			out[6 + k] = maxf(0.0, h - region.surface_height(cx + dxs, cz + dzs))
			var arm_x_level := int(region.storey_at(cx + dxs, cz)) == s_here
			var arm_z_level := int(region.storey_at(cx, cz + dzs)) == s_here
			if arm_x_level and arm_z_level and not _is_inner_corner(region, cx, cz, Vector2i(dxs, dzs)):
				out[10 + k] = 1.0
	return out


# The ramp math of surface_y_in_cell, reading baked per-cell data. Keep the
# two functions in lockstep — the equivalence test enforces it.
static func sample_baked(baked: PackedFloat32Array, cx: int, cz: int, x: float, z: float) -> float:
	if baked[0] > 0.5:
		return baked[1]
	var h := baked[1]
	var lx := x - float(cx) * TILE
	var lz := z - float(cz) * TILE
	var ix := 1 if lx >= 0.0 else 0
	var iz := 1 if lz >= 0.0 else 0
	var a := _edge_weight(absf(lx))
	var b := _edge_weight(absf(lz))
	var d_x := baked[2 + ix]
	var d_z := baked[4 + iz]
	var drop := 0.0
	if d_x > 0.0 or d_z > 0.0:
		var wx := a if d_x > 0.0 else 0.0
		var wz := b if d_z > 0.0 else 0.0
		drop = maxf(d_x, d_z) * (wx + wz - wx * wz)
	else:
		var k := ix * 2 + iz
		if baked[6 + k] > 0.0 and baked[10 + k] > 0.5:
			drop = baked[6 + k] * (a * b)
	return h - drop
```

- [ ] **Step 4: Run the equivalence test**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_terrain_surface_field.gd`
Expected: PASS. If any point disagrees, the failure message names the cell and offsets — diff `sample_baked` against `surface_y_in_cell` branch by branch; do not loosen the tolerance.

- [ ] **Step 5: Use it in the mesher's grid loop**

In `TerrainChunkMesher.build_chunk`, add a cache beside `clip_cache` (line 94) and replace the four `surface_y_in_cell` calls (lines 106-111):

```gdscript
	var clip_cache := {}           # per-cell lipped-slot masks for the visual clip
	var baked_cache := {}          # per-cell baked surface samplers
	for iz in GRID:
		for ix in GRID:
			var x0 := o.x + ix * STEP
			var x1 := x0 + STEP
			var z0 := o.y + iz * STEP
			var z1 := z0 + STEP
			# PIN the quad to its OWN cell: evaluate all four corners as if they belong to this
			# quad's cell, so a cliff top renders FLAT right up to its boundary (no slanted face).
			# Where two cells differ in height the shared boundary vertices land at different y and
			# don't weld — leaving a clean vertical gap that the rock skirt (below) fills. On flats
			# and slopes the pinned heights match the neighbour's, so vertices weld and stay smooth.
			var qcx := TerrainSurfaceField._cell_of((x0 + x1) * 0.5)
			var qcz := TerrainSurfaceField._cell_of((z0 + z1) * 0.5)
			var qkey := Vector2i(qcx, qcz)
			var baked: PackedFloat32Array = baked_cache.get(qkey, PackedFloat32Array())
			if baked.is_empty():
				baked = TerrainSurfaceField.bake_cell(region, qcx, qcz)
				baked_cache[qkey] = baked
			var y00 := TerrainSurfaceField.sample_baked(baked, qcx, qcz, x0, z0)
			var y10 := TerrainSurfaceField.sample_baked(baked, qcx, qcz, x1, z0)
			var y11 := TerrainSurfaceField.sample_baked(baked, qcx, qcz, x1, z1)
			var y01 := TerrainSurfaceField.sample_baked(baked, qcx, qcz, x0, z1)
```

(The rest of the loop body is unchanged.)

- [ ] **Step 6: Run the full suite**

Expected: 0 failures — `test_terrain_chunk_mesher`, `test_slope_tile_continuity`, `test_diag_seams`, `test_slope_socket_grounding` are the geometry guards.

- [ ] **Step 7: Profile**

Run the harness. Expected: `grid sampling` line drops from ~195 ms to ≤ 40 ms; per-chunk average roughly 230–300 ms.

- [ ] **Step 8: Commit**

```bash
git add scripts/terrain/field/TerrainSurfaceField.gd scripts/terrain/field/TerrainChunkMesher.gd tests/test_terrain_surface_field.gd
git commit -m "perf(terrain): bake per-cell surface samplers for the mesher grid loop

sample_baked proven pointwise-equal to surface_y_in_cell. Harness:
<paste summary>"
```

---

### Task 5: Collision sheet via `ConcavePolygonShape3D.set_faces`

The collision sheet currently pays a full second `SurfaceTool` emission (36,864 `set_uv` + `add_vertex` calls), a `commit()` to an `ArrayMesh`, and `create_trimesh_shape()` re-extracting the faces from that mesh. Collision needs none of that — just a `PackedVector3Array` of triangle vertices.

**Files:**
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd:92-93` (remove `stc`), `:119-120` (face writes), `:221-225` (shape creation)
- Test: `tests/test_terrain_chunk_mesher.gd`

- [ ] **Step 1: Write the test**

Append to `tests/test_terrain_chunk_mesher.gd`:

```gdscript
# The walkable collision sheet must cover the full chunk extent with exactly
# two triangles per grid quad, tracking the pinned surface heights.
func test_collision_sheet_faces_cover_full_grid():
	var p := HeightfieldPlan.new(4242, 40.0, 8, "mean")
	var m := TerrainChunkMesher.new()
	var node := m.build_chunk(p, Vector2i(0, 0))
	var cs: CollisionShape3D = node.get_node("Body/CollisionShape3D")
	var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
	assert_eq(faces.size(), TerrainChunkMesher.GRID * TerrainChunkMesher.GRID * 6,
		"2 triangles (6 vertices) per grid quad, full extent")
	# spot-check: the first quad's first vertex sits at the pinned surface height
	var region = p.compute_region(4, 4, 8)
	var qcx := TerrainSurfaceField._cell_of(TerrainChunkMesher.STEP * 0.5)
	var qcz := TerrainSurfaceField._cell_of(TerrainChunkMesher.STEP * 0.5)
	var expect := TerrainSurfaceField.surface_y_in_cell(region, 0.0, 0.0, qcx, qcz)
	assert_almost_eq(faces[0].y, expect, 0.001, "collision tracks the pinned surface")
	node.free()
```

- [ ] **Step 2: Run to verify it passes or fails for the right reason**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_terrain_chunk_mesher.gd`
Expected: the new test PASSES already (create_trimesh_shape preserves count and order) or fails only on face *ordering* — if it fails, note why before proceeding; after Step 3 it must pass cleanly.

- [ ] **Step 3: Implement**

In `build_chunk`, delete the `stc` SurfaceTool (lines 92-93) and replace with a pre-sized faces array:

```gdscript
	var st := SurfaceTool.new()    # VISUAL sheet: clipped back to TOP_CLIP under the lips
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# COLLISION sheet: full extent (the lip band stays walkable). Raw triangle
	# soup straight into a ConcavePolygonShape3D — no SurfaceTool, no ArrayMesh,
	# no create_trimesh_shape re-extraction.
	var col_faces := PackedVector3Array()
	col_faces.resize(GRID * GRID * 6)
	var col_i := 0
```

Replace the two `_tri(stc, ...)` calls (lines 119-120) with direct writes:

```gdscript
			col_faces[col_i] = v00
			col_faces[col_i + 1] = v10
			col_faces[col_i + 2] = v11
			col_faces[col_i + 3] = v00
			col_faces[col_i + 4] = v11
			col_faces[col_i + 5] = v01
			col_i += 6
```

Replace the shape creation (line 224 `cs.shape = stc.commit().create_trimesh_shape()`) with:

```gdscript
	var col_shape := ConcavePolygonShape3D.new()
	col_shape.set_faces(col_faces)
	cs.shape = col_shape
```

(Leave the apron and wall trimeshes as they are — they are small and reuse meshes that exist for visuals anyway.)

- [ ] **Step 4: Run the full suite**

Expected: 0 failures.

- [ ] **Step 5: Profile and commit**

Run the harness. Expected: per-chunk average roughly 180–260 ms.

```bash
git add scripts/terrain/field/TerrainChunkMesher.gd tests/test_terrain_chunk_mesher.gd
git commit -m "perf(terrain): build walkable collision as a raw faces array

Skips the second SurfaceTool emission + ArrayMesh + create_trimesh_shape.
Harness:
<paste summary>"
```

---

## Phase 2 — background chunk builder

### Task 6: Builder thread in `FieldTerrainStreamer`

The whole pipeline is scene-free `RefCounted` (the purity boundary), so `build_chunk` runs on a worker thread as-is, producing a detached `Node3D`; the main thread only `add_child`s finished chunks. **One** worker thread, on purpose: the plan/water caches are then touched by exactly one thread and need no locks. The main-thread synchronous fallback (player's own chunk) gets its *own* plan/water/mesher instances — same seed ⇒ identical output, zero shared mutable state.

**Files:**
- Rewrite: `scripts/terrain/field/FieldTerrainStreamer.gd`
- Test: `tests/test_field_streamer.gd`

- [ ] **Step 1: Write the failing integration test**

Append to `tests/test_field_streamer.gd`:

```gdscript
func test_background_builds_populate_radius():
	var s := Streamer.new()
	s.CHUNK_RADIUS = 1
	s.KEEP_RADIUS = 2
	s.MAX_BUILD_PER_FRAME = 4
	s.SEED_OVERRIDE = 4242
	var parent := Node3D.new()
	var player := Node3D.new()
	add_child_autofree(parent)
	add_child_autofree(player)
	s.terrain_parent = parent
	s.player = player
	add_child_autofree(s)
	# the spawn chunk is guaranteed synchronously in _ready
	assert_true(s._built.has(Vector2i(0, 0)), "spawn chunk built before first frame")
	# the rest of the 3x3 radius arrives from the background thread
	var deadline := Time.get_ticks_msec() + 60_000
	while s._built.size() < 9 and Time.get_ticks_msec() < deadline:
		await wait_seconds(0.25)
	assert_eq(s._built.size(), 9, "radius-1 ring built in the background")
	for c in s._built:
		assert_true(is_instance_valid(s._built[c]), "chunk node alive: %s" % str(c))
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_field_streamer.gd`
Expected: FAIL — with the current synchronous streamer the ring builds too (via `_process`), so it may PASS; if it passes, it still pins the contract. Either outcome, proceed.

- [ ] **Step 3: Rewrite the streamer**

Replace the entire contents of `scripts/terrain/field/FieldTerrainStreamer.gd` with:

```gdscript
# scripts/terrain/field/FieldTerrainStreamer.gd
# Slim per-chunk streaming driver: builds field chunks within a radius of the
# player on ONE background thread (the whole pipeline is scene-free RefCounted,
# so build_chunk runs off-thread as-is and returns a detached Node3D), then
# integrates finished chunks on the main thread, budgeted per frame. Evicts
# beyond a keep radius. The player's own chunk is still built synchronously
# when missing, so the player can never fall through unbuilt space.
class_name FieldTerrainStreamer
extends Node3D

const CHUNK_WORLD := 192.0   # TerrainChunkMesher.CHUNK_WORLD

@export var player: Node3D
@export var terrain_parent: Node
@export var CHUNK_RADIUS: int = 3
@export var KEEP_RADIUS: int = 4
## Finished background chunks INTEGRATED (added to the tree) per frame.
@export var MAX_BUILD_PER_FRAME: int = 1
@export var HEIGHTFIELD_AMPLITUDE: float = 22.0
@export var HEIGHTFIELD_MAX_STOREYS: int = 8
## Max storey difference between adjacent cells. 1 = all walkable slopes (SP1);
## 3 = cliffs up to 3 storeys (12m) form where the field steps down steeply.
@export var MAX_CLIFF_STEP: int = 3
## 0 = random each run. Set non-zero to pin the world for debugging (pairs
## with the F3 coord overlay screenshot workflow).
@export var SEED_OVERRIDE: int = 0

# Worker-thread pipeline instances. Their internal caches (plan sample memo,
# water trace/region caches) are touched ONLY by the worker thread — that
# confinement is the whole thread-safety story; no locks on the pipeline.
var _plan: HeightfieldPlan
var _water: WaterPlan
var _mesher: TerrainChunkMesher
var _water_builder := WaterSurfaceBuilder.new()
# Main-thread pipeline instances for the synchronous player-chunk guarantee.
# Separate objects with separate caches; same seed => identical output (the
# pipeline is a pure function of (seed, cell)).
var _plan_sync: HeightfieldPlan
var _water_sync: WaterPlan
var _mesher_sync: TerrainChunkMesher
var _water_builder_sync := WaterSurfaceBuilder.new()

var _built: Dictionary = {}        # Vector2i -> Node3D          (main thread only)
var _queued: Dictionary = {}       # Vector2i -> true, in-flight  (main thread only)
var world_seed: int = 0

var _thread := Thread.new()
var _sem := Semaphore.new()
var _mutex := Mutex.new()          # guards _jobs, _done, _exit
var _jobs: Array = []              # Vector2i, nearest-first at enqueue time
var _done: Array = []              # [Vector2i, Node3D] finished builds
var _exit := false

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
	world_seed = SEED_OVERRIDE if SEED_OVERRIDE != 0 else randi()
	_plan = HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)
	_water = WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS)
	_plan.set_water_plan(_water)
	_mesher = TerrainChunkMesher.new()
	_mesher.set_seed(world_seed)
	_plan_sync = HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)
	_water_sync = WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS)
	_plan_sync.set_water_plan(_water_sync)
	_mesher_sync = TerrainChunkMesher.new()
	_mesher_sync.set_seed(world_seed)
	# Warm every shared static resource on the main thread before the worker
	# starts (loading is thread-safe; warming here just keeps the first
	# background build fast and shader compiles on the main thread).
	CliffDressing._ensure_loaded()
	CliffDressing.shared_material()
	WaterSurfaceBuilder.sheet_material()
	_mesher._ensure_skirt_style()
	_mesher_sync._ensure_skirt_style()
	for tag in TerrainChunkMesher.FOLIAGE_SCENES:
		for path: String in TerrainChunkMesher.FOLIAGE_SCENES[tag]:
			load(path)
	# Build the chunk under the spawn point before the first physics frame, so
	# the player lands on real collision instead of falling through.
	if player != null:
		_build_now(chunk_of(player.global_position))
	_thread.start(_worker)

# Synchronous build on the MAIN thread (spawn + the rare case of the player
# outrunning the streamer). Uses the _sync pipeline instances exclusively.
func _build_now(c: Vector2i) -> void:
	if _built.has(c):
		return
	var node := _mesher_sync.build_chunk(_plan_sync, c)
	var wnode := _water_builder_sync.build_chunk(_water_sync, c)
	if wnode != null:
		node.add_child(wnode)
	terrain_parent.add_child(node)
	_built[c] = node

func _worker() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		if _exit:
			_mutex.unlock()
			return
		var c: Vector2i = _jobs.pop_front() if not _jobs.is_empty() else Vector2i.MAX
		_mutex.unlock()
		if c == Vector2i.MAX:
			continue
		var node := _mesher.build_chunk(_plan, c)
		var wnode := _water_builder.build_chunk(_water, c)
		if wnode != null:
			node.add_child(wnode)
		_mutex.lock()
		_done.append([c, node])
		_mutex.unlock()

func _process(_delta: float) -> void:
	if _plan == null or player == null:
		return
	var centre := chunk_of(player.global_position)
	# The player's own chunk never waits on the worker.
	_build_now(centre)
	# Integrate finished background builds (budgeted).
	var integrated := 0
	while integrated < MAX_BUILD_PER_FRAME:
		_mutex.lock()
		var pair: Array = _done.pop_front() if not _done.is_empty() else []
		_mutex.unlock()
		if pair.is_empty():
			break
		var c: Vector2i = pair[0]
		_queued.erase(c)
		if _built.has(c) or maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			pair[1].free()   # lost the race to _build_now, or stale — discard
			continue
		terrain_parent.add_child(pair[1])
		_built[c] = pair[1]
		integrated += 1
	# Queue missing chunks nearest-first, so terrain grows outward from the player.
	var want: Array = []
	for c: Vector2i in desired_chunks(centre, CHUNK_RADIUS):
		if not _built.has(c) and not _queued.has(c):
			want.append(c)
	if not want.is_empty():
		want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return maxi(absi(a.x - centre.x), absi(a.y - centre.y)) \
				< maxi(absi(b.x - centre.x), absi(b.y - centre.y)))
		_mutex.lock()
		for c: Vector2i in want:
			_queued[c] = true
			_jobs.append(c)
		_mutex.unlock()
		for i in want.size():
			_sem.post()
	# Evict chunks beyond keep radius (Chebyshev).
	for c: Vector2i in _built.keys():
		if maxi(absi(c.x - centre.x), absi(c.y - centre.y)) > KEEP_RADIUS:
			_built[c].queue_free()
			_built.erase(c)

func _exit_tree() -> void:
	if not _thread.is_started():
		return
	_mutex.lock()
	_exit = true
	_mutex.unlock()
	_sem.post()
	_thread.wait_to_finish()
	for pair in _done:
		pair[1].free()   # never entered the tree
	_done.clear()
```

- [ ] **Step 4: Run the streamer test, then the full suite**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_field_streamer.gd`
Expected: PASS, including the two pre-existing static tests.
Then the full suite. Expected: 0 failures, no thread-related errors/leaks reported at exit (Godot prints leaked-thread warnings — treat any as a failure).

- [ ] **Step 5: Manual smoke test (the actual acceptance test for this plan)**

Run: `godot --path .` — expected: the game opens at interactive framerate immediately; terrain fills outward within a few seconds with no multi-hundred-ms hitches; sprinting toward the horizon shows chunks appearing ahead without freezes. Walk far (>800 u from spawn) to cross a water super-cell boundary — no hitch (the trace happens on the worker). Check the console for threading errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/field/FieldTerrainStreamer.gd tests/test_field_streamer.gd
git commit -m "perf(terrain): build chunks on a background thread

One worker thread owns the pipeline instances (lock-free caches); main
thread integrates finished chunks budgeted per frame and keeps the
synchronous player-chunk guarantee on separate pipeline instances."
```

---

## Phase 3 — steady-state wins

### Task 7: Extract pure decoration placement from `build_chunk`

Preparation for MultiMesh batching, mirroring the `CliffDressing.compute()`/`build()` split (MultiMesh doesn't read back transforms in headless, so tests need the data form).

**Files:**
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd:190-212` (deco section)
- Test: `tests/test_terrain_chunk_mesher.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_terrain_chunk_mesher.gd`:

```gdscript
# compute_decorations returns the pure placement data (scene path ->
# Array[Transform3D]); deterministic and water-gated like the old inline loop.
func test_compute_decorations_deterministic_and_grounded():
	var p := HeightfieldPlan.new(4242, 40.0, 8, "mean")
	var m := TerrainChunkMesher.new()
	var region = p.compute_region(4, 4, 8)
	var a: Dictionary = m.compute_decorations(region, Vector2i(0, 0))
	var b: Dictionary = m.compute_decorations(region, Vector2i(0, 0))
	assert_eq(a.keys(), b.keys(), "deterministic scene set")
	var n := 0
	for path in a:
		assert_eq(a[path].size(), b[path].size(), "deterministic counts for %s" % path)
		for i in a[path].size():
			var tf: Transform3D = a[path][i]
			assert_almost_eq(tf.origin.y,
				TerrainSurfaceField.surface_y(region, tf.origin.x, tf.origin.z), 0.001,
				"decoration sits on the surface")
			n += 1
	assert_gt(n, 0, "chunk (0,0) at this seed scatters at least one decoration")
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot -d --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gselect=test_terrain_chunk_mesher.gd`
Expected: FAIL — `compute_decorations` not found.

- [ ] **Step 3: Implement the extraction**

In `TerrainChunkMesher.gd`, add above `build_chunk`:

```gdscript
# Pure decoration placement for a chunk: scene path -> Array[Transform3D]
# (position + yaw; the per-piece gltf local transform is applied at build).
# Split from build_chunk so tests can assert placements headlessly, where
# MultiMesh does not read back instance transforms (same pattern as
# CliffDressing.compute/build).
func compute_decorations(region, chunk: Vector2i) -> Dictionary:
	var by_scene: Dictionary = {}
	for cz in range(chunk.y * CELLS_PER_CHUNK, chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
		for cx in range(chunk.x * CELLS_PER_CHUNK, chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK):
			var wc := Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
			if Helper.is_water(wc, _water_seed):
				continue
			var sy := TerrainSurfaceField.surface_y(region, wc.x, wc.z)
			for d: Dictionary in DecorationScatter.cell_decorations(Vector2i(cx, cz), _water_seed, sy):
				var variants: Array = FOLIAGE_SCENES.get(d["tag"], [])
				if variants.is_empty():
					continue
				var pick: int = int(d["yaw"] / TAU * variants.size()) % variants.size()
				var path: String = variants[pick]
				# Sit each decoration on the surface at ITS OWN jittered position, not the
				# cell centre — otherwise decorations on a slope float above / sink below
				# the ground (the cell-centre height differs from the local height).
				var dp: Vector3 = d["pos"]
				var tf := Transform3D(Basis(Vector3.UP, d["yaw"]),
					Vector3(dp.x, TerrainSurfaceField.surface_y(region, dp.x, dp.z), dp.z))
				if not by_scene.has(path):
					by_scene[path] = []
				by_scene[path].append(tf)
	return by_scene
```

Replace the deco section of `build_chunk` (lines 190-212, from `var deco := Node3D.new()` through `root.add_child(deco)`) with — for now still scene instances, consuming the extracted data (MultiMesh lands in Task 8):

```gdscript
	# Decorations: scatter foliage on non-water land cells
	var deco := Node3D.new()
	deco.name = "Decorations"
	var by_scene := compute_decorations(region, chunk)
	for path in by_scene:
		for tf: Transform3D in by_scene[path]:
			var inst: Node3D = (load(path) as PackedScene).instantiate()
			inst.transform = tf
			deco.add_child(inst)
	root.add_child(deco)
```

- [ ] **Step 4: Run the full suite**

Expected: 0 failures (`Decorations` container still exists; placements identical — `Transform3D(Basis(UP, yaw), pos)` equals the old `position` + `rotation.y` assignment).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/field/TerrainChunkMesher.gd tests/test_terrain_chunk_mesher.gd
git commit -m "refactor(terrain): extract pure compute_decorations from build_chunk"
```

---

### Task 8: Batch decorations into MultiMeshes

**Files:**
- Modify: `scripts/terrain/field/TerrainChunkMesher.gd` (deco build section from Task 7 + new static piece cache)
- Test: `tests/test_terrain_chunk_mesher.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_terrain_chunk_mesher.gd`:

```gdscript
# Decorations batch into one MultiMesh per (scene, mesh piece) — instance
# counts must add up to placements x pieces-per-scene.
func test_decorations_batch_into_multimeshes():
	var p := HeightfieldPlan.new(4242, 40.0, 8, "mean")
	var m := TerrainChunkMesher.new()
	var region = p.compute_region(4, 4, 8)
	var by_scene: Dictionary = m.compute_decorations(region, Vector2i(0, 0))
	var node := m.build_chunk(p, Vector2i(0, 0))
	var deco := node.find_child("Decorations", true, false)
	var total := 0
	for child in deco.get_children():
		assert_true(child is MultiMeshInstance3D, "decoration child is a MultiMesh batch")
		total += (child as MultiMeshInstance3D).multimesh.instance_count
	var expected := 0
	for path in by_scene:
		expected += by_scene[path].size() * TerrainChunkMesher._foliage_pieces(path).size()
	assert_eq(total, expected, "every placement instanced once per mesh piece")
	assert_gt(total, 0, "chunk has decorations")
	node.free()
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `_foliage_pieces` not found / children are scene roots.

- [ ] **Step 3: Implement**

Add to `TerrainChunkMesher.gd` (below the `FOLIAGE_SCENES` const):

```gdscript
# scene path -> Array of [mesh: Mesh, local_xform: Transform3D], one entry per
# MeshInstance3D inside the foliage scene (KayKit gltf wrappers are visual-only:
# no collision, no scripts — verified before batching them; if a future foliage
# scene needs behaviour, it must not go through the MultiMesh path).
static var _foliage_piece_cache: Dictionary = {}

static func _foliage_pieces(path: String) -> Array:
	var got = _foliage_piece_cache.get(path)
	if got != null:
		return got
	var inst := (load(path) as PackedScene).instantiate()
	var out: Array = []
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var walk: Node = mi
		while walk != null and walk != inst:
			xf = (walk as Node3D).transform * xf
			walk = walk.get_parent()
		out.append([mi.mesh, xf])
	inst.free()
	_foliage_piece_cache[path] = out
	return out
```

Replace the Task 7 deco build section with:

```gdscript
	# Decorations: foliage batched into one MultiMesh per (scene, mesh piece) —
	# same pattern as CliffDressing. ~50 scene instantiations per chunk became
	# a handful of MultiMeshes: fewer nodes, fewer draw calls, cheap eviction.
	var deco := Node3D.new()
	deco.name = "Decorations"
	var by_scene := compute_decorations(region, chunk)
	for path in by_scene:
		var tfs: Array = by_scene[path]
		for piece in _foliage_pieces(path):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = piece[0]
			mm.instance_count = tfs.size()
			for i in tfs.size():
				mm.set_instance_transform(i, tfs[i] * piece[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d" % [String(path).get_file().get_basename(), deco.get_child_count()]
			mmi.multimesh = mm
			deco.add_child(mmi)
	root.add_child(deco)
```

- [ ] **Step 4: Run the full suite**

Expected: 0 failures. The `find_child("Decorations", ...)` container test still passes.

- [ ] **Step 5: Visual check**

Run: `godot --path .` — foliage must look identical to before (same positions, yaws, variants; gltf materials come with the mesh, so colors are unchanged). Then open `tests/harness/teleport_deco_harness.tscn` and eyeball decoration grounding.

- [ ] **Step 6: Profile and commit**

```bash
git add scripts/terrain/field/TerrainChunkMesher.gd tests/test_terrain_chunk_mesher.gd
git commit -m "perf(terrain): batch chunk decorations into MultiMeshes

Harness:
<paste summary>"
```

---

### Task 9: Final measurement + documentation

**Files:**
- Modify: `AGENTS.md` (streamer section, quick commands)

- [ ] **Step 1: Full verification**

Run the full suite (0 failures) and the harness. Record the final numbers next to the baseline:

| Metric | Baseline | Final |
|---|---|---|
| 49-chunk total | 30.2 s | *(measure)* |
| Per-chunk avg | 615 ms | *(measure — expect ≤ ~200 ms, all off-main-thread)* |

- [ ] **Step 2: Manual play test**

Run: `godot --path .` — startup smooth, no hitches while sprinting across super-cell boundaries, F3 overlay still works, water/swimming unaffected (cross a river; swim).

- [ ] **Step 3: Update AGENTS.md**

In the `field/FieldTerrainStreamer.gd` bullet, replace the description of budgeted building with the new architecture (background worker thread building whole chunks off-tree; main thread integrates `MAX_BUILD_PER_FRAME` results per frame; synchronous player-chunk guarantee on separate pipeline instances; nearest-first queue). In "Quick commands", add:

```markdown
- **Profile terrain generation**: `godot --headless --path . -s res://tests/harness/profile_terrain.gd`
  (per-phase timings; paste the summary into perf-related commit messages).
```

Also note in the pipeline section that `HeightfieldPlan` memoizes per-cell samples (performance-only; cleared by `set_raw_height_override`/`set_water_plan`) and that decorations are MultiMesh-batched.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md
git commit -m "docs: record threaded streamer architecture + profiling workflow

Before/after (seed 3046246887): 49-chunk startup 30.2s main-thread -> <final>
background; main thread per frame <final>."
```

---

## Risks & contingencies

- **Threading (Task 6) is the only risky task.** Everything the worker touches is scene-free by the purity boundary; the two things that would break it are (a) someone later making the main thread read `_plan`/`_water` (use `_plan_sync`/`_water_sync` instead — the code comments say so) and (b) resources shared with the render thread. If rare Vulkan validation errors appear when meshes are created off-thread, the fallback is to move only `SurfaceTool.commit()` results across as `ArrayMesh` data (they already are) — commit happens on the worker either way; node *creation* can be moved main-side without giving up the win, since it is ~ms.
- **If a Phase 1 equivalence test won't pass exactly**, do not loosen tolerances — the refactors are algebraically identical, so a mismatch means a real transcription bug.
- **Eviction hitches** (many nodes freed at once) shrink drastically after Task 8; if still visible, cap evictions at 2 chunks/frame in `_process` — one-line change, no design impact.
