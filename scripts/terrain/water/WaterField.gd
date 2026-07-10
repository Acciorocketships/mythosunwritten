# The continuous water surface: ONE height field w(x,z), discontinuous only
# at true waterfalls (bed drop > FALL_DROP_MIN between adjacent trace
# samples). Ponds are flat; river reaches slope monotonically between their
# anchors. Static wetness is a HYDROSTATIC FILL (see _build_fill): water
# seeded in the channel/pond footprints spreads outward over any ground that
# sits below its level, stopping only where the ground itself rises to meet
# it — the field's own claim geometry (nearest-sample margins, flood-
# extension gates) is gone; every wet sample's level is either a channel/
# pond seed or reachable-by-relaxation from one. This file is pure and
# deterministic — no rendering, no nodes.
class_name WaterField
extends Object

const TILE := 24.0
const FALL_DROP_MIN := 4.0    # the only fall threshold in the system
const SURFACE_RIDE := 2.2     # river surface height above the traced bed
const CLAIM_FEATHER := 8.0    # metres past the channel half-width a reach claims (channel membership + fall geometry only)
const EPS := 0.05

# Fill lattice: chunk span (TILE*8 = 192m) plus a margin on every side so a
# basin whose flood extends past the chunk's own border is fully resolved
# inside BOTH of two neighbouring chunks' windows (window determinism —
# test_fill_is_deterministic_across_chunks). Margin is 30m world-space each
# side (matching the brief's "concretely: fill over lattice indices covering
# chunk cells ±10 cells at 3 m step" — 10 lattice cells at the ORIGINAL 3m
# step = 30m; kept as a fixed WORLD-SPACE margin, not a fixed lattice-cell
# count, so the perf-driven coarsening below doesn't silently shrink the
# safety margin). The fill's own lower-level-wins relaxation converges to a
# unique fixpoint regardless of BFS/seed order (Phase 0 controller ruling,
# mitigation (a)); the margin exists only so a basin isn't clipped
# differently by two neighbours' windows (mitigation (b)) — see the
# WaterField section of the Phase 1 report for the derivation.
#
# PERF (Phase 1 report): the 3m lattice (85x85=7225 samples) measured a
# median 59.8ms per ctx() on this machine — ~4x over the 15ms budget (the
# brief's own escape hatch: "if the 3m lattice fill exceeds budget, fill at
# 6m and bilinear down"). Coarsened to 6m (43x43=1849 samples, ~3.9x fewer);
# level_at's existing bilinear (_fill_bilinear) already interpolates at
# whatever FILL_STEP is configured, so no other code changed — only these
# constants. Both timings are in the Phase 1 report.
const FILL_STEP := 6.0        # coarsened from 3.0 (WaterMesher.S) — see PERF above
const _FILL_MARGIN_WORLD := 30.0   # fixed world-space margin, independent of FILL_STEP
const FILL_MARGIN := int(_FILL_MARGIN_WORLD / FILL_STEP)   # margin in FILL_STEP cells
const FILL_N := int(TILE * 8.0 / FILL_STEP)   # chunk lattice cells per side at FILL_STEP
const FILL_M := FILL_N + 2 * FILL_MARGIN      # window lattice cells per side

static var _profiles: Dictionary = {}   # trace.source_cell -> profile dict
# The streamer calls build_chunk (and therefore profile()) from a worker
# thread, and teleports can trigger a main-thread build concurrently — the
# same lazily-filled-static-Dictionary race that has crashed this codebase
# before (the foliage-cache incident). Guard every check-compute-store access.
static var _profiles_lock := Mutex.new()


## Everything the samplers need for one chunk, fetched once (bodies_near is
## too expensive per point). Also builds a 24m spatial bucket over river
## samples so level_at is O(nearby samples), not O(all samples).
## region is optional: when provided, ctx also runs the hydrostatic fill (see
## _build_fill) over a chunk+margin lattice, and level_at/wet read the fill
## first; without a region there is no ground field to test against, so
## level_at/wet fall back to channel-membership-only (no fill, no flood —
## see level_at's docstring). Existing callers that never pass region (a few
## of test_water_field's pre-existing tests) keep exercising exactly that
## fallback path, which is intentional — see level_at.
static func ctx(water: WaterPlan, chunk: Vector2i, region = null) -> Dictionary:
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
	var out: Dictionary = {"water": water, "ponds": bodies.ponds, "rivers": bodies.rivers,
		"buckets": buckets, "region": region}
	if region != null:
		var base := Vector2(chunk.x, chunk.y) * (TILE * 8.0) - Vector2.ONE * (FILL_MARGIN * FILL_STEP)
		out["fill_base"] = base
		out["fill"] = _build_fill(out, region, base)
	return out


