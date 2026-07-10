# The continuous water surface: ONE height field w(x,z), continuous even
# across a true waterfall (Phase 2a) — a fall is now a STEEP STRETCH of the
# same monotone profile, not a discrete cut object. Ponds are flat; river
# reaches slope monotonically between their anchors, hugging the RENDERED
# terrain wherever the ground itself demands descent (see profile()). Static
# wetness is a HYDROSTATIC FILL (see _build_fill): water seeded in the
# channel/pond footprints spreads outward over any ground that sits below
# its level, stopping only where the ground itself rises to meet it — the
# field's own claim geometry (nearest-sample margins, flood-extension gates)
# is gone; every wet sample's level is either a channel/pond seed or
# reachable-by-relaxation from one. This file is pure and deterministic — no
# rendering, no nodes.
class_name WaterField
extends Object

const TILE := 24.0
const FALL_DROP_MIN := 4.0    # the only "this is a fall face" threshold in the system — now purely a TERRAIN classification (steep_spans), not a level-cut trigger
const SURFACE_RIDE := 2.2     # river surface height above the traced bed
const CLAIM_FEATHER := 8.0    # metres past the channel half-width a reach claims (channel membership + steep-span geometry only)
const EPS := 0.05
const FILM := 0.3             # minimum clearance the descending level keeps above the rendered ground when hugging a steep face (profile()'s "downstream_target" floor)
# PERF (this task's report): the brief's own "~3m steps" for the descent-
# shaping terrain walk measured a site-chunk ctx() COLD median (profile
# cache cleared, worst case — a chunk whose every trace is genuinely new)
# of 16.27ms, ~1.3ms over the 15ms budget; the realistic WARM/steady-state
# figure (profile cache hot — WaterField._profiles is a whole-session
# static cache that is never cleared in production, so a trace's terrain
# walk is only ever paid ONCE across its entire multi-chunk lifetime) was
# already comfortably under budget at 8.7ms. Coarsened one notch to 4.0m
# (same escape-hatch spirit as FILL_STEP's own perf-driven 3m->6m
# coarsening above) so BOTH the cold worst case (14.83ms median) and the
# warm steady-state stay under budget — removing the ambiguity rather than
# relying solely on the cache to keep the rare cold spike under the line.
# Re-verified after the change: H1's site still shows zero steep_spans,
# zero multi-seam-cell warnings, and all 4 water suites green (see this
# task's own report).
const _DESCENT_STEP := 4.0
const _EASE_BAND := 2.0       # metres of (ground-hug - smooth-trend) level gap over which profile() soft-blends the two curves — the substep-level stand-in for the brief's "~2m C1 easing"; see _descend_segment

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
		var prof: Dictionary = profile(tr, region)
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


