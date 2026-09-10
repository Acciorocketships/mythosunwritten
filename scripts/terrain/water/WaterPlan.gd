# scripts/terrain/water/WaterPlan.gd
# Deterministic water-network plan: river sources on a coarse super-grid,
# each ascended to its local mountain/hill summit (spring pool at the top),
# traced along descending contours, always ending in water —
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

const SOURCE_MIN01 := 0.48        # smooth height01 floor for a source
# Sources ASCEND to the local summit: rivers rise from mountain/hill TOPS
# (owner request), spring pool at the peak. A cell fires only when the climb
# converges on a prominent top — plateaus never qualify (they may still
# cross flat ground on the way down).
const ASCEND_STEP := 12.0         # uphill stride of the summit climb
# The finite climb is included in the source-discovery bound.
const ASCEND_MAX_STEPS := 32
const SOURCE_PEAK_EPS := 0.02     # |grad| in m/m at an accepted summit
# Cheap floor on the PRE-climb jitter point: the expensive ascent only runs
# on candidates already on meaningfully high ground (the climb budget can't
# lift lowland candidates to a qualifying peak anyway).
const SOURCE_JITTER_MIN01 := 0.32
const PROMINENCE_R := 48.0        # ring radius for the prominence test
const PROMINENCE_MIN := 0.03      # mean ring |grad| — real hills only
const SOURCE_PROB := 0.85          # fraction of qualifying super-cells that fire
const TRACE_STEP := 12.0
const MAX_STEPS := 360            # hard bound => max arc length 4320 m
# A bounded contour walk: prefer a small descent along the mountain's side,
# retain a winding handedness, and reserve space around previously visited
# reaches. The hydraulic bed remains monotone and bank-contained independently.
const CONTOUR_DESCENT := 0.22
const MEANDER_AMP := 0.25
const MEANDER_SCALE := 180.0
const STEEP_HI := 0.10
const SELF_AVOID_R := 76.0
const SELF_AVOID_SKIP := 10
# Arc length may grow without growing the source-discovery dependency halo.
const TRACE_REACH := 2400.0
const GRAD_EPS := 6.0             # finite-difference step for the gradient
const SENSE_RADIUS := 96.0        # conservative junction lookup halo
const _NEIGHBOUR_INDEX_CELL := SENSE_RADIUS
# Full-depth core exceeds half a terrain-cell diagonal (16.97m). Both
# bridge cells at a diagonal crossing therefore excavate fully, keeping a
# finite cardinal connection instead of two wet tiles touching at a corner.
const W_MIN := 20.0
const W_MAX := 26.0               # ... at max length
# Bed below the smooth terrain. MUST exceed one 4m storey + quantization
# slack (±2m), or the channel vanishes in storey rounding: floor and banks
# land on the same storey and the ribbon reads as water lying on flat grass.
const CHANNEL_DEPTH := 6.0
# Bathymetry is deliberately deeper than the hydraulic trace bed.  `beds`
# anchors the continuous water profile; changing CHANNEL_DEPTH therefore
# moves/spreads the surface as well as excavating terrain.  The reported
# river edge instead needs more clearance beneath the SAME smooth surface.
# Two extra metres crosses the 4m storey quantizer's half-storey threshold
# at the pinned shallow cell while remaining inside the existing channel
# footprint and the terrain's BED_MIN floor.
const CARVE_BED_EXTRA := 2.0
# One storey per trace step is already a fall face rather than an ordinary
# swimmable reach.  Do not turn those deliberately thin sheets into deep
# vertical swim volumes when adding bathymetry.
const CARVE_EXTRA_MAX_GRADE := STOREY / TRACE_STEP
# CONTAINMENT: the bed must also quantize a full storey below the LOWEST
# flanking bank's natural storey — smooth-relative depth alone is not enough
# on slopes and at cliff lips, where the downhill bank quantizes level with
# (or below) the floor and the water has no wall on that side: sheets hanging
# off hillsides (owner: "a plane of water hanging off the side of a cliff…
# cut deep enough that there is a channel bounded on both sides"). 4.5 =
# one storey + rounding margin: floor storey lands ≥ 1 below both banks and
# the surface (floor + 0.8, bed + 1.5) stays ≥ ~3m under the bank tops.
const CONTAIN_DROP := 4.5
# Beds never sink below this: quantize_storey clamps terrain to storey >= 0,
# so a deeper bed would put the water surface underneath the rendered floor.
const BED_MIN := -1.0
# Carve lateral falloff beyond the width. Kept under half a tile so the
# partial-carve band can't dither cells across the storey-rounding threshold
# (alternating poke/submerge plates along the channel edges).
const FEATHER := 8.0
# The hydraulic containment survey and route spacing retain FEATHER. Terrain
# banks occupy a wider, finite collar so normal ground slopes can reach water.
const BANK_FEATHER := 96.0
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
# Basins/lowlands may only end a river after this many steps (~2.6 km): flat
# ground keeps the trace meandering (bed simply stays level), so rivers are
# LONG winding channels, not short chutes into the first hollow.
const MIN_STEPS := 220
const LOWLANDS01 := 0.08          # smooth height01 floor => terminal pond
const SPAWN_WATER_RADIUS := 200.0 # dry spawn disk (spawn clear 60+120 + margin)
const JOIN_DEPTH := 2             # junction dependency recursion cap
# Route planning deliberately sees a slightly wider version of the source
# geometry than the rendered-water seed. Exact validation still reads the
# hydrostatic field through WaterFieldContext.
const PATH_WATER_GUARD := 6.0
const PATH_QUERY_MAX := SUPER
const PATH_INTERVAL_TOLERANCE := 0.05
const PLANNING_DISTANCE_LIPSCHITZ := 2.0
const _PATH_INSIDE_EPS := 0.0001
# Any point a river can influence lies within the summit ascent + the trace
# displacement + the largest pond bound + carve feather of its source's JITTER
# point ⇒ a fixed super-cell ring.
const REACH := ASCEND_MAX_STEPS * ASCEND_STEP + TRACE_REACH \
	+ POND_R_MAX * (1.0 + PondStamp.WOBBLE) + BANK_FEATHER