## Hydrostatic fill over a (FILL_M+1)x(FILL_M+1) lattice at FILL_STEP anchored
## at `base` (the window's own corner, chunk origin minus FILL_MARGIN cells).
## Two passes:
##  1. SEED: every lattice sample within a channel sample's width (river) or a
##     pond's wobbled footprint is marked wet at that body's own level — the
##     trace's own profile.levels[si] per sample (the brief's literal rule),
##     pond.surface_y() for ponds. A sample within two overlapping seed discs
##     at different levels is offered both; relaxation's ascending pop order
##     resolves it to the lower one (see _settle).
##  2. RELAX: multi-source flood by ASCENDING level (a min-heap keyed on
##     level — see the PriorityQueue import below). A dry sample floods to
##     level L the first time it is 4-adjacent to a sample already settled at
##     L, provided the sample's own ground sits below L - EPS. Settling
##     lowest-pending-level-first is what makes the result independent of
##     seed/traversal order (see FILL_MARGIN's comment): within one level,
##     reachability through "ground < L - EPS" is a fixed subgraph, so a
##     sample either is or isn't reachable at that level regardless of visit
##     order; across levels, once a sample is settled at its lowest possible
##     level no higher level may ever re-claim it (lower always wins), which
##     is exactly Dijkstra's greedy invariant with level standing in for
##     distance and same-level propagation standing in for zero-cost edges.
## Returns {"levels": PackedFloat32Array((FILL_M+1)^2, -INF where dry)}.
static func _build_fill(c: Dictionary, region, base: Vector2) -> Dictionary:
	var m1 := FILL_M + 1
	var levels := PackedFloat32Array()
	levels.resize(m1 * m1)
	levels.fill(-INF)
	# Ground-height memo, lazily filled via _ground_at (PERF, Phase 1
	# report): seeding and relaxation both re-query the SAME lattice
	# points' ground repeatedly (a point seeded by two overlapping discs,
	# or examined as the shared neighbour of two different settled cells
	# during relaxation) — TerrainSurfaceField.surface_y measured ~4us/call
	# in isolation, and the fill made thousands of calls per ctx() before
	# this cache, dominating the 3m lattice's ~60ms cost (see FILL_STEP's
	# PERF comment). INF is the "uncomputed" sentinel — ground never
	# legitimately reaches INF/-INF, unlike `levels[]` where -INF means
	# "genuinely dry" (a real, load-bearing value there).
	var gnd := PackedFloat32Array()
	gnd.resize(m1 * m1)
	gnd.fill(INF)
	# PriorityQueue extends Object (not RefCounted, see scripts/core/
	# PriorityQueue.gd) — it does not get automatically freed when it goes
	# out of scope, and _build_fill runs once per ctx() call (every chunk
	# build), so leaving this unfreed leaks one Object per chunk over a play
	# session. free() explicitly once relaxation is done.
	var pq := PriorityQueue.new()
	_seed_rivers(c, region, base, m1, levels, gnd, pq)
	_seed_ponds(c, region, base, m1, levels, gnd, pq)
	_relax_fill(region, base, m1, levels, gnd, pq)
	pq.free()
	return {"levels": levels}


## Ground height at lattice index (i,j), memoized in `gnd` (INF = uncomputed
## — see _build_fill's own comment on why INF is a safe sentinel here).
static func _ground_at(region, base: Vector2, m1: int, gnd: PackedFloat32Array,
		i: int, j: int) -> float:
	var idx: int = j * m1 + i
	var g: float = gnd[idx]
	if g == INF:
		var p: Vector2 = base + Vector2(i, j) * FILL_STEP
		g = TerrainSurfaceField.surface_y(region, p.x, p.y)
		gnd[idx] = g
	return g


