# Water Boundary-Mesh Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the patch-and-carve water sheet with a continuous surface
field `w(x,z)` (falls only where the bed drops > 4 m) meshed exactly at the
water/terrain boundary, per `docs/superpowers/specs/2026-07-09-water-boundary-mesh-design.md`.

**Architecture:** Three new units — `WaterField` (pure sampler: level / wet /
flow / fall cuts, built on the existing `WaterPlan` traces), `WaterMesher`
(marching squares on the 3 m sub-grid, welded index buffer, buried hem,
fall-cut splitting), `FallMesher` (ogee sweep from lip contours) — then a
thin `WaterSurfaceBuilder.build_chunk` that wires them to the existing
streamer, followed by a shader pass and a deletion sweep of the superseded
machinery.

**Tech Stack:** Godot 4.5.1 GDScript, GUT (headless), godot-MCP for in-game
verification.

## Global Constraints

- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`. Project root: `/Users/ryko/story`.
- GDScript uses **TABS** for indentation. Typed GDScript where practical.
- GUT run template: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After creating any new `class_name` script, refresh the global class cache
  before running tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`
- Pinned test seed: `2697992464`. Known water site: chunks `(0,-6)`/`(1,-6)`,
  owner frame `(33.9, 8.0, -1097.4)`. World constants: `TILE = 24.0`,
  `CELLS_PER_CHUNK = 8`, `SUBDIV = 8` (sub-grid step 3.0 m), `STOREY = 4.0`.
- Spec constants: `FALL_DROP_MIN := 4.0`, `HEM_DROP := 1.2`, `HEM_W := 1.5`,
  `SURFACE_RIDE := 2.2`, `CLAIM_FEATHER := 8.0`, `EPS := 0.05`,
  `CUT_JUMP := 2.0` (level jump between adjacent samples that marks a cut).
- **Never stage `project.godot` or `mcp_interaction_server.gd`** (godot-MCP
  injects them). Stage files by explicit path; no `git add -A`.
- Tests MUST cache one `HeightfieldPlan`/`WaterPlan` per seed and regions per
  chunk in `static var` dictionaries (fresh plans re-trace rivers cold; the
  suite goes from minutes to timeout). Copy the `_water(SEED)` / `_region(SEED, chunk)`
  helper pattern from `tests/test_water_float_invariants.gd` while it still exists.
- The swell CPU mirror: any change to swell constants in
  `terrain/water/water_common.gdshaderinc` must be mirrored in
  `characters/character.gd` `_swell_offset`. This plan does NOT change swell
  constants.
- Existing interfaces this plan consumes (verified against source):
  - `WaterPlan.bodies_near(center_cell: Vector2i, radius_cells: int) -> Dictionary`
    with keys `ponds: Array[PondStamp]`, `rivers: Array[RiverTrace]`;
    `WaterPlan.world_seed: int`; `WaterPlan.TILE/STOREY`.
  - `RiverTrace`: `points: PackedVector2Array` (world XZ, ~12 m apart),
    `beds: PackedFloat32Array` (monotone non-increasing), `widths: PackedFloat32Array`
    (half-widths), `source_pool: PondStamp`, `pond: PondStamp` (null when
    `joined`), `joined: bool`, `source_cell: Vector2i`.
  - `PondStamp`: `center: Vector2`, `footprint_t(p: Vector2) -> float`
    (0 centre → 1 boundary), `surface_y() -> float`, `radius: float`,
    `bound_radius() -> float`.
  - `TerrainSurfaceField.surface_y(region, x: float, z: float) -> float`
    (the rendered ground, ramps included — the ONLY ground oracle).
  - Region for a chunk: `plan.compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)`
    where `plan = HeightfieldPlan.new(SEED, 22.0, 8, "mean", 3)` +
    `plan.set_water_plan(water)`.
  - Materials: `WaterSurfaceBuilder.sheet_material()` /
    `WaterSurfaceBuilder.waterfall_material()` (keep these statics).
  - Swim volume layer: `1 << 7`; `VOLUME_TOP_PAD := 1.7`.
- In-game verification loop (no hot reload — stop/run between code edits):
  `mcp run_project` → `game_eval` (TABS in multiline code) →
  `ReviewCam.pose(pos)` → wait ~10 s → `ReviewCam.shoot(player, crosshair, png)`;
  vantage list in `tests/tools/review_vantages.json`.
- Commit style: `feat(water):` / `test(water):` / `refactor(water):` +
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer.

---

### Task 1: WaterField — profiles, level, wet

**Files:**
- Create: `scripts/terrain/water/WaterField.gd`
- Test: `tests/test_water_field.gd`

**Interfaces:**
- Consumes: `WaterPlan`, `RiverTrace`, `PondStamp`, `TerrainSurfaceField` (above).
- Produces (used by Tasks 2–9):
  - `WaterField.ctx(water: WaterPlan, chunk: Vector2i) -> Dictionary` — one
    per chunk build; opaque to callers.
  - `WaterField.level_at(ctx: Dictionary, p: Vector2) -> float` — surface
    height, `-INF` when no body claims `p`.
  - `WaterField.wet(ctx: Dictionary, region, p: Vector2) -> bool`.
  - `WaterField.profile(trace: RiverTrace) -> Dictionary` —
    `{levels: PackedFloat32Array, cuts: PackedInt32Array}` (cut between
    sample `i` and `i+1`).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_water_field.gd`:

```gdscript
extends GutTest

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)

static var _plans: Dictionary = {}
static var _waters: Dictionary = {}
static var _regions: Dictionary = {}


static func _water(seed_v: int) -> WaterPlan:
	if not _waters.has(seed_v):
		var plan := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		var water := WaterPlan.new(seed_v, 22.0, 8)
		plan.set_water_plan(water)
		_plans[seed_v] = plan
		_waters[seed_v] = water
	return _waters[seed_v]


