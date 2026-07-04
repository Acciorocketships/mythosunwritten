# Water: River Networks with Attached Ponds — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deterministic river networks (source pools → downhill snaking channels → junctions/terminal ponds) carved into the heightfield, with flowing river ribbons + stepped pond surfaces and swimmable volumes.

**Architecture:** A new pure `WaterPlan` (peer of `HeightfieldPlan`) traces rivers downhill on the smooth landform field, purely from `(world_seed, super_cell)` with bounded windows. It exposes `carve_at_cell` — subtracted inside `HeightfieldPlan.raw_height` before storey quantization, so the existing clamp/cliff/dressing pipeline builds all banks — and `bodies_near` for per-chunk water surface meshes and Area3D swim volumes built by a new `WaterSurfaceBuilder`.

**Tech Stack:** Godot 4 / GDScript (no .NET), GUT tests, KayKit-dressed field terrain.

**Spec:** `docs/superpowers/specs/2026-07-04-water-rivers-lakes-design.md`

**Conventions for every task:**
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`
- Run one test file: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- After creating a NEW `class_name` script, run `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` once so the headless runner can resolve the class (registers it in `.godot/global_script_class_cache.cfg`).
- `*.uid` files are gitignored — never commit them. Stage specific files only, never `git add -A`.
- Commit messages end with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: Smooth landform field (`HeightfieldPlan.height01` static)

River tracing must descend the same mountains the terrain renders, minus the fine detail octave (which would jitter the gradient). Extract `_height01` into a static with an `include_detail` flag.

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd:72-85` (`_height01`)
- Test: `tests/test_heightfield_plan.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/test_heightfield_plan.gd`:

```gdscript
# ------------------------------------------------------------
# height01 static — shared landform field (smooth variant for river tracing)
# ------------------------------------------------------------

func test_height01_static_matches_instance_raw_height() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 32.0)
	var pos: Vector3 = Vector3(3.0 * 24.0, 0.0, -5.0 * 24.0)
	assert_almost_eq(plan.raw_height(3, -5),
		HeightfieldPlan.height01(pos, 4242, true) * 32.0, 0.0001,
		"static height01(include_detail=true) is the rendered field")

func test_height01_smooth_is_deterministic_and_in_range() -> void:
	var pos: Vector3 = Vector3(400.0, 0.0, -900.0)
	var a: float = HeightfieldPlan.height01(pos, 7, false)
	var b: float = HeightfieldPlan.height01(pos, 7, false)
	assert_eq(a, b, "same seed+pos => same smooth height")
	assert_true(a >= 0.0 and a <= 1.0, "smooth height stays in [0,1]")

func test_height01_smooth_ignores_detail_octave() -> void:
	# The detail octave is seed+9. The smooth variant must not consume it, so
	# it is invariant under changes that only affect that octave. We can't
	# reseed one octave in isolation, but we CAN check the two variants differ
	# (detail contributes) while both track the same macro landform.
	var pos: Vector3 = Vector3(1000.0, 0.0, 1000.0)
	var with_detail: float = HeightfieldPlan.height01(pos, 7, true)
	var smooth: float = HeightfieldPlan.height01(pos, 7, false)
	assert_almost_eq(with_detail, smooth, 0.25,
		"variants track the same landform (only the fine octave differs)")
```

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_plan.gd -gexit`
Expected: FAIL — `height01` not found in `HeightfieldPlan`.

- [ ] **Step 3: Implement** — in `HeightfieldPlan.gd`, replace the body of `_height01` and add the static above it:

```gdscript
## Shared landform field in [0, 1]. include_detail=false is the SMOOTH field
## (macro + hills + rocky/ridge shaping, origin falloff — no fine octave):
## river tracing descends it so channels follow the rendered mountains
## without jittering on the detail noise. include_detail=true is the exact
## rendered terrain field (used by _height01 / raw_height).
static func height01(pos: Vector3, p_world_seed: int, include_detail: bool = true) -> float:
	var base: float = Helper._value_noise01(pos, p_world_seed, 320.0)
	var hills: float = Helper._value_noise01(pos, p_world_seed + 5, 120.0)
	var h: float
	if include_detail:
		var detail: float = Helper._value_noise01(pos, p_world_seed + 9, 46.0)
		h = (base + hills * 0.5 + detail * 0.25) / 1.75
	else:
		h = (base + hills * 0.5) / 1.5
	var rocky: float = Helper.biome_rocky01(pos, p_world_seed)
	h *= 0.35 + 1.5 * rocky
	if rocky > 0.5:
		# Ridged noise (sharp peaks) for mountain spines in rocky cores.
		var n: float = Helper._value_noise01(pos, p_world_seed + 17, 190.0)
		var ridge: float = 1.0 - absf(2.0 * n - 1.0)
		h += ridge * ridge * (rocky - 0.5) * 0.9
	var falloff: float = clampf((Vector2(pos.x, pos.z).length() - 60.0) / 120.0, 0.0, 1.0)
	return clampf(h * falloff, 0.0, 1.0)


func _height01(pos: Vector3) -> float:
	return height01(pos, world_seed, true)
```

Delete the old `_height01` body (the doc comment above it stays).

- [ ] **Step 4: Run to verify pass**

Run: the same command as Step 2.
Expected: PASS (all pre-existing tests in the file must still pass — this is a pure refactor for `include_detail=true`).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd tests/test_heightfield_plan.gd
git commit -m "feat(water): extract static height01 with smooth (no-detail) variant

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `PondStamp` — the one water-body primitive

**Files:**
- Create: `scripts/terrain/water/PondStamp.gd`
- Test: `tests/test_pond_stamp.gd`

- [ ] **Step 1: Write the failing tests** — create `tests/test_pond_stamp.gd`:

```gdscript
extends GutTest

# ------------------------------------------------------------
# PondStamp — wobbly bowl with a storey-aligned water level
# ------------------------------------------------------------

func _stamp() -> PondStamp:
	return PondStamp.new(Vector2(100.0, -50.0), 60.0, 12345, 3, 3.5)

func test_surface_and_bed_derive_from_level() -> void:
	var p: PondStamp = _stamp()
	assert_almost_eq(p.surface_y(), 3.0 * 4.0 - PondStamp.SURFACE_DROP, 0.0001,
		"surface = level*storey - drop")
	assert_almost_eq(p.bed_y(), 3.0 * 4.0 - 3.5, 0.0001, "bed = level*storey - depth")

func test_footprint_wobbles_but_stays_bounded() -> void:
	var p: PondStamp = _stamp()
	for k in 16:
		var r: float = p.radius_at(TAU * float(k) / 16.0)
		assert_true(r >= 60.0 * (1.0 - PondStamp.WOBBLE) - 0.001, "wobble lower bound")
		assert_true(r <= p.bound_radius() + 0.001, "wobble upper bound")

func test_carve_full_in_core_zero_outside() -> void:
	var p: PondStamp = _stamp()
	var ground: float = 14.0
	var core: float = p.carve_at(p.center, ground)
	assert_almost_eq(core, ground - p.bed_y(), 0.0001, "center carves to the bed")
	var outside: Vector2 = p.center + Vector2(p.bound_radius() + 1.0, 0.0)
	assert_eq(p.carve_at(outside, ground), 0.0, "no carve outside the footprint")

func test_carve_never_raises_ground() -> void:
	var p: PondStamp = _stamp()
	assert_eq(p.carve_at(p.center, p.bed_y() - 2.0), 0.0,
		"ground already below bed => carve 0 (only ever lowers)")

func test_footprint_deterministic_per_shape_seed() -> void:
	var a: PondStamp = _stamp()
	var b: PondStamp = _stamp()
	assert_eq(a.radius_at(1.0), b.radius_at(1.0), "same seed => same wobble")
```

- [ ] **Step 2: Create the class** — `scripts/terrain/water/PondStamp.gd`:

```gdscript
# scripts/terrain/water/PondStamp.gd
# One pond/pool: a wobbly-radius bowl carved into the heightfield with a
# storey-aligned water level. Terminal lakes, river source pools, and (future)
# standalone decorative ponds are all this one primitive. Pure record + pure
# math — deterministic per (center, radius, shape_seed, level, depth).
class_name PondStamp
extends RefCounted

const STOREY := 4.0
const WOBBLE := 0.3          # ±30% radial noise on the footprint boundary
const SURFACE_DROP := 1.0    # water sits this far below the bank storey top
const RIM_FEATHER := 0.35    # outer fraction of the footprint that eases to 0

var center: Vector2          # world XZ
var radius: float            # base radius, metres
var shape_seed: int
var level: int               # storey index of the banks; water just below
var depth: float             # bowl depth below level*STOREY


func _init(p_center: Vector2, p_radius: float, p_shape_seed: int, p_level: int, p_depth: float) -> void:
	center = p_center
	radius = p_radius
	shape_seed = p_shape_seed
	level = p_level
	depth = p_depth


## Wobbled boundary radius along direction `ang` (radians): 2- and 3-lobed
## low-frequency sin wobble so ponds read organic, not stamped circles.
func radius_at(ang: float) -> float:
	var a: float = Helper._hash01(Helper._mix64(shape_seed)) * TAU
	var b: float = Helper._hash01(Helper._mix64(shape_seed + 1)) * TAU
	return radius * (1.0 + WOBBLE * (0.6 * sin(2.0 * ang + a) + 0.4 * sin(3.0 * ang + b)))


## Everything the pond can touch lies within this radius (bucketing bound).
func bound_radius() -> float:
	return radius * (1.0 + WOBBLE)