## Marks every lattice sample within tr.widths[si] of a channel sample AND
## whose own ground sits below that sample's level (see _seed_disc) wet at
## that sample's own profile level, for every trace/sample in ctx. Iterates
## only the lattice index box around each sample (not the whole lattice).
static func _seed_rivers(c: Dictionary, region, base: Vector2, m1: int,
		levels: PackedFloat32Array, gnd: PackedFloat32Array, pq: PriorityQueue) -> void:
	for tr: RiverTrace in c.rivers:
		var prof: Dictionary = profile(tr)
		for si in tr.points.size():
			var p: Vector2 = tr.points[si]
			var w: float = tr.widths[si]
			var lvl: float = prof.levels[si]
			_seed_disc(region, base, m1, levels, gnd, pq, p, w, lvl)


## Marks every lattice sample inside a pond's wobbled footprint AND below the
## pond's own surface (see the ground-clearance note below) wet at the
## pond's surface. Bound by bound_radius() (a safe outer circle); footprint_t
## does the real (wobbled, non-circular) membership test per sample.
## GROUND CLEARANCE: footprint_t is a purely geometric test (inside the
## wobbled radius) — it says nothing about whether the terrain there was
## ever actually carved down to the pond's bed (PondStamp.carve_at only
## lowers ground that started ABOVE bed_y(); ground that was already high
## inside the nominal footprint, e.g. a natural rise near the pond's own
## feathered rim, is untouched). Seeding every footprint point unconditionally
## produced a real bug (verified against this seed's site chunk): a lattice
## node at (60,-1020), ground 24.0, sat inside pond (40.5,-1037.8)'s
## footprint and got seeded wet at the pond's 15.0 surface — water standing
## 9m ABOVE ground it demonstrably cannot reach, an unreachable-by-relaxation
## island the BFS then never corrects (nothing propagates a LOWER level
## there because the node is already "settled"). The same ground check
## _relax_fill's own propagation step already applies (ground < level - EPS)
## must gate seeding too, not just relaxation.
static func _seed_ponds(c: Dictionary, region, base: Vector2, m1: int,
		levels: PackedFloat32Array, gnd: PackedFloat32Array, pq: PriorityQueue) -> void:
	for pond: PondStamp in c.ponds:
		var lvl: float = pond.surface_y()
		var lo_i: int = maxi(0, int(floor((pond.center.x - pond.bound_radius() - base.x) / FILL_STEP)))
		var hi_i: int = mini(FILL_M, int(ceil((pond.center.x + pond.bound_radius() - base.x) / FILL_STEP)))
		var lo_j: int = maxi(0, int(floor((pond.center.y - pond.bound_radius() - base.y) / FILL_STEP)))
		var hi_j: int = mini(FILL_M, int(ceil((pond.center.y + pond.bound_radius() - base.y) / FILL_STEP)))
		for j in range(lo_j, hi_j + 1):
			for i in range(lo_i, hi_i + 1):
				var p: Vector2 = base + Vector2(i, j) * FILL_STEP
				if pond.footprint_t(p) >= 1.0:
					continue
				if _ground_at(region, base, m1, gnd, i, j) >= lvl - EPS:
					continue
				_settle(m1, levels, pq, i, j, lvl)


## Shared disc-seed helper: every lattice sample within `w` of `p` AND whose
## own ground sits below `lvl - EPS` (see _seed_ponds' ground-clearance note
## — the same reasoning applies to a channel sample's width-disc: the disc
## is a geometric circle, and can graze terrain the channel itself never
## carved, e.g. a bank cutting the corner of a meander) is offered to the
## relax queue at `lvl` (final value decided at pop time — see _settle).
static func _seed_disc(region, base: Vector2, m1: int, levels: PackedFloat32Array,
		gnd: PackedFloat32Array, pq: PriorityQueue, p: Vector2, w: float, lvl: float) -> void:
	var lo_i: int = maxi(0, int(floor((p.x - w - base.x) / FILL_STEP)))
	var hi_i: int = mini(FILL_M, int(ceil((p.x + w - base.x) / FILL_STEP)))
	var lo_j: int = maxi(0, int(floor((p.y - w - base.y) / FILL_STEP)))
	var hi_j: int = mini(FILL_M, int(ceil((p.y + w - base.y) / FILL_STEP)))
	for j in range(lo_j, hi_j + 1):
		for i in range(lo_i, hi_i + 1):
			var q: Vector2 = base + Vector2(i, j) * FILL_STEP
			if q.distance_to(p) > w:
				continue
			if _ground_at(region, base, m1, gnd, i, j) >= lvl - EPS:
				continue
			_settle(m1, levels, pq, i, j, lvl)