static func _region(seed_v: int, chunk: Vector2i):
	var key := [seed_v, chunk]
	if not _regions.has(key):
		_water(seed_v)
		_regions[key] = _plans[seed_v].compute_region(
			chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _regions[key]


func test_profiles_monotone_and_continuous() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var checked := 0
	for tr: RiverTrace in ctx.rivers:
		var prof: Dictionary = WaterField.profile(tr)
		var levels: PackedFloat32Array = prof.levels
		assert_eq(levels.size(), tr.points.size(), "one level per sample")
		for i in range(1, levels.size()):
			assert_true(levels[i] <= levels[i - 1] + 0.001,
				"water never flows uphill (trace %s sample %d)" % [tr.source_cell, i])
			var drop: float = levels[i - 1] - levels[i]
			if not prof.cuts.has(i - 1):
				assert_true(drop < WaterField.FALL_DROP_MIN,
					"continuous stretch drops %0.2f >= FALL_DROP_MIN at sample %d" % [drop, i])
			checked += 1
	assert_true(checked > 0, "site chunk has river samples")


func test_cuts_only_at_big_drops() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	for tr: RiverTrace in ctx.rivers:
		var prof: Dictionary = WaterField.profile(tr)
		for ci in prof.cuts:
			var drop: float = prof.levels[ci] - prof.levels[ci + 1]
			assert_true(drop > WaterField.FALL_DROP_MIN - 0.001,
				"cut %d drops only %0.2f" % [ci, drop])


func test_level_at_known_water_and_dry_land() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	# The mid pool at the owner's site: cell (2,-46) centre, water level ~5.
	var wet_p := Vector2(60.0, -1092.0)
	assert_true(WaterField.level_at(ctx, wet_p) > -INF, "site pool is claimed")
	assert_true(WaterField.wet(ctx, region, wet_p), "site pool is wet")
	# The bank the owner stands on (33.9, -1097.4), ground 8: must be dry.
	var dry_p := Vector2(33.9, -1097.4)
	assert_false(WaterField.wet(ctx, region, dry_p), "owner's bank is dry")


func test_level_continuous_away_from_cuts() -> void:
	# Walk 1 m steps along the site channel: |level step| must stay < 1.0
	# except when a cut lies between the two probes.
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var prev: float = INF
	var big_steps := 0
	for zi in range(-1130, -1080):
		var lvl: float = WaterField.level_at(ctx, Vector2(54.0, float(zi)))
		if prev < INF and lvl > -INF and prev > -INF:
			if absf(lvl - prev) > 1.0:
				big_steps += 1
		prev = lvl
	# The site has 2 real falls on this line historically (9->5, 5->3 was a
	# weir and must now be CONTINUOUS, so at most the >4m cuts remain).
	assert_true(big_steps <= 2, "at most the true falls jump; got %d" % big_steps)
```

- [ ] **Step 2: Run tests, verify they fail on the missing class**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_field.gd -gexit`
Expected: parse failure / "WaterField not declared" style errors.

- [ ] **Step 3: Implement WaterField**

Create `scripts/terrain/water/WaterField.gd`:

```gdscript
# The continuous water surface: ONE height field w(x,z), discontinuous only
# at true waterfalls (bed drop > FALL_DROP_MIN between adjacent trace
# samples). Ponds are flat; river reaches slope monotonically between their
# anchors. This file is pure and deterministic — no rendering, no nodes.
class_name WaterField
extends Object

const TILE := 24.0
const FALL_DROP_MIN := 4.0    # the only fall threshold in the system
const SURFACE_RIDE := 2.2     # river surface height above the traced bed
const CLAIM_FEATHER := 8.0    # metres past the channel half-width a reach claims
const EPS := 0.05

static var _profiles: Dictionary = {}   # trace.source_cell -> profile dict


## Everything the samplers need for one chunk, fetched once (bodies_near is
## too expensive per point). Also builds a 24m spatial bucket over river
## samples so level_at is O(nearby samples), not O(all samples).
static func ctx(water: WaterPlan, chunk: Vector2i) -> Dictionary:
	var centre := Vector2i(chunk.x * 8 + 4, chunk.y * 8 + 4)
	var bodies: Dictionary = water.bodies_near(centre, 8)
	var buckets: Dictionary = {}
	for ti in bodies.rivers.size():
		var tr: RiverTrace = bodies.rivers[ti]
		for si in tr.points.size():
			var cell := Vector2i(int(floor(tr.points[si].x / TILE)),
				int(floor(tr.points[si].y / TILE)))
			if not buckets.has(cell):
				buckets[cell] = []
			buckets[cell].append(Vector2i(ti, si))
	return {"water": water, "ponds": bodies.ponds, "rivers": bodies.rivers,
		"buckets": buckets}


## Continuous, monotone level per trace sample + fall cut indices.
## levels[i] = min(levels[i-1], beds[i] + SURFACE_RIDE), anchored to the
## source pool at the top and the terminal pond at the bottom; a cut is
## recorded wherever one step drops more than FALL_DROP_MIN (upstream holds
## its level to the lip; the jump IS the waterfall).
static func profile(trace: RiverTrace) -> Dictionary:
	if _profiles.has(trace.source_cell):
		return _profiles[trace.source_cell]
	var n: int = trace.points.size()
	var levels := PackedFloat32Array()
	levels.resize(n)
	var cuts := PackedInt32Array()
	var lvl: float = trace.beds[0] + SURFACE_RIDE
	if trace.source_pool != null:
		lvl = minf(lvl, trace.source_pool.surface_y())
	levels[0] = lvl
	for i in range(1, n):
		var raw: float = trace.beds[i] + SURFACE_RIDE
		if lvl - raw > FALL_DROP_MIN:
			cuts.append(i - 1)
			lvl = raw
		else:
			lvl = minf(lvl, raw)
		levels[i] = lvl
	if trace.pond != null:
		# Meet the pond surface continuously (or with a fall if the drop is big).
		var ps: float = trace.pond.surface_y()
		if levels[n - 1] - ps > FALL_DROP_MIN:
			cuts.append(n - 1)
		else:
			# ease the last few samples down onto the pond level, monotone
			var i: int = n - 1
			while i >= 0 and levels[i] > ps:
				levels[i] = maxf(ps, levels[i] - 0.0)  # clamp: never below pond
				i -= 1
			levels[n - 1] = ps
	var out := {"levels": levels, "cuts": cuts}
	_profiles[trace.source_cell] = out
	return out


## Surface height at p, or -INF when no pond/reach claims the point.
## Claimant = smallest signed margin (distance past the body's edge).
static func level_at(c: Dictionary, p: Vector2) -> float:
	var best_m: float = CLAIM_FEATHER
	var best_lvl: float = -INF
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		if m < best_m:
			best_m = m
			best_lvl = pond.surface_y()
	var cell := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var b: Array = c.buckets.get(cell + Vector2i(dx, dz), [])
			for ref: Vector2i in b:
				var tr: RiverTrace = c.rivers[ref.x]
				var si: int = ref.y
				var d: float = p.distance_to(tr.points[si])
				var m: float = d - tr.widths[si]
				if m < best_m:
					best_m = m
					best_lvl = _sample_level(tr, si, p)
	return best_lvl


## Level near sample si, projected onto the adjacent segment; across a cut
## the side of the cut plane decides which level applies (the jump line).
static func _sample_level(tr: RiverTrace, si: int, p: Vector2) -> float:
	var prof: Dictionary = profile(tr)
	var j: int = mini(si + 1, tr.points.size() - 1)
	if j == si:
		return prof.levels[si]
	if prof.cuts.has(si):
		var mid: Vector2 = (tr.points[si] + tr.points[j]) * 0.5
		var dirv: Vector2 = (tr.points[j] - tr.points[si]).normalized()
		return prof.levels[j] if (p - mid).dot(dirv) > 0.0 else prof.levels[si]
	var seg: Vector2 = tr.points[j] - tr.points[si]
	var t: float = clampf((p - tr.points[si]).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return lerpf(prof.levels[si], prof.levels[j], t)


static func wet(c: Dictionary, region, p: Vector2) -> bool:
	var lvl: float = level_at(c, p)
	return lvl > -INF and lvl > TerrainSurfaceField.surface_y(region, p.x, p.y) + EPS
```

- [ ] **Step 4: Refresh the class cache, run the tests**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`
Then the GUT command from Step 2.
Expected: 4/4 PASS. If `test_level_continuous_away_from_cuts` fails with
more big steps, print the levels along the probe line and check whether the
extra jumps are junction mismatches — junction continuity is Task 2's ease
pass; up to 2 extra jumps may be tolerated here by raising the bound to 4
with a `# TODO Task 2 tightens this` comment ONLY if the failures are at
junction points (verify by printing), never at plain reach interiors.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterField.gd tests/test_water_field.gd
git commit -m "feat(water): WaterField — continuous monotone reach profiles, falls only past 4m"
```

---

### Task 2: WaterField — flow, grade, fall cut geometry

**Files:**
- Modify: `scripts/terrain/water/WaterField.gd`
- Test: `tests/test_water_field.gd` (append)

**Interfaces:**
- Produces:
  - `WaterField.flow_at(ctx, p: Vector2) -> Vector2` (downstream unit * strength 0..1, ZERO in ponds)
  - `WaterField.grade_at(ctx, p: Vector2) -> float` (surface slope m/m, 0 in ponds)
  - `WaterField.fall_cuts(ctx, rect: Rect2) -> Array[Dictionary]` — each
    `{p: Vector2, dir: Vector2, across: Vector2, half: float, top: float, bottom: float}`

- [ ] **Step 1: Append failing tests**

```gdscript
func test_fall_cuts_geometry() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var rect := Rect2(Vector2(0, -1152), Vector2(192, 192))
	var cuts: Array = WaterField.fall_cuts(ctx, rect)
	assert_true(cuts.size() >= 1, "the site keeps its big falls")
	for cut: Dictionary in cuts:
		assert_true(cut.top - cut.bottom > WaterField.FALL_DROP_MIN - 0.001,
			"every cut is a true fall (drop %.2f)" % (cut.top - cut.bottom))
		assert_almost_eq(cut.dir.length(), 1.0, 0.001, "dir is unit")
		assert_almost_eq(cut.dir.dot(cut.across), 0.0, 0.001, "across is perpendicular")


func test_flow_and_grade() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var p := Vector2(54.0, -1100.0)   # mid-channel at the site
	if WaterField.level_at(ctx, p) > -INF:
		assert_true(WaterField.flow_at(ctx, p).length() <= 1.001, "flow bounded")
		assert_true(WaterField.grade_at(ctx, p) >= 0.0, "grade non-negative")
```

- [ ] **Step 2: Run, expect FAIL** (missing functions), same GUT command.

- [ ] **Step 3: Implement**

Append to `WaterField.gd`:

```gdscript
## Nearest-claimant helper shared by flow/grade: returns
## [trace, sample_i, margin] or [] when a pond wins / nothing claims.
static func _claim(c: Dictionary, p: Vector2) -> Array:
	var best_m: float = CLAIM_FEATHER
	var best: Array = []
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		if m < best_m:
			best_m = m
			best = []          # pond claims: still water
	var cell := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for ref: Vector2i in c.buckets.get(cell + Vector2i(dx, dz), []):
				var tr: RiverTrace = c.rivers[ref.x]
				var m: float = p.distance_to(tr.points[ref.y]) - tr.widths[ref.y]
				if m < best_m:
					best_m = m
					best = [tr, ref.y]
	return best


static func flow_at(c: Dictionary, p: Vector2) -> Vector2:
	var cl: Array = _claim(c, p)
	if cl.is_empty():
		return Vector2.ZERO
	var tr: RiverTrace = cl[0]
	var si: int = cl[1]
	var j: int = mini(si + 1, tr.points.size() - 1)
	if j == si:
		return Vector2.ZERO
	# Fade to zero at the channel edge (shore water is calm).
	var edge: float = clampf(1.0 - p.distance_to(tr.points[si]) / maxf(tr.widths[si], 1.0), 0.0, 1.0)
	return (tr.points[j] - tr.points[si]).normalized() * edge


static func grade_at(c: Dictionary, p: Vector2) -> float:
	var cl: Array = _claim(c, p)
	if cl.is_empty():
		return 0.0
	var tr: RiverTrace = cl[0]
	var si: int = cl[1]
	var prof: Dictionary = profile(tr)
	var j: int = mini(si + 1, tr.points.size() - 1)
	if j == si or prof.cuts.has(si):
		return 0.0
	var run: float = tr.points[si].distance_to(tr.points[j])
	return (prof.levels[si] - prof.levels[j]) / maxf(run, 0.001)


## Fall cut segments whose midpoint lies inside rect (grown by one tile so
## chunk-border cuts appear for both neighbouring chunks).
static func fall_cuts(c: Dictionary, rect: Rect2) -> Array:
	var out: Array = []
	var grown: Rect2 = rect.grow(TILE)
	for tr: RiverTrace in c.rivers:
		var prof: Dictionary = profile(tr)
		for ci in prof.cuts:
			var j: int = mini(ci + 1, tr.points.size() - 1)
			var mid: Vector2 = (tr.points[ci] + tr.points[j]) * 0.5
			if not grown.has_point(mid):
				continue
			var dirv: Vector2 = (tr.points[j] - tr.points[ci]).normalized()
			out.append({"p": mid, "dir": dirv,
				"across": Vector2(-dirv.y, dirv.x),
				"half": tr.widths[ci] + CLAIM_FEATHER,
				"top": prof.levels[ci], "bottom": prof.levels[j]})
	return out
```

- [ ] **Step 4: Run all `test_water_field.gd` tests — expect 6/6 PASS.**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterField.gd tests/test_water_field.gd
git commit -m "feat(water): WaterField flow/grade and fall-cut geometry"
```

---

### Task 3: WaterMesher — welded interior grid

**Files:**
- Create: `scripts/terrain/water/WaterMesher.gd`
- Test: `tests/test_water_mesher.gd`

**Interfaces:**
- Consumes: `WaterField.ctx/level_at/wet/fall_cuts`, `TerrainSurfaceField.surface_y`.
- Produces (Tasks 4–9 build on these exact names):
  - `WaterMesher.build(water: WaterPlan, chunk: Vector2i, region) -> Dictionary`
    with keys `verts: PackedVector3Array`, `idx: PackedInt32Array`,
    `cust: PackedFloat32Array` (4 floats/vert), `cuts: Array[Dictionary]`
    (filled in Task 5), `wet_cells: Dictionary` (filled in Task 7). Empty
    dict when the chunk is dry.
  - `WaterMesher.free_edges(verts: PackedVector3Array, idx: PackedInt32Array) -> Array`
    — list of `[Vector3, Vector3]` pairs used by exactly one triangle.
  - Internal lattice constants: `N := 64` cells/chunk side, step `S := 3.0`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_water_mesher.gd` (reuse the same cached `_water/_region`
helper block from `tests/test_water_field.gd` verbatim at the top):

```gdscript
func test_interior_is_welded() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	assert_false(m.is_empty(), "site chunk builds water")
	assert_true(m.idx.size() % 3 == 0, "triangles")
	# Welded: no two verts share a position (the weld map dedupes them).
	var seen: Dictionary = {}
	for v in m.verts:
		var key: Vector3i = Vector3i((v * 8.0).round())
		assert_false(seen.has(key), "duplicate vert at %s" % v)
		seen[key] = true


func test_dry_chunk_builds_nothing() -> void:
	var water: WaterPlan = _water(SEED)
	# Reuse the dry-chunk scan from test_water_surface_builder: any chunk
	# whose bodies_near window is empty.
	var dry := Vector2i.MAX
	for cz in range(0, 40):
		for cx in range(0, 40):
			var b: Dictionary = water.bodies_near(Vector2i(cx * 8 + 4, cz * 8 + 4), 5)
			if b.ponds.is_empty() and b.rivers.is_empty():
				dry = Vector2i(cx, cz)
				break
		if dry != Vector2i.MAX:
			break
	assert_true(dry != Vector2i.MAX, "found a dry chunk")
	assert_true(WaterMesher.build(water, dry, _region(SEED, dry)).is_empty(),
		"dry chunk => empty build")
```

- [ ] **Step 2: Run, expect FAIL on missing class.**

- [ ] **Step 3: Implement the lattice + interior meshing**

Create `scripts/terrain/water/WaterMesher.gd`:

```gdscript
# Boundary-conforming water sheet: marching squares over the 3m sub-grid on
# f(x,z) = level(x,z) - ground(x,z). Interior cells emit welded grid quads;
# boundary cells emit contour polygons whose edge vertices sit ON the
# waterline (Task 4); fall cuts split cells into upstream/downstream parts
# (Task 5); every contour free edge grows a buried hem (Task 6).
class_name WaterMesher
extends Object

const TILE := 24.0
const N := 64                 # marching cells per chunk side
const S := 3.0                # sub-grid step (TILE * 8 cells / 64)
const EPS := 0.05
const CUT_JUMP := 2.0         # adjacent-sample level jump that marks a cut
const HEM_DROP := 1.2
const HEM_W := 1.5


## st: shared build state. One per build() call.
static func build(water: WaterPlan, chunk: Vector2i, region) -> Dictionary:
	var c: Dictionary = WaterField.ctx(water, chunk)
	if c.ponds.is_empty() and c.rivers.is_empty():
		return {}
	var base := Vector2(chunk.x, chunk.y) * (TILE * 8.0)
	var st: Dictionary = {
		"region": region, "ctx": c, "base": base,
		"lvl": PackedFloat32Array(), "gnd": PackedFloat32Array(),
		"verts": PackedVector3Array(), "idx": PackedInt32Array(),
		"cust": PackedFloat32Array(), "weld": {},
		"cuts": WaterField.fall_cuts(c, Rect2(base, Vector2.ONE * TILE * 8.0)),
		"cut_hits": {},   # cut index -> Array of lip/base vert records (Task 5)
	}
	st.lvl.resize((N + 1) * (N + 1))
	st.gnd.resize((N + 1) * (N + 1))
	var any_wet := false
	for j in N + 1:
		for i in N + 1:
			var p: Vector2 = base + Vector2(i, j) * S
			var lvl: float = WaterField.level_at(c, p)
			st.lvl[j * (N + 1) + i] = lvl
			st.gnd[j * (N + 1) + i] = TerrainSurfaceField.surface_y(region, p.x, p.y)
			if lvl > -INF and lvl > st.gnd[j * (N + 1) + i] + EPS:
				any_wet = true
	if not any_wet:
		return {}
	for j in N:
		for i in N:
			_mesh_cell(st, i, j)
	_hem(st)          # no-op until Task 6
	_attributes(st)   # no-op until Task 7
	return {"verts": st.verts, "idx": st.idx, "cust": st.cust,
		"cuts": st.get("cut_records", []), "wet_cells": st.get("wet_cells", {})}


static func _f(st: Dictionary, i: int, j: int) -> float:
	var lvl: float = st.lvl[j * (N + 1) + i]
	return -INF if lvl == -INF else lvl - st.gnd[j * (N + 1) + i]


static func _wet(st: Dictionary, i: int, j: int) -> bool:
	return _f(st, i, j) > EPS


static func _lattice_vert(st: Dictionary, i: int, j: int) -> int:
	var key := "L:%d:%d" % [i, j]
	if st.weld.has(key):
		return st.weld[key]
	var p: Vector2 = st.base + Vector2(i, j) * S
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, st.lvl[j * (N + 1) + i], p.y))
	st.weld[key] = vi
	return vi