const REACH_SUPERS := int(ceil(REACH / SUPER))   # = 4

var world_seed: int
var amplitude: float
var max_storeys: int

var _trace_cache: Dictionary = {}    # Vector3i(sc.x, sc.y, depth) -> RiverTrace | null
var _source_pos_cache: Dictionary = {}   # Vector2i -> Vector2 (summit-ascended)
var _has_source_cache: Dictionary = {}   # Vector2i -> bool
## Optional worker-thread observer used only by startup progress reporting.
## It receives the completed fraction of the currently cold region's fixed
## source-candidate sweep; it never changes planning output or cache order.
var _planning_progress_callback := Callable()
var _planning_progress_last := -1.0


func _init(p_world_seed: int, p_amplitude: float, p_max_storeys: int) -> void:
	world_seed = p_world_seed
	amplitude = p_amplitude
	max_storeys = p_max_storeys


func set_planning_progress_callback(callback: Callable) -> void:
	_planning_progress_callback = callback


func _report_planning_progress(progress: float, force := false) -> void:
	progress = clampf(progress, 0.0, 1.0)
	# A cold trace tree contains many thousands of deterministic sub-steps. Keep
	# enough resolution for a smooth bar without taking the mutex for every
	# individual river sample.
	if not force and _planning_progress_last >= 0.0 \
		and progress - _planning_progress_last < 0.001:
		return
	_planning_progress_last = progress
	if _planning_progress_callback.is_valid():
		_planning_progress_callback.call(progress)


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
	# Survey four stratified candidates before climbing the highest. A single
	# random foothill used to reject a whole 768m mountain district.
	var best := Vector2.ZERO
	var best_h := -INF
	for i in 4:
		var jx := (float(i % 2) + Helper._hash01(_hash_cell(sc, 101 + i * 17))) * 0.5
		var jz := (float(i / 2) + Helper._hash01(_hash_cell(sc, 102 + i * 17))) * 0.5
		var p := (Vector2(sc) + Vector2(jx, jz)) * SUPER
		var h := smooth01(p)
		if h > best_h:
			best = p
			best_h = h
	return best


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
		return false   # density roll before the summit survey
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
func river_for(sc: Vector2i, depth: int = JOIN_DEPTH,
		progress_start := -1.0, progress_end := -1.0) -> RiverTrace:
	var key: Vector3i = Vector3i(sc.x, sc.y, depth)
	if _trace_cache.has(key):
		if progress_start >= 0.0:
			_report_planning_progress(progress_end)
		return _trace_cache[key]
	var t: RiverTrace = _trace(sc, depth, progress_start, progress_end)
	_trace_cache[key] = t
	if progress_start >= 0.0:
		_report_planning_progress(progress_end)
	return t