## Offers (i,j) to the relax queue at `lvl`. Called only during seeding,
## while `levels[]` (the OUTPUT/settled array) is still all -INF — a sample
## seeded by two overlapping discs (e.g. two channel reaches' width-discs
## meeting) is pushed twice, once per level; the ascending-order pop in
## _relax_fill settles the lower one first and the second pop is then
## skipped as stale (levels[idx] already != -INF), which is exactly the
## "lower level wins" rule applied at seed time too, not just during
## relaxation.
static func _settle(m1: int, levels: PackedFloat32Array, pq: PriorityQueue,
		i: int, j: int, lvl: float) -> void:
	var idx: int = j * m1 + i
	if levels[idx] == -INF:
		pq.push([idx, lvl], lvl)


## Pops the queue in ascending level order; the first pop for any index is
## final (a later, higher-level pop for the same index is a stale duplicate —
## skip it, `levels[idx]` already holds the lower value that settled it).
## Each settled sample floods its 4 neighbours at its own level when the
## neighbour's ground sits below level - EPS.
static func _relax_fill(region, base: Vector2, m1: int,
		levels: PackedFloat32Array, gnd: PackedFloat32Array, pq: PriorityQueue) -> void:
	while not pq.is_empty():
		var entry: Array = pq.pop()
		var idx: int = entry[0]
		var lvl: float = entry[1]
		if levels[idx] != -INF:
			continue   # a lower level already settled this index — stale
		levels[idx] = lvl
		var i: int = idx % m1
		var j: int = idx / m1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni: int = i + d.x
			var nj: int = j + d.y
			if ni < 0 or ni > FILL_M or nj < 0 or nj > FILL_M:
				continue
			var nidx: int = nj * m1 + ni
			if levels[nidx] != -INF:
				continue
			if _ground_at(region, base, m1, gnd, ni, nj) < lvl - EPS:
				pq.push([nidx, lvl], lvl)


## Continuous, monotone level per trace sample + fall cut indices.
## levels[i] = min(levels[i-1], beds[i] + SURFACE_RIDE), anchored to the
## source pool at the top and the terminal pond at the bottom. Falls are
## detected over a short along-window (spec "Falls" bullet, docs/superpowers/
## specs/2026-07-09-water-boundary-mesh-design.md): a genuine cliff can
## descend over 2-3 samples (~12 m apart) without any single step exceeding
## FALL_DROP_MIN, so before committing the held level at sample i we also
## peek at sample i+1 (a ~24 m lookahead). If the held level clears either
## raw_i or raw_{i+1} by more than FALL_DROP_MIN, one cut is placed at the
## single step with the largest drop inside the held window; the samples
## between the anchor and that step are the lip (held at the anchor level),
## and scanning resumes just downstream of the cut with lvl = raw at the cut.
## Windows never overlap — once a cut is placed, the next window starts
## fresh from the sample after it.
static func profile(trace: RiverTrace) -> Dictionary:
	# Check-compute-store guarded end to end: the streamer's worker thread and
	# a teleport-triggered main-thread build can both call profile() for the
	# same trace at once. Profiles are small, so holding the lock across the
	# compute (not just the dictionary ops) costs nothing measurable.
	_profiles_lock.lock()
	if _profiles.has(trace.source_cell):
		var cached: Dictionary = _profiles[trace.source_cell]
		_profiles_lock.unlock()
		return cached
	var n: int = trace.points.size()
	var levels := PackedFloat32Array()
	levels.resize(n)
	var cuts := PackedInt32Array()
	var lvl: float = trace.beds[0] + SURFACE_RIDE
	if trace.source_pool != null:
		lvl = minf(lvl, trace.source_pool.surface_y())
	levels[0] = lvl
	var si: int = 1
	while si < n:
		var i: int = si
		var raw_i: float = trace.beds[i] + SURFACE_RIDE
		# Falls are strictly > FALL_DROP_MIN (4.0 m). An exact one-storey (4.0)
		# drop stays a slope by owner decision. The +0.01 guards float32
		# chained-subtraction noise so exact 4.0 drops never become falls.
		var drop_i: float = lvl - raw_i
		var drop_j: float = drop_i
		var j: int = i
		if i + 1 < n:
			var raw_next: float = trace.beds[i + 1] + SURFACE_RIDE
			var drop_next: float = lvl - raw_next
			if drop_next > drop_j:
				drop_j = drop_next
				j = i + 1
		if drop_i > FALL_DROP_MIN + 0.01 or drop_j > FALL_DROP_MIN + 0.01:
			# One of the two lookahead samples clears the threshold — place a
			# single cut at the step (within the anchor..j window) with the
			# largest drop measured from the held anchor level, holding the
			# lip level up to it. Measuring from the anchor (not step-to-step)
			# guarantees the recorded jump itself exceeds the threshold —
			# two sub-threshold single steps (e.g. 4.0 + 4.0) that only trip
			# the window *together* must still cut at the point that carries
			# the whole qualifying drop, not at whichever half-step is
			# nominally larger.
			var cut_at: int = i - 1
			var best_drop: float = drop_i
			for k in range(i + 1, j + 1):
				var raw_k: float = trace.beds[k] + SURFACE_RIDE
				var drop_k: float = lvl - raw_k
				if drop_k > best_drop:
					best_drop = drop_k
					cut_at = k - 1
			for fill in range(i, cut_at + 1):
				levels[fill] = lvl
			cuts.append(cut_at)
			var raw_after: float = trace.beds[cut_at + 1] + SURFACE_RIDE
			lvl = raw_after
			levels[cut_at + 1] = lvl
			si = cut_at + 2
			continue
		lvl = minf(lvl, raw_i)
		levels[i] = lvl
		si += 1
	if trace.pond != null:
		# Meet the pond surface continuously (or with a fall if the drop is big).
		var ps: float = trace.pond.surface_y()
		if levels[n - 1] - ps > FALL_DROP_MIN + 0.01:
			cuts.append(n - 1)
		else:
			# The trace must end exactly at the pond surface. Levels are already
			# monotone non-increasing, so pinning the last sample to ps preserves
			# monotonicity by itself UNLESS trailing samples dipped below ps
			# (water can't sit below the pond it feeds) — walk backward fixing
			# those up to ps.
			var i: int = n - 1
			while i >= 0 and levels[i] < ps:
				levels[i] = maxf(levels[i], ps)
				i -= 1
			levels[n - 1] = ps
			# Raising the tail up to ps can shrink the drop across the cut just
			# upstream of it (index i) below FALL_DROP_MIN — it's no longer a
			# real fall once the water below it was lifted to meet the pond.
			if i >= 0 and cuts.has(i) and levels[i] - levels[i + 1] <= FALL_DROP_MIN + 0.01:
				cuts.remove_at(cuts.find(i))
	var out := {"levels": levels, "cuts": cuts}
	_profiles[trace.source_cell] = out
	_profiles_lock.unlock()
	return out