## Task 3 handles only fully-wet, cut-free cells: one welded quad.
static func _mesh_cell(st: Dictionary, i: int, j: int) -> void:
	if not (_wet(st, i, j) and _wet(st, i + 1, j)
			and _wet(st, i + 1, j + 1) and _wet(st, i, j + 1)):
		return
	if _cell_cut(st, i, j) != -1:
		return   # Task 5
	var a: int = _lattice_vert(st, i, j)
	var b: int = _lattice_vert(st, i + 1, j)
	var cc: int = _lattice_vert(st, i + 1, j + 1)
	var d: int = _lattice_vert(st, i, j + 1)
	for t in [[a, d, cc], [a, cc, b]]:   # +Y winding matches the old sheet
		for k in 3:
			st.idx.append(t[k])


## Index of a fall cut affecting this cell, or -1. A cell is cut when any
## of its four edges jumps more than CUT_JUMP between wet samples.
static func _cell_cut(st: Dictionary, i: int, j: int) -> int:
	var l00: float = st.lvl[j * (N + 1) + i]
	var l10: float = st.lvl[j * (N + 1) + i + 1]
	var l11: float = st.lvl[(j + 1) * (N + 1) + i + 1]
	var l01: float = st.lvl[(j + 1) * (N + 1) + i]
	var lo: float = INF
	var hi: float = -INF
	for l in [l00, l10, l11, l01]:
		if l > -INF:
			lo = minf(lo, l)
			hi = maxf(hi, l)
	if hi - lo <= CUT_JUMP:
		return -1
	var centre: Vector2 = st.base + Vector2(float(i) + 0.5, float(j) + 0.5) * S
	var best := -1
	var best_d := INF
	for ci in st.cuts.size():
		var d: float = absf((centre - st.cuts[ci].p).dot(st.cuts[ci].dir))
		if d < best_d:
			best_d = d
			best = ci
	return best


static func _hem(_st: Dictionary) -> void:
	pass   # Task 6