func _make_pool(p: Vector2) -> PondStamp:
	return PondStamp.new(p, SOURCE_POOL_R, _hash_cell(Vector2i(roundi(p.x), roundi(p.y)), 7),
		_pond_level(p, SOURCE_POOL_R), POOL_DEPTH)


func _make_pond(p: Vector2, arc: float, incoming_bed := INF) -> PondStamp:
	var shape_seed := _hash_cell(Vector2i(roundi(p.x), roundi(p.y)), 8)
	var maturity := clampf(arc / (MAX_STEPS * TRACE_STEP), 0.0, 1.0)
	var size_roll := Helper._hash01(Helper._mix64(shape_seed + 19))
	var r := lerpf(POND_R_MIN, POND_R_MAX, maturity * (0.35 + 0.65 * size_roll))
	var pond := PondStamp.new(p, r, shape_seed, _pond_level(p, r), POND_DEPTH)
	# A contour trace may excavate through naturally higher land after its bed
	# has descended. The receiving lake cannot lift that entire river back up.
	# PondStamp applies this same datum to the terrain carve and water surface.
	pond.surface_ceiling = incoming_bed + WaterField.SURFACE_RIDE
	pond.aspect_ratio = lerpf(0.5, 0.9, Helper._hash01(Helper._mix64(shape_seed + 23)))
	if r >= 85.0:
		var geology := Helper._hash01(Helper._mix64(shape_seed + 29))
		if geology < 0.65:
			pond.island_radius = maxf(24.0, r * 0.24)
			var angle := Helper._hash01(Helper._mix64(shape_seed + 31)) * TAU
			pond.island_offset = Vector2.from_angle(angle) * r * 0.24
			pond.peninsula = geology < 0.25
	return pond


## Bank storey for a pond at p: storey-quantized minimum of the PRE-CARVE
## rendered field over the footprint ∪ one-tile ring. Endpoints already sit in
## local lows, so this is a safety clamp guaranteeing water below its banks.
## FLOOR, never round: rounding UP put the level (and so the surface) half a
## storey above the lowest rim ground — the whole pool overtopped its banks
## and spilled a waterfall on every side (summit tarns especially).
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
	return clampi(int(floor(min_h / STOREY)), 1, max_storeys)


## One deterministic downhill trace. `depth` controls junction awareness:
## _neighbour_rivers returns [] at depth 0, so raw traces ignore other water.
func _trace(sc: Vector2i, depth: int,
		progress_start := -1.0, progress_end := -1.0) -> RiverTrace:
	if not has_source(sc):
		return null
	if depth > 0:
		return _joined_trace(sc, depth, progress_start, progress_end)
	var t: RiverTrace = RiverTrace.new()
	t.source_cell = sc
	t.priority = priority_of(sc)
	var p: Vector2 = source_pos(sc)
	t.source_pool = _make_pool(p)
	var meander_offset: float = float(absi(t.priority) % 4096) * 37.0
	var dir: Vector2 = Vector2.from_angle(Helper._hash01(_hash_cell(sc, 104)) * TAU)
	var g0: Vector2 = grad(p)
	if g0.length() > 0.000001:
		dir = (-g0).normalized()
	var bed: float = _contained_bed(INF, p, dir, W_MIN)
	var arc: float = 0.0
	var visited: Dictionary = {}
	var source := p
	var handedness := -1.0 if _hash_cell(sc, 107) < 0 else 1.0
	for i in MAX_STEPS:
		if progress_start >= 0.0 and i % 8 == 0:
			_report_planning_progress(lerpf(progress_start, progress_end,
				float(i) / float(MAX_STEPS)))
		var bucket := Vector2i((p / SELF_AVOID_R).floor())
		if not visited.has(bucket):
			visited[bucket] = []
		visited[bucket].append(t.points.size())
		t.points.append(p)
		t.beds.append(bed)
		t.widths.append(lerpf(W_MIN, W_MAX, arc / (MAX_STEPS * TRACE_STEP)))
		var g: Vector2 = grad(p)
		if i >= MIN_STEPS and g.length() < FLAT_EPS:
			break                                   # basin floor (late only)
		if i >= MIN_STEPS and smooth01(p) < LOWLANDS01:
			break                                   # lowlands (late only)
		var next := _contour_step(t, visited, p, dir, g, source, arc,
			meander_offset, handedness)
		if next == Vector2.INF:
			break
		dir = (next - p).normalized()
		p = next
		arc += TRACE_STEP
		bed = _contained_bed(bed, p, dir, lerpf(W_MIN, W_MAX, arc / (MAX_STEPS * TRACE_STEP)))
	t.pond = _make_pond(p, arc, t.beds[-1])
	return t