## Normalized footprint coordinate: < 1 inside the wobbled boundary.
func footprint_t(p: Vector2) -> float:
	var d: Vector2 = p - center
	if d.length_squared() < 0.000001:
		return 0.0
	return d.length() / radius_at(atan2(d.y, d.x))


func surface_y() -> float:
	return float(level) * STOREY - SURFACE_DROP


func bed_y() -> float:
	return float(level) * STOREY - depth


## Metres to remove at world point p given the pre-carve ground height there.
## Full bowl in the core, smootherstep feather over the outer RIM_FEATHER of
## the footprint. Only ever lowers ground.
func carve_at(p: Vector2, ground_y: float) -> float:
	var t: float = footprint_t(p)
	if t >= 1.0:
		return 0.0
	var w: float = SlopeProfile.smootherstep(clampf((1.0 - t) / RIM_FEATHER, 0.0, 1.0))
	return maxf(0.0, (ground_y - bed_y()) * w)
```

- [ ] **Step 3: Register the new class, run tests**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_pond_stamp.gd -gexit
```
Expected: PASS (5/5).

- [ ] **Step 4: Commit**

```bash
git add scripts/terrain/water/PondStamp.gd tests/test_pond_stamp.gd
git commit -m "feat(water): PondStamp primitive — wobbly bowl, storey level, carve

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `RiverTrace` record + `WaterPlan` sources

**Files:**
- Create: `scripts/terrain/water/RiverTrace.gd`
- Create: `scripts/terrain/water/WaterPlan.gd` (sources only; tracing lands in Task 4)
- Test: `tests/test_water_plan.gd`

- [ ] **Step 1: Write the failing tests** — create `tests/test_water_plan.gd`:

```gdscript
extends GutTest

# ------------------------------------------------------------
# WaterPlan — deterministic river-network plan
# ------------------------------------------------------------

const SEED := 991177

func _plan() -> WaterPlan:
	return WaterPlan.new(SEED, 22.0, 8)

## Scan a super-cell window for cells that have a source. Returns Array[Vector2i].
func _sources_in(plan: WaterPlan, r: int) -> Array:
	var out: Array = []
	for sz in range(-r, r + 1):
		for sx in range(-r, r + 1):
			var sc: Vector2i = Vector2i(sx, sz)
			if plan.has_source(sc):
				out.append(sc)
	return out

func test_sources_deterministic_across_instances() -> void:
	var a: Array = _sources_in(_plan(), 6)
	var b: Array = _sources_in(_plan(), 6)
	assert_eq(a, b, "same seed => identical source set")
	assert_true(a.size() > 0, "a 13x13 super-cell window (10km) contains at least one source")

func test_sources_sit_on_high_smooth_ground() -> void:
	var plan: WaterPlan = _plan()
	for sc in _sources_in(plan, 6):
		var p: Vector2 = plan.source_pos(sc)
		assert_true(plan.smooth01(p) >= WaterPlan.SOURCE_MIN01,
			"source %s at %s is on high ground" % [sc, p])

func test_no_source_inside_spawn_ring() -> void:
	var plan: WaterPlan = _plan()
	for sc in _sources_in(plan, 6):
		assert_true(plan.source_pos(sc).length() >= WaterPlan.SPAWN_WATER_RADIUS,
			"sources keep out of the spawn disk")
```

- [ ] **Step 2: Create `RiverTrace`** — `scripts/terrain/water/RiverTrace.gd`:

```gdscript
# scripts/terrain/water/RiverTrace.gd
# One traced river: a polyline descending the smooth landform field from a
# mountain source. Parallel arrays per sample: points (world XZ), beds
# (monotone non-increasing water-bed height), widths (ribbon half-width,
# grows downstream). A river ends either by JOINING higher-priority water
# (joined = true, no pond) or with a terminal pond. source_pool always set.
class_name RiverTrace
extends RefCounted

var source_cell: Vector2i          # super-grid cell — identity
var priority: int                  # 64-bit hash; higher wins junctions
var points: PackedVector2Array = PackedVector2Array()
var beds: PackedFloat32Array = PackedFloat32Array()
var widths: PackedFloat32Array = PackedFloat32Array()
var joined: bool = false
var source_pool: PondStamp = null
var pond: PondStamp = null         # terminal pond; null when joined


## Conservative world-space AABB around everything this river touches.
func bounds() -> Rect2:
	var r: Rect2 = Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	if source_pool != null:
		r = r.merge(Rect2(source_pool.center - Vector2.ONE * source_pool.bound_radius(),
			Vector2.ONE * source_pool.bound_radius() * 2.0))
	if pond != null:
		r = r.merge(Rect2(pond.center - Vector2.ONE * pond.bound_radius(),
			Vector2.ONE * pond.bound_radius() * 2.0))
	return r
```

- [ ] **Step 3: Create `WaterPlan` with sources** — `scripts/terrain/water/WaterPlan.gd`:

```gdscript
# scripts/terrain/water/WaterPlan.gd
# Deterministic water-network plan: river sources on a coarse super-grid,
# traced downhill on the smooth landform field, always ending in water —
# a junction with a higher-priority river or a terminal pond. Pure function
# of (world_seed, super_cell) with bounded windows: the same anti-churn
# guarantee as HeightfieldPlan. Instance caches are performance only.
#
# Spec: docs/superpowers/specs/2026-07-04-water-rivers-lakes-design.md
class_name WaterPlan
extends RefCounted

const SUPER := 768.0              # source super-grid pitch (32 tiles)
const TILE := 24.0
const STOREY := 4.0

const SOURCE_MIN01 := 0.55        # smooth height01 floor for a source
const SOURCE_PROB := 0.6          # fraction of qualifying super-cells that fire
const TRACE_STEP := 12.0
const MAX_STEPS := 220            # hard bound => max length 2640 u
const MOMENTUM := 0.65
const MEANDER_AMP := 0.6          # radians of curve wobble (~35°)
const MEANDER_SCALE := 90.0       # along-arc metres per meander noise cell
const GRAD_EPS := 6.0             # finite-difference step for the gradient
const SENSE_RADIUS := 96.0        # junction steering bias range
const STEER := 0.35               # max blend toward sensed water
const W_MIN := 6.0                # ribbon half-width at the source
const W_MAX := 16.0               # ... at max length
const CHANNEL_DEPTH := 2.5        # bed below the smooth terrain
const FEATHER := 12.0             # carve lateral falloff beyond the width
const SOURCE_POOL_R := 36.0
const POOL_DEPTH := 2.5
const POND_R_MIN := 60.0
const POND_R_MAX := 140.0
const POND_DEPTH := 3.5
const FLAT_EPS := 0.012           # |grad| (m/m) below which a basin ends the trace
const LOWLANDS01 := 0.08          # smooth height01 floor => terminal pond
const SPAWN_WATER_RADIUS := 200.0 # dry spawn disk (spawn clear 60+120 + margin)
const JOIN_DEPTH := 2             # junction dependency recursion cap
# Any point a river can influence lies within MAX_STEPS*TRACE_STEP + the
# largest pond bound + carve feather of its source ⇒ a fixed super-cell ring.
const REACH := MAX_STEPS * TRACE_STEP + POND_R_MAX * (1.0 + PondStamp.WOBBLE) + FEATHER
const REACH_SUPERS := int(ceil(REACH / SUPER))   # = 4

var world_seed: int
var amplitude: float
var max_storeys: int

var _trace_cache: Dictionary = {}    # Vector3i(sc.x, sc.y, depth) -> RiverTrace | null


func _init(p_world_seed: int, p_amplitude: float, p_max_storeys: int) -> void:
	world_seed = p_world_seed
	amplitude = p_amplitude
	max_storeys = p_max_storeys


# ---------------------------------------------------------------
# Fields
# ---------------------------------------------------------------

## Smooth landform field in [0,1] at world XZ (no fine octave — see Task 1).
func smooth01(p: Vector2) -> float:
	return HeightfieldPlan.height01(Vector3(p.x, 0.0, p.y), world_seed, false)


## Smooth landform height in metres.
func smooth_h(p: Vector2) -> float:
	return smooth01(p) * amplitude


## Pre-carve rendered-field height in metres (WITH detail) — pond levels and
## carve amounts measure against the ground the terrain will actually build.
func noise_h(p: Vector2) -> float:
	return HeightfieldPlan.height01(Vector3(p.x, 0.0, p.y), world_seed, true) * amplitude


## Central-difference gradient of the smooth height (metres per metre).
func grad(p: Vector2) -> Vector2:
	return Vector2(
		smooth_h(p + Vector2(GRAD_EPS, 0.0)) - smooth_h(p - Vector2(GRAD_EPS, 0.0)),
		smooth_h(p + Vector2(0.0, GRAD_EPS)) - smooth_h(p - Vector2(0.0, GRAD_EPS))
	) / (2.0 * GRAD_EPS)


# ---------------------------------------------------------------
# Sources
# ---------------------------------------------------------------

func _hash_cell(sc: Vector2i, salt: int) -> int:
	return Helper._mix64(world_seed ^ Helper._mix64(sc.x ^ Helper._mix64(sc.y + salt)))


## 64-bit junction priority. Strict order (ties are astronomically unlikely);
## a river may only ever join a STRICTLY higher-priority river.
func priority_of(sc: Vector2i) -> int:
	return _hash_cell(sc, 0x51ED)


## Candidate source point, jittered inside the super-cell.
func source_pos(sc: Vector2i) -> Vector2:
	var jx: float = Helper._hash01(_hash_cell(sc, 101))
	var jz: float = Helper._hash01(_hash_cell(sc, 102))
	return Vector2((float(sc.x) + jx) * SUPER, (float(sc.y) + jz) * SUPER)