## Continuous, monotone level per trace sample. NO cuts array (Phase 2a):
## levels[i] = min(levels[i-1], beds[i] + SURFACE_RIDE) is the CHASE target,
## same as before, but how the level GETS from levels[i-1] to that target
## across one 12m segment is now terrain-aware instead of an instant jump —
## see _descend_segment. Where the rendered ground (TerrainSurfaceField,
## sampled every _DESCENT_STEP along the segment) stays well clear of a
## smooth (gentle-slope) interpolation between the two anchors, the level
## just rides that smooth trend (ordinary continuous-reach behaviour,
## unchanged in spirit from before). Where the ground rises close to or
## above the smooth trend — a genuine cliff — the level instead hugs
## ground + FILM, descending steeply along the face; the two curves are
## soft-blended near their crossover (_EASE_BAND) so the exposed profile has
## no slope kink (the brief's "C1 easing... 1D ogee"). Falls are now a
## PROFILE SHAPE, not a cut object: a "fall" is just the stretch of this one
## continuous curve where hugging dominates. steep_spans() (below) reports
## WHERE that happens, purely for shader/mist consumers — nothing here
## forks the geometry.
## region is optional: hand-built test traces / callers with no terrain
## field (e.g. test_multi_seam_cell_never_folds' synthetic st, or a unit
## trace with no HeightfieldRegion) fall back to the OLD instant bed-chase
## (lvl = min(lvl, raw_i) with no terrain walk) — there is no ground to hug,
## so the only sound behaviour is the plain monotone chase. Every real
## production caller (ctx() with a region, WaterMesher.build) always passes
## one.
static func profile(trace: RiverTrace, region = null) -> Dictionary:
	# Check-compute-store guarded end to end: the streamer's worker thread and
	# a teleport-triggered main-thread build can both call profile() for the
	# same trace at once. Profiles are small, so holding the lock across the
	# compute (not just the dictionary ops) costs nothing measurable.
	# Cache key includes whether a region was supplied: a region-less probe
	# (rare, test-only) must never poison the cache for the same trace's
	# later terrain-aware call, or vice versa — see the region-optional note
	# above. Real per-chunk builds always pass the same (non-null) region
	# family, so this never doubles real work.
	var cache_key: Array = [trace.source_cell, region != null]
	_profiles_lock.lock()
	if _profiles.has(cache_key):
		var cached: Dictionary = _profiles[cache_key]
		_profiles_lock.unlock()
		return cached
	var n: int = trace.points.size()
	var levels := PackedFloat32Array()
	levels.resize(n)
	var lvl: float = trace.beds[0] + SURFACE_RIDE
	if trace.source_pool != null:
		lvl = minf(lvl, trace.source_pool.surface_y())
	levels[0] = lvl
	for i in range(1, n):
		var target: float = minf(lvl, trace.beds[i] + SURFACE_RIDE)
		lvl = _descend_segment(region, trace.points[i - 1], trace.points[i], lvl, target)
		levels[i] = lvl
	if trace.pond != null:
		var ps: float = trace.pond.surface_y()
		if levels[n - 1] - ps <= FALL_DROP_MIN + 0.01:
			# Gentle enough to meet the pond exactly (no terrain-hugging left
			# to do): the trace must end AT the pond surface. Levels are
			# already monotone non-increasing, so pinning the last sample to
			# ps preserves monotonicity by itself UNLESS trailing samples
			# dipped below ps (water can't sit below the pond it feeds) —
			# walk backward fixing those up to ps.
			var i: int = n - 1
			while i >= 0 and levels[i] < ps:
				levels[i] = maxf(levels[i], ps)
				i -= 1
			levels[n - 1] = ps
		elif n >= 2:
			# A genuine steep drop into the pond: re-run the LAST segment's
			# descent targeting the pond surface instead of beds[n-1]+RIDE, so
			# a real cliff right at the shore hugs it same as any other steep
			# stretch. Deliberately NOT forced to land exactly on ps (a real
			# cliff may still be descending when the trace itself ends) — the
			# hydrostatic fill's own lower-level-wins relaxation welds
			# whatever gap remains to the pond's own (lower) seed, the same
			# mechanism that already joins any two nearby seeds continuously
			# (see _relax_fill); forcing an exact pin here would just
			# reintroduce an artificial instant jump at the last sample.
			levels[n - 1] = _descend_segment(region, trace.points[n - 2], trace.points[n - 1],
				levels[n - 2], ps)
	var out := {"levels": levels}
	_profiles[cache_key] = out
	_profiles_lock.unlock()
	return out


## Advances the held level across one trace segment (a→b, normally the
## TRACE_STEP=12m spacing between adjacent RiverTrace samples) from
## start_lvl toward end_target. Two curves are evaluated at each
## _DESCENT_STEP-spaced substep along the segment:
##   - smooth(t): a gentle, smootherstep-eased interpolation from start_lvl
##     to end_target — the ordinary "continuous reach" trend, identical in
##     spirit to the old lvl = min(lvl, raw_i) instant chase but spread
##     across the whole segment instead of applied at the endpoint alone.
##   - ground_hug(t): TerrainSurfaceField.surface_y(region, ...) + FILM — the
##     lowest the level may physically sit at that point (can't run through
##     rock).
## The exposed level is whichever is HIGHER, but blended smoothly near their
## crossover (soft-max via smootherstep over _EASE_BAND of level-gap,
## instead of a hard max()) so the profile's slope has no kink where hugging
## takes over or lets go — the substep-granularity stand-in for the brief's
## "C1 easing over ~2m at the top and bottom of any steep stretch (1D
## ogee)": a literal along-channel arc-length ease window is awkward at
## _DESCENT_STEP's substep granularity (there is no continuous parametric
## curve to measure "2m in" against, only discrete samples), so the ease is
## driven by the LEVEL GAP between the two curves instead — same qualitative
## effect (a soft S-shaped blend, not a hard corner) and it degrades
## gracefully as substeps coarsen or the crossover falls between two
## samples. A final min() against the previous substep's own held value
## keeps the whole curve monotone non-increasing even if the ground (and so
## ground_hug) bumps back up mid-segment — smooth(t) alone is already
## monotone by construction, but the blend with ground_hug is not
## guaranteed to be.
## On gentle terrain (the pinned site, per H1: this trace's surface_y never
## drops more than 4.0m in ANY 24m window) ground_hug stays well below
## smooth(t) for the whole segment, so the level just rides the smooth
## trend end to end — ordinary continuous-reach behaviour, unchanged from
## before in outcome (only in mechanism).
static func _descend_segment(region, a: Vector2, b: Vector2, start_lvl: float, end_target: float) -> float:
	if region == null:
		return end_target
	var seg_len: float = a.distance_to(b)
	var steps: int = maxi(1, int(ceil(seg_len / _DESCENT_STEP)))
	var held: float = start_lvl
	for k in range(1, steps + 1):
		var t: float = float(k) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		var ground: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
		var smooth_t: float = lerpf(start_lvl, end_target, SlopeProfile.smootherstep(t))
		var hug_t: float = ground + FILM
		var w: float = SlopeProfile.smootherstep(clampf((hug_t - smooth_t) / _EASE_BAND, 0.0, 1.0))
		held = minf(held, lerpf(smooth_t, hug_t, w))
	return held


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


