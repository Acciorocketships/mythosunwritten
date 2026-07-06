# scripts/terrain/water/WaterPlan.gd
# Deterministic water-network plan: river sources on a coarse super-grid,
# each ascended to its local mountain/hill summit (spring pool at the top),
# traced downhill on the smooth landform field, always ending in water —
# a junction with a higher-priority river or a terminal pond. Pure function
# of (world_seed, super_cell) with bounded windows: the same anti-churn
# guarantee as HeightfieldPlan. Instance caches are performance only.
#
# Spec: docs/superpowers/specs/2026-07-04-water-rivers-lakes-design.md
#       docs/superpowers/specs/2026-07-06-water-look-and-mountain-sources-design.md
class_name WaterPlan
extends RefCounted

const SUPER := 768.0              # source super-grid pitch (32 tiles)
const TILE := 24.0
const STOREY := 4.0

const SOURCE_MIN01 := 0.55        # smooth height01 floor for a source
# Sources ASCEND to the local summit: rivers rise from mountain/hill TOPS
# (owner request), spring pool at the peak. A cell fires only when the climb
# converges on a prominent top — plateaus never qualify (they may still
# cross flat ground on the way down).
const ASCEND_STEP := 12.0         # uphill stride of the summit climb
# Climb budget caps REACH growth so REACH_SUPERS stays 4 (19*12 = 228 m —
# candidates must land within ~a quarter super-cell of their summit).
const ASCEND_MAX_STEPS := 19
const SOURCE_PEAK_EPS := 0.02     # |grad| in m/m at an accepted summit
# Cheap floor on the PRE-climb jitter point: the expensive ascent only runs
# on candidates already on meaningfully high ground (the climb budget can't
# lift lowland candidates to a qualifying peak anyway).
const SOURCE_JITTER_MIN01 := 0.42
const PROMINENCE_R := 48.0        # ring radius for the prominence test
const PROMINENCE_MIN := 0.03      # mean ring |grad| — real hills only
const SOURCE_PROB := 0.8          # fraction of qualifying super-cells that fire
const TRACE_STEP := 12.0
const MAX_STEPS := 220            # hard bound => max length 2640 u
# Gentle, long-wavelength snaking. Amplitude/wavelength must stay small
# relative to channel width or the trace switchbacks over itself: overlapping
# reaches read as blobs, the sliver between passes stays uncarved (ground
# protruding mid-river), and per-cell flow flips between reaches.
const MOMENTUM := 0.75
const MEANDER_AMP := 0.35         # radians of curve wobble (~20°)
const MEANDER_SCALE := 150.0      # along-arc metres per meander noise cell
const SELF_AVOID_R := 60.0        # steer away from own path within this range
const SELF_AVOID := 0.5           # strength of the self-repulsion blend
const SELF_AVOID_SKIP := 8        # ignore this many most-recent samples
const GRAD_EPS := 6.0             # finite-difference step for the gradient
const SENSE_RADIUS := 96.0        # junction steering bias range
const STEER := 0.35               # max blend toward sensed water
# Min half-width covers the adjacent cell CENTRE (w + FEATHER > 17u), or
# upstream reaches leave uncarved cells jutting into the channel.
const W_MIN := 9.0
const W_MAX := 16.0               # ... at max length
# Bed below the smooth terrain. MUST exceed one 4m storey + quantization
# slack (±2m), or the channel vanishes in storey rounding: floor and banks
# land on the same storey and the ribbon reads as water lying on flat grass.
const CHANNEL_DEPTH := 6.0
# Beds never sink below this: quantize_storey clamps terrain to storey >= 0,
# so a deeper bed would put the water surface underneath the rendered floor.
const BED_MIN := -1.0
# Carve lateral falloff beyond the width. Kept under half a tile so the
# partial-carve band can't dither cells across the storey-rounding threshold
# (alternating poke/submerge plates along the channel edges).
const FEATHER := 8.0
# Spring-pool radius. SMALL on purpose: the pool level clamps to the minimum
# ground under footprint∪ring, so a wide pool on a peaked summit reads that
# minimum far downhill and carves a crater lake into the mountain instead of
# a tarn nestled at the top (seen on the pinned review seed).
const SOURCE_POOL_R := 26.0
const POOL_DEPTH := 2.5
const POND_R_MIN := 60.0
const POND_R_MAX := 140.0
const POND_DEPTH := 3.5
const FLAT_EPS := 0.012           # |grad| (m/m) below which a basin ends the trace
# Basins/lowlands may only end a river after this many steps (~1.4 km): flat
# ground keeps the trace meandering (bed simply stays level), so rivers are
# LONG winding channels, not short chutes into the first hollow.
const MIN_STEPS := 120
const LOWLANDS01 := 0.08          # smooth height01 floor => terminal pond
const SPAWN_WATER_RADIUS := 200.0 # dry spawn disk (spawn clear 60+120 + margin)
const JOIN_DEPTH := 2             # junction dependency recursion cap
# Any point a river can influence lies within the summit ascent + the trace
# length + the largest pond bound + carve feather of its source's JITTER
# point ⇒ a fixed super-cell ring.
const REACH := ASCEND_MAX_STEPS * ASCEND_STEP + MAX_STEPS * TRACE_STEP \
	+ POND_R_MAX * (1.0 + PondStamp.WOBBLE) + FEATHER
