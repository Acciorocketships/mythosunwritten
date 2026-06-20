class_name HeightfieldPlan
extends RefCounted

## Deterministic, churn-free numerical terrain plan. A continuous height field
## H(cell) is quantized into integer cliff storeys and trickle-down clamped so
## adjacent cells never differ by more than one storey. The result is a pure
## function of (world_seed, cell), so a tile's planned height is final before it
## is ever instantiated — the anti-churn guarantee.
##
## Phases 1-2: storey (cliff) + level (terrace) tiers. See
## docs/superpowers/specs/2026-06-17-heightfield-terrain-design.md.

const TILE: float = 24.0
const STOREY_HEIGHT: float = 4.0
const LEVEL_HEIGHT: float = 0.5
# 4.0 / 0.5. Level saturates at LEVELS_PER_STOREY - 1 (=7), so a full storey is
# always a single cliff, never a stack of 8 level tiles.
const LEVELS_PER_STOREY: int = 8
# Search radius for the nearest different storey. Levels saturate at
# LEVELS_PER_STOREY - 1, so a cliff farther than LEVELS_PER_STOREY tiles can never
# affect a cell's level — no need to look past it.
const _CLIFF_SEARCH_MAX: int = LEVELS_PER_STOREY
const _NO_CLIFF: int = 999

var world_seed: int
var height_amplitude: float   # metres; macro field [0,1] -> [0, amplitude]
var max_storeys: int          # caps column height -> bounds clamp margin
var aggregation: String       # "min" (floor) | "mean" (nearest) | "max" (ceil)

var _raw_override: Callable = Callable()


func _init(
	p_world_seed: int,
	p_height_amplitude: float = 32.0,
	p_max_storeys: int = 8,
	p_aggregation: String = "mean"
) -> void:
	assert(p_height_amplitude > 0.0, "HeightfieldPlan: height_amplitude must be positive")
	# max_storeys is the clamp window margin; a non-positive value collapses the
	# window to a single cell and silently breaks the churn-free guarantee.
	assert(p_max_storeys > 0, "HeightfieldPlan: max_storeys must be positive")
	if not (p_aggregation == "min" or p_aggregation == "mean" or p_aggregation == "max"):
		push_warning("HeightfieldPlan: unknown aggregation '%s', defaulting to nearest (mean)" % p_aggregation)
	world_seed = p_world_seed
	height_amplitude = p_height_amplitude
	max_storeys = p_max_storeys
	aggregation = p_aggregation


## Replace the noise source with a synthetic field for tests. fn(cx, cz) -> float.
func set_raw_height_override(fn: Callable) -> void:
	_raw_override = fn


## Continuous height (metres) at a tile cell.
func raw_height(cx: int, cz: int) -> float:
	if _raw_override.is_valid():
		return _raw_override.call(cx, cz)
	var pos: Vector3 = Vector3(float(cx) * TILE, 0.0, float(cz) * TILE)
	return _height01(pos) * height_amplitude


## Layered terrain height in [0, 1]: broad landforms + rolling hills + fine
## detail (the fine octave's local gradient is what the clamp turns into cliff
## steps on steep ground). Rocky highlands rise much taller/steeper — with a
## ridged spine for mountain ranges — while meadows stay low and flat. A flat
## clearing near the world origin keeps the spawn gentle.
func _height01(pos: Vector3) -> float:
	var base: float = Helper._value_noise01(pos, world_seed, 320.0)
	var hills: float = Helper._value_noise01(pos, world_seed + 5, 120.0)
	var detail: float = Helper._value_noise01(pos, world_seed + 9, 46.0)
	var h: float = (base + hills * 0.5 + detail * 0.25) / 1.75
	var rocky: float = Helper.biome_rocky01(pos, world_seed)
	h *= 0.35 + 1.5 * rocky
	if rocky > 0.5:
		# Ridged noise (sharp peaks) for mountain spines in rocky cores.
		var n: float = Helper._value_noise01(pos, world_seed + 17, 190.0)
		var ridge: float = 1.0 - absf(2.0 * n - 1.0)
		h += ridge * ridge * (rocky - 0.5) * 0.9
	var falloff: float = clampf((Vector2(pos.x, pos.z).length() - 60.0) / 120.0, 0.0, 1.0)
	return clampf(h * falloff, 0.0, 1.0)