## Zero or one river source per super-cell: the jittered candidate must land
## on high smooth ground, outside the spawn ring, and win a density roll.
func has_source(sc: Vector2i) -> bool:
	var p: Vector2 = source_pos(sc)
	if p.length() < SPAWN_WATER_RADIUS:
		return false
	if smooth01(p) < SOURCE_MIN01:
		return false
	return Helper._hash01(_hash_cell(sc, 103)) < SOURCE_PROB
```

- [ ] **Step 4: Register classes, run tests**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_plan.gd -gexit
```
Expected: PASS (3/3). If `test_sources_deterministic_across_instances` fails on "at least one source", widen the scan radius in `_sources_in` to 8 — the assertion exists to catch a broken threshold, not to pin density.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/RiverTrace.gd scripts/terrain/water/WaterPlan.gd tests/test_water_plan.gd
git commit -m "feat(water): WaterPlan skeleton — super-grid river sources, RiverTrace record

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Downhill tracing with terminal ponds (no junctions yet)

**Files:**
- Modify: `scripts/terrain/water/WaterPlan.gd`
- Test: `tests/test_water_plan.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/test_water_plan.gd`:

```gdscript
# ------------------------------------------------------------
# Tracing — monotone beds, bounded length, guaranteed terminal water
# ------------------------------------------------------------

## First super-cell with a source, scanning outward — the shared test subject.
func _first_source(plan: WaterPlan) -> Vector2i:
	for r in range(0, 10):
		for sz in range(-r, r + 1):
			for sx in range(-r, r + 1):
				if maxi(absi(sx), absi(sz)) != r:
					continue
				if plan.has_source(Vector2i(sx, sz)):
					return Vector2i(sx, sz)
	assert_true(false, "no source found within 10 super-cell rings")
	return Vector2i.ZERO

func test_trace_is_deterministic_across_instances() -> void:
	var sc_a: Vector2i = _first_source(_plan())
	var a: RiverTrace = _plan().river_for(sc_a, 0)
	var b: RiverTrace = _plan().river_for(sc_a, 0)
	assert_eq(a.points, b.points, "identical polyline across instances")
	assert_eq(a.beds, b.beds, "identical beds across instances")

func test_trace_bed_is_monotone_nonincreasing() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	for i in range(1, t.beds.size()):
		assert_true(t.beds[i] <= t.beds[i - 1] + 0.0001,
			"bed never rises (i=%d: %f -> %f)" % [i, t.beds[i - 1], t.beds[i]])

func test_trace_is_bounded_and_ends_in_water() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	assert_true(t.points.size() >= 2, "trace has at least two samples")
	assert_true(t.points.size() <= WaterPlan.MAX_STEPS, "trace respects MAX_STEPS")
	assert_not_null(t.source_pool, "every river starts with a source pool")
	assert_true(t.joined or t.pond != null, "every river ends in water")

func test_trace_widths_grow_downstream() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	assert_true(t.widths[t.widths.size() - 1] >= t.widths[0],
		"ribbon widens downstream")

func test_pond_level_at_or_below_ring_minimum() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	if t.pond == null:
		pass_test("river joined; pond rule untestable on this seed cell")
		return
	var pond: PondStamp = t.pond
	var min_h: float = INF
	var r_cells: int = int(ceil((pond.bound_radius() + WaterPlan.TILE) / WaterPlan.TILE))
	var cc: Vector2i = Vector2i(roundi(pond.center.x / WaterPlan.TILE), roundi(pond.center.y / WaterPlan.TILE))
	for dz in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var p: Vector2 = Vector2(float(cc.x + dx) * WaterPlan.TILE, float(cc.y + dz) * WaterPlan.TILE)
			if pond.footprint_t(p) <= 1.0 + WaterPlan.TILE / pond.radius:
				min_h = minf(min_h, plan.noise_h(p))
	assert_true(float(pond.level) * 4.0 <= roundi(min_h / 4.0) * 4.0 + 0.0001,
		"pond bank storey never exceeds the footprint∪ring minimum")

func test_trace_never_enters_spawn_disk() -> void:
	var plan: WaterPlan = _plan()
	var t: RiverTrace = plan.river_for(_first_source(plan), 0)
	for p in t.points:
		assert_true(p.length() >= WaterPlan.SPAWN_WATER_RADIUS - 0.001,
			"polyline stays out of the spawn disk")
```

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_plan.gd -gexit`
Expected: FAIL — `river_for` not defined.

- [ ] **Step 3: Implement tracing** — append to `scripts/terrain/water/WaterPlan.gd`:

```gdscript
# ---------------------------------------------------------------
# Tracing
# ---------------------------------------------------------------

## The river for a source super-cell, resolved with `depth` levels of junction
## awareness (depth 0 = raw trace, no junctions — Task 5 wires depths > 0).
## Returns null when the super-cell has no source. Cached per (cell, depth).
func river_for(sc: Vector2i, depth: int = JOIN_DEPTH) -> RiverTrace:
	var key: Vector3i = Vector3i(sc.x, sc.y, depth)
	if _trace_cache.has(key):
		return _trace_cache[key]
	var t: RiverTrace = _trace(sc, depth)
	_trace_cache[key] = t
	return t


func _make_pool(p: Vector2) -> PondStamp:
	return PondStamp.new(p, SOURCE_POOL_R, _hash_cell(Vector2i(roundi(p.x), roundi(p.y)), 7),
		_pond_level(p, SOURCE_POOL_R), POOL_DEPTH)


func _make_pond(p: Vector2, arc: float) -> PondStamp:
	var r: float = lerpf(POND_R_MIN, POND_R_MAX, clampf(arc / (MAX_STEPS * TRACE_STEP), 0.0, 1.0))
	return PondStamp.new(p, r, _hash_cell(Vector2i(roundi(p.x), roundi(p.y)), 8),
		_pond_level(p, r), POND_DEPTH)


## Bank storey for a pond at p: storey-quantized minimum of the PRE-CARVE
## rendered field over the footprint ∪ one-tile ring. Endpoints already sit in
## local lows, so this is a safety clamp guaranteeing water below its banks.
## Floor of 1 keeps beds above y=0.
func _pond_level(center: Vector2, radius: float) -> int:
	var bound: float = radius * (1.0 + PondStamp.WOBBLE) + TILE
	var r_cells: int = int(ceil(bound / TILE))
	var cc: Vector2i = Vector2i(roundi(center.x / TILE), roundi(center.y / TILE))
	var min_h: float = INF
	for dz in range(-r_cells, r_cells + 1):
		for dx in range(-r_cells, r_cells + 1):
			var p: Vector2 = Vector2(float(cc.x + dx) * TILE, float(cc.y + dz) * TILE)
			if p.distance_to(center) <= bound:
				min_h = minf(min_h, noise_h(p))
	return clampi(roundi(min_h / STOREY), 1, max_storeys)


## One deterministic downhill trace. `depth` controls junction awareness:
## _neighbour_rivers returns [] at depth 0, so raw traces ignore other water.
func _trace(sc: Vector2i, depth: int) -> RiverTrace:
	if not has_source(sc):
		return null
	var t: RiverTrace = RiverTrace.new()
	t.source_cell = sc
	t.priority = priority_of(sc)
	var others: Array = _neighbour_rivers(sc, depth)
	var p: Vector2 = source_pos(sc)
	t.source_pool = _make_pool(p)
	var meander_offset: float = float(absi(t.priority) % 4096) * 37.0
	var dir: Vector2 = Vector2.from_angle(Helper._hash01(_hash_cell(sc, 104)) * TAU)
	var g0: Vector2 = grad(p)
	if g0.length() > 0.000001:
		dir = (-g0).normalized()
	var bed: float = smooth_h(p) - CHANNEL_DEPTH
	var arc: float = 0.0
	for i in MAX_STEPS:
		t.points.append(p)
		t.beds.append(bed)
		t.widths.append(lerpf(W_MIN, W_MAX, arc / (MAX_STEPS * TRACE_STEP)))
		if _join_test(p, bed, others):
			t.joined = true
			return t
		var g: Vector2 = grad(p)
		if i > 4 and g.length() < FLAT_EPS:
			break                                   # basin floor
		if smooth01(p) < LOWLANDS01:
			break                                   # reached the lowlands
		var down: Vector2 = (-g).normalized() if g.length() > 0.000001 else dir
		dir = (dir * MOMENTUM + down * (1.0 - MOMENTUM)).normalized()
		var m01: float = Helper._value_noise01(
			Vector3(arc, 0.0, meander_offset), world_seed + 71, MEANDER_SCALE)
		dir = dir.rotated((m01 - 0.5) * 2.0 * MEANDER_AMP)
		dir = _steer(dir, p, others)
		var q: Vector2 = p + dir * TRACE_STEP
		if q.length() < SPAWN_WATER_RADIUS:
			break                                   # truncate at the spawn ring
		p = q
		arc += TRACE_STEP
		bed = minf(bed, smooth_h(p) - CHANNEL_DEPTH)
	t.pond = _make_pond(p, arc)
	return t


## Higher-priority rivers within junction reach, resolved one depth lower.
## Depth 0 = raw trace: sees nothing. Task 5 fills this in; the stub keeps
## Task 4 green.
func _neighbour_rivers(_sc: Vector2i, _depth: int) -> Array:
	return []


## Does p (with bed height `bed`) touch higher-priority water it can join?
func _join_test(_p: Vector2, _bed: float, others: Array) -> bool:
	return false if others.is_empty() else _join_target(_p, _bed, others) != null