const REACH_SUPERS := int(ceil(REACH / SUPER))   # = 4

var world_seed: int
var amplitude: float
var max_storeys: int

var _trace_cache: Dictionary = {}    # Vector3i(sc.x, sc.y, depth) -> RiverTrace | null
var _source_pos_cache: Dictionary = {}   # Vector2i -> Vector2 (summit-ascended)
var _has_source_cache: Dictionary = {}   # Vector2i -> bool


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


## Deterministic hill-climb on the smooth field: fixed stride uphill, halving
## on overshoot, until the gradient flattens (summit) or the budget runs out.
func _ascend(start: Vector2) -> Vector2:
	var p: Vector2 = start
	var step: float = ASCEND_STEP
	var h: float = smooth_h(p)
	for i in ASCEND_MAX_STEPS:
		var g: Vector2 = grad(p)
		if g.length() < SOURCE_PEAK_EPS * 0.5:
			break
		var q: Vector2 = p + g.normalized() * step
		var hq: float = smooth_h(q)
		if hq <= h:
			step *= 0.5   # overshot the summit — tighten the stride
			if step < 1.0:
				break
			continue
		p = q
		h = hq
	return p


## Mean gradient magnitude on a ring around p — summit prominence: real
## mountain/hill tops have steep flanks; plateau tops read ~0 and never fire.
func _ring_prominence(p: Vector2) -> float:
	var acc: float = 0.0
	for i in 8:
		acc += grad(p + Vector2.from_angle(TAU * float(i) / 8.0) * PROMINENCE_R).length()
	return acc / 8.0


## The jittered pre-climb candidate point inside the super-cell.
func _jitter_pos(sc: Vector2i) -> Vector2:
	var jx: float = Helper._hash01(_hash_cell(sc, 101))
	var jz: float = Helper._hash01(_hash_cell(sc, 102))
	return Vector2((float(sc.x) + jx) * SUPER, (float(sc.y) + jz) * SUPER)


## Source point for a super-cell: the jittered candidate ascended to its
## local summit. Pure function of (seed, cell); cached per instance.
func source_pos(sc: Vector2i) -> Vector2:
	if _source_pos_cache.has(sc):
		return _source_pos_cache[sc]
	var p: Vector2 = _ascend(_jitter_pos(sc))
	_source_pos_cache[sc] = p
	return p


## Zero or one river source per super-cell: the ascended candidate must be a
## genuine summit (converged climb, prominent ring) on high smooth ground,
## outside the spawn ring, and win a density roll. HOT during region builds
## (every super-cell in reach is asked, per depth) — cached, and gated
## cheap-first so the climb only ever runs on plausibly-high candidates.
func has_source(sc: Vector2i) -> bool:
	if _has_source_cache.has(sc):
		return _has_source_cache[sc]
	var ok: bool = _has_source_uncached(sc)
	_has_source_cache[sc] = ok
	return ok