static func _attributes(st: Dictionary) -> void:
	st["cust"] = PackedFloat32Array()
	st.cust.resize(st.verts.size() * 4)   # zeros until Task 7


## Edges used by exactly one triangle — the continuity oracle.
static func free_edges(verts: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var count: Dictionary = {}
	var tri: int = 0
	while tri < idx.size():
		for k in 3:
			var a: int = idx[tri + k]
			var b: int = idx[tri + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = count.get(key, 0) + 1
		tri += 3
	var out: Array = []
	for key: Vector2i in count:
		if count[key] == 1:
			out.append([verts[key.x], verts[key.y]])
	return out
```

- [ ] **Step 4: Refresh class cache, run tests — expect 2/2 PASS.**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterMesher.gd tests/test_water_mesher.gd
git commit -m "feat(water): WaterMesher welded interior grid + free-edge oracle"
```

---

### Task 4: WaterMesher — marching-squares boundary

**Files:**
- Modify: `scripts/terrain/water/WaterMesher.gd` (replace `_mesh_cell`)
- Test: `tests/test_water_mesher.gd` (append)

**Interfaces:**
- Produces: contour vertices ON the waterline; free edges classified by
  `WaterMesher.classify_edge(st-free) -> "contour"|"border"|"cut"` is NOT
  needed publicly — tests classify geometrically (see test code).

- [ ] **Step 1: Append failing tests**

```gdscript
func test_boundary_verts_sit_on_the_waterline() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	var checked := 0
	for e: Array in WaterMesher.free_edges(m.verts, m.idx):
		for v: Vector3 in e:
			if _on_chunk_border(v):
				continue
			var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			var lvl: float = WaterField.level_at(ctx, Vector2(v.x, v.z))
			# Contour verts: water meets ground within tolerance. Cut verts
			# (Task 5) sit far above ground and are excluded by the same
			# tolerance test against their own level.
			if absf(v.y - g) < 0.25:
				checked += 1
				assert_true(absf(lvl - g) < 0.35,
					"contour vert not on the waterline: %s (lvl %.2f g %.2f)" % [v, lvl, g])
	assert_true(checked > 20, "site has a real shoreline (%d verts)" % checked)


func _on_chunk_border(v: Vector3) -> bool:
	var span: float = 24.0 * 8.0
	var lx: float = fposmod(v.x, span)
	var lz: float = fposmod(v.z, span)
	return lx < 0.01 or lx > span - 0.01 or lz < 0.01 or lz > span - 0.01
```

- [ ] **Step 2: Run — the new test FAILS** (boundary cells currently skipped,
`checked > 20` unmet).

- [ ] **Step 3: Replace `_mesh_cell` with the perimeter-walk version**

```gdscript
## Perimeter-walk marching squares. Corners in CCW order; walking the cell
## boundary and inserting a waterline vertex at every wet/dry sign change
## yields the wet polygon directly (fan-triangulated). Saddle rule: the
## cell-centre sample decides connectivity (documented spec choice).
static func _mesh_cell(st: Dictionary, i: int, j: int) -> void:
	var corners: Array = [
		Vector2i(i, j), Vector2i(i + 1, j),
		Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
	var wet_flags: Array = []
	var wet_n := 0
	for cnr: Vector2i in corners:
		var w: bool = _wet(st, cnr.x, cnr.y)
		wet_flags.append(w)
		wet_n += 1 if w else 0
	if wet_n == 0:
		return
	if _cell_cut(st, i, j) != -1:
		_mesh_cut_cell(st, i, j, corners, wet_flags)   # Task 5
		return
	if wet_n == 4:
		var a: int = _lattice_vert(st, i, j)
		var b: int = _lattice_vert(st, i + 1, j)
		var cc: int = _lattice_vert(st, i + 1, j + 1)
		var d: int = _lattice_vert(st, i, j + 1)
		for t in [[a, d, cc], [a, cc, b]]:
			for k in 3:
				st.idx.append(t[k])
		return
	# Saddle: wet at opposite corners only -> centre sample picks joined/split.
	var saddle: bool = wet_n == 2 and wet_flags[0] == wet_flags[2]
	var centre_wet := false
	if saddle:
		var cp: Vector2 = st.base + Vector2(float(i) + 0.5, float(j) + 0.5) * S
		var clvl: float = WaterField.level_at(st.ctx, cp)
		centre_wet = clvl > -INF \
			and clvl > TerrainSurfaceField.surface_y(st.region, cp.x, cp.y) + EPS
	if saddle and not centre_wet:
		for k in 4:   # two separate corner triangles
			if wet_flags[k]:
				st.idx.append(_lattice_vert(st, corners[k].x, corners[k].y))
				st.idx.append(_edge_vert(st, corners[k], corners[(k + 3) % 4]))
				st.idx.append(_edge_vert(st, corners[k], corners[(k + 1) % 4]))
		return
	var poly: Array = []
	for k in 4:
		var a: Vector2i = corners[k]
		var b: Vector2i = corners[(k + 1) % 4]
		if wet_flags[k]:
			poly.append(_lattice_vert(st, a.x, a.y))
		if wet_flags[k] != wet_flags[(k + 1) % 4]:
			poly.append(_edge_vert(st, a, b))
	for k in range(1, poly.size() - 1):   # fan
		st.idx.append(poly[0])
		st.idx.append(poly[k])
		st.idx.append(poly[k + 1])


## Waterline vertex on the lattice edge a-b: linear interp on f, refined by
## two bisection steps against the REAL ground (linear undershoots on curved
## ramps). Welded by edge key so both cells sharing the edge reuse it.
static func _edge_vert(st: Dictionary, a: Vector2i, b: Vector2i) -> int:
	var key := "X:%d:%d:%d:%d" % [mini(a.x, b.x), mini(a.y, b.y),
		absi(b.x - a.x), absi(b.y - a.y)]
	if st.weld.has(key):
		return st.weld[key]
	var fa: float = _f(st, a.x, a.y)
	var fb: float = _f(st, b.x, b.y)
	if fa == -INF:
		fa = -1.0
	if fb == -INF:
		fb = -1.0
	var t: float = clampf(fa / (fa - fb), 0.05, 0.95)
	var pa: Vector2 = st.base + Vector2(a) * S
	var pb: Vector2 = st.base + Vector2(b) * S
	var lo: float = 0.0
	var hi: float = 1.0
	if fa < 0.0:   # ensure lo is the wet end
		var tmp: Vector2 = pa
		pa = pb
		pb = tmp
		t = 1.0 - t
	for _pass in 2:
		var p: Vector2 = pa.lerp(pb, t)
		var lvl: float = WaterField.level_at(st.ctx, p)
		var g: float = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
		if lvl > -INF and lvl - g > 0.0:
			lo = t
		else:
			hi = t
		t = (lo + hi) * 0.5
	var p: Vector2 = pa.lerp(pb, t)
	var lvl: float = WaterField.level_at(st.ctx, p)
	if lvl == -INF:
		lvl = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, lvl, p.y))
	st.weld[key] = vi
	return vi


static func _mesh_cut_cell(_st: Dictionary, _i: int, _j: int,
		_corners: Array, _wet: Array) -> void:
	pass   # Task 5
```

- [ ] **Step 4: Run all mesher tests — expect PASS** (welded test, dry test,
boundary test).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterMesher.gd tests/test_water_mesher.gd
git commit -m "feat(water): marching-squares shoreline — mesh edge IS the waterline"
```

---

### Task 5: WaterMesher — fall-cut splitting + lip records

**Files:**
- Modify: `scripts/terrain/water/WaterMesher.gd` (implement `_mesh_cut_cell`,
  collect `cut_records`)
- Test: `tests/test_water_mesher.gd` (append)

**Interfaces:**
- Produces: `build()` result key `cuts: Array[Dictionary]`, each
  `{cut: Dictionary (the WaterField cut), lip: PackedVector3Array,
  base: PackedVector3Array}` — lip/base ordered along `cut.across`, positions
  bit-identical to sheet verts (FallMesher consumes them in Task 8).

- [ ] **Step 1: Append failing tests**

```gdscript
func test_no_triangle_bridges_a_fall() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	var tri: int = 0
	while tri < m.idx.size():
		var lo: float = INF
		var hi: float = -INF
		for k in 3:
			var y: float = m.verts[m.idx[tri + k]].y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		assert_true(hi - lo < WaterMesher.CUT_JUMP + 0.5,
			"triangle spans %.2f vertically — bridges a fall" % (hi - lo))
		tri += 3


func test_cut_records_have_welded_lips() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	assert_true(m.cuts.size() >= 1, "site records its falls")
	var vset: Dictionary = {}
	for v in m.verts:
		vset[v] = true
	for rec: Dictionary in m.cuts:
		assert_true(rec.lip.size() >= 2, "lip is a polyline")
		for v: Vector3 in rec.lip:
			assert_true(vset.has(v), "lip vert %s is bit-equal to a sheet vert" % v)
		for v: Vector3 in rec.base:
			assert_true(vset.has(v), "base vert %s is bit-equal to a sheet vert" % v)
```

- [ ] **Step 2: Run — both FAIL** (cut cells skipped; `cuts` empty).

- [ ] **Step 3: Implement cut cells**

Replace `_mesh_cut_cell` and add the cut-vertex helper:

```gdscript
## A cell straddling a fall: mesh each side separately. Corner membership =
## wet AND on this side of the cut line; edges crossing the cut get one
## vertex PER SIDE at the cut line (same XZ, that side's level) — the two
## sides deliberately do NOT weld across the jump; FallMesher's curtain
## owns the face between them.
static func _mesh_cut_cell(st: Dictionary, i: int, j: int,
		corners: Array, wet_flags: Array) -> void:
	var ci: int = _cell_cut(st, i, j)
	var cut: Dictionary = st.cuts[ci]
	for side in [1, -1]:   # 1 = upstream of the cut (higher), -1 = downstream
		var poly: Array = []
		for k in 4:
			var a: Vector2i = corners[k]
			var b: Vector2i = corners[(k + 1) % 4]
			var a_in: bool = wet_flags[k] and _side_of(st, cut, a) == side
			var b_in: bool = wet_flags[(k + 1) % 4] and _side_of(st, cut, b) == side
			if a_in:
				poly.append(_lattice_vert(st, a.x, a.y))
			if a_in != b_in:
				# Crossing the waterline or the cut? Cut when both wet.
				if wet_flags[k] and wet_flags[(k + 1) % 4]:
					poly.append(_cut_vert(st, ci, a, b, side))
				else:
					poly.append(_edge_vert(st, a, b))
		for k in range(1, poly.size() - 1):
			st.idx.append(poly[0])
			st.idx.append(poly[k])
			st.idx.append(poly[k + 1])


static func _side_of(st: Dictionary, cut: Dictionary, c: Vector2i) -> int:
	var p: Vector2 = st.base + Vector2(c) * S
	return 1 if (p - cut.p).dot(cut.dir) < 0.0 else -1


## Vertex where lattice edge a-b crosses the cut line, at `side`'s level.
## Registered into cut_hits so build() can assemble ordered lip/base
## polylines afterwards.
static func _cut_vert(st: Dictionary, ci: int, a: Vector2i, b: Vector2i, side: int) -> int:
	var key := "C:%d:%d:%d:%d:%d:%d" % [ci, side, mini(a.x, b.x), mini(a.y, b.y),
		absi(b.x - a.x), absi(b.y - a.y)]
	if st.weld.has(key):
		return st.weld[key]
	var cut: Dictionary = st.cuts[ci]
	var pa: Vector2 = st.base + Vector2(a) * S
	var pb: Vector2 = st.base + Vector2(b) * S
	# Intersect edge with the cut line (point cut.p, normal cut.dir).
	var da: float = (pa - cut.p).dot(cut.dir)
	var db: float = (pb - cut.p).dot(cut.dir)
	var t: float = clampf(da / (da - db), 0.0, 1.0) if absf(da - db) > 0.0001 else 0.5
	var p: Vector2 = pa.lerp(pb, t)
	var lvl: float = cut.top if side == 1 else cut.bottom
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, lvl, p.y))
	st.weld[key] = vi
	if not st.cut_hits.has(ci):
		st.cut_hits[ci] = {"lip": [], "base": []}
	st.cut_hits[ci]["lip" if side == 1 else "base"].append(vi)
	return vi