## Plan the expensive contour walk once. Junction resolution only selects a
## prefix of that immutable walk; neighbour recursion cannot reroute a mountain
## or multiply all of its terrain probes at every dependency depth.
func _joined_trace(sc: Vector2i, depth: int, progress_start: float,
		progress_end: float) -> RiverTrace:
	var raw := river_for(sc, 0)
	var others := _neighbour_rivers(sc, depth, progress_start, progress_end)
	var index := _index_neighbour_rivers(others)
	for i in raw.points.size():
		if _join_target(raw.points[i], raw.beds[i], index) == null:
			continue
		var t := RiverTrace.new()
		t.source_cell = raw.source_cell
		t.priority = raw.priority
		t.source_pool = raw.source_pool
		t.points = raw.points.slice(0, i + 1)
		t.beds = raw.beds.slice(0, i + 1)
		t.widths = raw.widths.slice(0, i + 1)
		t.joined = true
		return t
	return raw


## Score a finite fan of open-air steps, like a maze walk with occupied
## corridors. Level travel wins over rushing downhill; uphill excavation is
## expensive, and old reaches/spawn/the finite planning boundary are hard walls.
func _contour_step(t: RiverTrace, visited: Dictionary, p: Vector2,
		dir: Vector2, g: Vector2, source: Vector2, arc: float,
		phase: float, hand: float) -> Vector2:
	var down := -g.normalized() if g.length_squared() > 0.000001 else dir
	var contour := down.rotated(hand * acos(CONTOUR_DESCENT))
	var strength := clampf(g.length() / STEEP_HI, 0.0, 1.0)
	# Outside the summit's first bend, a broad outward potential carries the
	# river through successive lowland basins instead of orbiting one hollow.
	var outward := (p - source).normalized() if p.distance_to(source) > TILE else dir
	var preferred := outward.lerp(contour, strength * 0.75).normalized()
	var wobble := Helper._value_noise01(Vector3(arc + phase, 0, 0),
		world_seed + 71, MEANDER_SCALE) * 2.0 - 1.0
	preferred = preferred.rotated(wobble * MEANDER_AMP)
	var height := smooth_h(p)
	var best := Vector2.INF
	var best_score := INF
	var nearby: Array[Vector2] = []
	var lo := Vector2i(((p - Vector2.ONE * (SELF_AVOID_R + TRACE_STEP)) / SELF_AVOID_R).floor())
	var hi := Vector2i(((p + Vector2.ONE * (SELF_AVOID_R + TRACE_STEP)) / SELF_AVOID_R).floor())
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			for k: int in visited.get(Vector2i(x, z), []):
				if k < t.points.size() - SELF_AVOID_SKIP:
					nearby.append(t.points[k])
	for turn in range(-6, 7):
		var heading := dir.rotated(float(turn) * PI / 12.0)
		var q := p + heading * TRACE_STEP
		if q.length() < SPAWN_WATER_RADIUS + SOURCE_POOL_R \
			or q.distance_to(source) > TRACE_REACH:
			continue
		# A gentle outward drift leaves room for the next turn around the hill.
		# It prevents the contour walk from sealing itself inside its first loop.
		if p.distance_to(source) > TILE * 4.0 and heading.dot(outward) < 0.15:
			continue
		var clearance := SELF_AVOID_R
		for old: Vector2 in nearby:
			clearance = minf(clearance, q.distance_to(old))
		if clearance < W_MAX * 2.0 + FEATHER:
			continue
		var change := smooth_h(q) - height
		var desired_drop := g.length() * TRACE_STEP * CONTOUR_DESCENT
		var score := absf(change + desired_drop) * 2.0 \
			+ maxf(change, 0.0) * 3.0 + (1.0 - heading.dot(preferred)) * 3.0 \
			+ (1.0 - clearance / SELF_AVOID_R) * 3.0
		if score < best_score:
			best_score = score
			best = q
	return best