func _has_source_uncached(sc: Vector2i) -> bool:
	if Helper._hash01(_hash_cell(sc, 103)) >= SOURCE_PROB:
		return false   # density roll — free, kills 20% before any noise eval
	var j: Vector2 = _jitter_pos(sc)
	if j.length() < SPAWN_WATER_RADIUS:
		return false   # summit position re-checked below; this skips the climb
	if smooth01(j) < SOURCE_JITTER_MIN01:
		return false   # lowland candidate — the climb budget can't save it
	var p: Vector2 = source_pos(sc)
	if p.length() < SPAWN_WATER_RADIUS:
		return false
	if smooth01(p) < SOURCE_MIN01:
		return false
	if grad(p).length() >= SOURCE_PEAK_EPS:
		return false   # never converged — a vast flank; another cell owns this summit
	return _ring_prominence(p) >= PROMINENCE_MIN   # plateau tops never fire


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
		if i >= MIN_STEPS and g.length() < FLAT_EPS:
			break                                   # basin floor (late only)
		if i >= MIN_STEPS and smooth01(p) < LOWLANDS01:
			break                                   # lowlands (late only)
		var down: Vector2 = (-g).normalized() if g.length() > 0.000001 else dir
		dir = (dir * MOMENTUM + down * (1.0 - MOMENTUM)).normalized()
		var m01: float = Helper._value_noise01(
			Vector3(arc, 0.0, meander_offset), world_seed + 71, MEANDER_SCALE)
		dir = dir.rotated((m01 - 0.5) * 2.0 * MEANDER_AMP)
		# Self-avoidance: repel from the river's own OLDER samples so meanders
		# never fold back onto an earlier reach (overlapping channels left
		# uncarved slivers mid-river and flipped per-cell flow directions).
		var rep: Vector2 = Vector2.ZERO
		for k in range(0, t.points.size() - SELF_AVOID_SKIP):
			var sd: float = p.distance_to(t.points[k])
			if sd < SELF_AVOID_R:
				rep += (p - t.points[k]) / maxf(sd, 1.0)
		if rep.length_squared() > 0.000001:
			dir = (dir + rep.normalized() * SELF_AVOID).normalized()
		dir = _steer(dir, p, others)
		var q: Vector2 = p + dir * TRACE_STEP
		if q.length() < SPAWN_WATER_RADIUS:
			break                                   # truncate at the spawn ring
		p = q
		arc += TRACE_STEP
		bed = maxf(minf(bed, smooth_h(p) - CHANNEL_DEPTH), BED_MIN)
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


## Water bodies overlapping a cell window (for surface meshing + volumes).
## Returns {"ponds": Array[PondStamp], "rivers": Array[RiverTrace]} — rivers
## come whole (the builder clips); ponds include source pools. The window may
## straddle super-cell borders, so it unions the regions of every super-cell
## the window's corners fall in (≤4 for a window ≤ SUPER) and dedupes by source.
func bodies_near(center_cell: Vector2i, radius_cells: int) -> Dictionary:
	var world_r: float = float(radius_cells + 1) * TILE
	assert(world_r * 2.0 <= SUPER, "bodies_near window exceeds one super-cell — widen the union first")
	var centre: Vector2 = Vector2(float(center_cell.x), float(center_cell.y)) * TILE
	var window: Rect2 = Rect2(centre - Vector2.ONE * world_r, Vector2.ONE * world_r * 2.0)
	var corners: Array = [
		window.position,
		window.position + Vector2(window.size.x, 0.0),
		window.position + Vector2(0.0, window.size.y),
		window.position + window.size,
	]
	var super_cells: Dictionary = {}
	for corner in corners:
		super_cells[Vector2i(int(floor(corner.x / SUPER)), int(floor(corner.y / SUPER)))] = true
	var seen: Dictionary = {}
	var ponds: Array = []
	var rivers: Array = []
	for rc in super_cells.keys():
		for t in _region_for(rc).rivers:
			if seen.has(t.source_cell):
				continue
			if not t.bounds().grow(FEATHER).intersects(window):
				continue
			seen[t.source_cell] = true
			rivers.append(t)
			if t.source_pool != null:
				ponds.append(t.source_pool)
			if t.pond != null:
				ponds.append(t.pond)
	return {"ponds": ponds, "rivers": rivers}
