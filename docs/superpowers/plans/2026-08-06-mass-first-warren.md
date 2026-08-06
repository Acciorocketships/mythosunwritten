# Mass-First Warren Towns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Invert warren-town generation so a tall terraced solid massif comes first and the public route is excavated negative space — paths bounded by buildings by construction — behind a `mass_first` mode flag, with a mesh-overlap audit as a new acceptance gate.

**Architecture:** Three new solver stages (WarrenMassifBuilder → WarrenExcavationCarver → WarrenSolidPartitioner) produce a `WarrenVolumePlan`-compatible output that flows into the *unchanged* fabric construction/asset layers. A `WarrenMeshOverlapAudit` checks built plans for coplanar z-fighting and shell interpenetration. `WarrenTownSolver.GENERATION_MODE` selects `route_first` (default, current behaviour) or `mass_first`.

**Tech Stack:** Godot 4.5.1 GDScript (typed, tabs, `class_name` RefCounted statics), GUT tests via `Godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`.

## Global Constraints

- Cell lattice: `FabricRecipe.CELL_SIZE = 1.5` m horizontal; vertical bands 1.5 m; storeys = 2 bands (from spec §"1.5m lattice").
- Determinism: no `Date.now()`/randf; all randomness via integer hash of `world_seed` (existing carver/envelope idiom). Identical inputs must produce identical plans.
- New `class_name` scripts must be registered before GUT runs pick them up (run any Godot command once to refresh `.godot/global_script_class_cache.cfg`; see memory note "Godot GUT test workflow").
- Never call RenderingServer read-back on worker/headless probe paths (memory: "terrain worker: no RenderingServer").
- Massif gates (spec §3): core height ≥ 16 bands, ≥ 5 distinct terrace levels, no plateau wider than 6 cells.
- Excavation gates (spec §3): route 22–26 cells, vertical span ≥ 8 bands, covered ratio 0.55–0.70, portals 1–2.
- Overlap audit tolerances (spec §3): coplanar 0.02 m, interpenetration 0.10 m, junction bites exempt.
- Mode default stays `route_first` until mass-first corpus hits: acceptance ≥ 6/12, median span ≥ 8 bands, covered ratio 0.45–0.70, warren battery green, overlap audit clean (spec §5).
- Commits: one per green task step-5; message style `feat(villages): …`; end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; never `git add -A`.

---

### Task 1: WarrenMassif + WarrenMassifBuilder

**Files:**
- Create: `scripts/terrain/features/villages/fabric/WarrenMassif.gd`
- Create: `scripts/terrain/features/villages/fabric/WarrenMassifBuilder.gd`
- Test: `tests/test_warren_massif.gd`

**Interfaces:**
- Consumes: nothing new (hash idiom copied from `WarrenVolumeEnvelope`).
- Produces: `WarrenMassif` with `columns: Dictionary` (`Vector2i -> {"base": int, "top": int, "terrace": int}`), `core_top_bands: int`, `terrace_levels() -> Array[int]`, `top_at(column: Vector2i) -> int`, `base_at(column: Vector2i) -> int`, `has_column(column) -> bool`, `is_sealed() -> bool`, `widest_plateau_cells() -> int`; `WarrenMassifBuilder.build(world_seed: int, ground_bands: Dictionary = {}) -> WarrenMassif` (null on gate failure), `WarrenMassifBuilder.last_failure: String`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## The massif is the primary object of the mass-first pipeline: a tall,
## terraced, deterministic solid. These tests pin its hard gates.


func test_massif_builds_tall_terraced_and_deterministic() -> void:
	var a := WarrenMassifBuilder.build(1)
	var b := WarrenMassifBuilder.build(1)
	assert_not_null(a, WarrenMassifBuilder.last_failure)
	assert_true(a.is_sealed())
	assert_gte(a.core_top_bands, 16,
		"core must reach 16 bands so excavation has vertical room")
	assert_gte(a.terrace_levels().size(), 5,
		"a smooth dome is not a terraced town silhouette")
	assert_lte(a.widest_plateau_cells(), 6,
		"wide flat plateaus read as empty platforms, not terraces")
	assert_eq(a.columns.size(), b.columns.size())
	for column: Vector2i in a.columns:
		assert_eq(a.top_at(column), b.top_at(column),
			"same seed must give identical column heights")


func test_massif_seeds_differ_and_respect_ground_bands() -> void:
	var flat := WarrenMassifBuilder.build(2)
	var raised_bands: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			raised_bands[Vector2i(x, z)] = 2
	var raised := WarrenMassifBuilder.build(2, raised_bands)
	assert_not_null(flat, WarrenMassifBuilder.last_failure)
	assert_not_null(raised, WarrenMassifBuilder.last_failure)
	var differing := 0
	var other := WarrenMassifBuilder.build(3)
	for column: Vector2i in flat.columns:
		if other.has_column(column) \
				and flat.top_at(column) != other.top_at(column):
			differing += 1
	assert_gt(differing, 10, "different seeds must differ meaningfully")
	for column: Vector2i in raised.columns:
		assert_gte(raised.base_at(column), 2,
			"terrain ground bands lift the massif base")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_massif.gd -gexit 2>&1 | tail -20`
Expected: parse/identifier failure on `WarrenMassifBuilder` (class does not exist yet).

- [ ] **Step 3: Write minimal implementation**

`WarrenMassif.gd` — data + queries only:

```gdscript
class_name WarrenMassif
extends RefCounted

## Terraced solid city mass: per-column occupiable band interval. The public
## realm is carved FROM this object; it never grows to meet a route.

var world_seed: int
var columns: Dictionary = {}
var core_top_bands: int = 0
var _sealed := false


func _init(p_world_seed: int) -> void:
	world_seed = p_world_seed


func seal() -> bool:
	if columns.is_empty():
		return false
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func has_column(column: Vector2i) -> bool:
	return columns.has(column)


func top_at(column: Vector2i) -> int:
	return int((columns.get(column, {}) as Dictionary).get("top", 0))


func base_at(column: Vector2i) -> int:
	return int((columns.get(column, {}) as Dictionary).get("base", 0))


func terrace_levels() -> Array[int]:
	var seen: Dictionary = {}
	for column: Vector2i in columns:
		seen[top_at(column)] = true
	var out: Array[int] = []
	out.assign(seen.keys())
	out.sort()
	return out