```

And at the end of `build()` (before the return), assemble ordered records:

```gdscript
	var cut_records: Array = []
	for ci: int in st.cut_hits:
		var cut: Dictionary = st.cuts[ci]
		var rec := {"cut": cut, "lip": PackedVector3Array(), "base": PackedVector3Array()}
		for side_key in ["lip", "base"]:
			var vis: Array = st.cut_hits[ci][side_key]
			vis.sort_custom(func(x, y):
				var px := Vector2(st.verts[x].x, st.verts[x].z)
				var py := Vector2(st.verts[y].x, st.verts[y].z)
				return (px - cut.p).dot(cut.across) < (py - cut.p).dot(cut.across))
			for vi: int in vis:
				rec[side_key].append(st.verts[vi])
		cut_records.append(rec)
	st["cut_records"] = cut_records
```

- [ ] **Step 4: Run all mesher tests — expect PASS.** If
`test_no_triangle_bridges_a_fall` still fails, print the offending triangle
positions: the usual cause is a cut cell whose neighbour cell ALSO straddles
the cut but `_cell_cut` returned -1 there (level spread just under
CUT_JUMP). Fix by growing the cut test to include diagonal spread, not by
raising the assertion tolerance.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterMesher.gd tests/test_water_mesher.gd
git commit -m "feat(water): fall cuts split the sheet; ordered lip/base records for the falls"
```

---

### Task 6: WaterMesher — the buried hem

**Files:**
- Modify: `scripts/terrain/water/WaterMesher.gd` (implement `_hem`)
- Test: `tests/test_water_mesher.gd` (append)

- [ ] **Step 1: Append failing tests**

```gdscript
func test_every_free_edge_is_accounted_for() -> void:
	# THE continuity invariant: after the hem, a free edge may only be
	# (a) on the chunk border, (b) a fall-cut lip/base line, or
	# (c) the hem's outer rim, buried under the terrain.
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	for e: Array in WaterMesher.free_edges(m.verts, m.idx):
		if _on_chunk_border(e[0]) and _on_chunk_border(e[1]):
			continue
		var buried := true
		var on_cut := true
		for v: Vector3 in e:
			var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			if v.y > g - 0.3:
				buried = false
			var near := false
			for rec: Dictionary in m.cuts:
				if absf((Vector2(v.x, v.z) - rec.cut.p).dot(rec.cut.dir)) < WaterMesher.S:
					near = true
			if not near:
				on_cut = false
		assert_true(buried or on_cut,
			"unaccounted free edge %s-%s (not border/cut/buried)" % [e[0], e[1]])


func test_hem_is_buried() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	var hem_n := 0
	for v in m.verts:
		var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
		if v.y < g - 0.5:
			hem_n += 1
	assert_true(hem_n > 10, "hem exists and dives under the banks (%d)" % hem_n)
```

- [ ] **Step 2: Run — `test_every_free_edge_is_accounted_for` FAILS**
(contour edges are free and not buried).

- [ ] **Step 3: Implement `_hem`**

```gdscript
## One uniform edge rule replaces every legacy shore special case: each
## CONTOUR free edge (not chunk border, not a fall cut) extrudes a strip
## outward and down to ground - HEM_DROP, INSIDE the bank. Swells raise the
## surface; the waterline slides up the bank; the edge never lifts free.
static func _hem(st: Dictionary) -> void:
	var span: float = TILE * 8.0
	var outer: Dictionary = {}   # inner vert index -> hem vert index
	for e_idx: Array in _free_edge_indices(st):
		var a: int = e_idx[0]
		var b: int = e_idx[1]
		var va: Vector3 = st.verts[a]
		var vb: Vector3 = st.verts[b]
		if _border2(st.base, span, va) and _border2(st.base, span, vb):
			continue
		if _near_cut(st, va) and _near_cut(st, vb):
			continue
		# Outward = away from the water: the free edge belongs to exactly one
		# triangle; its third vertex lies IN the water.
		var third: Vector3 = st.verts[_third_vert(st, a, b)]
		var edge2 := Vector2(vb.x - va.x, vb.z - va.z)
		var n2 := Vector2(-edge2.y, edge2.x).normalized()
		var to_third := Vector2(third.x - va.x, third.z - va.z)
		if n2.dot(to_third) > 0.0:
			n2 = -n2
		var ha: int = _hem_vert(st, outer, a, n2)
		var hb: int = _hem_vert(st, outer, b, n2)
		for t in [[a, b, hb], [a, hb, ha]]:
			for k in 3:
				st.idx.append(t[k])


static func _hem_vert(st: Dictionary, outer: Dictionary, src: int, n2: Vector2) -> int:
	if outer.has(src):
		return outer[src]
	var v: Vector3 = st.verts[src]
	var p := Vector2(v.x, v.z) + n2 * HEM_W
	var g: float = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
	var vi: int = st.verts.size()
	st.verts.append(Vector3(p.x, minf(v.y, g) - HEM_DROP, p.y))
	outer[src] = vi
	return vi


static func _border2(base: Vector2, span: float, v: Vector3) -> bool:
	var lx: float = v.x - base.x
	var lz: float = v.z - base.y
	return lx < 0.01 or lx > span - 0.01 or lz < 0.01 or lz > span - 0.01


static func _near_cut(st: Dictionary, v: Vector3) -> bool:
	for cut: Dictionary in st.cuts:
		if absf((Vector2(v.x, v.z) - cut.p).dot(cut.dir)) < S:
			return true
	return false


## free_edges but returning index pairs plus a helper to find the lone
## triangle's third vertex.
static func _free_edge_indices(st: Dictionary) -> Array:
	var count: Dictionary = {}
	var tri: int = 0
	while tri < st.idx.size():
		for k in 3:
			var a: int = st.idx[tri + k]
			var b: int = st.idx[tri + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = count.get(key, 0) + 1
		tri += 3
	var out: Array = []
	for key: Vector2i in count:
		if count[key] == 1:
			out.append([key.x, key.y])
	return out


static func _third_vert(st: Dictionary, a: int, b: int) -> int:
	var tri: int = 0
	while tri < st.idx.size():
		var tvs: Array = [st.idx[tri], st.idx[tri + 1], st.idx[tri + 2]]
		if a in tvs and b in tvs:
			for v: int in tvs:
				if v != a and v != b:
					return v
		tri += 3
	return a
```

