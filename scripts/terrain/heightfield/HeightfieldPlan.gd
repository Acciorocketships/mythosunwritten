class_name HeightfieldPlan
extends RefCounted

## Deterministic, churn-free numerical terrain plan. A continuous height field
## H(point) is sampled on a lattice of POINTS 12 m apart (point (i, j) sits at
## world (12 i, 12 j)), quantized into integer cliff storeys and trickle-down
## clamped so cardinal neighbour points never differ by more than max_step
## storeys. The result is a pure function of (world_seed, point), so a planned
## height is final before anything is instantiated — the anti-churn guarantee.
## Every (i, j) in this API is a point index; 24 m CELLs (2 x 2 tiles) are the
## coarse settlement/route lattice and are NOT addressed here.
##
## Phases 1-2: storey (cliff) + level (terrace) tiers. See
## docs/superpowers/specs/2026-06-17-heightfield-terrain-design.md.

# Sampling pitch: one height sample per lattice point, 12 m apart.
const POINT: float = 12.0
# Coarse route/settlement/biome cell: 2 x 2 tiles of POINT pitch.
const CELL: float = 24.0
const STOREY_HEIGHT: float = 4.0
const LEVEL_HEIGHT: float = 1.0
# 4.0 / 1.0. Level saturates at LEVELS_PER_STOREY - 1 (=3), so a full storey is
# always a single cliff, never a stack of 4 level tiles.
const LEVELS_PER_STOREY: int = 4
# Search radius for the nearest different storey. Levels saturate at
# LEVELS_PER_STOREY - 1, so a cliff farther than LEVELS_PER_STOREY tiles can never
# affect a cell's level — no need to look past it.
const _CLIFF_SEARCH_MAX: int = LEVELS_PER_STOREY
const _NO_CLIFF: int = 999

## C# mirror of TerrainField.height_m, used per seed once verified bit-identical.
const NativeHeightField := preload("res://scripts/native/NativeHeightField.gd")

var world_seed: int
var height_amplitude: float   # metres; macro field [0,1] -> [0, amplitude]
var max_storeys: int          # caps column height -> bounds clamp margin
var aggregation: String       # "min" (floor) | "mean" (nearest) | "max" (ceil)
var max_step: int = 1         # max storey difference between cardinal neighbours (1=classic, 3=cliffs)

## Low-pass tuning knob (spec 2026-09-30 dual-grid tiles, section 9 risk 1).
## Metres; 0 = off (byte-identical to the unfiltered field). When > 0 the
## NATURAL height (rendered field with detail, before the water carve) is a
## separable tent filter of height01 over offsets {-r, 0, +r} per axis with
## weights (1, 2, 1) / 4, r = LOWPASS_M. The carve is never filtered, so river
## channels stay sharp. Process-wide: set it BEFORE any plan is built; every
## memo (per-plan _samples, WaterPlan.noise_h) assumes it never changes.
static var LOWPASS_M: float = 0.0
const _TENT: Array = [1.0, 2.0, 1.0]

var _raw_override: Callable = Callable()
var _lowpass_seen: float = -1.0

# Optional water carve (untyped to avoid a WaterPlan<->HeightfieldPlan
# class-resolution cycle; duck-typed: needs carve_at(x, z) -> float).
var _water_plan = null

# Per-point sample memo: Vector2i(i,j) -> [height_after_carve, carve, original_height].
# Purely a performance cache — raw_height is a pure function of (seed, cell) —
# persisted across compute_region calls so the ~77%-overlapping windows of
# neighbouring chunks are sampled once. The raw carve amount is cached too so
# compute_region can apply the water threshold without a third carve sweep.
# Evict one oldest sample at capacity, preserving the overlapping warm windows.
const _SAMPLE_CACHE_MAX := 1_000_000
var _samples: Dictionary = {}
var _sample_keys: Array[Vector2i] = []
var _sample_cursor: int = 0
## Chunk tails sample on pool threads beside the planner: the memo is read and
## written under this lock, never held while a sample is computed.
var _samples_lock := Mutex.new()


