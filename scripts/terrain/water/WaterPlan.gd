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