## Bilinear over the fill lattice, with one correction against the raw
## lattice's own discreteness: WET-vs-DRY (-INF) mixing is renormalized over
## only the wet corners (raw IEEE754 0.0 * -INF is NaN, not 0.0, so plain
## weighted summation cannot be trusted once any corner is -INF) — a
## corner's own weight only ever pulls the result toward THAT corner's real
## level, dry corners are excluded and their weight redistributed over the
## remaining wet ones. -INF when no corner is wet, or the point's weight
## lands entirely on dry corners. This is the ONE guard the wall-ramp logic
## still needs: fabricating water toward DRY land (a corner that is
## genuinely -INF) is the actual bug class it prevents, so it applies only
## at a wet/dry pair.
##
## Phase 1's FILL_JUMP snap (superseded, Phase 2a): an earlier version of
## this function ALSO snapped to the nearest corner instead of blending
## whenever two WET corners' levels differed by more than a fixed 2.0m
## (FILL_JUMP), reasoning that two adjacent lattice nodes far apart in level
## must be different, unrelated water bodies (a real storey wall) rather
## than one continuous slope — correct for Phase 1, where profile() could
## only ever put a HARD CUT between two samples (so two nearby fill-lattice
## nodes on truly different levels really were disjoint pieces). Phase 2a
## deletes that premise: profile() now shapes a genuinely continuous,
## monotone descent even across what used to be a fall cut (see profile()/
## _descend_segment), so two adjacent WET fill-lattice nodes at very
## different levels are now routinely a LEGITIMATE steep fall face, not a
## different body — snapping them would chop a real continuous drop into a
## blocky step. The Phase 1 follow-up comment that used to live here (the
## "zero slack, not a margin" derivation showing the steepest legal Phase-1
## river slope landed EXACTLY at the old FILL_JUMP=2.0 threshold) is
## superseded along with the guard it was documenting — that derivation was
## about protecting a hard-cut boundary that no longer exists. Two adjacent
## wet nodes can still legitimately belong to different, disconnected
## bodies (e.g. two lakes split by a real, dry ridge) — but the fill's own
## ground-clearance gate (_relax_fill) already guarantees a dry ridge
## between them shows up as an actually-DRY lattice node in between, which
## the wet/dry renormalization above already handles correctly; there is no
## longer a case where two WET-WET neighbours need special-casing.
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
					best_lvl = _sample_level(tr, si, p, c.get("region"))
	return best_lvl


## Level near sample si, projected onto the adjacent segment. Phase 2a: the
## old "which side of the cut plane" branch is gone — the profile has no
## discontinuities left to straddle, so a plain along-segment lerp between
## the two endpoint levels is always the right (and now genuinely
## meaningful, not just a fallback) answer.
static func _sample_level(tr: RiverTrace, si: int, p: Vector2, region = null) -> float:
	var prof: Dictionary = profile(tr, region)
	var j: int = mini(si + 1, tr.points.size() - 1)
	if j == si:
		return prof.levels[si]
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


## Phase 2a: the old "prof.cuts.has(si) -> 0.0" exemption is gone — there is
## no cut left to probe "across" (a gradient over a real fall face is now a
## perfectly well-defined, and meaningful, large number: exactly the signal
## a future steep-look shader keys foam/scroll off, per the plan's Phase 2
## shader item). grade_at is unbounded on purpose; callers that need a
## display-safe range (WaterMesher._attributes' `steep` attribute) already
## clamp it themselves.
static func grade_at(c: Dictionary, p: Vector2) -> float:
	var cl: Array = _claim(c, p)
	if cl.is_empty():
		return 0.0
	var tr: RiverTrace = cl[0]
	var si: int = cl[1]
	var prof: Dictionary = profile(tr, c.get("region"))
	var j: int = mini(si + 1, tr.points.size() - 1)
	if j == si:
		return 0.0
	var run: float = tr.points[si].distance_to(tr.points[j])
	return (prof.levels[si] - prof.levels[j]) / maxf(run, 0.001)