## Bed candidate at p: CHANNEL_DEPTH under the smooth field, ALSO capped a
## full storey below the lowest flanking bank (CONTAIN_DROP — the channel
## must survive storey quantization bounded by ground on both sides),
## monotone via prev, floored at BED_MIN. Banks are the natural pre-carve
## field just past the carve feather on each side of the flow, sampled at two
## rings so a cell-centre never slips between the probes.
func _contained_bed(prev_bed: float, p: Vector2, dir: Vector2, half_w: float) -> float:
	var n: Vector2 = Vector2(-dir.y, dir.x)
	var d0: float = half_w + FEATHER + TILE * 0.5
	var bank: float = INF
	for off in [n * d0, -n * d0, n * (d0 + TILE), -n * (d0 + TILE)]:
		bank = minf(bank, roundf(noise_h(p + off) / STOREY) * STOREY)
	return maxf(minf(minf(prev_bed, smooth_h(p) - CHANNEL_DEPTH), bank - CONTAIN_DROP), BED_MIN)


## Higher-priority rivers within junction reach of sc's river, each resolved
## one depth lower. Depth 0 = raw trace (sees nothing) — the recursion floor.
## Every trace is cached by (cell, depth), so the fan-out is bounded by the
## number of distinct super-cells within REACH_SUPERS rings per depth level.
func _neighbour_rivers(sc: Vector2i, depth: int,
		progress_start := -1.0, progress_end := -1.0) -> Array:
	if depth <= 0:
		if progress_start >= 0.0:
			_report_planning_progress(progress_end)
		return []
	var mine: int = priority_of(sc)
	var mine_bounds := river_for(sc, 0).bounds().grow(SENSE_RADIUS + W_MAX)
	var out: Array = []
	var side := REACH_SUPERS * 4 + 1
	var total := side * side
	var done := 0
	for dz in range(-REACH_SUPERS * 2, REACH_SUPERS * 2 + 1):
		for dx in range(-REACH_SUPERS * 2, REACH_SUPERS * 2 + 1):
			var nb: Vector2i = sc + Vector2i(dx, dz)
			var child_start := lerpf(progress_start, progress_end,
				float(done) / float(total)) if progress_start >= 0.0 else -1.0
			done += 1
			var child_end := lerpf(progress_start, progress_end,
				float(done) / float(total)) if progress_start >= 0.0 else -1.0
			if nb == sc or priority_of(nb) <= mine:
				if progress_start >= 0.0:
					_report_planning_progress(child_end)
				continue
			var raw := river_for(nb, 0)
			if raw == null or not raw.bounds().intersects(mine_bounds):
				if progress_start >= 0.0:
					_report_planning_progress(child_end)
				continue
			var t: RiverTrace = river_for(nb, depth - 1,
				child_start, child_end)
			if t != null:
				out.append(t)
	return out


## The higher-priority river whose water p lands in, or null. A join needs
## the target's bed at the touch point to be at-or-below ours (+0.5 m slack)
## — water never joins uphill. Pond/pool footprints count as their river.
func _join_target(p: Vector2, bed: float,
		index: Dictionary) -> RiverTrace:
	var others: Array = index.rivers
	var first_match := others.size()
	# Pools and ponds are few and can be substantially wider than the point
	# index cell.  Keep their exact source-order precedence while the channel
	# samples use the local index below.
	for other_index in others.size():
		var other := others[other_index] as RiverTrace
		if other.source_pool != null and other.source_pool.footprint_t(p) < 1.0 \
				and other.source_pool.surface_y() <= bed + 0.5:
			first_match = other_index
			break
		if other.pond != null and other.pond.footprint_t(p) < 1.0 \
				and other.pond.surface_y() <= bed + 0.5:
			first_match = other_index
			break
	for entry: Vector3i in _nearby_neighbour_points(index, p, W_MAX):
		if entry.x >= first_match:
			continue
		var other := others[entry.x] as RiverTrace
		var point := other.points[entry.y] as Vector2
		var width := float(other.widths[entry.y])
		if p.distance_squared_to(point) <= width * width \
				and float(other.beds[entry.y]) <= bed + 0.5:
			first_match = entry.x
	return others[first_match] as RiverTrace if first_match < others.size() \
		else null