func widest_plateau_cells() -> int:
	## Largest 4-connected component sharing one top band.
	var visited: Dictionary = {}
	var widest := 0
	for start_value: Variant in columns.keys():
		var start := start_value as Vector2i
		if visited.has(start):
			continue
		var level := top_at(start)
		var frontier: Array[Vector2i] = [start]
		var count := 0
		visited[start] = true
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			count += 1
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbor := cell + direction
				if visited.has(neighbor) or not columns.has(neighbor) \
						or top_at(neighbor) != level:
					continue
				visited[neighbor] = true
				frontier.append(neighbor)
		widest = maxi(widest, count)
	return widest
```

`WarrenMassifBuilder.gd` — deterministic terraced Gaussian:

```gdscript
class_name WarrenMassifBuilder
extends RefCounted

## Builds the terraced solid massif. Heights come from a warped Gaussian
## quantised into 1-2 band terrace risers, with radial spur/notch warping so
## silhouettes vary per seed. Gates reject domes, low cores, and plateaus.
const RADIUS_CELLS := 12
const MIN_CORE_BANDS := 16
const MAX_CORE_BANDS := 20
const MIN_TERRACE_LEVELS := 5
const MAX_PLATEAU_CELLS := 6
const MIN_COLUMN_BANDS := 2

static var last_failure := ""


static func build(world_seed: int,
		ground_bands: Dictionary = {}) -> WarrenMassif:
	last_failure = ""
	var massif := WarrenMassif.new(world_seed)
	var core := MIN_CORE_BANDS + posmod(_hash(world_seed, 5, 0, 0),
		MAX_CORE_BANDS - MIN_CORE_BANDS + 1)
	var warp_phase := float(posmod(_hash(world_seed, 7, 0, 0), 1000)) \
		/ 1000.0 * TAU
	var warp_strength := 0.22 + float(posmod(_hash(world_seed, 11, 0, 0),
		100)) / 100.0 * 0.18
	for z in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
		for x in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
			var column := Vector2i(x, z)
			var radius := Vector2(float(x), float(z)).length()
			var angle := atan2(float(z), float(x))
			var warped := radius * (1.0 + warp_strength \
				* sin(angle * 3.0 + warp_phase))
			var gaussian := exp(-pow(warped / float(RADIUS_CELLS) * 1.9,
				2.0))
			var raw := float(core) * gaussian
			var jitter := posmod(_hash(world_seed, 13, x, z), 3) - 1
			var terrace := _quantise_terrace(raw, world_seed, x, z) + jitter
			if terrace < MIN_COLUMN_BANDS:
				continue
			var base := int(ground_bands.get(column, 0))
			massif.columns[column] = {
				"base": base,
				"top": base + terrace,
				"terrace": terrace,
			}
	massif.core_top_bands = 0
	for column: Vector2i in massif.columns:
		massif.core_top_bands = maxi(massif.core_top_bands,
			massif.top_at(column) - massif.base_at(column))
	if massif.core_top_bands < MIN_CORE_BANDS:
		last_failure = "core reaches %d bands; %d required" % [
			massif.core_top_bands, MIN_CORE_BANDS]
		return null
	if massif.terrace_levels().size() < MIN_TERRACE_LEVELS:
		last_failure = "only %d terrace levels" \
			% massif.terrace_levels().size()
		return null
	if massif.widest_plateau_cells() > MAX_PLATEAU_CELLS:
		last_failure = "plateau of %d cells exceeds %d" % [
			massif.widest_plateau_cells(), MAX_PLATEAU_CELLS]
		return null
	if not massif.seal():
		last_failure = "empty massif"
		return null
	return massif


static func _quantise_terrace(raw_bands: float, world_seed: int, x: int,
		z: int) -> int:
	## Snap to 1-2 band risers; the riser rhythm itself is seed-varied so
	## terraces do not repeat one global step size.
	var riser := 1 + posmod(_hash(world_seed, 17, x / 4, z / 4), 2)
	return int(floorf(raw_bands / float(riser))) * riser


static func _hash(world_seed: int, salt: int, x: int, z: int) -> int:
	var value := world_seed * 73856093 ^ salt * 19349663 \
		^ x * 83492791 ^ z * 2971215073
	value = posmod(value, 2147483647)
	return value
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_massif.gd -gexit 2>&1 | tail -5`
Expected: `Passing Tests 2`. If gates fail for seeds 1–3, tune `warp_strength`/`jitter` until the probe seeds pass — the gates are the spec; the noise constants are free.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenMassif.gd scripts/terrain/features/villages/fabric/WarrenMassifBuilder.gd tests/test_warren_massif.gd
git commit -m "feat(villages): terraced massif builder for mass-first warrens"
```

---

### Task 2: WarrenExcavation + WarrenExcavationCarver

**Files:**
- Create: `scripts/terrain/features/villages/fabric/WarrenExcavation.gd`
- Create: `scripts/terrain/features/villages/fabric/WarrenExcavationCarver.gd`
- Test: `tests/test_warren_excavation.gd`

**Interfaces:**
- Consumes: `WarrenMassif` (Task 1): `has_column`, `top_at`, `base_at`, `columns`.
- Produces: `WarrenExcavation` with `route: Array[Vector3i]` (walk cells, y = band of the floor), `carved: Dictionary` (`Vector3i -> true`, all removed cells incl. headroom), `covered: Dictionary` (`Vector3i(walk cell) -> bool` — true when mass remains overhead), `transitions: Array[Dictionary]` (`{"from": Vector3i, "to": Vector3i, "kind": int}` using `WarrenVolumeTransition.Kind`), `portals: Array[Vector3i]`, `covered_ratio() -> float`, `route_span_bands() -> int`, `is_sealed() -> bool`; `WarrenExcavationCarver.carve(world_seed: int, massif: WarrenMassif) -> WarrenExcavation` (null + `last_failure` on gate failure).

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## Excavation gates operate on negative space: the bored route must climb,
## stay mostly covered, and never open a cavern or a through-sightline.

const PROBE_SEEDS := [1, 2, 6]


func _carved(world_seed: int) -> WarrenExcavation:
	var massif := WarrenMassifBuilder.build(world_seed)
	if massif == null:
		return null
	return WarrenExcavationCarver.carve(world_seed, massif)


func test_probe_seeds_carve_climbing_covered_routes() -> void:
	var accepted := 0
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		accepted += 1
		assert_true(excavation.is_sealed())
		assert_between(excavation.route.size(), 22, 26,
			"route length family (seed %d)" % world_seed)
		assert_gte(excavation.route_span_bands(), 8,
			"the route must genuinely climb (seed %d)" % world_seed)
		assert_between(excavation.covered_ratio(), 0.55, 0.70,
			"most of the route tunnels under mass (seed %d)" % world_seed)
		assert_between(excavation.portals.size(), 1, 2,
			"portals (seed %d)" % world_seed)
	assert_gt(accepted, 0, "no probe seed carved a route: %s" \
		% WarrenExcavationCarver.last_failure)