## Surface height at p, or -INF when the water can't be shown to reach p.
## Two regimes:
##  - ctx carries a fill (built by ctx() when region != null) AND p sits
##    inside the fill window: BILINEAR over the fill lattice — see
##    _fill_bilinear. This is the hydrostatic answer: reachable-by-relaxation
##    water at its own settled level, -INF everywhere the fill left dry.
##  - No fill available (ctx built without region — a few pre-existing
##    tests/callers still do this) OR p falls outside the fill window (the
##    fill only covers chunk+FILL_MARGIN — see FILL_MARGIN's comment): fall
##    back to CHANNEL-MEMBERSHIP ONLY, i.e. exactly the old nearest-claimant
##    search but with NO flood/margin competition — a point only claims
##    water when it is within a channel sample's width or a pond's
##    footprint (m < 0), smallest-margin wins among those. This never
##    fabricates flood coverage outside the window; it just answers "is this
##    point literally inside the carved channel/pond," which is always safe
##    to ask regardless of whether a fill was ever computed for the point's
##    neighbourhood (callers probing far from any built ctx must not crash
##    — see the Phase 1 report).
static func level_at(c: Dictionary, p: Vector2) -> float:
	if c.has("fill") and _in_fill_window(c, p):
		return _fill_bilinear(c, p)
	return _channel_membership_level(c, p)


## True when p sits inside the fill window built by ctx() (chunk span plus
## FILL_MARGIN lattice cells on every side).
static func _in_fill_window(c: Dictionary, p: Vector2) -> bool:
	var base: Vector2 = c.fill_base
	var span: float = FILL_M * FILL_STEP
	return p.x >= base.x and p.x <= base.x + span and p.y >= base.y and p.y <= base.y + span