## Pure window-scan over a ground-height array sampled at uniform `step`
## along a channel: finds contiguous index ranges where a sliding 24m window
## (window_n = round(24/step) samples) drop exceeds FALL_DROP_MIN + 0.01 —
## the owner's I1 rule ("no fall look where the ground's 24m window drop
## doesn't clear FALL_DROP_MIN"), encoded directly against ground samples so
## it's testable with a hand-built PackedFloat32Array and no terrain/region
## at all (steep_spans, below, is the thin wrapper that supplies the real
## world positions/dir/levels around this).
## Algorithm: for every window start i, compute that window's own drop
## (grounds[i] - min(grounds[i..i+window_n])). Consecutive triggering starts
## are merged into ONE span (a real cliff trips many overlapping windows as
## the scan slides across it) covering ground indices [a, b+window_n], where
## a is the first triggering start and b the last. Within that merged range
## the span's actual top (lo) is the highest ground sample BEFORE the
## range's own lowest point (hi = argmin over the whole merged range) — this
## guarantees lo <= hi and reproduces (or exceeds) whichever single window's
## drop triggered the merge, so the reported drop always still clears the
## threshold. Non-overlapping, ordered by lo, same "windows never overlap"
## discipline the old cut-placement loop used.
## Returns Array of {lo: int, hi: int, drop: float} (drop = grounds[lo] -
## grounds[hi]). Empty when grounds is too short to hold one window.
static func _steep_scan(grounds: PackedFloat32Array, step: float) -> Array:
	var n: int = grounds.size()
	var window_n: int = maxi(1, roundi(24.0 / step))
	if n <= window_n:
		return []
	var last_start: int = n - 1 - window_n
	var triggering := PackedByteArray()
	triggering.resize(last_start + 1)
	for i in range(0, last_start + 1):
		var min_v: float = grounds[i]
		for k in range(i + 1, i + window_n + 1):
			min_v = minf(min_v, grounds[k])
		if grounds[i] - min_v > FALL_DROP_MIN + 0.01:
			triggering[i] = 1
	var out: Array = []
	var i: int = 0
	while i <= last_start:
		if triggering[i] == 0:
			i += 1
			continue
		var run_start: int = i
		var run_end: int = i
		while run_end + 1 <= last_start and triggering[run_end + 1] == 1:
			run_end += 1
		var range_end: int = run_end + window_n
		var hi: int = run_start
		var hi_val: float = grounds[run_start]
		for k in range(run_start, range_end + 1):
			if grounds[k] < hi_val:
				hi_val = grounds[k]
				hi = k
		var lo: int = run_start
		var lo_val: float = grounds[run_start]
		for k in range(run_start, hi + 1):
			if grounds[k] > lo_val:
				lo_val = grounds[k]
				lo = k
		out.append({"lo": lo, "hi": hi, "drop": lo_val - hi_val})
		i = run_end + 1
	return out


## Ground samples (+ parallel world positions, + which trace segment each
## came from) walking the WHOLE trace polyline at `step` spacing — shared
## ground-truth for steep_spans' terrain scan. Segment-local t=0 is shared
## with the previous segment's t=1 (no duplicate sample at sample points),
## so the array is one continuous along-channel walk, exactly what
## _steep_scan's sliding window needs to see a drop that straddles a trace
## sample boundary.
static func _channel_ground_walk(tr: RiverTrace, region, step: float) -> Dictionary:
	var grounds := PackedFloat32Array()
	var pos := PackedVector2Array()
	var seg_of := PackedInt32Array()
	var n: int = tr.points.size()
	if n == 0:
		return {"grounds": grounds, "pos": pos, "seg_of": seg_of}
	grounds.append(TerrainSurfaceField.surface_y(region, tr.points[0].x, tr.points[0].y))
	pos.append(tr.points[0])
	seg_of.append(0)
	for i in range(1, n):
		var a: Vector2 = tr.points[i - 1]
		var b: Vector2 = tr.points[i]
		var seg_len: float = a.distance_to(b)
		var steps: int = maxi(1, int(ceil(seg_len / step)))
		for k in range(1, steps + 1):
			var t: float = float(k) / float(steps)
			var p: Vector2 = a.lerp(b, t)
			grounds.append(TerrainSurfaceField.surface_y(region, p.x, p.y))
			pos.append(p)
			seg_of.append(i - 1)
	return {"grounds": grounds, "pos": pos, "seg_of": seg_of}