## Stub — implemented with junctions in Task 5.
func _join_target(_p: Vector2, _bed: float, _others: Array) -> RiverTrace:
	return null


## Steering bias toward nearby higher-priority water — stub until Task 5.
func _steer(dir: Vector2, _p: Vector2, _others: Array) -> Vector2:
	return dir
```

- [ ] **Step 4: Run to verify pass**

Run: the same command as Step 2.
Expected: PASS (all, including Task 3's).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterPlan.gd tests/test_water_plan.gd
git commit -m "feat(water): downhill river tracing — momentum+meander, monotone beds, terminal ponds

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Junctions — priority order, join termination, steering bias

**Files:**
- Modify: `scripts/terrain/water/WaterPlan.gd` (replace the three stubs)
- Test: `tests/test_water_plan.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/test_water_plan.gd`:

```gdscript
# ------------------------------------------------------------
# Junctions — strict priority, bounded depth, joins land in real water
# ------------------------------------------------------------

func _all_rivers(plan: WaterPlan, r: int) -> Array:
	var out: Array = []
	for sz in range(-r, r + 1):
		for sx in range(-r, r + 1):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null:
				out.append(t)
	return out

func test_full_depth_rivers_deterministic_across_instances() -> void:
	var a: Array = _all_rivers(_plan(), 4)
	var b: Array = _all_rivers(_plan(), 4)
	assert_eq(a.size(), b.size(), "same river count")
	for i in a.size():
		assert_eq(a[i].points, b[i].points, "river %d identical polyline" % i)
		assert_eq(a[i].joined, b[i].joined, "river %d identical join outcome" % i)

func test_joined_rivers_touch_higher_priority_water() -> void:
	var plan: WaterPlan = _plan()
	var rivers: Array = _all_rivers(plan, 4)
	var by_cell: Dictionary = {}
	for t in rivers:
		by_cell[t.source_cell] = t
	for t in rivers:
		if not t.joined:
			continue
		var tail: Vector2 = t.points[t.points.size() - 1]
		var found: bool = false
		for other in rivers:
			if other.priority <= t.priority:
				continue
			# tail must lie inside the other's channel or a pond footprint
			if other.source_pool != null and other.source_pool.footprint_t(tail) < 1.2:
				found = true
			if other.pond != null and other.pond.footprint_t(tail) < 1.2:
				found = true
			for i in other.points.size():
				if tail.distance_to(other.points[i]) <= other.widths[i] + WaterPlan.FEATHER:
					found = true
					break
			if found:
				break
		assert_true(found, "joined river %s tail sits in higher-priority water" % t.source_cell)

func test_every_river_still_ends_in_water_at_full_depth() -> void:
	for t in _all_rivers(_plan(), 4):
		assert_true(t.joined or t.pond != null, "river %s ends in water" % t.source_cell)
```

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_plan.gd -gexit`
Expected: `test_joined_rivers_touch_higher_priority_water` passes vacuously only if NO river joins; on most seeds at least one joins and the stubs make it FAIL. If all three pass because zero rivers join on this seed, still proceed — Step 3's implementation is what creates joins; re-run after.

- [ ] **Step 3: Replace the Task-4 stubs** (`_neighbour_rivers`, `_join_target`, `_join_test`, `_steer`) in `WaterPlan.gd`:

```gdscript
## Higher-priority rivers within junction reach of sc's river, each resolved
## one depth lower. Depth 0 = raw trace (sees nothing) — the recursion floor.
## Every trace is cached by (cell, depth), so the fan-out is bounded by the
## number of distinct super-cells within REACH_SUPERS rings per depth level.
func _neighbour_rivers(sc: Vector2i, depth: int) -> Array:
	if depth <= 0:
		return []
	var mine: int = priority_of(sc)
	var out: Array = []
	for dz in range(-REACH_SUPERS * 2, REACH_SUPERS * 2 + 1):
		for dx in range(-REACH_SUPERS * 2, REACH_SUPERS * 2 + 1):
			var nb: Vector2i = sc + Vector2i(dx, dz)
			if nb == sc or priority_of(nb) <= mine:
				continue
			var t: RiverTrace = river_for(nb, depth - 1)
			if t != null:
				out.append(t)
	return out


## The higher-priority river whose water p lands in, or null. A join needs
## the target's bed at the touch point to be at-or-below ours (+0.5 m slack)
## — water never joins uphill. Pond/pool footprints count as their river.
func _join_target(p: Vector2, bed: float, others: Array) -> RiverTrace:
	for other in others:
		if other.source_pool != null and other.source_pool.footprint_t(p) < 1.0 \
				and other.source_pool.surface_y() <= bed + 0.5:
			return other
		if other.pond != null and other.pond.footprint_t(p) < 1.0 \
				and other.pond.surface_y() <= bed + 0.5:
			return other
		for i in other.points.size():
			if p.distance_to(other.points[i]) <= other.widths[i] \
					and other.beds[i] <= bed + 0.5:
				return other
	return null


func _join_test(p: Vector2, bed: float, others: Array) -> bool:
	return _join_target(p, bed, others) != null


## Bend `dir` toward the nearest higher-priority water sample within
## SENSE_RADIUS, weighted by proximity — junctions become common instead of
## coincidental, per the spec's "bias the tracing so they end in other water".
func _steer(dir: Vector2, p: Vector2, others: Array) -> Vector2:
	var best_d: float = SENSE_RADIUS
	var best_at: Vector2 = Vector2.ZERO
	var found: bool = false
	for other in others:
		for i in other.points.size():
			var d: float = p.distance_to(other.points[i])
			if d < best_d:
				best_d = d
				best_at = other.points[i]
				found = true
	if not found:
		return dir
	var toward: Vector2 = (best_at - p).normalized()
	var w: float = STEER * (1.0 - best_d / SENSE_RADIUS)
	return (dir * (1.0 - w) + toward * w).normalized()
```

- [ ] **Step 4: Run to verify pass**

Run: the same command as Step 2.
Expected: PASS (all tests in the file, including Tasks 3–4). This is the slowest test file (traces a 9×9 super-cell window at depth 2); expect a few seconds, not minutes — if it hangs, the `_neighbour_rivers` cache key is wrong.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterPlan.gd tests/test_water_plan.gd
git commit -m "feat(water): junctions — strict priority order, join termination, steering bias

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Carve field + `bodies_near`

**Files:**
- Modify: `scripts/terrain/water/WaterPlan.gd`
- Test: `tests/test_water_plan.gd` (append)

- [ ] **Step 1: Write the failing tests** — append to `tests/test_water_plan.gd`:

```gdscript
# ------------------------------------------------------------
# Carve field — window-independent, spawn-dry, lowers toward beds
# ------------------------------------------------------------

func test_carve_zero_in_spawn_disk() -> void:
	var plan: WaterPlan = _plan()
	for cell in [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-5, 5)]:
		assert_eq(plan.carve_at_cell(cell.x, cell.y), 0.0, "spawn cell %s dry" % cell)

func test_carve_positive_under_a_terminal_pond() -> void:
	var plan: WaterPlan = _plan()
	var pond: PondStamp = null
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.pond != null:
				pond = t.pond
				break
		if pond != null:
			break
	assert_not_null(pond, "window contains a terminal pond")
	var cx: int = roundi(pond.center.x / WaterPlan.TILE)
	var cz: int = roundi(pond.center.y / WaterPlan.TILE)
	var carve: float = plan.carve_at_cell(cx, cz)
	var ground: float = plan.noise_h(Vector2(cx * WaterPlan.TILE, cz * WaterPlan.TILE))
	assert_almost_eq(ground - carve, pond.bed_y(), 0.5,
		"pond centre cell is carved to the bowl bed")

func test_carve_identical_across_instances_and_query_order() -> void:
	var a: WaterPlan = _plan()
	var b: WaterPlan = _plan()
	# Prime b with a far-away query first — result must not depend on history.
	b.carve_at_cell(400, 400)
	var cells: Array = [Vector2i(40, -60), Vector2i(-33, 21), Vector2i(90, 88)]
	for c in cells:
		assert_almost_eq(a.carve_at_cell(c.x, c.y), b.carve_at_cell(c.x, c.y), 0.0001,
			"carve at %s is a pure function of (seed, cell)" % c)

func test_bodies_near_finds_the_water_that_carved() -> void:
	var plan: WaterPlan = _plan()
	# Find a carved cell by scanning a band away from spawn.
	var hit: Vector2i = Vector2i.MAX
	for cz in range(20, 120):
		for cx in range(20, 120):
			if plan.carve_at_cell(cx, cz) > 0.5:
				hit = Vector2i(cx, cz)
				break
		if hit != Vector2i.MAX:
			break
	assert_true(hit != Vector2i.MAX, "found a carved cell in the scan band")
	var bodies: Dictionary = plan.bodies_near(hit, 2)
	assert_true(bodies.ponds.size() + bodies.rivers.size() > 0,
		"bodies_near sees the water that carved cell %s" % hit)
```

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_plan.gd -gexit`
Expected: FAIL — `carve_at_cell` / `bodies_near` not defined.

- [ ] **Step 3: Implement** — append to `WaterPlan.gd`:

```gdscript
# ---------------------------------------------------------------
# Carve field (hot path: called for every cell of every region window)
# ---------------------------------------------------------------

var _region_cache: Dictionary = {}   # Vector2i super_cell -> {"rivers": Array, "buckets": Dictionary}