## Apply the aggregation rounding mode to a quotient: min=floor (hug valleys),
## max=ceil (build up), mean/unknown=nearest. Shared by storey and level quantization.
func _round_mode(q: float) -> int:
	match aggregation:
		"min":
			return floori(q)
		"max":
			return ceili(q)
		_:
			return roundi(q)


## Quantize a height (metres) to an integer storey index, clamped to [0, max_storeys].
func quantize_storey(h: float) -> int:
	return clampi(_round_mode(h / STOREY_HEIGHT), 0, max_storeys)


const _CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

## Monotone trickle-down clamp: repeatedly lower each cell to at most one storey
## above its lowest cardinal neighbour, until nothing changes. The operation
## only lowers and is bounded below by the input, so it terminates; the fixpoint
## (each cell <= min_neighbour + 1) is unique regardless of sweep order. `targets`
## maps Vector2i(cx, cz) -> storey; returns a new clamped map.
static func clamp_field(targets: Dictionary) -> Dictionary:
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
				var cap: int = out[nb] + 1
				if here > cap:
					here = cap
					changed = true
			out[cell] = here
	return out


## Clamp influence fans out one storey per tile, and storeys are capped at
## max_storeys, so a window margin of max_storeys guarantees the center cell's
## clamped value equals the global (infinite-window) result.
func storey_margin() -> int:
	return max_storeys


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
	var clamped: Dictionary = clamp_field(targets)
	return clamped[Vector2i(cx, cz)]


## Rendered surface height (metres): storey tier (4m steps) plus level tier (0.5m).
func surface_height(cx: int, cz: int) -> float:
	return float(storey_at(cx, cz)) * STOREY_HEIGHT + float(level_at(cx, cz)) * LEVEL_HEIGHT


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
## saturates at 7, so a spike settles within 7 tiles). LEVELS_PER_STOREY thus has
## one tile of spare margin — do NOT shrink it.
func level_margin() -> int:
	return LEVELS_PER_STOREY


## Final (clamped) storeys over [cx +/- radius]. Quantizes a window padded by
## max_storeys (the clamp's influence distance) so the inner `radius` storeys are
## settled, then runs the storey clamp once. Reused by level_at to avoid per-cell
## storey windows.
func _build_storey_map(cx: int, cz: int, radius: int) -> Dictionary:
	var outer: int = radius + max_storeys
	var targets: Dictionary = {}
	for dz in range(-outer, outer + 1):
		for dx in range(-outer, outer + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			targets[cell] = quantize_storey(raw_height(cell.x, cell.y))
	return clamp_field(targets)


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


## Batched region computation (storey clamp + level clamp once). `target_cache`,
## if provided, persists quantized storey targets across calls so the ~98%-
## overlapping window of a moving player is not re-sampled (the noise step
## dominates). Cliff distances use one BFS field. Returns values equal to the
## per-cell reference.
func compute_region(center_cx: int, center_cz: int, radius: int, target_cache: Dictionary = {}) -> HeightfieldRegion:
	var place_r: int = radius + 1
	var level_r: int = place_r + LEVELS_PER_STOREY
	var storey_final_r: int = level_r + _CLIFF_SEARCH_MAX
	var storey_outer: int = storey_final_r + max_storeys

	var targets: Dictionary = {}
	for dz in range(-storey_outer, storey_outer + 1):
		for dx in range(-storey_outer, storey_outer + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			var q: int
			if target_cache.has(cell):
				q = target_cache[cell]
			else:
				q = quantize_storey(raw_height(cell.x, cell.y))
				target_cache[cell] = q
			targets[cell] = q
	var storeys: Dictionary = clamp_field(targets)

	var cliff_field: Dictionary = _cliff_distance_field(storeys, _CLIFF_SEARCH_MAX)
	var l0: Dictionary = {}
	for dz in range(-level_r, level_r + 1):
		for dx in range(-level_r, level_r + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			var s: int = int(storeys[cell])
			var residual: float = raw_height(cell.x, cell.y) - float(s) * STOREY_HEIGHT
			var detail: int = clampi(_round_mode(residual / LEVEL_HEIGHT), 0, LEVELS_PER_STOREY - 1)
			var cliff_cap: int = int(cliff_field.get(cell, _NO_CLIFF)) - 1
			l0[cell] = clampi(mini(detail, cliff_cap), 0, LEVELS_PER_STOREY - 1)

	var levels: Dictionary = _clamp_levels(l0, storeys)
	return HeightfieldRegion.new(storeys, levels)