func _index_neighbour_rivers(others: Array) -> Dictionary:
	var buckets: Dictionary = {}
	var order := 0
	for other_index in others.size():
		var other := others[other_index] as RiverTrace
		for point_index in other.points.size():
			var point := other.points[point_index] as Vector2
			var cell := Vector2i(floori(point.x / _NEIGHBOUR_INDEX_CELL),
				floori(point.y / _NEIGHBOUR_INDEX_CELL))
			if not buckets.has(cell):
				buckets[cell] = []
			buckets[cell].append(Vector3i(other_index, point_index, order))
			order += 1
	return {"rivers": others, "buckets": buckets}


func _nearby_neighbour_points(index: Dictionary, p: Vector2,
		radius: float) -> Array[Vector3i]:
	var buckets := index.buckets as Dictionary
	var lo := Vector2i(floori((p.x - radius) / _NEIGHBOUR_INDEX_CELL),
		floori((p.y - radius) / _NEIGHBOUR_INDEX_CELL))
	var hi := Vector2i(floori((p.x + radius) / _NEIGHBOUR_INDEX_CELL),
		floori((p.y + radius) / _NEIGHBOUR_INDEX_CELL))
	var out: Array[Vector3i] = []
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			out.append_array(buckets.get(Vector2i(x, z), []) as Array)
	return out


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
		Vector2(float(rc.x), float(rc.y)) * SUPER, Vector2(SUPER, SUPER)).grow(BANK_FEATHER + W_MAX)
	var rivers: Array = []
	var buckets: Dictionary = {}
	# +1 ring: a source within REACH of a cell inside this super-cell can sit
	# up to REACH + SUPER·√2 from the super-cell's own corner.
	var candidate_side := (REACH_SUPERS + 1) * 2 + 1
	var candidate_total := candidate_side * candidate_side
	var candidate_done := 0
	_planning_progress_last = -1.0
	_report_planning_progress(0.0, true)
	for dz in range(-(REACH_SUPERS + 1), REACH_SUPERS + 2):
		for dx in range(-(REACH_SUPERS + 1), REACH_SUPERS + 2):
			var candidate_start := float(candidate_done) / float(candidate_total)
			candidate_done += 1
			var candidate_end := float(candidate_done) / float(candidate_total)
			var sc := rc + Vector2i(dx, dz)
			# Junctions only shorten this immutable route. Reject its raw bounds
			# before expanding neighbour dependencies for a distant source.
			var raw := river_for(sc, 0)
			if raw == null or not raw.bounds().grow(BANK_FEATHER).intersects(region_rect):
				_report_planning_progress(candidate_end)
				continue
			var t: RiverTrace = river_for(sc, JOIN_DEPTH, candidate_start, candidate_end)
			if not t.bounds().grow(BANK_FEATHER).intersects(region_rect):
				continue
			rivers.append(t)
			for i in t.points.size():
				var infl: float = t.widths[i] + BANK_FEATHER
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
	_report_planning_progress(1.0, true)
	return out


## Signed radial clearance from the guarded river/pond source footprint.
## Negative is inside. This is the cheap planning approximation; it never
## builds the hydrostatic fill or a shoreline contour.
func planning_signed_distance(point: Vector2) -> float:
	assert(is_finite(point.x) and is_finite(point.y))
	var rc := Vector2i(int(floor(point.x / SUPER)), int(floor(point.y / SUPER)))
	var region: Dictionary = _region_for(rc)
	var best := PATH_QUERY_MAX
	for pond: PondStamp in region.ponds:
		var from_centre := point - pond.center
		var radius := pond.radius_at(atan2(from_centre.y, from_centre.x))
		best = minf(best, (pond.footprint_t(point) - 1.0) * radius - PATH_WATER_GUARD)
	for trace: RiverTrace in region.rivers:
		if trace.points.size() == 1:
			best = minf(best, point.distance_to(trace.points[0])
				- trace.widths[0] - PATH_WATER_GUARD)
			continue
		for i in trace.points.size() - 1:
			var a := trace.points[i]
			var delta := trace.points[i + 1] - a
			var length_squared := delta.length_squared()
			var along := clampf((point - a).dot(delta) / length_squared, 0.0, 1.0) \
				if length_squared > 0.000001 else 0.0
			var width := lerpf(trace.widths[i], trace.widths[i + 1], along)
			best = minf(best, point.distance_to(a + delta * along)
				- width - PATH_WATER_GUARD)
	return best