## Rivers (full depth) whose bounds overlap super-cell `rc`, plus a bucket
## index: tile cell -> Array of [RiverTrace, sample_index] for fast carve
## lookups. Built lazily once per super-cell per session.
func _region_for(rc: Vector2i) -> Dictionary:
	if _region_cache.has(rc):
		return _region_cache[rc]
	var region_rect: Rect2 = Rect2(
		Vector2(float(rc.x), float(rc.y)) * SUPER, Vector2(SUPER, SUPER)).grow(FEATHER + W_MAX)
	var rivers: Array = []
	var buckets: Dictionary = {}
	# +1 ring: a source within REACH of a cell inside this super-cell can sit
	# up to REACH + SUPER·√2 from the super-cell's own corner.
	for dz in range(-(REACH_SUPERS + 1), REACH_SUPERS + 2):
		for dx in range(-(REACH_SUPERS + 1), REACH_SUPERS + 2):
			var t: RiverTrace = river_for(rc + Vector2i(dx, dz))
			if t == null or not t.bounds().grow(FEATHER).intersects(region_rect):
				continue
			rivers.append(t)
			for i in t.points.size():
				var infl: float = t.widths[i] + FEATHER
				var lo_x: int = int(floor((t.points[i].x - infl) / TILE + 0.5))
				var hi_x: int = int(floor((t.points[i].x + infl) / TILE + 0.5))
				var lo_z: int = int(floor((t.points[i].y - infl) / TILE + 0.5))
				var hi_z: int = int(floor((t.points[i].y + infl) / TILE + 0.5))
				for bz in range(lo_z, hi_z + 1):
					for bx in range(lo_x, hi_x + 1):
						var key: Vector2i = Vector2i(bx, bz)
						if not buckets.has(key):
							buckets[key] = []
						buckets[key].append([t, i])
	var out: Dictionary = {"rivers": rivers, "buckets": buckets}
	_region_cache[rc] = out
	return out


## Metres to subtract from the raw noise height at tile cell (cx, cz).
## Max over every pond bowl and channel sample that reaches the cell — pure
## function of (world_seed, cell); the caches never change the value.
func carve_at_cell(cx: int, cz: int) -> float:
	var p: Vector2 = Vector2(float(cx) * TILE, float(cz) * TILE)
	if p.length() < SPAWN_WATER_RADIUS:
		return 0.0
	var rc: Vector2i = Vector2i(int(floor(p.x / SUPER)), int(floor(p.y / SUPER)))
	var region: Dictionary = _region_for(rc)
	var ground: float = noise_h(p)
	var best: float = 0.0
	for t in region.rivers:
		if t.source_pool != null:
			best = maxf(best, t.source_pool.carve_at(p, ground))
		if t.pond != null:
			best = maxf(best, t.pond.carve_at(p, ground))
	var key: Vector2i = Vector2i(cx, cz)
	if region.buckets.has(key):
		for entry in region.buckets[key]:
			var t: RiverTrace = entry[0]
			var i: int = entry[1]
			var d: float = p.distance_to(t.points[i])
			var infl: float = t.widths[i] + FEATHER
			if d >= infl:
				continue
			# Full carve to the bed inside the width; smootherstep feather out.
			var w: float = SlopeProfile.smootherstep(clampf((infl - d) / FEATHER, 0.0, 1.0))
			best = maxf(best, maxf(0.0, ground - t.beds[i]) * w)
	return best


## Water bodies overlapping a cell window (for surface meshing + volumes).
## Returns {"ponds": Array[PondStamp], "rivers": Array[RiverTrace]} — rivers
## come whole (the builder clips); ponds include source pools.
func bodies_near(center_cell: Vector2i, radius_cells: int) -> Dictionary:
	var world_r: float = float(radius_cells + 1) * TILE
	var centre: Vector2 = Vector2(float(center_cell.x), float(center_cell.y)) * TILE
	var window: Rect2 = Rect2(centre - Vector2.ONE * world_r, Vector2.ONE * world_r * 2.0)
	var rc: Vector2i = Vector2i(int(floor(centre.x / SUPER)), int(floor(centre.y / SUPER)))
	var ponds: Array = []
	var rivers: Array = []
	for t in _region_for(rc).rivers:
		var touches: bool = t.bounds().grow(FEATHER).intersects(window)
		if not touches:
			continue
		rivers.append(t)
		if t.source_pool != null:
			ponds.append(t.source_pool)
		if t.pond != null:
			ponds.append(t.pond)
	return {"ponds": ponds, "rivers": rivers}
```

Note: `_region_for` keys the region by the QUERY cell's super-cell but scans `REACH_SUPERS` rings of sources, and each river carries its full geometry — a cell near a super-cell border still sees rivers from the neighbouring region because reach covers them. `bodies_near` windows are chunk-sized (radius ≤ 9 cells = 216 u < SUPER), so a single region lookup plus its reach ring covers any window... **except** a window straddling a super-cell border could sit in the corner where a river from `rc + (REACH_SUPERS+1)` rings just barely overlaps. `REACH` already includes the pond bound + feather margin, so no body can extend past it — the ring math is airtight as long as `bodies_near` windows stay ≤ SUPER; assert it:

```gdscript
	assert(world_r * 2.0 <= SUPER, "bodies_near window exceeds one super-cell — widen REACH_SUPERS math first")
```
(place the assert at the top of `bodies_near`).

- [ ] **Step 4: Run to verify pass**

Run: the same command as Step 2.
Expected: PASS (whole file).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/water/WaterPlan.gd tests/test_water_plan.gd
git commit -m "feat(water): carve field with segment buckets + bodies_near query

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Hook the carve into `HeightfieldPlan` + streamer

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldPlan.gd:60-64` (`raw_height`)
- Modify: `scripts/terrain/field/FieldTerrainStreamer.gd:35-45` (`_ready`)
- Test: `tests/test_heightfield_plan.gd` (append)

- [ ] **Step 1: Write the failing test** — append to `tests/test_heightfield_plan.gd`:

```gdscript
# ------------------------------------------------------------
# Water carve hook
# ------------------------------------------------------------

func test_water_plan_carve_lowers_raw_height() -> void:
	var dry: HeightfieldPlan = HeightfieldPlan.new(991177, 22.0, 8)
	var wet: HeightfieldPlan = HeightfieldPlan.new(991177, 22.0, 8)
	wet.set_water_plan(WaterPlan.new(991177, 22.0, 8))
	# Find a carved cell (same scan band as the WaterPlan tests).
	var water: WaterPlan = WaterPlan.new(991177, 22.0, 8)
	var hit: Vector2i = Vector2i.MAX
	for cz in range(20, 120):
		for cx in range(20, 120):
			if water.carve_at_cell(cx, cz) > 0.5:
				hit = Vector2i(cx, cz)
				break
		if hit != Vector2i.MAX:
			break
	assert_true(hit != Vector2i.MAX, "seed has a carved cell in the scan band")
	assert_true(wet.raw_height(hit.x, hit.y) < dry.raw_height(hit.x, hit.y) - 0.4,
		"carve lowers the raw field where water lives")
	assert_almost_eq(wet.raw_height(0, 0), dry.raw_height(0, 0), 0.0001,
		"spawn cell untouched")
```

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_plan.gd -gexit`
Expected: FAIL — `set_water_plan` not defined.

- [ ] **Step 3: Implement the hook.** In `HeightfieldPlan.gd`, below `_raw_override`:

```gdscript
# Optional water carve (untyped to avoid a WaterPlan<->HeightfieldPlan
# class-resolution cycle; duck-typed: needs carve_at_cell(cx, cz) -> float).
var _water_plan = null


## Attach the water network: raw_height subtracts its carve BEFORE storey
## quantization, so banks/cliffs/slopes around water come from the existing
## clamp + surface-field machinery with no downstream changes.
func set_water_plan(p_water_plan) -> void:
	_water_plan = p_water_plan
```

Replace `raw_height`:

```gdscript
## Continuous height (metres) at a tile cell, after the water carve.
func raw_height(cx: int, cz: int) -> float:
	var h: float
	if _raw_override.is_valid():
		h = _raw_override.call(cx, cz)
	else:
		var pos: Vector3 = Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
		h = _height01(pos) * height_amplitude
	if _water_plan != null:
		h -= _water_plan.carve_at_cell(cx, cz)
	return h
```

In `FieldTerrainStreamer.gd` `_ready`, after `_plan = HeightfieldPlan.new(...)`:

```gdscript
	_plan.set_water_plan(WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS))
```

- [ ] **Step 4: Run to verify pass, plus the untouched-suite check**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heightfield_plan.gd -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_terrain_surface_field.gd -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_field_streamer.gd -gexit
```
Expected: PASS. Plans without `set_water_plan` behave exactly as before (all existing tests run dry).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/heightfield/HeightfieldPlan.gd scripts/terrain/field/FieldTerrainStreamer.gd tests/test_heightfield_plan.gd
git commit -m "feat(water): subtract water carve in raw_height; streamer wires WaterPlan

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Shared water shader family

No unit tests — shader compilation is verified by the import step and Task 11's in-game pass. Keep the existing `Water.gdshader` untouched (old scenes may still reference it); the new family lives beside it.

**Files:**
- Create: `terrain/water/water_common.gdshaderinc`
- Create: `terrain/water/water_pond.gdshader`
- Create: `terrain/water/water_river.gdshader`

- [ ] **Step 1: Create `terrain/water/water_common.gdshaderinc`:**