func _sample(cx: int, cz: int) -> Array:
	if _lowpass_seen < 0.0:
		_lowpass_seen = LOWPASS_M
	assert(_lowpass_seen == LOWPASS_M,
		"HeightfieldPlan.LOWPASS_M changed after this plan sampled; set it before building plans")
	var key := Vector2i(cx, cz)
	_samples_lock.lock()
	var s = _samples.get(key)
	_samples_lock.unlock()
	if s == null:
		var h: float
		if _raw_override.is_valid():
			h = _raw_override.call(cx, cz)
		else:
			h = natural01(Vector3(float(cx) * POINT, 0.0, float(cz) * POINT), world_seed) * height_amplitude
		var carve: float = 0.0
		if _water_plan != null:
			carve = _water_plan.carve_at(float(cx) * POINT, float(cz) * POINT)
		s = [h - carve, carve, h]
		_samples_lock.lock()
		_store_sample(key, s)
		_samples_lock.unlock()
	return s


## Insert one sample into the memo. Caller holds _samples_lock.
func _store_sample(key: Vector2i, s: Array) -> void:
	if _samples.has(key):
		pass
	elif _samples.size() >= _SAMPLE_CACHE_MAX:
		_samples.erase(_sample_keys[_sample_cursor])
		_sample_keys[_sample_cursor] = key
		_sample_cursor = (_sample_cursor + 1) % _SAMPLE_CACHE_MAX
	else:
		_sample_keys.append(key)
	_samples[key] = s


func _clear_samples() -> void:
	_samples_lock.lock()
	_samples.clear()
	_sample_keys.clear()
	_sample_cursor = 0
	_samples_lock.unlock()


func _init(
	p_world_seed: int,
	p_height_amplitude: float = 32.0,
	p_max_storeys: int = 8,
	p_aggregation: String = "mean",
	p_max_step: int = 1
) -> void:
	assert(p_height_amplitude > 0.0, "HeightfieldPlan: height_amplitude must be positive")
	# max_storeys bounds the derived clamp dependency radius; a non-positive value collapses the
	# window to a single cell and silently breaks the churn-free guarantee.
	assert(p_max_storeys > 0, "HeightfieldPlan: max_storeys must be positive")
	assert(p_aggregation == "min" or p_aggregation == "mean" \
		or p_aggregation == "max",
		"HeightfieldPlan: aggregation must be min, mean, or max")
	assert(p_max_step > 0, "HeightfieldPlan: max_step must be positive")
	world_seed = p_world_seed
	height_amplitude = p_height_amplitude
	max_storeys = p_max_storeys
	aggregation = p_aggregation
	max_step = p_max_step
	# Main thread for the streamer (its _ready builds the plan before the worker
	# starts); a no-op after the seed's first plan and under the standard editor.
	NativeHeightField.setup(world_seed)


## Replace the noise source with a synthetic field for tests. fn(i, j) -> float,
## keyed by lattice point index (world position 12 i, 12 j).
## Forwarded to the relief stamp when one is attached: the stamp reads natural
## ground too (its fill formula and its storey-ceiling clamp both do), so the
## two must never disagree about what the ground is.
func set_raw_height_override(fn: Callable) -> void:
	_raw_override = fn
	_clear_samples()


## Attach the water network: raw_height subtracts its carve BEFORE storey
## quantization, so banks/cliffs/slopes around water come from the existing
## clamp + surface-field machinery with no downstream changes.
func set_water_plan(p_water_plan) -> void:
	_water_plan = p_water_plan
	_clear_samples()


## Continuous height (metres) at lattice point (i, j), after the water carve. Memoized.
func raw_height(cx: int, cz: int) -> float:
	return _sample(cx, cz)[0]