## Two fill-lattice nodes only ever get BLENDED (bilinear) if they are
## within this of each other — otherwise they are two DIFFERENT water
## bodies/storeys and must NOT be smoothed into a fabricated ramp between
## them (see _fill_bilinear). Matches WaterMesher.CUT_JUMP's own semantics
## (adjacent-sample jump that marks a real seam, not a continuous slope) —
## not read from WaterMesher directly (WaterField is the lower-level module;
## the dependency would point the wrong way), just the same physically-
## motivated threshold restated here.
## Safety-margin check against the steepest LEGAL (non-fall) reach: a
## continuous river slope may drop up to FALL_DROP_MIN (4.0m, exclusive) per
## TRACE_STEP (12.0m, WaterPlan.gd) before profile() cuts a fall — so over
## one FILL_STEP=6m fill-lattice cell, the steepest legal slope reaches
## 4.0/12.0*6.0 = 2.0m, i.e. it lands EXACTLY at FILL_JUMP, not comfortably
## under it. Because the corner-mixing gate above is strict '>' (wet_hi -
## wet_lo > FILL_JUMP), an exact 2.0m difference still blends; only a
## difference exceeding 2.0m snaps — so there is zero slack, not a margin,
## between the steepest legal reach and the different-body snap threshold.
## No test currently exercises _fill_bilinear against a near-4.0m/12m legal
## slope resampled onto the 6m lattice to confirm it blends rather than
## snaps at this boundary — a real gap, not yet covered by
## test_water_field.gd or test_water_mesher.gd.
const FILL_JUMP := 2.0

## Bilinear over the fill lattice, with two corrections against the raw
## lattice's own discreteness:
##  1. WET-vs-DRY (-INF) mixing: renormalized over only the wet corners
##     (raw IEEE754 0.0 * -INF is NaN, not 0.0, so plain weighted summation
##     cannot be trusted once any corner is -INF) — a corner's own weight
##     only ever pulls the result toward THAT corner's real level, dry
##     corners are excluded and their weight redistributed over the
##     remaining wet ones. -INF when no corner is wet, or the point's
##     weight lands entirely on dry corners.
##  2. WET-vs-WET-AT-A-DIFFERENT-BODY mixing: two adjacent fill-lattice
##     nodes settled by DIFFERENT seeds at meaningfully different levels
##     (> FILL_JUMP apart) are not a continuous slope — each node's level is
##     independently, discretely correct (the BFS's own fixpoint), so
##     linearly blending BETWEEN them fabricates intermediate "levels" the
##     fill never actually computed and that can smear a real storey wall
##     into a fake ramp (verified against this seed's data: a flat 0m shelf
##     right up to a real storey step to 4m ground, claimed by a 3.0 body on
##     the low side and a 5.70 body on the high side — bilinear invented a
##     smooth 3.0->5.70 ramp across the 3m cell straddling that wall, which
##     is not the physical answer). When the wet corners span more than
##     FILL_JUMP, this snaps to the NEAREST wet corner's own level instead
##     of blending — a step at the cell's own midline, not a fabricated
##     slope; still continuous everywhere except at that midline, same as
##     the true wall it approximates.
static func _fill_bilinear(c: Dictionary, p: Vector2) -> float:
	var base: Vector2 = c.fill_base
	var levels: PackedFloat32Array = c.fill.levels
	var m1 := FILL_M + 1
	var lf: float = (p.x - base.x) / FILL_STEP
	var jf: float = (p.y - base.y) / FILL_STEP
	var i0: int = clampi(int(floor(lf)), 0, FILL_M - 1)
	var j0: int = clampi(int(floor(jf)), 0, FILL_M - 1)
	var tx: float = clampf(lf - float(i0), 0.0, 1.0)
	var tz: float = clampf(jf - float(j0), 0.0, 1.0)
	var corners := [
		[i0, j0, (1.0 - tx) * (1.0 - tz)],
		[i0 + 1, j0, tx * (1.0 - tz)],
		[i0, j0 + 1, (1.0 - tx) * tz],
		[i0 + 1, j0 + 1, tx * tz],
	]
	var wet_lo: float = INF
	var wet_hi: float = -INF
	for cnr: Array in corners:
		var lvl: float = levels[cnr[1] * m1 + cnr[0]]
		if lvl == -INF:
			continue
		wet_lo = minf(wet_lo, lvl)
		wet_hi = maxf(wet_hi, lvl)
	if wet_hi == -INF:
		return -INF
	if wet_hi - wet_lo > FILL_JUMP:
		var best_d: float = INF
		var best_lvl: float = -INF
		for cnr: Array in corners:
			var lvl: float = levels[cnr[1] * m1 + cnr[0]]
			if lvl == -INF:
				continue
			var cp: Vector2 = base + Vector2(cnr[0], cnr[1]) * FILL_STEP
			var d: float = cp.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best_lvl = lvl
		return best_lvl
	var wsum := 0.0
	var acc := 0.0
	for cnr: Array in corners:
		var lvl: float = levels[cnr[1] * m1 + cnr[0]]
		if lvl == -INF:
			continue
		acc += lvl * cnr[2]
		wsum += cnr[2]
	if wsum <= 0.0:
		return -INF
	return acc / wsum