```glsl
// Shared stylized-water building blocks (ponds + rivers). Extracted from
// Water.gdshader so both surfaces keep one visual language: rolling world-
// space waves, vertical-depth tinting, animated shore foam.

// Long-wavelength swells: two crossing directional waves plus a broad noise
// drift. Pure function of world position — seamless across chunk meshes.
float water_wave_h(sampler2D noise_tex, vec2 p, float t) {
	float h = sin(p.x * 0.11 + t * 0.9) * cos(p.y * 0.085 + t * 0.66);
	h += 0.7 * sin(dot(p, vec2(0.071, 0.052)) - t * 1.05);
	h += 1.0 * (textureLod(noise_tex, p * 0.0045 + vec2(t * 0.006, -t * 0.0045), 0.0).r - 0.5);
	return h;
}

// VERTICAL water depth at this fragment: reconstruct the opaque scene point
// behind it and measure how far below the (displaced) water surface it sits.
float water_depth_world(sampler2D depth_tex, vec2 screen_uv, mat4 inv_projection, mat4 inv_view, float surface_world_y) {
	float depth_raw = texture(depth_tex, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth_raw);
	vec4 scene_view = inv_projection * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	vec4 scene_world = inv_view * vec4(scene_view.xyz, 1.0);
	return max(surface_world_y - scene_world.y, 0.0);
}

// Animated lapping shore-foam mask from vertical depth.
float water_foam_mask(sampler2D noise_tex, vec2 world_xz, float t, float depth, float foam_width) {
	float foam_noise = texture(noise_tex, world_xz * 0.11 + vec2(t * 0.03, -t * 0.022)).r;
	float foam_edge = foam_width * (0.5 + 0.7 * foam_noise);
	float mask = 1.0 - smoothstep(foam_edge * 0.55, foam_edge, depth);
	return mask * (0.8 + 0.2 * sin(t * 1.9 + foam_noise * 6.0));
}
```

- [ ] **Step 2: Create `terrain/water/water_pond.gdshader`** (the current look, on static per-chunk meshes):

```glsl
// Still water for ponds/lakes: per-chunk flat sheets at each pond's storey-
// aligned level. Same visual family as rivers via water_common.gdshaderinc.
// cull_disabled: the player swims and looks up at the surface from below.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"

uniform vec3 color_deep : source_color = vec3(0.12, 0.45, 0.55);
uniform vec3 color_shallow : source_color = vec3(0.32, 0.66, 0.69);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float foam_width : hint_range(0.0, 3.0) = 0.7;
uniform float depth_fade : hint_range(0.5, 8.0) = 1.8;
uniform float wave_height : hint_range(0.0, 0.6) = 0.17;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = water_wave_h(noise_tex, world_pos.xz, t);
	VERTEX.y += h * wave_height;
	world_pos.y += h * wave_height;
	float e = 2.0;
	float hx = water_wave_h(noise_tex, world_pos.xz + vec2(e, 0.0), t);
	float hz = water_wave_h(noise_tex, world_pos.xz + vec2(0.0, e), t);
	NORMAL = normalize(vec3((h - hx) * wave_height / e, 1.0, (h - hz) * wave_height / e));
}

void fragment() {
	float t = TIME * wave_speed;
	float depth = water_depth_world(depth_texture, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	float depth_t = clamp(depth / depth_fade, 0.0, 1.0);
	vec3 base = mix(color_shallow, color_deep, depth_t);
	float foam = clamp(water_foam_mask(noise_tex, world_pos.xz, t, depth, foam_width), 0.0, 1.0);
	ALBEDO = mix(base, foam_color, foam);
	ALPHA = max(mix(0.6, 0.9, depth_t), foam * 0.95);
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = 0.7;
}
```

- [ ] **Step 3: Create `terrain/water/water_river.gdshader`:**

```glsl
// Flowing water for river ribbons. Flow direction comes from the mesh: the
// builder writes the downstream tangent into CUSTOM0.xyz and the local
// steepness into CUSTOM0.w — no baked flow maps (the waterways-net idea,
// GDScript pipeline). Dual-phase scrolling hides the texture reset; steep
// reaches whiten into rapids foam.
// cull_disabled: the player swims and looks up at the surface from below.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_disabled;

#include "res://terrain/water/water_common.gdshaderinc"

uniform vec3 color_deep : source_color = vec3(0.12, 0.45, 0.55);
uniform vec3 color_shallow : source_color = vec3(0.32, 0.66, 0.69);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float foam_width : hint_range(0.0, 3.0) = 0.7;
uniform float depth_fade : hint_range(0.5, 8.0) = 1.8;
uniform float wave_height : hint_range(0.0, 0.6) = 0.06;   // rivers barely swell
uniform float wave_speed : hint_range(0.0, 4.0) = 0.8;
uniform float flow_speed : hint_range(0.0, 12.0) = 3.0;    // metres/second scroll
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;
varying vec3 flow_dir;     // downstream, world space, unit XZ
varying float steepness;   // 0 calm .. 1 waterfall-ish

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow_dir = CUSTOM0.xyz;
	steepness = CUSTOM0.w;
	float t = TIME * wave_speed;
	float h = water_wave_h(noise_tex, world_pos.xz, t);
	VERTEX.y += h * wave_height;
	world_pos.y += h * wave_height;
}

void fragment() {
	float t = TIME * wave_speed;
	// Dual-phase flow scroll: two copies of the noise slide downstream half a
	// period apart; a triangle-wave blend swaps them before either visibly
	// resets. Classic no-flow-map river trick.
	vec2 fl = flow_dir.xz * flow_speed;
	float ph = fract(TIME * 0.5);
	vec2 uv = world_pos.xz * 0.09;
	float n1 = texture(noise_tex, uv - fl * ph * 0.09).r;
	float n2 = texture(noise_tex, uv - fl * (ph - 0.5) * 0.09).r;
	float stream = mix(n1, n2, abs(ph * 2.0 - 1.0));
	// Streak the normal along the flow so highlights read as moving water.
	vec3 n = normalize(vec3((stream - 0.5) * 0.35 * flow_dir.x, 1.0, (stream - 0.5) * 0.35 * flow_dir.z));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	float depth = water_depth_world(depth_texture, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, world_pos.y);
	float depth_t = clamp(depth / depth_fade, 0.0, 1.0);
	vec3 base = mix(color_shallow, color_deep, depth_t);
	float foam = water_foam_mask(noise_tex, world_pos.xz, t, depth, foam_width);
	// Rapids: steep reaches churn white, scrolled by the same stream noise.
	foam += steepness * (0.55 + 0.45 * stream);
	foam = clamp(foam, 0.0, 1.0);
	ALBEDO = mix(base, foam_color, foam);
	ALPHA = max(mix(0.65, 0.9, depth_t), foam * 0.95);
	ROUGHNESS = mix(roughness, 0.5, foam);
	SPECULAR = 0.7;
}
```

- [ ] **Step 4: Verify the shaders compile**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | grep -i "shader\|error" | head -20
```
Expected: no shader errors in the output (the import registers the three files; any parse error prints here).

- [ ] **Step 5: Commit**

```bash
git add terrain/water/water_common.gdshaderinc terrain/water/water_pond.gdshader terrain/water/water_river.gdshader
git commit -m "feat(water): shared shader family — pond + flowing river (no baked flow maps)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: `WaterSurfaceBuilder` — chunk meshes + swim volumes

**Files:**
- Create: `scripts/terrain/water/WaterSurfaceBuilder.gd`
- Modify: `scripts/terrain/field/FieldTerrainStreamer.gd:48-54` (`_ensure_chunk`)
- Test: `tests/test_water_surface_builder.gd`

- [ ] **Step 1: Write the failing tests** — create `tests/test_water_surface_builder.gd`:

```gdscript
extends GutTest

# ------------------------------------------------------------
# WaterSurfaceBuilder — ribbon profile math + chunk node assembly
# ------------------------------------------------------------

const SEED := 991177

func _water() -> WaterPlan:
	return WaterPlan.new(SEED, 22.0, 8)

func _a_river(plan: WaterPlan) -> RiverTrace:
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.points.size() > 10:
				return t
	assert_true(false, "no river with >10 samples in the window")
	return null

func test_surface_profile_monotone_and_above_bed() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(river)
	assert_eq(prof.size(), river.points.size(), "one surface sample per polyline sample")
	for i in prof.size():
		assert_true(prof[i] >= river.beds[i] + 0.1,
			"surface stays above the bed (i=%d)" % i)
	for i in range(1, prof.size()):
		assert_true(prof[i] <= prof[i - 1] + 0.0001,
			"surface never flows uphill (i=%d)" % i)

func test_surface_profile_ends_at_terminal_pond_level() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = null
	for sz in range(-4, 5):
		for sx in range(-4, 5):
			var t: RiverTrace = plan.river_for(Vector2i(sx, sz))
			if t != null and t.pond != null and t.points.size() > 10:
				river = t
				break
		if river != null:
			break
	if river == null:
		pass_test("no ponded river in window on this seed")
		return
	var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(river)
	assert_almost_eq(prof[prof.size() - 1], river.pond.surface_y(), 0.6,
		"backwater reach flattens into the pond")

func test_build_chunk_makes_meshes_and_swim_volumes() -> void:
	var plan: WaterPlan = _water()
	var river: RiverTrace = _a_river(plan)
	var mid: Vector2 = river.points[river.points.size() / 2]
	var chunk: Vector2i = Vector2i(int(floor(mid.x / 192.0)), int(floor(mid.y / 192.0)))
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(plan, chunk)
	assert_not_null(node, "chunk containing a river builds a water node")
	var meshes: int = 0
	var areas: int = 0
	for c in node.get_children():
		if c is MeshInstance3D:
			meshes += 1
		if c is Area3D:
			areas += 1
			assert_true(c.has_meta("surface_y"), "swim volume carries surface_y")
			assert_eq(c.collision_layer, 1 << 7, "swim volume on the water layer")
	assert_true(meshes > 0, "water meshes present")
	assert_true(areas > 0, "swim volumes present")
	node.free()

func test_build_chunk_returns_null_when_dry() -> void:
	var plan: WaterPlan = _water()
	# Scan for a chunk whose window has no bodies (seed-independent), then
	# assert the builder agrees. (The spawn chunk's corners poke past the dry
	# radius, so it is NOT guaranteed dry — don't hardcode it.)
	var dry: Vector2i = Vector2i.MAX
	for cz in range(0, 40):
		for cx in range(0, 40):
			var b: Dictionary = plan.bodies_near(Vector2i(cx * 8 + 4, cz * 8 + 4), 5)
			if b.ponds.is_empty() and b.rivers.is_empty():
				dry = Vector2i(cx, cz)
				break
		if dry != Vector2i.MAX:
			break
	assert_true(dry != Vector2i.MAX, "found a dry chunk in the scan band")
	assert_null(WaterSurfaceBuilder.new().build_chunk(plan, dry), "dry chunk => no node")
```