Note: `_third_vert` as written is O(edges × tris); build an edge→tri map in
`_free_edge_indices` and return it alongside if the site chunk build exceeds
~2 s in the test run (measure first — a 64×64 chunk has few thousand tris
and few hundred free edges; the naive loop is usually fine for a build that
runs on a worker thread).

- [ ] **Step 4: Run all mesher tests — expect PASS (5 tests).**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterMesher.gd tests/test_water_mesher.gd
git commit -m "feat(water): buried hem — one edge rule, zero unaccounted free edges"
```

---

### Task 7: WaterMesher — attributes, seam identity, ArrayMesh commit

**Files:**
- Modify: `scripts/terrain/water/WaterMesher.gd`
- Test: `tests/test_water_mesher.gd` (append)

**Interfaces:**
- Produces:
  - `WaterMesher.commit(m: Dictionary) -> ArrayMesh` — CUSTOM0 RGBA_FLOAT
    format, normals UP (the water shader computes its own).
  - `build()` result key `wet_cells: Dictionary` — `Vector2i cell ->
    {lvl: float, grad: Vector2, gnd_lo: float}` for the volume builder
    (Task 9): cell-centre level, XZ level gradient, lowest ground sample.
  - CUSTOM0 layout (matches the existing shader contract):
    `(flow.x, shore, flow.y, steep)` — steep is `grade*8` clamped 0..1, PLUS
    the plunge band: within 3.5 m of a cut's base line, `steep = max(...)`
    of `w = clamp((3.5 - dist)/2, 0, 1)` and `shore = max(shore, 0.85*w)`.

- [ ] **Step 1: Append failing tests**

```gdscript
func test_chunk_seam_identity() -> void:
	var water: WaterPlan = _water(SEED)
	var a: Dictionary = WaterMesher.build(water, Vector2i(0, -6), _region(SEED, Vector2i(0, -6)))
	var b: Dictionary = WaterMesher.build(water, Vector2i(1, -6), _region(SEED, Vector2i(1, -6)))
	var seam_x: float = 24.0 * 8.0   # world x of the shared border
	var a_seam: Dictionary = {}
	for v in a.verts:
		if absf(v.x - seam_x) < 0.01:
			a_seam[Vector3i((v * 100.0).round())] = v
	var matched := 0
	for v in b.verts:
		if absf(v.x - seam_x) < 0.01 and a_seam.has(Vector3i((v * 100.0).round())):
			matched += 1
	assert_true(matched >= 2, "adjacent chunks share bit-identical seam verts (%d)" % matched)


func test_commit_and_attributes() -> void:
	var water: WaterPlan = _water(SEED)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, _region(SEED, SITE_CHUNK))
	assert_eq(m.cust.size(), m.verts.size() * 4, "4 floats per vertex")
	var mesh: ArrayMesh = WaterMesher.commit(m)
	assert_eq(mesh.surface_get_array_len(0), m.verts.size(), "verts committed")
	assert_true(m.wet_cells.size() > 0, "volume cells recorded")
	var churn := 0
	var idx := 0
	while idx < m.cust.size():
		if m.cust[idx + 3] > 0.9:
			churn += 1
		idx += 4
	assert_true(churn > 0, "plunge band baked near falls")
```

- [ ] **Step 2: Run — FAIL** (cust zeros, no commit/wet_cells).

- [ ] **Step 3: Implement `_attributes`, `wet_cells`, `commit`**

```gdscript
static func _attributes(st: Dictionary) -> void:
	var cust := PackedFloat32Array()
	cust.resize(st.verts.size() * 4)
	for vi in st.verts.size():
		var v: Vector3 = st.verts[vi]
		var p := Vector2(v.x, v.z)
		var fl: Vector2 = WaterField.flow_at(st.ctx, p)
		var g: float = TerrainSurfaceField.surface_y(st.region, v.x, v.z)
		var shore: float = clampf(1.0 - (v.y - g) * 1.2, 0.0, 1.0) \
			if v.y > g - 0.5 else 1.0   # near/below ground = the very shoreline
		var steep: float = clampf(WaterField.grade_at(st.ctx, p) * 8.0, 0.0, 0.85)
		for cut: Dictionary in st.cuts:
			var along: float = (p - cut.p).dot(cut.dir)
			if along > -0.5 and absf((p - cut.p).dot(cut.across)) < cut.half + S:
				var w: float = clampf((3.5 - along) / 2.0, 0.0, 1.0)
				steep = maxf(steep, w)
				shore = maxf(shore, 0.85 * w)
		cust[vi * 4 + 0] = fl.x
		cust[vi * 4 + 1] = shore
		cust[vi * 4 + 2] = fl.y
		cust[vi * 4 + 3] = steep
	st["cust"] = cust
	var wet_cells: Dictionary = {}
	for j in range(0, N + 1, 8):
		for i in range(0, N + 1, 8):
			var lvl: float = st.lvl[j * (N + 1) + i]
			if lvl == -INF or lvl <= st.gnd[j * (N + 1) + i] + EPS:
				continue
			var cell := Vector2i(int(floor((st.base.x + i * S) / TILE)),
				int(floor((st.base.y + j * S) / TILE)))
			var pr: Vector2 = st.base + Vector2(i + 4, j) * S
			var pd: Vector2 = st.base + Vector2(i, j + 4) * S
			var gx: float = (WaterField.level_at(st.ctx, pr) - lvl) / (4.0 * S)
			var gz: float = (WaterField.level_at(st.ctx, pd) - lvl) / (4.0 * S)
			wet_cells[cell] = {"lvl": lvl,
				"grad": Vector2(gx if absf(gx) < 1.0 else 0.0, gz if absf(gz) < 1.0 else 0.0),
				"gnd_lo": st.gnd[j * (N + 1) + i]}
	st["wet_cells"] = wet_cells