## Sorted, disjoint guarded-source intervals along a->b, expressed as t in
## [0,1]. Adaptive subdivision uses the distance field's conservative
## Lipschitz bound, so even a sub-sample-width tangent cannot be skipped.
func planning_intervals(a: Vector2, b: Vector2) -> Array[Vector2]:
	assert(is_finite(a.x) and is_finite(a.y) and is_finite(b.x) and is_finite(b.y))
	var delta := b - a
	var length := delta.length()
	assert(length <= PATH_QUERY_MAX,
		"Planning water segment exceeds the supported %.1fm look-ahead" % PATH_QUERY_MAX)
	if length <= 0.000001:
		return [Vector2.ZERO] if planning_signed_distance(a) <= _PATH_INSIDE_EPS else []

	var samples: Array[Vector2] = [Vector2(0.0, planning_signed_distance(a))]
	_append_planning_samples(a, delta, length, 0.0, samples[0].y,
		1.0, planning_signed_distance(b), samples, 0)
	var intervals: Array[Vector2] = []
	var threshold := _PATH_INSIDE_EPS
	var inside := samples[0].y <= threshold
	var enter := 0.0 if inside else -1.0
	for i in range(1, samples.size()):
		var next_inside := samples[i].y <= threshold
		if next_inside != inside:
			var crossing := _refine_planning_boundary(a, delta, length,
				samples[i - 1], samples[i], threshold, inside)
			if next_inside:
				enter = crossing
			else:
				_append_planning_interval(intervals, Vector2(enter, crossing), length)
				enter = -1.0
		inside = next_inside
	if inside:
		_append_planning_interval(intervals, Vector2(enter, 1.0), length)
	return intervals


func _append_planning_samples(a: Vector2, delta: Vector2, length: float,
		t0: float, d0: float, t1: float, d1: float,
		out: Array[Vector2], depth: int) -> void:
	assert(depth < 24, "Planning water interval refinement exceeded its fixed bound")
	var world_span := (t1 - t0) * length
	if minf(d0, d1) > PLANNING_DISTANCE_LIPSCHITZ * world_span + PATH_INTERVAL_TOLERANCE:
		out.append(Vector2(t1, d1))
		return
	if maxf(d0, d1) < -PLANNING_DISTANCE_LIPSCHITZ * world_span - PATH_INTERVAL_TOLERANCE:
		out.append(Vector2(t1, d1))
		return
	var tm := (t0 + t1) * 0.5
	var dm := planning_signed_distance(a + delta * tm)
	if world_span <= PATH_INTERVAL_TOLERANCE:
		out.append(Vector2(tm, dm))
		out.append(Vector2(t1, d1))
		return
	_append_planning_samples(a, delta, length, t0, d0, tm, dm, out, depth + 1)
	_append_planning_samples(a, delta, length, tm, dm, t1, d1, out, depth + 1)


func _refine_planning_boundary(a: Vector2, delta: Vector2, length: float,
		lo_sample: Vector2, hi_sample: Vector2, threshold: float,
		lo_inside: bool) -> float:
	var lo := lo_sample.x
	var hi := hi_sample.x
	while (hi - lo) * length > PATH_INTERVAL_TOLERANCE:
		var mid := (lo + hi) * 0.5
		var mid_inside := planning_signed_distance(a + delta * mid) <= threshold
		if mid_inside == lo_inside:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


static func _append_planning_interval(out: Array[Vector2], interval: Vector2,
		length: float) -> void:
	var t_tolerance := PATH_INTERVAL_TOLERANCE / maxf(length, PATH_INTERVAL_TOLERANCE)
	if not out.is_empty() and interval.x <= out[-1].y + t_tolerance:
		out[-1] = Vector2(out[-1].x, maxf(out[-1].y, interval.y))
	else:
		out.append(interval)


# Keep waterfalls and their abutments on the established narrow channel
# profile. Only reaches separated from a steep descent receive broad banks;
# the transition is continuous and determined before any chunk is meshed.
const BANK_GENTLE_GRADE := 0.05
const BANK_PROFILE_CACHE_LIMIT := 64
var _bank_strength_cache: Dictionary = {}