func test_every_route_cell_is_bounded_by_mass_or_declared_open() -> void:
	for world_seed: int in PROBE_SEEDS:
		var excavation := _carved(world_seed)
		if excavation == null:
			continue
		var massif := WarrenMassifBuilder.build(world_seed)
		for cell: Vector3i in excavation.route:
			var flanked := 0
			for direction: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT,
					Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var side := cell + direction
				var column := Vector2i(side.x, side.z)
				var solid_beside := massif.has_column(column) \
					and massif.top_at(column) > cell.y \
					and not excavation.carved.has(side)
				flanked += int(solid_beside)
			assert_gte(flanked, 1,
				("route cell %s (seed %d) floats beside no remaining " \
				+ "mass; excavated streets are canyons, not causeways") \
				% [cell, world_seed])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_excavation.gd -gexit 2>&1 | tail -20`
Expected: identifier failure on `WarrenExcavationCarver`.

- [ ] **Step 3: Write minimal implementation**

`WarrenExcavation.gd`:

```gdscript
class_name WarrenExcavation
extends RefCounted

## The carved negative space: route walk cells, all removed cells, cover
## flags, transition specs, and portals. Pure data + derived metrics.

var world_seed: int
var route: Array[Vector3i] = []
var carved: Dictionary = {}
var covered: Dictionary = {}
var transitions: Array[Dictionary] = []
var portals: Array[Vector3i] = []
var _sealed := false


func _init(p_world_seed: int) -> void:
	world_seed = p_world_seed


func seal() -> bool:
	if route.size() < 2 or carved.is_empty() or portals.is_empty():
		return false
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func covered_ratio() -> float:
	if route.is_empty():
		return 0.0
	var count := 0
	for cell: Vector3i in route:
		count += int(bool(covered.get(cell, false)))
	return float(count) / float(route.size())


func route_span_bands() -> int:
	var low := 1 << 30
	var high := -(1 << 30)
	for cell: Vector3i in route:
		low = mini(low, cell.y)
		high = maxi(high, cell.y)
	return high - low
```

`WarrenExcavationCarver.gd` — greedy deterministic borer (same attempt-corpus idiom as the old carver):

```gdscript
class_name WarrenExcavationCarver
extends RefCounted

## Bores a climbing, mostly covered route through a WarrenMassif. Moves are
## scored, not random: inward+upward ambition, cover preference, straight-run
## and cavern penalties. Bounded attempts; best sealed survivor wins.
const HEADROOM_BANDS := 3
const MIN_ROUTE_CELLS := 22
const MAX_ROUTE_CELLS := 26
const MIN_SPAN_BANDS := 8
const MIN_COVERED_RATIO := 0.55
const MAX_COVERED_RATIO := 0.70
const ATTEMPTS := 96
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]

static var last_failure := ""


static func carve(world_seed: int, massif: WarrenMassif) -> WarrenExcavation:
	last_failure = "no attempt sealed"
	if massif == null or not massif.is_sealed():
		last_failure = "massif missing or unsealed"
		return null
	var best: WarrenExcavation = null
	var best_score := INF
	for attempt in ATTEMPTS:
		var candidate := _bore(world_seed, attempt, massif)
		if candidate == null:
			continue
		var score := _score(candidate)
		if best == null or score < best_score:
			best = candidate
			best_score = score
	return best


static func _bore(world_seed: int, attempt: int,
		massif: WarrenMassif) -> WarrenExcavation:
	var portal := _portal(world_seed, attempt, massif)
	if portal == Vector3i(0, -1, 0):
		return null
	var excavation := WarrenExcavation.new(world_seed)
	excavation.portals.append(portal)
	var target := MIN_ROUTE_CELLS + posmod(
		_hash(world_seed, attempt, 3, 0), MAX_ROUTE_CELLS - MIN_ROUTE_CELLS + 1)
	var current := portal
	var direction := Vector2i.ZERO
	_carve_cell(excavation, massif, current)
	for step in range(1, target):
		var moves := _candidate_moves(world_seed, attempt, step, current,
			direction, massif, excavation)
		if moves.is_empty():
			break
		moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.score) < float(b.score))
		var selected := moves[0]
		var destination := selected.destination as Vector3i
		if destination.y != current.y:
			excavation.transitions.append({"from": current,
				"to": destination,
				"kind": WarrenVolumeTransition.Kind.STAIR})
		direction = selected.direction as Vector2i
		current = destination
		_carve_cell(excavation, massif, current)
	if excavation.route.size() < MIN_ROUTE_CELLS \
			or excavation.route_span_bands() < MIN_SPAN_BANDS \
			or excavation.covered_ratio() < MIN_COVERED_RATIO \
			or excavation.covered_ratio() > MAX_COVERED_RATIO:
		return null
	return excavation if excavation.seal() else null


static func _carve_cell(excavation: WarrenExcavation, massif: WarrenMassif,
		cell: Vector3i) -> void:
	excavation.route.append(cell)
	var column := Vector2i(cell.x, cell.z)
	var column_top := massif.top_at(column)
	for band in range(cell.y, cell.y + HEADROOM_BANDS):
		excavation.carved[Vector3i(cell.x, band, cell.z)] = true
	excavation.covered[cell] = column_top > cell.y + HEADROOM_BANDS


static func _portal(world_seed: int, attempt: int,
		massif: WarrenMassif) -> Vector3i:
	## Boundary column whose base can host a ground-level entry.
	var boundary: Array[Vector3i] = []
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		var exposed := false
		for direction: Vector2i in DIRECTIONS:
			if not massif.has_column(column + direction):
				exposed = true
		if exposed:
			boundary.append(Vector3i(column.x, massif.base_at(column),
				column.y))
	if boundary.is_empty():
		return Vector3i(0, -1, 0)
	boundary.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return String(var_to_str(a)) < String(var_to_str(b)))
	return boundary[posmod(_hash(world_seed, attempt, 1, 0),
		boundary.size())]