- [ ] **Step 2: Run to verify failure**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_surface_builder.gd -gexit`
Expected: FAIL — `WaterSurfaceBuilder` unknown.

- [ ] **Step 3: Create `scripts/terrain/water/WaterSurfaceBuilder.gd`:**

```gdscript
# scripts/terrain/water/WaterSurfaceBuilder.gd
# Per-chunk water: pond quad sheets at storey-aligned levels, river ribbon
# meshes following the monotone surface profile, and Area3D swim volumes.
# Built beside each terrain chunk and parented under it, so streaming
# eviction frees water with the ground it belongs to.
class_name WaterSurfaceBuilder
extends RefCounted

const TILE := 24.0
const CELLS_PER_CHUNK := 8            # = TerrainChunkMesher.CELLS_PER_CHUNK
const CHUNK_WORLD := TILE * CELLS_PER_CHUNK
const RIBBON_DEPTH_OFFSET := 1.5      # river surface above its carved bed
const STEEP_RISE := 2.0               # bed drop per sample that reads as rapids=1
const VOLUME_STRIDE := 4              # river swim-box every N samples
const WATER_LAYER := 1 << 7

static var _pond_material: ShaderMaterial = null
static var _river_material: ShaderMaterial = null


## Water surface height per polyline sample: bed + offset, flattened into the
## terminal pond (backwater) and made monotone by a single backward pass —
## walking upstream, the surface may only rise. Pure function of the trace.
static func surface_profile(river: RiverTrace) -> PackedFloat32Array:
	var n: int = river.points.size()
	var prof: PackedFloat32Array = PackedFloat32Array()
	prof.resize(n)
	for i in n:
		prof[i] = river.beds[i] + RIBBON_DEPTH_OFFSET
	if river.pond != null:
		prof[n - 1] = maxf(river.pond.surface_y(), river.beds[n - 1] + 0.2)
	for i in range(n - 2, -1, -1):
		prof[i] = maxf(prof[i], prof[i + 1])
	return prof


## 0 (calm) .. 1 (waterfall) steepness per sample, from the bed's local drop.
static func steepness_profile(river: RiverTrace) -> PackedFloat32Array:
	var n: int = river.points.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var a: int = maxi(i - 1, 0)
		var b: int = mini(i + 1, n - 1)
		var drop: float = river.beds[a] - river.beds[b]
		out[i] = clampf(drop / (STEEP_RISE * float(b - a if b > a else 1)), 0.0, 1.0)
	return out


static func _material(shader_path: String) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(shader_path)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.008
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	mat.set_shader_parameter("noise_tex", tex)
	return mat


static func pond_material() -> ShaderMaterial:
	if _pond_material == null:
		_pond_material = _material("res://terrain/water/water_pond.gdshader")
	return _pond_material


static func river_material() -> ShaderMaterial:
	if _river_material == null:
		_river_material = _material("res://terrain/water/water_river.gdshader")
	return _river_material


## Build the water node for a chunk, or null when the chunk is dry.
func build_chunk(water: WaterPlan, chunk: Vector2i) -> Node3D:
	var centre_cx: int = chunk.x * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var centre_cz: int = chunk.y * CELLS_PER_CHUNK + CELLS_PER_CHUNK / 2
	var bodies: Dictionary = water.bodies_near(Vector2i(centre_cx, centre_cz), CELLS_PER_CHUNK / 2 + 1)
	if bodies.ponds.is_empty() and bodies.rivers.is_empty():
		return null
	var chunk_rect: Rect2 = Rect2(
		Vector2(float(chunk.x), float(chunk.y)) * CHUNK_WORLD, Vector2(CHUNK_WORLD, CHUNK_WORLD))
	var root: Node3D = Node3D.new()
	root.name = "Water"
	var any: bool = false
	any = _build_ponds(water, bodies.ponds, chunk_rect, root) or any
	any = _build_rivers(water, bodies.rivers, chunk_rect, root) or any
	if not any:
		root.free()
		return null
	return root


# --- ponds ------------------------------------------------------

## Two upward-facing triangles for quad a-b-c-d (corners in walk order:
## (x0,z0) → (x0+T,z0) → (x0+T,z0+T) → (x0,z0+T)). Winding chosen so
## generate_normals() yields +Y.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(d)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


func _build_ponds(water: WaterPlan, ponds: Array, chunk_rect: Rect2, root: Node3D) -> bool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads: int = 0
	var done: Dictionary = {}
	for pond in ponds:
		if done.has(pond):
			continue
		done[pond] = true
		var cells: Array = []
		var lo_cx: int = int(floor(chunk_rect.position.x / TILE + 0.5))
		var lo_cz: int = int(floor(chunk_rect.position.y / TILE + 0.5))
		for dz in CELLS_PER_CHUNK:
			for dx in CELLS_PER_CHUNK:
				var cx: int = lo_cx + dx
				var cz: int = lo_cz + dz
				var p: Vector2 = Vector2(float(cx) * TILE, float(cz) * TILE)
				if pond.footprint_t(p) >= 1.0:
					continue
				# Islands: skip cells whose carved ground still clears the surface.
				var ground: float = water.noise_h(p) - water.carve_at_cell(cx, cz)
				if ground >= pond.surface_y() - 0.25:
					continue
				cells.append(Vector2i(cx, cz))
		for c in cells:
			var x0: float = float(c.x) * TILE - TILE * 0.5
			var z0: float = float(c.y) * TILE - TILE * 0.5
			var y: float = pond.surface_y()
			_quad(st, Vector3(x0, y, z0), Vector3(x0 + TILE, y, z0),
				Vector3(x0 + TILE, y, z0 + TILE), Vector3(x0, y, z0 + TILE))
			quads += 1
		if not cells.is_empty():
			_pond_volume(pond, cells, root)
	if quads == 0:
		return false
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "PondSheet"
	mi.mesh = st.commit()
	mi.material_override = WaterSurfaceBuilder.pond_material()
	root.add_child(mi)
	return true


func _pond_volume(pond: PondStamp, cells: Array, root: Node3D) -> void:
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var area: Area3D = Area3D.new()
	area.name = "PondVolume"
	area.collision_layer = WATER_LAYER
	area.collision_mask = 0
	area.monitoring = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	var span: Vector2 = Vector2(float(hi.x - lo.x + 1), float(hi.y - lo.y + 1)) * TILE
	var height: float = pond.surface_y() - pond.bed_y() + 1.0
	box.size = Vector3(span.x, height, span.y)
	shape.shape = box
	area.add_child(shape)
	area.position = Vector3(
		(float(lo.x) + float(hi.x)) * 0.5 * TILE,
		pond.surface_y() - height * 0.5,
		(float(lo.y) + float(hi.y)) * 0.5 * TILE)
	area.set_meta("surface_y", pond.surface_y())
	root.add_child(area)


# --- rivers -----------------------------------------------------

func _build_rivers(water: WaterPlan, rivers: Array, chunk_rect: Rect2, root: Node3D) -> bool:
	var grown: Rect2 = chunk_rect.grow(TILE)
	var built: bool = false
	for river in rivers:
		var prof: PackedFloat32Array = WaterSurfaceBuilder.surface_profile(river)
		var steep: PackedFloat32Array = WaterSurfaceBuilder.steepness_profile(river)
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		var strip: int = 0
		for i in range(0, river.points.size() - 1):
			# Keep segments overlapping the grown chunk (1 tile skirt kills seams).
			if not (grown.has_point(river.points[i]) or grown.has_point(river.points[i + 1])):
				continue
			_ribbon_quad(st, river, prof, steep, i)
			strip += 1
		if strip == 0:
			continue
		st.generate_normals()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "River_%d_%d" % [river.source_cell.x, river.source_cell.y]
		mi.mesh = st.commit()
		mi.material_override = WaterSurfaceBuilder.river_material()
		root.add_child(mi)
		_river_volumes(river, prof, grown, root)
		built = true
	return built