## Original terrain input before subtraction, with its exact floating-point
## value retained. Reusing a prepared cell avoids a second noise/carve query;
## adding the carve back to a rounded subtraction could lose low bits.
func uncarved_height(cx: int, cz: int) -> float:
	return _sample(cx, cz)[2]


## Natural terrain in [0, 1] (spec 2026-10-02): TerrainField's metre field over
## the production amplitude. include_detail=false is the SMOOTH field that river
## tracing descends (continental base + placed set pieces + each regime's macro
## relief, no terraces); include_detail=true adds the fine relief and terraces
## and is the rendered field (raw_height).
## A flat clearing near the world origin keeps the spawn gentle. It lies at
## the level of its surroundings (TerrainField.spawn_level_m), never at zero:
## a clearing at zero was a bowl that rivers ended in (2026-10-04).
static func height01(pos: Vector3, p_world_seed: int, include_detail: bool = true) -> float:
	var h: float
	if NativeHeightField.ready_for(p_world_seed):
		h = NativeHeightField.height_m(Vector2(pos.x, pos.z), p_world_seed, include_detail)
	else:
		h = TerrainField.height_m(Vector2(pos.x, pos.z), p_world_seed, include_detail)
	var falloff: float = SlopeProfile.smootherstep(clampf((Vector2(pos.x, pos.z).length() - 60.0) / 180.0, 0.0, 1.0))
	if falloff < 1.0:
		h = lerpf(TerrainField.spawn_level_m(p_world_seed), h, falloff)
	return clampf(h / TerrainField.REF_AMPLITUDE, 0.0, 1.0)


func _height01(pos: Vector3) -> float:
	return height01(pos, world_seed, true)


## The rendered natural field in [0, 1]: height01(include_detail=true), low-passed
## by LOWPASS_M when set. Everything that compares against rendered ground
## (plan samples, pre-carve levels, settlement relief) reads this; river routing
## deliberately keeps the unfiltered smooth field.
static func natural01(pos: Vector3, p_world_seed: int) -> float:
	var r := LOWPASS_M
	if r <= 0.0:
		return height01(pos, p_world_seed, true)
	var sum := 0.0
	for ix in 3:
		for iz in 3:
			sum += _TENT[ix] * _TENT[iz] * height01(
				Vector3(pos.x + float(ix - 1) * r, pos.y, pos.z + float(iz - 1) * r),
				p_world_seed, true)
	return sum / 16.0


## Apply the aggregation rounding mode to a quotient: min=floor (hug valleys),
## max=ceil (build up), mean=nearest. Shared by storey and level quantization.
func _round_mode(q: float) -> int:
	match aggregation:
		"min":
			return floori(q)
		"mean":
			return roundi(q)
		"max":
			return ceili(q)
		_:
			assert(false, "HeightfieldPlan has an invalid aggregation")
			return 0


## Quantize a height (metres) to an integer storey index, clamped to [0, max_storeys].
func quantize_storey(h: float) -> int:
	return clampi(_round_mode(h / STOREY_HEIGHT), 0, max_storeys)


const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const _DIAGONALS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]


## True if a DIAGONAL neighbour is a different storey (a cliff on the diagonal).
## The cardinal cliff ramp already pins cells next to a cardinal cliff to level 0;
## this extends that pin to diagonal cliffs. Without it, a cell whose only cliff is
## diagonal keeps a 1m terrace bump (cardinal cliff-distance is 2 there, capping
## level at 1), comes out level-family, and the diagonal cliff's interior corner is
## never rendered — leaving a gap at the corner.
static func _has_diagonal_cliff(storeys: Dictionary, cell: Vector2i) -> bool:
	var s: int = storeys[cell]
	for d in _DIAGONALS:
		var nb: Vector2i = cell + d
		if storeys.has(nb) and storeys[nb] != s:
			return true
	return false