static func commit(m: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = m.verts
	arrays[Mesh.ARRAY_INDEX] = m.idx
	var normals := PackedVector3Array()
	normals.resize(m.verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_CUSTOM0] = m.cust
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh
```

- [ ] **Step 4: Run all mesher tests — expect PASS (7 tests).**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterMesher.gd tests/test_water_mesher.gd
git commit -m "feat(water): vertex attributes, plunge band, seam identity, ArrayMesh commit"
```

---

### Task 8: FallMesher — ogee sweep from lip contours

**Files:**
- Create: `scripts/terrain/water/FallMesher.gd`
- Test: `tests/test_water_falls.gd`

**Interfaces:**
- Consumes: `build()` cut records (Task 5): `{cut, lip, base}`.
- Produces: `FallMesher.build(cuts: Array, region) -> ArrayMesh` (null when
  no cuts). UV2 = (side_flag, drop_height) per the existing waterfall
  shader contract; UV.y runs 0 at the lip to ~1.05 past the plunge.
- Copy `_fall_curve(top, bottom)`, `FALL_PAR_ROWS`, `FALL_FILLET_ROWS`,
  `FALL_OVERLAP` VERBATIM from `WaterSurfaceBuilder.gd` into `FallMesher.gd`
  (the originals are deleted in Task 12).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_water_falls.gd` (same cached helper block):

```gdscript
func test_falls_weld_to_lip_and_dive_under_the_pool() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	assert_true(m.cuts.size() >= 1, "site has falls")
	var mesh: ArrayMesh = FallMesher.build(m.cuts, region)
	assert_not_null(mesh, "falls build")
	var arrays: Array = mesh.surface_get_arrays(0)
	var fverts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vset: Dictionary = {}
	for v in fverts:
		vset[v] = true
	for rec: Dictionary in m.cuts:
		var top_row := 0
		for v: Vector3 in rec.lip:
			if vset.has(v):
				top_row += 1
		assert_eq(top_row, rec.lip.size(),
			"every lip vert appears in the fall mesh bit-identically")
		var below := false
		for v in fverts:
			if v.y < rec.cut.bottom - 0.3:
				below = true
		assert_true(below, "fall dives under the plunge surface")


func test_no_fall_without_a_big_drop() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	for rec: Dictionary in m.cuts:
		assert_true(rec.cut.top - rec.cut.bottom > WaterField.FALL_DROP_MIN - 0.001,
			"a sub-4m fall exists — the weir staircase is back")
```

- [ ] **Step 2: Run — FAIL on missing FallMesher.**

- [ ] **Step 3: Implement FallMesher**

Create `scripts/terrain/water/FallMesher.gd`:

```gdscript
# True waterfalls (>4m only): a swept ogee from the sheet's own lip contour.
# Lip vertices arrive from WaterMesher's cut records — the SAME Vector3s the
# sheet uses, so crest continuity is data flow, not float matching. The lip
# polyline is a waterline contour: its ends already bend into the banks, so
# the swept sides wrap into the ground; the bottom dives 0.5m below the
# plunge surface so the visible intersection is submerged under the churn.
class_name FallMesher
extends Object

# --- copied verbatim from the retired WaterSurfaceBuilder ---------------
# const FALL_OVERLAP / FALL_PAR_ROWS / FALL_FILLET_ROWS := ...
# static func _fall_curve(top: float, bottom: float) -> Dictionary: ...
# (copy the exact block; do not re-derive)
# -------------------------------------------------------------------------


static func build(cuts: Array, region) -> ArrayMesh:
	if cuts.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for rec: Dictionary in cuts:
		if rec.lip.size() >= 2:
			_sweep(st, rec, region)
			any = true
	if not any:
		return null
	st.generate_normals()
	return st.commit()


static func _sweep(st: SurfaceTool, rec: Dictionary, region) -> void:
	var cut: Dictionary = rec.cut
	var drop_h: float = maxf(cut.top - cut.bottom, 0.5)
	var cv: Dictionary = _fall_curve(cut.top, cut.bottom)
	var rows: Array = _rows(cv, cut, drop_h)   # [[along, y_below_lip, uv_y], ...]
	var thick: float = clampf(drop_h * 0.10, 0.4, 1.2)
	var cols: Array = []
	for v: Vector3 in rec.lip:
		var fcol: Array = []
		for row: Array in rows:
			fcol.append(Vector3(v.x + cut.dir.x * row[0], v.y - row[1],
				v.z + cut.dir.y * row[0]))
		cols.append(fcol)
	for ci in cols.size() - 1:
		var ux0: float = float(ci) / float(cols.size() - 1)
		var ux1: float = float(ci + 1) / float(cols.size() - 1)
		for ri in rows.size() - 1:
			_quad(st, [cols[ci][ri], cols[ci + 1][ri],
				cols[ci + 1][ri + 1], cols[ci][ri + 1]],
				[rows[ri][2], rows[ri][2], rows[ri + 1][2], rows[ri + 1][2]],
				[ux0, ux1, ux1, ux0], 0.0, drop_h)
		# Back sheet: offset upstream by `thick` along -dir, same rows.
		for ri in rows.size() - 1:
			var o := Vector3(-cut.dir.x, 0.0, -cut.dir.y) * thick
			_quad(st, [cols[ci][ri] + o, cols[ci][ri + 1] + o,
				cols[ci + 1][ri + 1] + o, cols[ci + 1][ri] + o],
				[rows[ri][2], rows[ri + 1][2], rows[ri + 1][2], rows[ri][2]],
				[ux0, ux0, ux1, ux1], 0.0, drop_h)
	# Lip cap between front row 0 and back row 0 (UV2.x = 1 marks it).
	for ci in cols.size() - 1:
		var o := Vector3(-cut.dir.x, 0.0, -cut.dir.y) * thick
		_quad(st, [cols[ci][0], cols[ci][0] + o,
			cols[ci + 1][0] + o, cols[ci + 1][0]],
			[0.0, 0.0, 0.0, 0.0],
			[float(ci) / float(cols.size() - 1), 0.0, 1.0, 1.0], 1.0, drop_h)


static func _rows(cv: Dictionary, cut: Dictionary, drop_h: float) -> Array:
	var rows: Array = []
	rows.append([-FALL_OVERLAP, 0.03, 0.0])
	for i in FALL_PAR_ROWS + 1:
		var x: float = cv.x_star * float(i) / float(FALL_PAR_ROWS)
		var y: float = cv.y0 - cv.s0 * x - cv.c * x * x
		rows.append([x, cv.y0 - y, (cut.top - y) / drop_h])
	for jj in range(1, FALL_FILLET_ROWS + 1):
		var th: float = cv.th0 * (1.0 - float(jj) / float(FALL_FILLET_ROWS))
		var x: float = cv.x_star + cv.arc_r * (sin(cv.th0) - sin(th))
		var y: float = cv.y_star - cv.arc_r * (cos(th) - cos(cv.th0))
		rows.append([x, cv.y0 - y, (cut.top - y) / drop_h])
	rows.append([cv.x_end + 1.6, cv.y0 - (cut.bottom - 0.5), 1.05])
	return rows


static func _quad(st: SurfaceTool, vs: Array, uv_y: Array, uv_x: Array,
		side: float, drop_h: float) -> void:
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2(uv_x[k], uv_y[k]))
		st.set_uv2(Vector2(side, drop_h))
		st.add_vertex(vs[k])
```

Copy the marked block (`FALL_OVERLAP`, `FALL_PAR_ROWS`, `FALL_FILLET_ROWS`,
`_fall_curve`) from `WaterSurfaceBuilder.gd` — search for
`static func _fall_curve` — verbatim into the marked section.

- [ ] **Step 4: Refresh class cache, run `test_water_falls.gd` — expect 2/2 PASS.**

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/FallMesher.gd tests/test_water_falls.gd
git commit -m "feat(water): FallMesher — ogee sweep from the sheet's own lip contour"
```

---

### Task 9: Integration — new build_chunk + swim volumes

**Files:**
- Modify: `scripts/terrain/water/WaterSurfaceBuilder.gd` — replace the BODY
  of `func build_chunk(water, chunk, region) -> Node3D` (keep the signature;
  the streamer calls it). Keep `sheet_material()` / `waterfall_material()`.
- Modify: `tests/test_water_swim_volumes.gd` — update surface expectations.
- Test: `tests/test_water_mesher.gd` (append one integration test).

**Interfaces:**
- Consumes: `WaterMesher.build/commit`, `FallMesher.build`, `wet_cells`.
- Produces: scene contract UNCHANGED — a `Node3D` named `"Water"` with
  `MeshInstance3D "WaterSheet"`, `MeshInstance3D "Waterfalls"` (when falls
  exist), and one `Area3D` per wet cell on layer `1 << 7` with metas:
  `surface_c: Vector3` (cell-centre x, level, z) and `surface_g: Vector2`
  (level gradient d(level)/dx, d(level)/dz) — Task 10's character contract.

- [ ] **Step 1: Append the failing integration test to `tests/test_water_mesher.gd`**

```gdscript
func test_build_chunk_scene_contract() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	assert_not_null(node, "site builds")
	assert_not_null(node.get_node_or_null("WaterSheet"), "sheet present")
	var areas := 0
	for ch in node.get_children():
		if ch is Area3D:
			areas += 1
			assert_true(ch.has_meta("surface_c") and ch.has_meta("surface_g"),
				"volume carries the sampled surface plane")
			assert_eq(ch.collision_layer, 1 << 7, "water layer")
	assert_true(areas > 0, "swim volumes present")
	node.free()
```

- [ ] **Step 2: Run — FAILS** (old build_chunk emits `surface_y` meta, old mesh path).

- [ ] **Step 3: Replace `build_chunk`'s body**

```gdscript
func build_chunk(water: WaterPlan, chunk: Vector2i, region) -> Node3D:
	var m: Dictionary = WaterMesher.build(water, chunk, region)
	if m.is_empty():
		return null
	var root := Node3D.new()
	root.name = "Water"
	var mi := MeshInstance3D.new()
	mi.name = "WaterSheet"
	mi.mesh = WaterMesher.commit(m)
	mi.material_override = WaterSurfaceBuilder.sheet_material()
	root.add_child(mi)
	var falls: ArrayMesh = FallMesher.build(m.cuts, region)
	if falls != null:
		var fi := MeshInstance3D.new()
		fi.name = "Waterfalls"
		fi.mesh = falls
		fi.material_override = WaterSurfaceBuilder.waterfall_material()
		root.add_child(fi)
	for cell: Vector2i in m.wet_cells:
		var wc: Dictionary = m.wet_cells[cell]
		var area := Area3D.new()
		area.collision_layer = 1 << 7
		area.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var top: float = wc.lvl + 1.7
		var bottom: float = wc.gnd_lo - 5.0
		box.size = Vector3(TILE, top - bottom, TILE)
		shape.shape = box
		area.add_child(shape)
		area.position = Vector3((float(cell.x) + 0.5) * TILE,
			(top + bottom) * 0.5, (float(cell.y) + 0.5) * TILE)
		area.set_meta("surface_c", Vector3((float(cell.x) + 0.5) * TILE,
			wc.lvl, (float(cell.y) + 0.5) * TILE))
		area.set_meta("surface_g", wc.grad)
		root.add_child(area)
	return root
```

Keep the old helper functions in place for now (Tasks 10–11 still reference
nothing from them; deletion happens in Task 12). If `build_chunk` referenced
mist helpers, drop those calls — mist is re-evaluated after the redesign
(note it in the Task 12 commit message as an intentional follow-up).

- [ ] **Step 4: Run mesher + swim suites.** `test_water_swim_volumes.gd` will
FAIL where it reads meta `surface_y`: update those assertions to compute
`surface_c.y + surface_g.dot(probe_xz - Vector2(surface_c.x, surface_c.z))`
and re-run until green.