func _ribbon_quad(st: SurfaceTool, river: RiverTrace, prof: PackedFloat32Array,
		steep: PackedFloat32Array, i: int) -> void:
	var a: Vector2 = river.points[i]
	var b: Vector2 = river.points[i + 1]
	var tan2: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-tan2.y, tan2.x)
	var la: Vector2 = a + perp * river.widths[i]
	var ra: Vector2 = a - perp * river.widths[i]
	var lb: Vector2 = b + perp * river.widths[i + 1]
	var rb: Vector2 = b - perp * river.widths[i + 1]
	var ya: float = prof[i]
	var yb: float = prof[i + 1]
	var ca: Color = Color(tan2.x, 0.0, tan2.y, steep[i])
	var cb: Color = Color(tan2.x, 0.0, tan2.y, steep[i + 1])
	# two triangles, wound so generate_normals() yields +Y (la is LEFT of flow)
	for v in [[la, ya, ca], [rb, yb, cb], [ra, ya, ca], [la, ya, ca], [lb, yb, cb], [rb, yb, cb]]:
		st.set_custom(0, v[2])
		st.set_uv(Vector2(0.0, float(i)))
		st.add_vertex(Vector3(v[0].x, v[1], v[0].y))


func _river_volumes(river: RiverTrace, prof: PackedFloat32Array, grown: Rect2, root: Node3D) -> void:
	var i: int = 0
	while i < river.points.size() - 1:
		var j: int = mini(i + VOLUME_STRIDE, river.points.size() - 1)
		var a: Vector2 = river.points[i]
		var b: Vector2 = river.points[j]
		if grown.has_point(a) or grown.has_point(b):
			var area: Area3D = Area3D.new()
			area.name = "RiverVolume"
			area.collision_layer = WATER_LAYER
			area.collision_mask = 0
			area.monitoring = false
			var shape: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			var depth: float = prof[i] - river.beds[i] + 1.0
			box.size = Vector3(a.distance_to(b) + 2.0, depth, river.widths[i] * 2.0 + 4.0)
			shape.shape = box
			area.add_child(shape)
			var mid: Vector2 = (a + b) * 0.5
			area.position = Vector3(mid.x, prof[i] - depth * 0.5, mid.y)
			var ang: float = atan2(b.x - a.x, b.y - a.y)
			area.rotation = Vector3(0.0, ang - PI * 0.5, 0.0)
			area.set_meta("surface_y", maxf(prof[i], prof[j]))
			var flow: Vector2 = (b - a).normalized()
			area.set_meta("flow", Vector3(flow.x, 0.0, flow.y))
			root.add_child(area)
		i = j
	# (Area boxes overlap slightly and hug the profile coarsely — swimming
	# tolerance, not rendering. VOLUME_STRIDE=4 => one box per 48 u.)
```

- [ ] **Step 4: Wire the streamer** — in `FieldTerrainStreamer.gd`, add a field and extend `_ensure_chunk`:

```gdscript
var _water: WaterPlan
var _water_builder := WaterSurfaceBuilder.new()
```

In `_ready`, keep Task 7's line but capture the instance:

```gdscript
	_water = WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE, HEIGHTFIELD_MAX_STOREYS)
	_plan.set_water_plan(_water)
```

In `_ensure_chunk`, after `terrain_parent.add_child(node)`:

```gdscript
	var wnode := _water_builder.build_chunk(_water, c)
	if wnode != null:
		node.add_child(wnode)
```

- [ ] **Step 5: Register classes, run tests**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_water_surface_builder.gd -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_field_streamer.gd -gexit
```
Expected: PASS both files.

- [ ] **Step 6: Commit**

```bash
git add scripts/terrain/water/WaterSurfaceBuilder.gd scripts/terrain/field/FieldTerrainStreamer.gd tests/test_water_surface_builder.gd
git commit -m "feat(water): per-chunk pond sheets, river ribbons, swim volumes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Per-volume swim surface in `character.gd`

**Files:**
- Modify: `characters/character.gd:21-31, 134-176`

No new unit test — the swim system has no test harness (scene-dependent physics); Task 11 verifies in-game. Keep the change minimal and mechanical.

- [ ] **Step 1: Track the surface height of the volume the character is in.** Replace the constant comment block and `_update_in_water`:

```gdscript
const WATER_LAYER_MASK: int = 1 << 7
# Fallback surface for legacy water volumes that carry no surface_y meta
# (the old flat-sheet water). Field-terrain volumes always set the meta.
const WATER_SURFACE_Y: float = -1.5
var water_surface_y: float = WATER_SURFACE_Y
```

```gdscript
# The probe sits at knee height: standing on a dry bank keeps it above the
# water volume, while floating at the surface keeps it inside. The overlapped
# volume's surface_y meta (per-body water level) drives buoyancy.
func _update_in_water() -> void:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = global_position + Vector3(0.0, 0.3, 0.0)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = WATER_LAYER_MASK
	var hits: Array = get_world_3d().direct_space_state.intersect_point(params, 4)
	in_water = not hits.is_empty()
	if in_water:
		var best: float = -INF
		for h in hits:
			var collider: Object = h.get("collider")
			if collider != null and collider.has_meta("surface_y"):
				best = maxf(best, float(collider.get_meta("surface_y")))
		water_surface_y = best if best > -INF else WATER_SURFACE_Y
```

- [ ] **Step 2: Use it.** In `_swim_vertical`, replace `WATER_SURFACE_Y` with `water_surface_y`:

```gdscript
	var submerged: float = clampf(
		(water_surface_y - global_position.y) / BODY_HEIGHT, 0.0, 1.0
	)
```

In `_try_water_exit`, replace the depth check:

```gdscript
	if global_position.y < water_surface_y - BODY_HEIGHT:
		return false
```

- [ ] **Step 3: Sanity-run an unrelated suite to catch parse errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | grep -i "error" | head
```
Expected: no script errors.

- [ ] **Step 4: Commit**

```bash
git add characters/character.gd
git commit -m "feat(water): swim buoyancy reads per-volume surface_y (legacy fallback kept)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: Retire the global sheet + in-game verification

**Files:**
- Modify: `scenes/world.tscn` (remove the `WaterSurface` node + its ext_resource)
- Modify: `scripts/terrain/field/FieldTerrainStreamer.gd` (seed override for repro)

- [ ] **Step 1: Seed override for reproducible verification** — in `FieldTerrainStreamer.gd`:

```gdscript
## 0 = random each run. Set non-zero to pin the world for debugging (pairs
## with the F3 coord overlay screenshot workflow).
@export var SEED_OVERRIDE: int = 0
```

and in `_ready`: `world_seed = SEED_OVERRIDE if SEED_OVERRIDE != 0 else randi()`

- [ ] **Step 2: Remove the global water sheet from `scenes/world.tscn`.** Delete these two lines (line numbers as of this writing — re-grep before editing):

- Line 6: `[ext_resource type="PackedScene" path="res://terrain/water/WaterSurface.tscn" id="5_water"]`
- Line 57: `[node name="WaterSurface" parent="." instance=ExtResource("5_water")]`

Then decrement the `load_steps` count in the `[gd_scene ...]` header at line 1 by 1 (Godot recalculates on save, but keep the file consistent for review).

- [ ] **Step 3: Full-suite regression**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://tests/gutconfig.json -gexit
```
Expected: all green except the known pre-existing failure in `test_heightfield_interior_corners.gd` (baseline — see memory). If the full suite truncates/crashes (known flake around the heightfield tests), fall back to isolated per-file runs of: `test_heightfield_plan`, `test_pond_stamp`, `test_water_plan`, `test_water_surface_builder`, `test_terrain_surface_field`, `test_terrain_chunk_mesher`, `test_field_streamer`, `test_cliff_dressing`.

- [ ] **Step 4: In-game verification (godot MCP).** Launch with `mcp__godot__run_project`, then:

1. Set `SEED_OVERRIDE` to a seed whose water is known from the tests (e.g. 991177) so findings are reproducible.
2. Use `WaterPlan` from a debug print (or the test scan band) to get a river's world coords; teleport the character near them (`mcp__godot__game_set_property` on the character's `global_position`).
3. Screenshot checklist (`mcp__godot__game_screenshot`):
   - River channel reads as a carved valley; banks are ordinary terrain slopes/cliffs (KayKit-dressed, no floating lips).
   - Ribbon water flows visibly downstream; no z-fighting with pond sheets at the mouth; foam at banks.
   - Terminal pond sits below its banks all the way around (walk the shoreline).
   - A steep reach shows whitened rapids; note the worst bed-poke-through, tune `RIBBON_DEPTH_OFFSET` (builder) / `CHANNEL_DEPTH` (plan) if ground pierces the ribbon.
   - Spawn area bone dry.
4. Swim test: walk into a pond — buoyancy at the pond's own level (not −1.5); jump-exit at a bank; enter the river and confirm the same.
5. File anything structural (seams, holes, dressing conflicts) as follow-ups rather than tuning blind.

- [ ] **Step 5: Commit**

```bash
git add scenes/world.tscn scripts/terrain/field/FieldTerrainStreamer.gd
git commit -m "feat(water): retire global water sheet; pinned-seed verification pass

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Performance notes (for the implementer)

- `carve_at_cell` is called for every cell of every `compute_region` window (~67×67 per chunk). The segment buckets make each call O(nearby samples); `_region_for` builds them once per super-cell per session. If chunk builds stutter, profile before optimizing — the noise field, not the carve, has historically dominated.
- Full-depth river resolution fans out as (cells within reach)² across depth levels, but every `(cell, depth)` trace is cached; the steady-state cost of entering new territory is a handful of fresh raw traces (≈220 noise samples each).
- If `test_water_plan.gd` runs longer than ~30 s, something defeats the trace cache (typically a mutated cache key type).

## Deviations & judgment calls

Document any deviation from this plan in the final report. Known soft spots the implementer may legitimately tune (values only, not structure): all `WaterPlan` constants, `RIBBON_DEPTH_OFFSET`, `STEEP_RISE`, foam/flow shader uniforms.