static func _candidate_moves(world_seed: int, attempt: int, step: int,
		current: Vector3i, current_direction: Vector2i,
		massif: WarrenMassif, excavation: WarrenExcavation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for direction_index in DIRECTIONS.size():
		var direction := DIRECTIONS[direction_index]
		for rise in [0, 1, -1]:
			var destination := current + Vector3i(direction.x, rise,
				direction.y)
			var column := Vector2i(destination.x, destination.z)
			if not massif.has_column(column):
				continue
			if destination.y < massif.base_at(column) \
					or destination.y + 1 >= massif.top_at(column):
				continue
			if excavation.carved.has(destination):
				continue
			out.append({
				"destination": destination,
				"direction": direction,
				"score": _move_score(world_seed, attempt, step, current,
					destination, direction, current_direction, massif,
					excavation, direction_index),
			})
	return out


static func _move_score(world_seed: int, attempt: int, step: int,
		current: Vector3i, destination: Vector3i, direction: Vector2i,
		current_direction: Vector2i, massif: WarrenMassif,
		excavation: WarrenExcavation, direction_index: int) -> float:
	var column := Vector2i(destination.x, destination.z)
	var depth_below_top := massif.top_at(column) - destination.y
	var score := 0.0
	score -= float(destination.y - current.y) * 260.0
	score -= float(clampi(depth_below_top - HEADROOM_BANDS, 0, 6)) * 55.0
	score += 180.0 if direction == -current_direction else 0.0
	score += 90.0 if direction == current_direction else 0.0
	var tie := posmod(_hash(world_seed, attempt,
		step * 31 + direction_index, destination.y), 997)
	return score + float(tie) * 0.05


static func _score(excavation: WarrenExcavation) -> float:
	return -float(excavation.route_span_bands()) * 100.0 \
		- excavation.covered_ratio() * 400.0 \
		+ float(excavation.route.size())


static func _hash(world_seed: int, attempt: int, a: int, b: int) -> int:
	var value := world_seed * 73856093 ^ attempt * 50331653 \
		^ a * 83492791 ^ b * 19349663
	return posmod(value, 2147483647)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_excavation.gd -gexit 2>&1 | tail -5`
Expected: `Passing Tests 2`. Score weights (260/55/180/90) are free variables; the gates are not. Tune weights until ≥1 probe seed passes all gates.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenExcavation.gd scripts/terrain/features/villages/fabric/WarrenExcavationCarver.gd tests/test_warren_excavation.gd
git commit -m "feat(villages): excavation carver bores covered climbing routes"
```

---

### Task 3: Excavation → WarrenVolumePlan adapter

**Files:**
- Create: `scripts/terrain/features/villages/fabric/WarrenExcavationVolumeAdapter.gd`
- Test: `tests/test_warren_excavation_adapter.gd`

**Interfaces:**
- Consumes: `WarrenExcavation` (Task 2), `WarrenMassif` (Task 1); existing `WarrenVolumePlan` (`_init(stable_id: StringName, world_seed: int, envelope: WarrenVolumeEnvelope)`, `add_walk_cell(cell) -> bool`, `add_transition(WarrenVolumeTransition) -> bool`, `seal(entry_cell)` — copy exact seal signature from `WarrenVolumePlan.gd` when implementing), existing `WarrenVolumeEnvelope.build(world_seed, ground_bands)`.
- Produces: `WarrenExcavationVolumeAdapter.to_volume_plan(massif: WarrenMassif, excavation: WarrenExcavation) -> WarrenVolumePlan` — a sealed plan whose envelope is synthesised from the massif (`WarrenExcavationVolumeAdapter.envelope_from_massif(massif) -> WarrenVolumeEnvelope`).

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## The adapter is the seam between the new mass-first stages and the whole
## existing parcel/fabric machine: its output must satisfy the same sealed
## WarrenVolumePlan contract the route-first carver produces.


func test_adapter_produces_sealed_volume_plan() -> void:
	var massif := WarrenMassifBuilder.build(1)
	assert_not_null(massif, WarrenMassifBuilder.last_failure)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	assert_not_null(excavation, WarrenExcavationCarver.last_failure)
	var plan := WarrenExcavationVolumeAdapter.to_volume_plan(massif,
		excavation)
	assert_not_null(plan,
		"adapter failed: %s" % WarrenExcavationVolumeAdapter.last_failure)
	assert_true(plan.is_sealed(), plan.last_rejection)
	assert_eq(plan.primary_itinerary.size(), excavation.route.size())
	assert_gt(plan.transitions.size(), 0)
	var envelope := plan.envelope
	for cell: Vector3i in excavation.route:
		assert_true(envelope.has_column(Vector2i(cell.x, cell.z)),
			"every route column exists in the synthesised envelope")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_excavation_adapter.gd -gexit 2>&1 | tail -20`
Expected: identifier failure on `WarrenExcavationVolumeAdapter`.

- [ ] **Step 3: Write minimal implementation**

Before writing: `Read scripts/terrain/features/villages/fabric/WarrenVolumePlan.gd` and `WarrenVolumeEnvelope.gd` fully — mirror the exact seal contract (entry cell, walk air, transition validation). Skeleton:

```gdscript
class_name WarrenExcavationVolumeAdapter
extends RefCounted

## Adapts the excavated negative space into the sealed WarrenVolumePlan the
## downstream parcel/asset stages already consume. The synthesised envelope
## reports massif heights so frontage/height logic sees the terraced mass.

static var last_failure := ""


static func envelope_from_massif(massif: WarrenMassif) -> WarrenVolumeEnvelope:
	## WarrenVolumeEnvelope exposes build(seed, ground_bands) plus height
	## queries. Synthesise by constructing directly: copy massif column tops
	## into height_bands and ground bands into its ground map, then seal via
	## the same method build() uses (read WarrenVolumeEnvelope.gd and reuse
	## its constructor path; do NOT re-run its Gaussian).
	var envelope := WarrenVolumeEnvelope.new()
	envelope.max_height_bands = massif.core_top_bands
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		envelope.height_bands[column] = massif.top_at(column) \
			- massif.base_at(column)
	return envelope if envelope.seal_synthesised(massif) else null


static func to_volume_plan(massif: WarrenMassif,
		excavation: WarrenExcavation) -> WarrenVolumePlan:
	last_failure = ""
	var envelope := envelope_from_massif(massif)
	if envelope == null:
		last_failure = "synthesised envelope failed to seal"
		return null
	var plan := WarrenVolumePlan.new(
		StringName("warren.volume.mass.%d" % excavation.world_seed),
		excavation.world_seed, envelope)
	for cell: Vector3i in excavation.route:
		if not plan.add_walk_cell(cell):
			last_failure = "duplicate walk cell %s" % cell
			return null
	for index in excavation.transitions.size():
		var spec := excavation.transitions[index]
		var transition := WarrenVolumeTransition.new(
			StringName("volume.transition.%02d" % index),
			spec.from as Vector3i, spec.to as Vector3i,
			int(spec.kind) as WarrenVolumeTransition.Kind, [])
		if not plan.add_transition(transition):
			last_failure = "invalid transition %d" % index
			return null
	if not plan.seal(excavation.portals[0]):
		last_failure = "plan seal rejected: %s" % plan.last_rejection
		return null
	return plan
```

`seal_synthesised` will need to be added to `WarrenVolumeEnvelope.gd` (a
sibling of its existing seal that accepts externally supplied height maps —
keep its validation, skip its generation). Transitions may need swept air
cells from `excavation.carved`; follow what `WarrenVolumePlan._validate_transitions` demands.

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_excavation_adapter.gd -gexit 2>&1 | tail -5`
Expected: `Passing Tests 1`. Iterate against `plan.last_rejection` messages until sealed — the plan's validator is the contract oracle.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenExcavationVolumeAdapter.gd scripts/terrain/features/villages/fabric/WarrenVolumeEnvelope.gd tests/test_warren_excavation_adapter.gd
git commit -m "feat(villages): adapt excavated negative space to sealed volume plans"
```

---

### Task 4: GENERATION_MODE flag + mass-first candidates in WarrenTownSolver

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenTownSolver.gd` (around `ranked_candidates`, line ~142)
- Test: `tests/test_warren_generation_mode.gd`

**Interfaces:**
- Consumes: Tasks 1–3 (`WarrenMassifBuilder.build`, `WarrenExcavationCarver.carve`, `WarrenExcavationVolumeAdapter.to_volume_plan`).
- Produces: `WarrenTownSolver.GENERATION_MODE: StringName` (`&"route_first"` default | `&"mass_first"`), consulted at the top of `ranked_candidates`: in mass-first mode the topology frontier comes from massif+excavation attempts instead of `WarrenPublicRealmCarver.sealed_candidate`; everything downstream (arcade extension, frontage variants, parcelize, rank) is unchanged.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## The mode flag is the migration boundary: route_first must stay
## byte-identical, mass_first must produce sealed ranked candidates through
## the same downstream machinery.


func test_route_first_default_is_unchanged() -> void:
	assert_eq(WarrenTownSolver.GENERATION_MODE, &"route_first")


func test_mass_first_produces_ranked_candidates() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	var previous := WarrenTownSolver.GENERATION_MODE
	WarrenTownSolver.GENERATION_MODE = &"mass_first"
	var towns := WarrenTownSolver.ranked_candidates(1, {}, program, 4)
	WarrenTownSolver.GENERATION_MODE = previous
	assert_gt(towns.size(), 0,
		"mass-first seed 1 must survive to ranked candidates: %s" \
		% WarrenTownSolver.last_failure)
	for town: WarrenTownPlan in towns:
		assert_true(town.volume.is_sealed())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_generation_mode.gd -gexit 2>&1 | tail -10`
Expected: FAIL — `GENERATION_MODE` not defined.

- [ ] **Step 3: Write minimal implementation**

In `WarrenTownSolver.gd`: add near other consts (`GENERATION_MODE` is a
`static var`, not const, so tests/corpus probes can flip it):

```gdscript
## Migration boundary (mass-first design spec §5): route_first preserves the
## existing pipeline byte-for-byte; mass_first sources its topology frontier
## from excavated massifs. Downstream stages are shared.
static var GENERATION_MODE := &"route_first"
const MASS_FIRST_EXCAVATION_ATTEMPTS := 24
```

In `ranked_candidates`, replace the topology-frontier loop head (keep the body
that appends `WarrenElevatedFrontageSolver.variants(...)`):

```gdscript
	var topology_frontier: Array[WarrenVolumePlan] = []
	if GENERATION_MODE == &"mass_first":
		var massif := WarrenMassifBuilder.build(world_seed, ground_bands)
		if massif == null:
			last_failure = "massif rejected: %s" \
				% WarrenMassifBuilder.last_failure
			return out
		for attempt in MASS_FIRST_EXCAVATION_ATTEMPTS:
			var excavation := WarrenExcavationCarver.carve(
				world_seed + attempt * 1000003, massif)
			if excavation == null:
				continue
			var adapted := WarrenExcavationVolumeAdapter.to_volume_plan(
				massif, excavation)
			if adapted == null:
				continue
			var extended := WarrenGroundArcadeSolver.extend(adapted)
			if extended == null:
				continue
			for gallery_variant: WarrenVolumePlan in \
					WarrenElevatedFrontageSolver.variants(extended):
				topology_frontier.append(gallery_variant)
	else:
		for attempt in TOPOLOGY_ATTEMPTS:
			var volume := WarrenPublicRealmCarver.sealed_candidate(world_seed,
				attempt, envelope)
			if volume == null:
				continue
			volume = WarrenGroundArcadeSolver.extend(volume)
			if volume == null:
				continue
			for gallery_variant: WarrenVolumePlan in \
					WarrenElevatedFrontageSolver.variants(volume):
				topology_frontier.append(gallery_variant)
```

Note: `envelope` is currently built before the loop; in mass-first mode skip
the `WarrenVolumeEnvelope.build` call (the adapter synthesises envelopes), so
move that build inside the `else` branch.

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_generation_mode.gd -gexit 2>&1 | tail -5`
Expected: `Passing Tests 2`. Expect the arcade/frontage/parcel stages to reject early attempts; iterate on adapter fidelity (walk air, address sides) until at least one candidate ranks. Then run the existing battery to prove route_first untouched: `for t in test_warren_outcrops test_warren_production_surfaces; do … done` — counts must match current green (8, 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenTownSolver.gd tests/test_warren_generation_mode.gd
git commit -m "feat(villages): mass_first generation mode behind migration flag"
```

---

### Task 5: WarrenSolidPartitioner — route-facing faces become houses

**Files:**
- Create: `scripts/terrain/features/villages/fabric/WarrenSolidPartitioner.gd`
- Test: `tests/test_warren_solid_partitioner.gd`

**Interfaces:**
- Consumes: `WarrenMassif`, `WarrenExcavation`; existing `WarrenBuildingParcel` (read `WarrenBuildingParcel.gd` for its constructor/fields: footprint `Array[Vector2i]`, `base_band`, `top_band`, `address_walk_cell`, `has_occupied_overpass`).
- Produces: `WarrenSolidPartitioner.partition(massif, excavation) -> Array[WarrenBuildingParcel]` — house volumes carved from the remaining solid, one per footprint cluster (1×1 to 2×3 columns), tops following massif terraces, every route-flanking column owned by exactly one parcel; `last_failure: String`. Audit helper `unowned_route_faces(parcels, excavation, massif) -> Array[Vector3i]` used by tests and later gates.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## Partition audits (spec §3): every carved flank face belongs to a house;
## footprints stay in the 1x1..2x3 family; tops follow the terraced massif.


func test_partition_owns_every_route_flank() -> void:
	var massif := WarrenMassifBuilder.build(1)
	var excavation := WarrenExcavationCarver.carve(1, massif)
	assert_not_null(excavation, WarrenExcavationCarver.last_failure)
	var parcels := WarrenSolidPartitioner.partition(massif, excavation)
	assert_gt(parcels.size(), 9,
		"a town needs 10+ houses: %s" % WarrenSolidPartitioner.last_failure)
	var unowned := WarrenSolidPartitioner.unowned_route_faces(parcels,
		excavation, massif)
	assert_eq(unowned, [] as Array[Vector3i],
		"route faces without an owning house: %s" % str(unowned))
	for parcel: WarrenBuildingParcel in parcels:
		assert_between(parcel.footprint.size(), 1, 6,
			"footprints stay in the 1x1..2x3 family")
		assert_gt(parcel.top_band, parcel.base_band + 1,
			"terraced houses are at least one storey")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_solid_partitioner.gd -gexit 2>&1 | tail -10`
Expected: identifier failure on `WarrenSolidPartitioner`.

- [ ] **Step 3: Write minimal implementation**

Algorithm (read `WarrenBuildingParcel.gd` first; construct parcels the way
`WarrenParcelizer._candidates` does — copy its constructor call shape):

```gdscript
class_name WarrenSolidPartitioner
extends RefCounted

## Partitions the post-excavation solid into terraced house volumes. Greedy
## seeded flood: route-flanking columns seed footprints first (guaranteeing
## every carved face an owner), then interior leftovers cluster into 1x1..2x3
## footprints. Tops come from the massif terrace; bases from ground bands.
const MAX_FOOTPRINT_COLUMNS := 6

static var last_failure := ""


static func partition(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[WarrenBuildingParcel]:
	last_failure = ""
	var out: Array[WarrenBuildingParcel] = []
	var owned: Dictionary = {}
	var flank_columns := _route_flank_columns(massif, excavation)
	for column: Vector2i in flank_columns:
		if owned.has(column):
			continue
		var footprint := _grow_footprint(column, massif, excavation, owned)
		var parcel := _parcel_from_footprint(footprint, massif, excavation)
		if parcel != null:
			out.append(parcel)
	if out.size() < 10:
		last_failure = "only %d houses partitioned" % out.size()
	return out


static func _route_flank_columns(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for cell: Vector3i in excavation.route:
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT,
				Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var side := cell + direction
			var column := Vector2i(side.x, side.z)
			if seen.has(column) or not massif.has_column(column) \
					or excavation.carved.has(side):
				continue
			if massif.top_at(column) <= cell.y:
				continue
			seen[column] = true
			out.append(column)
	return out


static func _grow_footprint(seed_column: Vector2i, massif: WarrenMassif,
		excavation: WarrenExcavation, owned: Dictionary) -> Array[Vector2i]:
	var footprint: Array[Vector2i] = [seed_column]
	owned[seed_column] = true
	var level := massif.top_at(seed_column)
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i(0, 1),
			Vector2i.LEFT, Vector2i(0, -1)]:
		if footprint.size() >= MAX_FOOTPRINT_COLUMNS:
			break
		var neighbor := seed_column + direction
		if owned.has(neighbor) or not massif.has_column(neighbor):
			continue
		if absi(massif.top_at(neighbor) - level) > 1:
			continue
		owned[neighbor] = true
		footprint.append(neighbor)
	return footprint


static func _parcel_from_footprint(footprint: Array[Vector2i],
		massif: WarrenMassif,
		excavation: WarrenExcavation) -> WarrenBuildingParcel:
	## Construct exactly like WarrenParcelizer builds candidates — copy the
	## constructor/field assignment shape from WarrenBuildingParcel.gd.
	var top := 0
	var base := 1 << 30
	for column: Vector2i in footprint:
		top = maxi(top, massif.top_at(column))
		base = mini(base, massif.base_at(column))
	var parcel := WarrenBuildingParcel.new()
	parcel.footprint = footprint.duplicate()
	parcel.base_band = base
	parcel.top_band = top
	return parcel


static func unowned_route_faces(parcels: Array[WarrenBuildingParcel],
		excavation: WarrenExcavation,
		massif: WarrenMassif) -> Array[Vector3i]:
	var owned: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		for column: Vector2i in parcel.footprint:
			owned[column] = true
	var out: Array[Vector3i] = []
	for column: Vector2i in _route_flank_columns(massif, excavation):
		if not owned.has(column):
			out.append(Vector3i(column.x, 0, column.y))
	return out
```

Adjust field names to the real `WarrenBuildingParcel` API when reading it
(e.g. if it requires `stable_id`/`address_walk_cell`, derive the address from
the adjacent route cell).

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_solid_partitioner.gd -gexit 2>&1 | tail -5`
Expected: `Passing Tests 1`.

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenSolidPartitioner.gd tests/test_warren_solid_partitioner.gd
git commit -m "feat(villages): partition excavated massif into terraced houses"
```

---

### Task 6: Wire partitioner into mass-first parcel stage

**Files:**
- Modify: `scripts/terrain/features/villages/fabric/WarrenTownSolver.gd` (`_parcelize`, line ~389)
- Test: extend `tests/test_warren_generation_mode.gd`

**Interfaces:**
- Consumes: Task 5 partition output; existing `WarrenParcelPlan` (read its constructor/seal in `WarrenParcelPlan.gd`), existing `WarrenParcelHeightSolver` (skyline audit only in mass-first mode).
- Produces: in mass-first mode `_parcelize` builds the `WarrenParcelPlan` from `WarrenSolidPartitioner.partition(...)` (massif/excavation carried on the volume plan via `WarrenVolumePlan` metadata dictionary — add `volume.mass_context: Dictionary` holding `{"massif": WarrenMassif, "excavation": WarrenExcavation}` in the Task 3 adapter) instead of running the packing search; route-first path untouched.

- [ ] **Step 1: Write the failing test** (append to `tests/test_warren_generation_mode.gd`)

```gdscript
func test_mass_first_towns_are_bounded_and_tall() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	var previous := WarrenTownSolver.GENERATION_MODE
	WarrenTownSolver.GENERATION_MODE = &"mass_first"
	var towns := WarrenTownSolver.ranked_candidates(1, {}, program, 4)
	WarrenTownSolver.GENERATION_MODE = previous
	assert_gt(towns.size(), 0, WarrenTownSolver.last_failure)
	var town := towns[0]
	assert_gte(town.parcels.parcels.size(), 10)
	var span := 0
	var low := 1 << 30
	for cell: Vector3i in town.volume.primary_itinerary:
		span = maxi(span, cell.y)
		low = mini(low, cell.y)
	assert_gte(span - low, 8,
		"mass-first routes climb at least 8 bands")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_generation_mode.gd -gexit 2>&1 | tail -10`
Expected: FAIL — parcel count or span (packing search still runs and rejects, or produces short spans).

- [ ] **Step 3: Write minimal implementation**

In `_parcelize`, branch at the top:

```gdscript
	if WarrenTownSolver.GENERATION_MODE == &"mass_first" \
			and not volume.mass_context.is_empty():
		var massif := volume.mass_context.massif as WarrenMassif
		var excavation := volume.mass_context.excavation as WarrenExcavation
		var houses := WarrenSolidPartitioner.partition(massif, excavation)
		if houses.size() < WarrenParcelizer.MIN_PARCELS:
			return null
		return WarrenParcelPlan.from_parcels(houses, volume)
```

`WarrenParcelPlan.from_parcels` is a new static constructor on
`WarrenParcelPlan.gd` — read that file and mirror however `WarrenParcelizer.solve`
assembles/seals its return value (audit fields included; set
`occupied_overpass_parcel_count` by counting parcels whose footprint columns
sit over route cells with clearance — reuse `WarrenBuildingParcel.has_occupied_overpass`
if the field is computed there).

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_generation_mode.gd -gexit 2>&1 | tail -5`
Expected: `Passing Tests 3`, and route-first battery still green (`test_warren_outcrops` 8).

- [ ] **Step 5: Commit**

```bash
git add scripts/terrain/features/villages/fabric/WarrenTownSolver.gd scripts/terrain/features/villages/fabric/WarrenParcelPlan.gd scripts/terrain/features/villages/fabric/WarrenVolumePlan.gd scripts/terrain/features/villages/fabric/WarrenExcavationVolumeAdapter.gd tests/test_warren_generation_mode.gd
git commit -m "feat(villages): mass-first parcels come from solid partitioning"
```

---

### Task 7: WarrenMeshOverlapAudit — acceptance gate #5

**Files:**
- Create: `scripts/terrain/features/villages/fabric/WarrenMeshOverlapAudit.gd`
- Test: `tests/test_warren_mesh_overlap.gd`
- Modify: `tests/harness/warren_volume_review.gd` (print audit summary after commit)

**Interfaces:**
- Consumes: `SettlementFabricPlan.expanded_placements()` (`{asset_id, transform, stable_id}`), `EnvironmentCatalog.descriptor(asset_id)` + baked visual AABBs (read `EnvironmentAssetDescriptor.gd`/`EnvironmentVisual.gd` for the bounds fields; use CPU AABBs, never RenderingServer read-back).
- Produces: `WarrenMeshOverlapAudit.audit(plan: SettlementFabricPlan, catalog: EnvironmentCatalog) -> Dictionary` — `{"coplanar_pairs": Array[Dictionary], "interpenetrating_pairs": Array[Dictionary], "checked_pairs": int}`; each pair entry `{"a": StringName, "b": StringName, "overlap_m": float}`. Tolerances: coplanar 0.02 m, interpenetration 0.10 m; pairs whose stable_ids share a unit prefix or that bond via sockets are exempt (declared junction bites).

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## Gate #5: module placements must not z-fight (coplanar overlap) or
## interpenetrate beyond junction tolerance. Fixture proves detection; the
## accepted-seed test proves the town is clean.


func test_detects_seeded_coplanar_overlap() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var plan := SettlementFabricPlan.new(&"overlap.fixture", 0)
	var wall := &"sfv.fabric.wall.wood.plain.001"
	plan.add_direct_placement(&"a", wall, Transform3D(Basis.IDENTITY,
		Vector3.ZERO))
	plan.add_direct_placement(&"b", wall, Transform3D(Basis.IDENTITY,
		Vector3(0.005, 0.0, 0.0)))
	plan.seal_for_test()
	var report := WarrenMeshOverlapAudit.audit(plan, catalog)
	assert_gt((report.coplanar_pairs as Array).size(), 0,
		"two walls 5mm apart in the same plane must be flagged")


func test_accepted_seed_town_is_overlap_clean() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	var built := WarrenBuiltTownSolver.solve(1, program)
	assert_not_null(built, WarrenBuiltTownSolver.last_failure)
	var report := WarrenMeshOverlapAudit.audit(built.fabric,
		EnvironmentCatalog.load_default())
	assert_eq((report.coplanar_pairs as Array).size(), 0,
		"z-fighting pairs: %s" % JSON.stringify(report.coplanar_pairs))
	assert_eq((report.interpenetrating_pairs as Array).size(), 0,
		"interpenetrating pairs: %s" \
		% JSON.stringify(report.interpenetrating_pairs))
```

`add_direct_placement`/`seal_for_test` are small test-support additions to
`SettlementFabricPlan` ONLY if no existing constructor path can build a
two-placement plan — first read `SettlementFabricPlan.gd`; prefer building the
fixture through whatever minimal public API exists (a recipe-free plan or a
FabricRecipe with two placements).

- [ ] **Step 2: Run test to verify it fails**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_mesh_overlap.gd -gexit 2>&1 | tail -10`
Expected: identifier failure on `WarrenMeshOverlapAudit`.

- [ ] **Step 3: Write minimal implementation**

```gdscript
class_name WarrenMeshOverlapAudit
extends RefCounted

## Acceptance gate #5 (mass-first design spec §3): flags coplanar z-fighting
## and shell interpenetration between placed modules using baked visual AABBs
## on the CPU. Junction bites (socket-bonded neighbours and same-unit pieces)
## are declared geometry and exempt.
const COPLANAR_TOLERANCE_M := 0.02
const INTERPENETRATION_TOLERANCE_M := 0.10


static func audit(plan: SettlementFabricPlan,
		catalog: EnvironmentCatalog) -> Dictionary:
	var placements := plan.expanded_placements()
	var entries: Array[Dictionary] = []
	for placement: Dictionary in placements:
		var descriptor := catalog.descriptor(
			StringName(placement.asset_id))
		if descriptor == null:
			continue
		var bounds := descriptor.visual_bounds() \
			as AABB  # read descriptor API; fall back to collision AABB
		entries.append({
			"stable_id": StringName(placement.stable_id),
			"aabb": (placement.transform as Transform3D) * bounds,
		})
	var coplanar: Array[Dictionary] = []
	var interpenetrating: Array[Dictionary] = []
	var checked := 0
	for left_index in entries.size():
		for right_index in range(left_index + 1, entries.size()):
			var left := entries[left_index]
			var right := entries[right_index]
			if _same_unit(left.stable_id, right.stable_id):
				continue
			var a := left.aabb as AABB
			var b := right.aabb as AABB
			if not a.intersects(b):
				continue
			checked += 1
			var overlap := a.intersection(b)
			var thinnest := minf(overlap.size.x,
				minf(overlap.size.y, overlap.size.z))
			var deepest := overlap.size[overlap.size.min_axis_index()]
			if thinnest <= COPLANAR_TOLERANCE_M \
					and overlap.get_volume() > 0.0:
				coplanar.append(_pair(left, right, thinnest))
			elif deepest > INTERPENETRATION_TOLERANCE_M:
				interpenetrating.append(_pair(left, right, deepest))
	return {
		"coplanar_pairs": coplanar,
		"interpenetrating_pairs": interpenetrating,
		"checked_pairs": checked,
	}


static func _same_unit(a: StringName, b: StringName) -> bool:
	## Placement stable ids embed their unit prefix before the last '/'.
	var left := String(a)
	var right := String(b)
	return left.get_slice("/", 0) == right.get_slice("/", 0)


static func _pair(left: Dictionary, right: Dictionary,
		overlap_m: float) -> Dictionary:
	return {"a": left.stable_id, "b": right.stable_id,
		"overlap_m": overlap_m}
```

Expect iteration: AABB-only coplanarity over-flags butt-jointed neighbours
(walls meeting at corners legitimately touch). Refine `_same_unit` into a
socket-bond exemption (plan.units carry `socket_bonds`; exempt bonded unit
pairs) and require the overlap slab to be *parallel-face* overlap (both AABBs
extend past each other in the two long axes) before flagging. The accepted-seed
test defines done: real seams stay, false positives go.

- [ ] **Step 4: Run test to verify it passes**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryko/story -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_warren_mesh_overlap.gd -gexit 2>&1 | tail -5`
Expected: `Passing Tests 2`. If the accepted-seed test reveals REAL overlaps (likely — the round-6 review saw them), list them in the failure, fix the offending recipes/junction entries one at a time (each its own commit), and only then tighten the test to zero.

- [ ] **Step 5: Add review-harness surfacing + commit**

In `tests/harness/warren_volume_review.gd` after the commit call, print:

```gdscript
	var overlap_report := WarrenMeshOverlapAudit.audit(_built.fabric, catalog)
	print("[warren_volume] overlap coplanar=%d interpenetrating=%d checked=%d" % [
		(overlap_report.coplanar_pairs as Array).size(),
		(overlap_report.interpenetrating_pairs as Array).size(),
		int(overlap_report.checked_pairs)])
```

```bash
git add scripts/terrain/features/villages/fabric/WarrenMeshOverlapAudit.gd tests/test_warren_mesh_overlap.gd tests/harness/warren_volume_review.gd
git commit -m "feat(villages): mesh-overlap audit gate flags z-fighting and interpenetration"
```

---

### Task 8: Corpus probe columns + mass-first sweep + showcase gate

**Files:**
- Modify: `/private/tmp/claude-501/-Users-ryko-story/8e9ab161-9ece-46e4-b71a-12aa4b4222f1/scratchpad/probe_height_variety.gd` (add `covered_ratio` column; already prints `route_y_span`)
- Test: none new (probe is the instrument; acceptance criteria from spec §5 are the oracle)

**Steps:**

- [ ] **Step 1:** Add covered-ratio to the probe print: compute from the built plan audit (`plan.audit.get("overhead_route_ratio")` already exists — rename usage to note it IS covered ratio for mass-first) and print `mode=` from `WarrenTownSolver.GENERATION_MODE`.
- [ ] **Step 2:** Run the 12-seed sweep in `route_first` mode → confirm unchanged vs `final_metrics.log` (6/12, same seeds).
- [ ] **Step 3:** Flip `GENERATION_MODE` to `mass_first` (probe sets it at startup) and sweep → record acceptance, median span, covered ratios, overpasses.
- [ ] **Step 4:** Iterate excavation/partition constants until spec §5 targets hold: acceptance ≥ 6/12, median span ≥ 8, covered 0.45–0.70, battery green, overlap audit clean. Every constant change gets one sweep and one commit with the measured numbers in the message.
- [ ] **Step 5:** Render one accepted mass-first seed via `warren_volume_review.tscn` (GUI, `--output`), visually critique (bounded canyons? tunnels? terraced silhouettes?), then run a full 12-town showcase batch and deliver. Only after two green showcase batches: flip the default to `mass_first` in a dedicated commit (spec §5 rollback boundary).

---

## Self-Review

1. **Spec coverage:** massif (T1), excavation (T2), volume-plan seam (T3), mode flag (T4), partitioner (T5+T6), street-section resolution — deliberately *not* a new component: T3/T6 route the carved output through the existing fabric layer, which the spec names as the surviving mechanism; overlap audit (T7); migration criteria + corpus (T8). Open questions from spec §7 stay open (interior granularity, grotto markets) — no task pretends to close them.
2. **Placeholder scan:** every code step carries real code; the two "read the file first" notes (WarrenVolumePlan seal contract, WarrenBuildingParcel constructor) are deliberate context-gathering steps against drift, each naming the exact file and what to copy.
3. **Type consistency:** `WarrenMassifBuilder.build(world_seed, ground_bands) -> WarrenMassif`, `WarrenExcavationCarver.carve(world_seed, massif) -> WarrenExcavation`, `WarrenExcavationVolumeAdapter.to_volume_plan(massif, excavation) -> WarrenVolumePlan`, `WarrenSolidPartitioner.partition(massif, excavation) -> Array[WarrenBuildingParcel]`, `WarrenMeshOverlapAudit.audit(plan, catalog) -> Dictionary` — used identically across tasks; `GENERATION_MODE` is a `static var` everywhere.