## Monotone trickle-down clamp: repeatedly lower each cell to at most one storey
## above its lowest CARDINAL neighbour, until nothing changes. Diagonals are NOT
## constrained — a cliff may drop two storeys diagonally (a valid formation); the
## instantiator renders the extra interior corner at such a corner. The operation
## only lowers and is bounded below by the input, so it terminates; the fixpoint
## (each cell <= min_neighbour + 1) is unique regardless of sweep order. `targets`
## maps Vector2i(cx, cz) -> storey; returns a new clamped map.
static func clamp_field(targets: Dictionary, max_step: int = 1) -> Dictionary:
	assert(max_step > 0, "HeightfieldPlan.clamp_field: max_step must be positive")
	var out: Dictionary = targets.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for cell in out.keys():
			var here: int = out[cell]
			for d in _CARDINALS:
				var nb: Vector2i = cell + d
				if not out.has(nb):
					continue
				# Reads the possibly-already-lowered neighbour (Gauss-Seidel): safe
				# and faster to converge because values only ever decrease.
				var cap: int = out[nb] + max_step
				if here > cap:
					here = cap
					changed = true
			out[cell] = here
	return out


## A source q contributes target(q) + max_step * ManhattanDistance(p,q).
## Targets lie in [0,max_storeys]; beyond this radius even zero cannot lower
## the query. The same bound applies to both reference and batched compilers.
func storey_margin() -> int:
	return ceili(float(max_storeys) / max_step)