## Steep terrain stretches along every river channel in c, whose lip (`p`)
## lies inside rect (grown by one tile so chunk-border spans appear for both
## neighbouring chunks) — the terrain-scan replacement for the old
## bed-cut-derived fall_cuts (Phase 2a: falls are a PROFILE SHAPE now, not a
## cut object; this feeds ONLY the shader churn band and (later) mist, never
## geometry — see the file header and profile()'s own docstring). Each
## entry: {p: Vector2 (lip position), dir (unit, downstream), across (unit,
## perpendicular), half (channel half-width + CLAIM_FEATHER at the lip),
## top: WATER level at the lip, bottom: WATER level at the base, drop: the
## GROUND drop _steep_scan measured}. top/bottom are profile() levels (what
## the shader actually renders), not ground heights — drop is the ground
## figure that qualified this as a steep span in the first place (the I1
## rule is a TERRAIN test, per steep_spans' own oracle).
## region absent (c.region == null, e.g. a ctx built without one) => no
## ground to scan => no spans, same graceful-fallback convention as
## level_at/_channel_membership_level elsewhere in this file.
static func steep_spans(c: Dictionary, rect: Rect2) -> Array:
	var out: Array = []
	var region = c.get("region")
	if region == null:
		return out
	var grown: Rect2 = rect.grow(TILE)
	for tr: RiverTrace in c.rivers:
		var n: int = tr.points.size()
		if n < 2:
			continue
		var walk: Dictionary = _channel_ground_walk(tr, region, _DESCENT_STEP)
		var spans: Array = _steep_scan(walk.grounds, _DESCENT_STEP)
		if spans.is_empty():
			continue
		var prof: Dictionary = profile(tr, region)
		for span: Dictionary in spans:
			var lo: int = span.lo
			var hi: int = span.hi
			var p: Vector2 = walk.pos[lo]
			if not grown.has_point(p):
				continue
			var dirv: Vector2 = (walk.pos[hi] - p)
			if dirv.length_squared() < 0.000001:
				# The scan's own lo/hi collapsed to the same point (a
				# vanishingly short merged range) — fall back to the trace's
				# local downstream direction instead of a zero vector (see
				# the module-wide "zero dir silently matches/exempts
				# everything downstream" caution this file has carried since
				# the old fall_cuts' pond-terminal degenerate case).
				var seg_i: int = clampi(walk.seg_of[lo], 0, n - 2)
				dirv = tr.points[seg_i + 1] - tr.points[seg_i]
			dirv = dirv.normalized()
			var seg_i: int = walk.seg_of[lo]
			var top_lvl: float = _sample_level(tr, seg_i, p, region)
			var bot_lvl: float = _sample_level(tr, walk.seg_of[hi], walk.pos[hi], region)
			# base_p (Phase 2b addition): the world position at the span's own
			# base/plunge end (walk.pos[hi], already computed above for dirv) —
			# exposed alongside `p` (the lip) so a shader-baking consumer
			# (WaterMesher._attributes' plunge-churn band) can measure "near the
			# base" directly instead of "far downstream of the lip," which for
			# a tall span is not the same distance at all. Purely additive: no
			# existing reader destructures this dict positionally.
			out.append({"p": p, "dir": dirv, "across": Vector2(-dirv.y, dirv.x),
				"half": tr.widths[seg_i] + CLAIM_FEATHER,
				"top": maxf(top_lvl, bot_lvl), "bottom": minf(top_lvl, bot_lvl),
				"drop": span.drop, "base_p": walk.pos[hi]})
	return out


## Back-compat shim (Phase 2a): fall_cuts() is retired as the SOURCE of
## fall geometry — see steep_spans' own docstring — but WaterMesher.build,
## FallMesher, and the plunge-band code in _attributes all still read the
## old `{p, dir, across, half, top, bottom}` record shape this phase (the
## mesher/shader/volume rewrite that deletes those readers is Phase 2b).
## Mapping steep_spans() 1:1 into that shape keeps every existing caller
## compiling and behaviourally inert where it matters: this seed's site has
## ZERO steep spans (H1: the rendered terrain here never drops more than
## 4.0m in any 24m window), so this returns [] at the site exactly like the
## old fall_cuts() no longer would have (its bed-quantization false
## positive is gone) — WaterMesher's cut-cell paths simply never fire,
## FallMesher.build([]) returns null, and the multi-seam-cell guard's own
## site trigger (a real, pre-existing lateral body seam at a cliff base —
## see the Phase 1 report — unrelated to falls) is the only remaining
## WARNING source, unaffected by this shim either way.
static func fall_cuts(c: Dictionary, rect: Rect2) -> Array:
	return steep_spans(c, rect)