## Channel-membership-only claim: a point claims water only when it is
## literally inside a channel sample's width or a pond's footprint (no
## margin/flood competition beyond that — CLAIM_FEATHER still gates the
## pond loop below to keep the same "just past the edge" tolerance the old
## code always applied even to its own hard-margin branch). Smallest margin
## among qualifying candidates wins. Used both as ctx()-without-region's
## only behaviour and as level_at's outside-the-fill-window fallback.
static func _channel_membership_level(c: Dictionary, p: Vector2) -> float:
	var best_m: float = INF
	var best_lvl: float = -INF
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		if m < best_m and m < CLAIM_FEATHER:
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
				if m < best_m and m < CLAIM_FEATHER:
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


## ctx must be built WITH region (see ctx()'s region param) for the fill to
## have run at all: level_at falls back to channel-membership-only without
## it (see level_at), under-reporting wetness anywhere the hydrostatic fill
## would otherwise have reached.
static func wet(c: Dictionary, region, p: Vector2) -> bool:
	var lvl: float = level_at(c, p)
	return lvl > -INF and lvl > TerrainSurfaceField.surface_y(region, p.x, p.y) + EPS


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
## Degenerate case: profile() can append a cut at ci == n-1 (the trace ends
## more than FALL_DROP_MIN above its terminal pond — see profile()'s pond
## tail-fixup). There j == mini(ci+1, n-1) == ci, so the "normal" (points[j]
## - points[ci]) direction is the zero vector — a poisoned record: dir.
## normalized() would come back ZERO, and downstream consumers key exemption/
## gating on dot products against dir/across, so a zero dir silently exempts
## or matches EVERYTHING (WaterMesher._near_cut, the plunge band in
## _attributes, _cell_cut's gate). Handle it explicitly: derive dir from the
## trace's last real segment instead of the (degenerate) cut segment, and
## drop straight to the terminal pond's surface as the bottom.
static func fall_cuts(c: Dictionary, rect: Rect2) -> Array:
	var out: Array = []
	var grown: Rect2 = rect.grow(TILE)
	for tr: RiverTrace in c.rivers:
		var prof: Dictionary = profile(tr)
		var n: int = tr.points.size()
		for ci in prof.cuts:
			var j: int = mini(ci + 1, n - 1)
			if j == ci:
				# Pond-terminal cut: no downstream sample to point at. Need at
				# least 2 points to form a direction from the last segment.
				if n < 2:
					push_warning("WaterField.fall_cuts: trace %s has < 2 points, skipping degenerate terminal cut" % [tr.source_cell])
					continue
				if tr.pond == null:
					push_warning("WaterField.fall_cuts: trace %s terminal cut at %d has no pond, skipping" % [tr.source_cell, ci])
					continue
				var p: Vector2 = tr.points[n - 1]
				var dirv: Vector2 = (tr.points[n - 1] - tr.points[n - 2]).normalized()
				if not grown.has_point(p):
					continue
				out.append({"p": p, "dir": dirv,
					"across": Vector2(-dirv.y, dirv.x),
					"half": tr.widths[n - 1] + CLAIM_FEATHER,
					"top": prof.levels[n - 1], "bottom": tr.pond.surface_y()})
				continue
			var mid: Vector2 = (tr.points[ci] + tr.points[j]) * 0.5
			if not grown.has_point(mid):
				continue
			var dirv: Vector2 = (tr.points[j] - tr.points[ci]).normalized()
			out.append({"p": mid, "dir": dirv,
				"across": Vector2(-dirv.y, dirv.x),
				"half": tr.widths[ci] + CLAIM_FEATHER,
				"top": prof.levels[ci], "bottom": prof.levels[j]})
	return out