## Final clamped storey for a cell. Reference implementation: builds a window of
## quantized targets and clamps it. (Production will batch this over chunks; the
## per-cell window here is for correctness/validation, not the hot path.)
func storey_at(cx: int, cz: int) -> int:
	var m: int = storey_margin()
	var targets: Dictionary = {}
	for dz in range(-m, m + 1):
		for dx in range(-m, m + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			# cell.x = cx, cell.y = cz (Vector2i stores the horizontal grid pair,
			# NOT world Y / the up-axis).
			targets[cell] = quantize_storey(raw_height(cell.x, cell.y))
	var clamped: Dictionary = clamp_field(targets, max_step)
	return clamped[Vector2i(cx, cz)]


## Whether the 1m sub-storey LEVEL terraces contribute to the rendered surface. ON (owner,
## 2026-07-16): a level step between two points is a LEVEL edge of the tile kernel and renders
## through the SAME smootherstep slope profile as a one-storey edge (TerrainTileField), at one
## quarter of the storey height. Walls key off storey_at alone (a cliff edge differs by two or
## more storeys), and level_at pins to 0 near storey boundaries, so levels only ever read as
## short procedural slopes.
const RENDER_LEVELS: bool = true

## Rendered surface height (metres): storey tier (4m steps), plus the level tier (1m) only when
## RENDER_LEVELS is on (the cliff logic keys off the storey tier alone either way).
func surface_height(cx: int, cz: int) -> float:
	var h := float(storey_at(cx, cz)) * STOREY_HEIGHT
	if RENDER_LEVELS:
		h += float(level_at(cx, cz)) * LEVEL_HEIGHT
	return h


## Read API for downstream instantiation: storey index, terrace level, and the
## combined world height. Reference path — it computes storey_at and level_at
## separately (two windows). Phase 3 should batch a whole chunk in one pass
## rather than call this per cell in a hot loop.
func tile_plan(cx: int, cz: int) -> Dictionary:
	var s: int = storey_at(cx, cz)
	var l: int = level_at(cx, cz)
	return {"storey": s, "level": l, "height": float(s) * STOREY_HEIGHT + float(l) * LEVEL_HEIGHT}


## Sub-storey height (metres) of the raw field above this cell's clamped storey base.
func residual_height(cx: int, cz: int) -> float:
	return raw_height(cx, cz) - float(storey_at(cx, cz)) * STOREY_HEIGHT


## Quantized sub-storey terrace index in [0, LEVELS_PER_STOREY - 1], using the same
## aggregation rounding as the storey tier.
## Uncapped/unclamped building block — see level_at for the final settled level.
func detail_level(cx: int, cz: int) -> int:
	var r: float = residual_height(cx, cz)
	return clampi(_round_mode(r / LEVEL_HEIGHT), 0, LEVELS_PER_STOREY - 1)


## Cardinal (Manhattan) distance from `cell` to the nearest cell in `storeys` whose
## storey differs, searched out to `max_r`. Returns _NO_CLIFF if none within range.
## Pure function of the supplied storey map.
static func _cliff_distance_in(cell: Vector2i, storeys: Dictionary, max_r: int) -> int:
	var s0: int = storeys[cell]
	for r in range(1, max_r + 1):
		for dx in range(-r, r + 1):
			var rem: int = r - absi(dx)
			var dzs: Array[int]
			if rem == 0:
				dzs = [0]
			else:
				dzs = [rem, -rem]
			for dz in dzs:
				var nb: Vector2i = cell + Vector2i(dx, dz)
				if storeys.has(nb) and storeys[nb] != s0:
					return r
	return _NO_CLIFF


## Monotone trickle-down clamp for the level field, masked by storey: a cell is
## lowered to at most one level above its lowest SAME-storey cardinal neighbour.
## Cross-storey neighbours impose no constraint — that transition is a cliff,
## owned by the storey tier. Same unique-fixpoint / order-independence properties
## as clamp_field. `levels` and `storeys` share keys.
static func _clamp_levels(levels: Dictionary, storeys: Dictionary) -> Dictionary:
	var out: Dictionary = levels.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for cell in out.keys():
			var here: int = out[cell]
			var s: int = storeys[cell]
			for d in _CARDINALS:
				var nb: Vector2i = cell + d
				if not out.has(nb):
					continue
				if storeys[nb] != s:
					continue
				var cap: int = out[nb] + 1
				if here > cap:
					here = cap
					changed = true
			out[cell] = here
	return out


## Window radius over which the level field is assembled and clamped around a
## query cell. The cliff-distance ramp reaches _CLIFF_SEARCH_MAX (= LEVELS_PER_STOREY)
## tiles; the masked level clamp reaches at most LEVELS_PER_STOREY - 1 (a level
## saturates at 3, so a spike settles within 3 tiles). LEVELS_PER_STOREY thus has
## one tile of spare margin — do NOT shrink it.
func level_margin() -> int:
	return LEVELS_PER_STOREY


## Final (clamped) storeys over [cx +/- radius]. Quantizes a window padded by
## storey_margin() (the clamp's influence distance) so the inner `radius` storeys are
## settled, then runs the storey clamp once. Reused by level_at to avoid per-cell
## storey windows.
func _build_storey_map(cx: int, cz: int, radius: int) -> Dictionary:
	var outer: int = radius + storey_margin()
	var targets: Dictionary = {}
	for dz in range(-outer, outer + 1):
		for dx in range(-outer, outer + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			targets[cell] = quantize_storey(raw_height(cell.x, cell.y))
	return clamp_field(targets, max_step)


## Final terrace level in [0, LEVELS_PER_STOREY - 1] for a cell. Builds a settled
## storey map over the window, derives a pre-clamp level for each cell (the detail
## terrace capped by the ramp from the nearest cliff: a cell touching a different
## storey is pinned to 0), then runs the storey-masked level clamp and returns the
## center. Reference implementation; production batches this over chunks.
func level_at(cx: int, cz: int) -> int:
	var lm: int = level_margin()
	var storeys: Dictionary = _build_storey_map(cx, cz, lm + _CLIFF_SEARCH_MAX)
	var l0: Dictionary = {}
	for dz in range(-lm, lm + 1):
		for dx in range(-lm, lm + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			var s: int = storeys[cell]
			var residual: float = raw_height(cell.x, cell.y) - float(s) * STOREY_HEIGHT
			var detail: int = clampi(_round_mode(residual / LEVEL_HEIGHT), 0, LEVELS_PER_STOREY - 1)
			var cliff_cap: int = _cliff_distance_in(cell, storeys, _CLIFF_SEARCH_MAX) - 1
			if _has_diagonal_cliff(storeys, cell):
				cliff_cap = 0
			l0[cell] = clampi(mini(detail, cliff_cap), 0, LEVELS_PER_STOREY - 1)
	var leveled: Dictionary = _clamp_levels(l0, storeys)
	return leveled[Vector2i(cx, cz)]


## Cliff distance for every cell at once via a BFS from storey-boundary cells
## through same-storey regions (O(N) vs per-cell ring scans). For a cell, the
## nearest different-storey cell is reached by a same-storey path to a boundary,
## so seeding boundaries at distance 1 and flooding within each storey gives the
## same Manhattan distance as _cliff_distance_in. Cells not reached within max_r
## are absent (== _NO_CLIFF). Equivalent to _cliff_distance_in for all cells.
static func _cliff_distance_field(storeys: Dictionary, max_r: int) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell in storeys.keys():
		var s: int = storeys[cell]
		for d in _CARDINALS:
			var nb: Vector2i = cell + d
			if storeys.has(nb) and storeys[nb] != s:
				dist[cell] = 1
				queue.append(cell)
				break
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var cd: int = dist[cell]
		if cd >= max_r:
			continue
		var s: int = storeys[cell]
		for off in _CARDINALS:
			var nb: Vector2i = cell + off
			if not storeys.has(nb):
				continue
			if storeys[nb] != s:
				continue
			if not dist.has(nb):
				dist[nb] = cd + 1
				queue.append(nb)
	return dist


## Batched region computation (storey clamp + level clamp once). All noise /
## water sampling goes through the per-cell _sample memo, so the overlapping
## windows of successive chunk builds are sampled once per cell per session.
## Cliff distances use one BFS field. Returns values equal to the per-cell
## reference.
func compute_region(center_cx: int, center_cz: int, radius: int) -> HeightfieldRegion:
	return compute_rect_region(Rect2i(Vector2i(center_cx-radius,center_cz-radius),Vector2i.ONE*(radius*2+1)))


## Below this many missing samples a rectangle is sampled serially.
const PREFETCH_MIN := 4096
## Pool tasks a large rectangle's samples are split across: leaves cores for
## the main thread and the chunk tails.
const PREFETCH_TASKS := 4
## Off only for A/B checks (tests/harness/water_block_cost.gd --serial).
static var prefetch_enabled := true

## Fill the sample memo for a large rectangle on the thread pool. _sample is a
## pure function of the point and the memo is locked, so the result is the
## serial one. Each river carve region (one per WaterPlan.SUPER cell) is built
## first, serially, from one point in it, so the tasks never build the same
## region side by side.
func _prefetch_samples(lo: Vector2i, width: int, rows: int) -> void:
	if not prefetch_enabled or _raw_override.is_valid() or width * rows < PREFETCH_MIN \
			or WaterPlan.on_pool_thread():
		return
	var missing := PackedInt32Array()
	_samples_lock.lock()
	for z in rows:
		for x in width:
			if not _samples.has(Vector2i(lo.x + x, lo.y + z)):
				missing.append(z * width + x)
	_samples_lock.unlock()
	if missing.size() < PREFETCH_MIN:
		return
	if _prefetch_native(lo, width, rows, missing):
		return
	if _water_plan != null:
		var step := int(WaterPlan.SUPER / POINT)
		var xs: Array[int] = []
		for x in range(0, width, step): xs.append(x)
		xs.append(width - 1)
		var zs: Array[int] = []
		for z in range(0, rows, step): zs.append(z)
		zs.append(rows - 1)
		for z: int in zs:
			for x: int in xs:
				_sample(lo.x + x, lo.y + z)
	var band := ceili(float(missing.size()) / PREFETCH_TASKS)
	var job := func(task: int) -> void:
		for k in range(task * band, mini(missing.size(), (task + 1) * band)):
			var index := missing[k]
			_sample(lo.x + index % width, lo.y + index / width)
	var group := WorkerThreadPool.add_group_task(job, PREFETCH_TASKS, PREFETCH_TASKS, true,
		"heightfield prefetch")
	WorkerThreadPool.wait_for_group_task_completion(group)


## The prefetch in C# (NativeCarve.SampleBatch: native height, the height01
## wrapper and the carve, [h - carve, carve, h] per point), when the seed's
## height field and carve are verified and every carve region the window needs
## carries its verified native copy. False leaves the window to the GDScript
## prefetch. Only plain plans (test subclasses override field reads).
func _prefetch_native(lo: Vector2i, width: int, rows: int, missing: PackedInt32Array) -> bool:
	if _water_plan == null or get_script() != HeightfieldPlan or _water_plan.get_script() != WaterPlan \
			or not NativeHeightField.ready_for(world_seed) \
			or not WaterPlan.NATIVE_CARVE.ready_for(_water_plan.world_seed):
		return false
	if _lowpass_seen < 0.0:
		_lowpass_seen = LOWPASS_M
	# Owner super-cells of the window (carve_at's rule; monotone in the index).
	var per_super := int(WaterPlan.SUPER / WaterPlan.TILE)
	var rc_lo := Vector2i(floori(float(floori(float(lo.x) * POINT / WaterPlan.TILE + 0.5)) / per_super),
		floori(float(floori(float(lo.y) * POINT / WaterPlan.TILE + 0.5)) / per_super))
	var rc_hi := Vector2i(floori(float(floori(float(lo.x + width - 1) * POINT / WaterPlan.TILE + 0.5)) / per_super),
		floori(float(floori(float(lo.y + rows - 1) * POINT / WaterPlan.TILE + 0.5)) / per_super))
	var regions: Array = []
	var keys := PackedInt32Array()
	for rz in range(rc_lo.y, rc_hi.y + 1):
		for rx in range(rc_lo.x, rc_hi.x + 1):
			var region: Dictionary = _water_plan._region_for(Vector2i(rx, rz))
			if not region.has("native"):
				return false
			regions.append(region.native)
			keys.append(rx)
			keys.append(rz)
	var band := ceili(float(missing.size()) / PREFETCH_TASKS)
	var job := func(task: int) -> void:
		var part := missing.slice(task * band, mini(missing.size(), (task + 1) * band))
		if part.is_empty():
			return
		var out := WaterPlan.NATIVE_CARVE.sample_batch(self, lo, width, part, regions, keys)
		_samples_lock.lock()
		for k in part.size():
			var index := part[k]
			_store_sample(Vector2i(lo.x + index % width, lo.y + index / width),
				[out[3 * k], out[3 * k + 1], out[3 * k + 2]])
		_samples_lock.unlock()
	var group := WorkerThreadPool.add_group_task(job, PREFETCH_TASKS, PREFETCH_TASKS, true,
		"heightfield prefetch")
	WorkerThreadPool.wait_for_group_task_completion(group)
	return true


## Same certified terrain computation on a rectangular requested interior.
## Long river corridors need the complete clamp halo, not an unrelated square
## extending equally far in the narrow direction. Square callers retain their
## exact former buffer extents, iteration order and output dictionaries.
func compute_rect_region(interior: Rect2i) -> HeightfieldRegion:
	assert(interior.size.x > 0 and interior.size.y > 0)
	var level_rect := interior.grow(1 + LEVELS_PER_STOREY)
	var inset := _CLIFF_SEARCH_MAX + storey_margin()
	var outer_rect := level_rect.grow(inset)
	var width := outer_rect.size.x
	var rows := outer_rect.size.y
	var count := width * rows
	var lo := outer_rect.position
	_prefetch_samples(lo, width, rows)
	var storeys := PackedInt32Array()
	storeys.resize(count)
	for z in rows:
		for x in width:
			storeys[z*width+x] = quantize_storey(_sample(lo.x+x,lo.y+z)[0])
	# The rectangular cardinal clamp is the minimum of target(q) plus
	# max_step * ManhattanDistance(p,q). Its two separable distance transforms
	# reach exactly the old monotone fixpoint, including finite outer edges.
	for z in rows:
		var row := z*width
		for x in range(1,width):
			storeys[row+x] = mini(storeys[row+x],storeys[row+x-1]+max_step)
		for x in range(width-2,-1,-1):
			storeys[row+x] = mini(storeys[row+x],storeys[row+x+1]+max_step)
	for z in range(1,rows):
		for x in width:
			var idx := z*width+x
			storeys[idx] = mini(storeys[idx],storeys[idx-width]+max_step)
	for z in range(rows-2,-1,-1):
		for x in width:
			var idx := z*width+x
			storeys[idx] = mini(storeys[idx],storeys[idx+width]+max_step)
	var distances := PackedInt32Array()
	distances.resize(count)
	distances.fill(_NO_CLIFF)
	var queue := PackedInt32Array()
	for z in rows:
		for x in width:
			var idx := z*width+x
			var here := storeys[idx]
			if (x>0 and storeys[idx-1]!=here) or (x+1<width and storeys[idx+1]!=here) \
					or (z>0 and storeys[idx-width]!=here) or (z+1<rows and storeys[idx+width]!=here):
				distances[idx]=1
				queue.append(idx)
	var head := 0
	var offsets: Array[int] = [1,-1,width,-width]
	while head<queue.size():
		var idx := queue[head]
		head+=1
		if distances[idx]>=_CLIFF_SEARCH_MAX: continue
		for offset in offsets:
			var nb := idx+offset
			if nb<0 or nb>=count: continue
			if offset==1 and idx%width==width-1: continue
			if offset==-1 and idx%width==0: continue
			if storeys[nb]==storeys[idx] and distances[nb]==_NO_CLIFF:
				distances[nb]=distances[idx]+1
				queue.append(nb)
	var levels := PackedInt32Array()
	levels.resize(count)
	levels.fill(-1) # the original level map excludes the outer storey margin
	var end_x := width-inset
	var end_z := rows-inset
	var carved: Dictionary = {}
	for z in range(inset,end_z):
		for x in range(inset,end_x):
			var idx := z*width+x
			var here := storeys[idx]
			var smp := _sample(lo.x+x,lo.y+z)
			var residual: float = smp[0]-float(here)*STOREY_HEIGHT
			var detail := clampi(_round_mode(residual/LEVEL_HEIGHT),0,LEVELS_PER_STOREY-1)
			var cap := distances[idx]-1
			if storeys[idx-width-1]!=here or storeys[idx-width+1]!=here \
					or storeys[idx+width-1]!=here or storeys[idx+width+1]!=here:
				cap=0
			levels[idx]=clampi(mini(detail,cap),0,LEVELS_PER_STOREY-1)
			if smp[1]>3.0: carved[Vector2i(lo.x+x,lo.y+z)]=true
	# Terrace relaxation remains masked by storey; use the same row order and
	# cardinal neighbors as the dictionary reference, with contiguous storage.
	var changed := true
	while changed:
		changed=false
		for z in range(inset,end_z):
			for x in range(inset,end_x):
				var idx := z*width+x
				var here := levels[idx]
				for offset in offsets:
					var nb := idx+offset
					if levels[nb]<0 or storeys[nb]!=storeys[idx]: continue
					if here>levels[nb]+1:
						here=levels[nb]+1
						changed=true
				levels[idx]=here
	var storey_map: Dictionary = {}
	var level_map: Dictionary = {}
	for z in rows:
		for x in width:
			storey_map[Vector2i(lo.x+x,lo.y+z)]=storeys[z*width+x]
	for z in range(inset,end_z):
		for x in range(inset,end_x):
			level_map[Vector2i(lo.x+x,lo.y+z)]=levels[z*width+x]
	var result := HeightfieldRegion.new(storey_map,level_map,carved,self)
	result.certified_points = interior
	return result