func bank_strengths(trace: RiverTrace) -> PackedFloat64Array:
	var key := trace.get_instance_id()
	if _bank_strength_cache.has(key): return _bank_strength_cache[key]
	var steep: Array[Vector2i] = []
	for i in range(trace.points.size()-1):
		if absf(trace.beds[i+1]-trace.beds[i]) / maxf(trace.points[i].distance_to(trace.points[i+1]),0.001) > BANK_GENTLE_GRADE:
			steep.append(Vector2i(i,i+1))
	var weights := PackedFloat64Array()
	for point: Vector2 in trace.points:
		var distance := INF
		for edge: Vector2i in steep:
			var a := trace.points[edge.x]
			var ab := trace.points[edge.y]-a
			var t := clampf((point-a).dot(ab)/maxf(ab.length_squared(),0.000001),0,1)
			distance = minf(distance,point.distance_to(a+ab*t))
		weights.append(smoothstep(BANK_FEATHER,BANK_FEATHER*2,distance))
	if _bank_strength_cache.size() >= BANK_PROFILE_CACHE_LIMIT:
		_bank_strength_cache.erase(_bank_strength_cache.keys()[0])
	_bank_strength_cache[key] = weights
	return weights


## Metres to subtract from the raw noise height at tile cell (cx, cz).
## Max over every pond bowl and channel segment that reaches the cell — pure
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
		var seen_segments: Dictionary = {}
		for entry in region.buckets[key]:
			var t: RiverTrace = entry[0]
			var i: int = entry[1]
			# Buckets are populated from sample influence AABBs for the hot-path
			# lookup, but carving is evaluated on the two SEGMENTS touching that
			# sample.  A segment appears through both endpoints; the stable key
			# makes the duplicate a no-op without relying on visit order.
			for si in [i - 1, i]:
				if si < 0 or si + 1 >= t.points.size():
					continue
				var segment_key := Vector3i(t.source_cell.x, t.source_cell.y, si)
				if seen_segments.has(segment_key):
					continue
				seen_segments[segment_key] = true
				var a: Vector2 = t.points[si]
				var b: Vector2 = t.points[si + 1]
				var ab: Vector2 = b - a
				var len2: float = ab.length_squared()
				var along: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0) \
					if len2 > 0.000001 else 0.0
				var nearest: Vector2 = a + ab * along
				var half_width: float = lerpf(t.widths[si], t.widths[si + 1], along)
				var d: float = p.distance_to(nearest)
				var infl: float = half_width + BANK_FEATHER
				if d >= infl:
					continue
				if ground == -INF:
					ground = noise_h(p)
				# The channel keeps its complete hydraulic footprint. Beyond it,
				# bank controls rise from dry shore toward natural ground. The
				# ordinary terrain kernel reconstructs the actual walkable slopes.
				var grade: float = absf(t.beds[si + 1] - t.beds[si]) \
					/ maxf(sqrt(len2), 0.001)
				var extra: float = CARVE_BED_EXTRA \
					if grade < CARVE_EXTRA_MAX_GRADE else 0.0
				var bed: float = lerpf(t.beds[si], t.beds[si + 1], along)
				var carve_bed: float = maxf(bed - extra, BED_MIN)
				var target := carve_bed
				if d > half_width:
					var shore := bed + WaterField.SURFACE_RIDE + 0.5
					target = lerpf(shore, ground, (d - half_width) / BANK_FEATHER)
				var weights := bank_strengths(t)
				var strength := lerpf(weights[si], weights[si+1], along)
				var original_weight := SlopeProfile.smootherstep(clampf((half_width+FEATHER-d)/FEATHER,0,1))
				var original_carve := maxf(0.0,ground-carve_bed)*original_weight
				best = maxf(best,lerpf(original_carve,maxf(0.0,ground-target),strength))
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
	return bodies_in_rect(window)


## Complete carving-source inventory for a finite hydraulic solve. Sources
## are discovered over the solve's entire terrain extent, not just its output
## chunk: a distant crossing river may have opened a lower outlet there.
func bodies_in_rect(window: Rect2) -> Dictionary:
	var lo := Vector2i((window.position / SUPER).floor())
	var hi := Vector2i((window.end / SUPER).floor())
	var super_cells: Dictionary = {}
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			super_cells[Vector2i(x, z)] = true
	var seen: Dictionary = {}
	var ponds: Array = []
	var rivers: Array = []
	for rc in super_cells.keys():
		for t in _region_for(rc).rivers:
			if seen.has(t.source_cell):
				continue
			if not t.bounds().grow(W_MAX + BANK_FEATHER).intersects(window):
				continue
			seen[t.source_cell] = true
			rivers.append(t)
			if t.source_pool != null:
				ponds.append(t.source_pool)
			if t.pond != null:
				ponds.append(t.pond)
	return {"ponds": ponds, "rivers": rivers}