- [ ] **Step 5: In-game smoke** — `run_project`, `ReviewCam.pose(Vector3(33.9, 8.0, -1097.4))`,
wait 10 s, `shoot(...)` to the scratchpad, LOOK at the frame (water present,
no obvious holes at the site), `stop_project`.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/water/WaterSurfaceBuilder.gd tests/test_water_mesher.gd tests/test_water_swim_volumes.gd
git commit -m "feat(water): boundary mesh wired into the streamer; volumes carry sampled surface planes"
```

---

### Task 10: Character sampling on sloped water

**Files:**
- Modify: `characters/character.gd` — `_update_in_water` (the block reading
  meta `surface_y`).
- Test: `tests/test_water_swim_volumes.gd` (append).

**Interfaces:**
- Consumes: `surface_c: Vector3` / `surface_g: Vector2` metas (Task 9).
- The swell mirror `_swell_offset()` is UNCHANGED.

- [ ] **Step 1: Append the failing test**

```gdscript
func test_volume_surface_matches_field_at_probe_points() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var checked := 0
	for ch in node.get_children():
		if ch is Area3D:
			var c: Vector3 = ch.get_meta("surface_c")
			var g: Vector2 = ch.get_meta("surface_g")
			var lvl: float = WaterField.level_at(ctx, Vector2(c.x, c.z))
			assert_almost_eq(c.y, lvl, 0.05, "volume centre level == field level")
			var px := Vector2(c.x + 6.0, c.z)
			var plvl: float = WaterField.level_at(ctx, px)
			if plvl > -INF and absf(plvl - lvl) < 2.0:
				assert_almost_eq(c.y + g.dot(px - Vector2(c.x, c.z)), plvl, 0.6,
					"sampled plane tracks the sloped surface")
				checked += 1
	assert_true(checked > 0, "at least one sloped/flat cell verified")
	node.free()
```

- [ ] **Step 2: Run — likely PASSES for the volume side (Task 9 built it);
if so this test is the guard. The RED part is the character:**
open `characters/character.gd`, find `get_meta("surface_y"...)`; the old
default `-1.5` fallback path. There is no headless character test; the
verification is Step 4's in-game swim check.

- [ ] **Step 3: Edit character.gd**

Replace the meta read (keep every other line of the probe/gating logic —
especially the `probe_y <= sy + swell + 0.45` gate):

```gdscript
	var sy: float
	if vol.has_meta("surface_c"):
		var c: Vector3 = vol.get_meta("surface_c")
		var g: Vector2 = vol.get_meta("surface_g")
		sy = c.y + g.dot(Vector2(global_position.x - c.x, global_position.z - c.z))
	else:
		sy = vol.get_meta("surface_y", global_position.y - 1.5)
```

- [ ] **Step 4: In-game verification** — run, teleport into the site pool
(F4 spot or `RC.pose` at `(54, 6, -1100)`), `game_eval` press-forward into
the water; confirm float at the surface, no mid-air swimming beside the
falls, sink gate intact. Screenshot for the record. Stop the game.

- [ ] **Step 5: Commit**

```bash
git add characters/character.gd tests/test_water_swim_volumes.gd
git commit -m "feat(water): character samples the sloped surface plane per volume"
```

---

### Task 11: Shader pass — swell edges, roughness speed, river motion

**Files:**
- Modify: `terrain/water/water_unified.gdshader`
- Test: `tests/tools/shader_compile_check.gd` run + in-game battery

- [ ] **Step 1: Remove the shore swell damping (spec: static-edge fix).**
In `vertex()`, change:

```glsl
	float amp = wave_height * (1.0 + 0.35 * ff) * (1.0 - smoothstep(0.45, 0.9, shore_v));
```
to:
```glsl
	// The buried hem owns the edge now: the whole surface rides the swell
	// and the waterline slides up and down the bank with it.
	float amp = wave_height * (1.0 + 0.35 * ff);
```

- [ ] **Step 2: Slow the micro-roughness and advect it downstream.**
Add a uniform near the other speed uniforms:

```glsl
uniform float wobble_speed : hint_range(0.0, 2.0) = 0.5;
```

and in `fragment()` replace the two wobble samples:

```glsl
	vec2 adv = flow_v.xz * TIME * 0.35;
	float wa = texture(noise_tex, world_pos.xz * 0.045 - adv
			+ vec2(TIME * 0.021, -TIME * 0.017) * wobble_speed).r;
	float wb = texture(noise_tex, world_pos.xz * 0.045 + vec2(37.7, 11.3) - adv * 1.15
			+ vec2(-TIME * 0.019, TIME * 0.023) * wobble_speed).r;
```

(The two advection rates differ 15% so the drift never reads as a rigid
texture slide.)

- [ ] **Step 3: Compile check**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/tools/shader_compile_check.gd`
Expected: `COMPILE-CHECK OK` for both water shaders.

- [ ] **Step 4: In-game look pass** — run, shoot the battery
(`tests/tools/review_vantages.json`, at minimum the owner frame
`(33.9, 8.0, -1097.4)/(33.6, 8.2, -1097.7)` and the head-on
`cam (49.3,12,-1118.6) -> (49.3,7.6,-1110.6)`). LOOK for: waterline riding
the swell (no static ring), calm-but-alive rivers, no fall/pool seam. Tune
`wobble_speed` live via
`WaterSurfaceBuilder.sheet_material().set_shader_parameter("wobble_speed", X)`
then bake the chosen value into the shader file. Stop the game.

- [ ] **Step 5: Commit**

```bash
git add terrain/water/water_unified.gdshader
git commit -m "feat(water): edges ride the swells, slower micro-roughness, downstream drift"
```

---

### Task 12: Deletion sweep + full battery

**Files:**
- Modify: `scripts/terrain/water/WaterSurfaceBuilder.gd` — delete:
  `compute_field`, `corner_map`, `_corner`, `_corner_wetf_smooth`,
  `sheet_ctx`, `_sheet_vert`, `_fiction_cap`, `_on_dry_cell`,
  `_clear_of_droops`, `_edge_dist`, `edge_profile`, `sheet_cell_grid`,
  `_bilerp_pos/_bilerp_cust/_bilerp_gnd`, `compute_ribbons`, `_ribbon_mesh`,
  `_fall_quad`, `_fall_curve` + row constants (now living in FallMesher),
  `crest_droop_at`, `_build_volumes` and the old volume constants, the mist
  block if orphaned, and constants `BRIDGE_MAX`, `CREST_DROOP*`,
  `SHORE_WOBBLE_*`, `SHORE_SDF_SCALE`, `FLOOD_*`, `FIELD_MARGIN`, `SUBDIV`
  (the mesher owns granularity now). What remains: `build_chunk`,
  `sheet_material`, `waterfall_material`, `TILE`, `CELLS_PER_CHUNK`.
- Delete: `tests/test_water_float_invariants.gd`,
  `tests/test_water_surface_builder.gd` (their machinery is gone; their
  survivors were re-expressed in the new suites), `tests/tools/skirt_probe.gd`
  (superseded by the free-edge oracle + `ReviewCam.skirt_debug`).
- Modify: `scripts/terrain/tools/ReviewCam.gd` — keep as-is (`skirt_debug`
  works on the rendered mesh + volumes; expected to report ~0 skirt verts).

- [ ] **Step 1: Delete, then grep for stragglers**

Run: `grep -rn "compute_field\|sheet_ctx\|sheet_cell_grid\|compute_ribbons\|BRIDGE_MAX\|edge_profile" scripts/ tests/ --include="*.gd"`
Expected: no hits outside comments/docs. Fix any caller found.

- [ ] **Step 2: Full suite battery**

Run every suite:
`for t in test_water_field test_water_mesher test_water_falls test_water_swim_volumes test_field_streamer; do ...GUT command...; done`
Expected: ALL PASS.

- [ ] **Step 3: Full visual battery** — run the game; shoot EVERY entry in
`tests/tools/review_vantages.json` (natural), plus `ReviewCam.skirt_debug`
at the owner frame (expect ~0; print goes to the log), plus a free-edge
count print per site chunk via `game_eval`. Review every frame against the
owner's issue list (the six bullets in the spec). Any regression: fix
before committing, or document explicitly in the commit message and report.

- [ ] **Step 4: Docs + memory** — update the water section of `AGENTS.md`
(if present) to describe the field/mesher/falls architecture; update the
assistant memory file per its own conventions.

- [ ] **Step 5: Commit**

```bash
git add -u scripts/terrain/water tests scripts/terrain/tools
git status --short   # VERIFY project.godot and mcp_interaction_server.gd are NOT staged
git commit -m "refactor(water): delete the patch-and-carve machinery — the boundary mesh replaces it"
```

---

## Self-Review Notes (already applied)

- Spec coverage: field/continuity (T1–2), boundary mesh + welding + hem
  (T3–7), falls >4m + lip weld + submerged base (T5, T8), scene/volumes
  (T9–10), shader items incl. static-edge fix, roughness speed, river motion
  (T11), deletion sweep + invariants battery (T12). Spec invariants map:
  1→T6 test, 2→T4 test, 3→T6 test, 4→T5 tri-span test, 5→T8 test, 6→T1 test,
  7→T7 test, 8→T10 test.
- Type consistency: `ctx`/`level_at`/`wet`/`flow_at`/`grade_at`/`fall_cuts`
  and mesher/fall record keys are used with identical names across tasks.
- Known judgement points left to the implementer (flagged inline): Task 1
  junction tolerance, Task 6 `_third_vert` perf, Task 11 `wobble_speed`
  final value (visual), Task 9 mist follow-up.
