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
const _EASE_BAND := 2.0       # metres of (ground-hug - smooth-trend) level gap over which profile() soft-blends the two curves — the substep-level stand-in for the brief's "~2m C1 easing"; see _descend_segment (now used OUTSIDE descent spans only — see _find_descent_spans/_shape_descent_span)
# r3 Task 12 (round-4 addendum): the owner REVERSED run-2's terrain-hugging
# descent after seeing it render as a staircase down a real multi-storey
# slope — the site chute's beds (WaterPlan._contained_bed, itself following
# storey-quantized banks; see that function's own docstring) drop in
# discrete ~4m jumps every single TRACE_STEP=12m, and _descend_segment's OWN
# per-segment ease resets to ZERO SLOPE at every trace sample (smootherstep's
# defining property), so stacking several of those segments back to back
# reads as a staircase of independent S-curves, not one curve, even though
# each one is individually C1. Fix: identify the WHOLE descent (see
# _find_descent_spans) and ease it in ONE smootherstep from the upper pool's
# held level to the lower pool's own target — ground is consulted only as a
# floor afterward (DESCENT_CLAMP), never as the shaping signal.
# 0.10m descent floor, applied UNIFORMLY (every floor-pinned point: both span
# anchors and every inserted sill knot). It MUST strictly exceed the FILL's
# own wetness epsilon EPS(0.05) — the fill settles a cell wet only when
# `level > ground + EPS` (see _relax_fill/_seed_rivers' shared gate). r3
# Task 12b found (report): with DESCENT_CLAMP==EPS==0.05, a point the envelope
# pins to `ground + DESCENT_CLAMP` reads `level - ground == EPS` EXACTLY — not
# strictly greater — so the fill DRIES the very band the envelope shaped to
# keep wet (reproduced at the far pond chunk (-4,-18)'s sill knot
# (-606.135,-3432.959): curve 4.0320, ground 3.9820, depth 0.0500 == EPS). The
# fix is a UNIFORM floor lift, NOT a knot-local margin: an earlier 12b cut
# added the margin only at ground-DERIVED knot assignments, which raised a
# sill knot ABOVE its own eased-curve neighbours — a level discontinuity that
# left unhealed free edges at the pond (test_skin_handles_closed_and_border_
# exit_curves went red). Lifting the WHOLE floor together keeps the sill-ride
# C1 (no local peak), so floor-pinned verts read depth 0.10 (comfortably >
# EPS, wet) with the mesh still watertight. Dormant on the pinned SITE_CHUNK
# (its chute resolves to zero interior knots, r3-task-12a-report.md) — a
# geometry coincidence, not an algorithm property; the pond is where it bites.
# Sill-ride floor `dense[k] >= ground[k] + DESCENT_CLAMP` and the second-diff
# bound move WITH the constant, so both stay consistent.
const DESCENT_CLAMP := 0.10
# r3 Task 12a: the ORIGINAL "ease, then clamp to ground+DESCENT_CLAMP, then
# re-smooth over an >=8m box window" pipeline (3cd407d) was self-defeating —
# the resmooth pass, run AFTER the clamp, is a plain average with the clamp's
# OWN unclamped neighbours, so it routinely pulled a just-clamped sample back
# UNDER the very floor it had just been pinned to (measured at the site: the
# resmoothed curve landed 0.2228m BELOW ground+DESCENT_CLAMP at one dense
# sample — see this task's report). Replaced by the monotone knot envelope
# below (_find_descent_knots/_eval_descent_knots): the ground clamp is no
# longer a post-hoc correction that something else can undo — a ground
# contact the naive ease would under-run becomes a KNOT the curve is fit
# THROUGH, and nothing runs after that fit to disturb it. DESCENT_RESMOOTH_
# WINDOW and _box_smooth are deleted along with the pass they configured.
# Arc-length (metres) a FLAT run in the naive, region-independent bed chase
# (see _find_descent_spans' own `raw`) must reach to count as a genuine
# intervening pool that ends a descent span. Shorter flat runs (a storey
# ledge/shelf mid-slope, not a real landing) are ABSORBED into the
# surrounding span instead, merging what would otherwise be two-plus short,
# steep, independently-eased drops into one longer, gentler one — measured
# necessary at the site (r3-task-12-report.md): the chute's own 12m flat
# blip between two ~4m storey drops, left un-merged, eases each drop over
# just one ~12-24m segment on its own, which is short enough relative to a
# single storey's drop that even a smootherstep's OWN peak curvature (at its
# midpoint, 1.875x the span's average slope) breaches the "no second-
# difference step > 0.5m per 4m sample" bound the red test measures; merged
# into one span, the SAME total drop spreads over enough arc length that the
# peak curvature drops comfortably under it (see the report's own
# before/after numbers). 24.0 reuses this file's own existing 24m feature
# scale (FALL_DROP_MIN's own window, steep_scan's own sliding window) rather
# than inventing an unrelated new one.
const DESCENT_POOL_GAP := 24.0

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
# I-1 (final-review-run2.md): the plan also specifies the fill as "unlimited
# distance, no depth cap," which is in tension with ANY fixed window — a
# flood reaching >30m past a chunk border from its own seeds (a pond near
# POND_R_MAX=140m, or a long still-water flood over storey-flat ground)
# could in principle leave its own seeds outside a neighbouring chunk's
# window, so that chunk would mesh the flooded ground dry: a hard wet/dry
# crack at the border. MEASURED, not assumed: tests/test_water_field.gd's
# test_wet_agreement_across_all_chunk_borders walks all four borders of
# several chunks (including a pond at bound_radius=139.0, right at
# POND_R_MAX's own ceiling) on two independently-generated seeds (the pinned
# 2697992464 plus 991177), comparing wet() between neighbouring chunks at
# every 3m step across the FULL 0-30m margin on both sides of each shared
# border — 8712 points checked, ZERO mismatches. The margin is therefore
# promoted from "the brief said so" to measured-adequate on the seeds this
# suite exercises; it remains a WINDOWING HAZARD in principle (a pond whose
# true reach exceeds this margin, or a still-water flood over unusually flat
# terrain, could still crack on some future seed) — named as a known
# limitation in .superpowers/sdd/progress.md's own running ledger, the same
# CLASS of hazard as final-review-run2.md's known-limitations roll-up item 1
# (the 6m fill lattice's own blind spot), not fixed proactively since no
# live instance has been found. The oracle above is the regression gate: if
# a future seed/site DOES trip it, the fix is a seed-aware adaptive window
# (extend the margin to cover any in-ctx body's own footprint + slack)
# rather than a blind margin bump.
#
# PERF (Phase 1 report): the 3m lattice (85x85=7225 samples) measured a
# median 59.8ms per ctx() on this machine — ~4x over the 15ms budget (the
# brief's own escape hatch: "if the 3m lattice fill exceeds budget, fill at
# 6m and bilinear down"). Coarsened to 6m (43x43=1849 samples, ~3.9x fewer);
# level_at's existing bilinear (_fill_bilinear) already interpolates at
# whatever FILL_STEP is configured, so no other code changed — only these
# constants. Both timings are in the Phase 1 report.
const FILL_STEP := 6.0        # coarsened from 3.0 (the mesh's own lattice step) — see PERF above
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

# C1 fix (final-review-run2.md Critical 1): a TRACE-OWNED canonical ground
# source, memoized per source_cell exactly like _profiles itself, so
# profile()'s terrain hug is a pure function of (trace, plan) instead of
# whichever caller's chunk-window happened to reach it first. Guarded by the
# SAME _profiles_lock — both caches are populated together inside profile()'s
# one critical section, so a second lock would only add contention without
# adding safety (see profile()'s own comment on why the lock spans the
# compute, not just the dict ops).
static var _trace_regions: Dictionary = {}   # trace.source_cell -> HeightfieldRegion
# Radius (in HeightfieldPlan tile-cells) around a trace's own bbox centre
# passed to compute_region when building its canonical region. compute_region
# ALREADY pads any requested radius by a fixed ~25-cell margin internally
# (LEVELS_PER_STOREY + _CLIFF_SEARCH_MAX + max_storeys, independent of the
# requested radius — see HeightfieldPlan.compute_region), and that margin
# alone comfortably covers everything ONE _DESCENT_STEP-spaced segment walk
# needs (a 12m TRACE_STEP segment plus TerrainSurfaceField's own 1-cell
# cardinal/diagonal neighbour reads). This constant only needs to cover the
# WORST-CASE segment's own extent — a small, fixed value — never the whole
# trace: see _trace_owned_region's own docstring for why one region per
# trace, sized to the trace's bbox (not one per segment), is the right unit.
const _TRACE_REGION_MARGIN_CELLS := 4


## Trace-owned canonical HeightfieldRegion, built once per source_cell (and
## reused by every caller thereafter — hand in hand with _profiles' own
## per-source_cell memoization) from the trace's OWN world-space bbox
## (RiverTrace.bounds(), which already folds in source_pool/pond extents),
## not from any caller's chunk. This is what makes profile()'s cache key
## sound again: every plan-backed caller for a given source_cell computes
## (or reuses) the exact SAME region, so the terrain hug can no longer
## depend on caller order.
##
## COST (measured this task, see the report): compute_region's cost is
## dominated by a ~25-cell FIXED internal margin (LEVELS_PER_STOREY +
## _CLIFF_SEARCH_MAX + max_storeys), not by the requested radius — radius=0
## already costs ~65ms cold on this machine, radius=8 ~120ms. A single
## region sized to cover a trace's full bbox (up to ~2640m/110 tile-cells
## for the longest legal trace) would need radius~110-135 and cost
## 2-3 SECONDS (quadratic in radius: ~27-32us/cell, confirmed by direct
## measurement) — real, but this is a ONE-TIME cost per trace, paid once
## ever and cached forever after in _trace_regions/_profiles, exactly like
## the existing "whole-session static cache" design this fix restores the
## soundness of (see _profiles' own comment) — not a per-chunk-build cost.
## It is comparable in order of magnitude to the codebase's OTHER existing
## one-time cold cost (FieldTerrainStreamer._ready's own comment: "the first
## build pays the whole cold water-trace cache (~10s)" for WaterPlan's trace
## generation alone). It does NOT run on the steady-state per-chunk path
## profile()'s own PERF comments budget against (~9ms/chunk fill) — that
## budget is for the FILL, which reads the trace's already-computed,
## already-cached profile.levels; this cost is paid once per trace, the
## first time ANY chunk anywhere touches it, not once per chunk.
static func _trace_owned_region(trace: RiverTrace, plan: HeightfieldPlan) -> HeightfieldRegion:
	if _trace_regions.has(trace.source_cell):
		return _trace_regions[trace.source_cell]
	var bounds: Rect2 = trace.bounds()
	var centre: Vector2 = bounds.get_center()
	var half_span: float = maxf(bounds.size.x, bounds.size.y) * 0.5
	var radius: int = int(ceil(half_span / TILE)) + _TRACE_REGION_MARGIN_CELLS
	var cx: int = int(roundf(centre.x / TILE))
	var cz: int = int(roundf(centre.y / TILE))
	var region: HeightfieldRegion = plan.compute_region(cx, cz, radius)
	_trace_regions[trace.source_cell] = region
	return region


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
##
## r3 Task 12 follow-up (seeding): within a DESCENT SPAN the seeds ride the
## profile's own dense smooth curve (prof.descents — cached by profile()
## from _dense_span_curve/_dense_span_points) at _DESCENT_STEP (~4m)
## spacing, replacing the span-interior 12m trace-sample discs. The
## per-12m-sample discs' hard lowest-wins competition was exactly what
## re-quantized the smooth ramp back into flat-ramp-flat kinks at
## fill-lattice boundaries — and, worse, fragmented the flood where the
## redistributed plateau levels dipped below a connecting cell's ground
## (r3-task-12-report.md, "Root cause"). Adjacent dense seeds disagree by at
## most the curve's own local 4m slope step, so the fill's bilinear surface
## tracks the ramp instead of stair-casing it. Span ENDPOINT samples (lo,
## hi) keep their ordinary per-sample discs too — their levels coincide with
## the dense curve's own pinned anchors, so the duplicate is a no-op under
## lower-wins (belt and braces, not a second opinion). ONLY the seed set
## changes here: _relax_fill's rule (4-connected spread, ground < level -
## EPS, ascending lower-level-wins) is untouched, so the unique-fixpoint
## argument (Phase 0 controller ruling — see _build_fill's docstring)
## survives verbatim: it never depended on the seed set's density or
## placement, only on its determinism, and the dense seeds are the same
## pure function of (trace, plan) the per-sample seeds were (levels cached
## in _profiles under the canonical-region key; positions/widths from the
## trace alone — see _dense_span_points). Ponds' seeding (_seed_ponds) is
## unchanged.
static func _seed_rivers(c: Dictionary, region, base: Vector2, m1: int,
		levels: PackedFloat32Array, gnd: PackedFloat32Array, pq: PriorityQueue) -> void:
	for tr: RiverTrace in c.rivers:
		var prof: Dictionary = profile(tr, region)
		var descents: Array = prof.get("descents", [])
		var in_span := PackedByteArray()
		in_span.resize(tr.points.size())
		for d: Dictionary in descents:
			for si in range(int(d.lo) + 1, int(d.hi)):
				in_span[si] = 1   # strictly interior — endpoints keep their per-sample disc
		for si in tr.points.size():
			if in_span[si] == 1:
				continue
			var p: Vector2 = tr.points[si]
			var w: float = tr.widths[si]
			var lvl: float = prof.levels[si]
			_seed_disc(region, base, m1, levels, gnd, pq, p, w, lvl)
		for d: Dictionary in descents:
			var dpos: PackedVector2Array = d.pos
			var dw: PackedFloat32Array = d.w
			var dlvl: PackedFloat32Array = d.lvl
			for k in dpos.size():
				_seed_disc(region, base, m1, levels, gnd, pq, dpos[k], dw[k], dlvl[k])


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
## production caller (ctx() with a region, WaterSkin.build) always passes
## one.
##
## C1 fix (final-review-run2.md Critical 1): a `region` that carries a real
## `plan` back-pointer (built by HeightfieldPlan.compute_region — see
## HeightfieldRegion.plan's own docstring; hand-built test fixtures that
## construct a HeightfieldRegion directly leave `plan` null) is traded here
## for a TRACE-OWNED canonical region from that SAME plan (_trace_owned_
## region), sized to the trace's own bbox rather than any caller's chunk
## window. This is what makes profile() a pure function of (trace, plan)
## again: every plan-backed caller for a given source_cell ends up shaping
## the descent against the exact same ground data regardless of which
## chunk/region reached this function first — the bug this fixes (see the
## final review) was exactly that the FIRST caller's chunk-scoped region won
## and poisoned the cache for every later caller, including ones whose own
## region would have been accurate. A region with no plan (or no region at
## all) keeps the OLD region-identity behaviour unchanged — see the
## region-optional note above; those callers have no plan to build a
## canonical source from in the first place.
static func profile(trace: RiverTrace, region = null) -> Dictionary:
	# Check-compute-store guarded end to end: the streamer's worker thread and
	# a teleport-triggered main-thread build can both call profile() for the
	# same trace at once. Profiles are small, so holding the lock across the
	# compute (not just the dictionary ops) costs nothing measurable.
	var plan_backed: bool = region != null and region.plan != null
	# Cache key: a plan-backed call is keyed on source_cell ALONE — sound,
	# because _trace_owned_region guarantees every plan-backed caller for
	# this source_cell shapes against the identical canonical region (see
	# that function's own docstring), so there is no longer a "which region"
	# axis left to disambiguate. A non-plan-backed call (region-less probe,
	# or a hand-built-fixture region with no plan) keeps the OLD key
	# (region != null) so it can never collide with, or be shadowed by, a
	# plan-backed call for the same trace — the two regimes are disjoint by
	# construction (different Array shapes never compare equal as Dictionary
	# keys), matching the region-optional note above: a region-less probe
	# must never poison the cache for the same trace's later terrain-aware
	# call, or vice versa.
	var cache_key = trace.source_cell if plan_backed else [trace.source_cell, region != null]
	_profiles_lock.lock()
	if _profiles.has(cache_key):
		var cached: Dictionary = _profiles[cache_key]
		_profiles_lock.unlock()
		return cached
	if plan_backed:
		region = _trace_owned_region(trace, region.plan)
	var n: int = trace.points.size()
	var levels := PackedFloat32Array()
	levels.resize(n)
	# r3 Task 12 follow-up (seeding): the descent spans' own dense shaped
	# curves, cached alongside levels[] under the SAME key — one entry per
	# span: {lo, hi, pos, w, lvl} where pos/w come from _dense_span_points
	# (pure function of the trace) and lvl is the exact _dense_span_curve
	# output levels[] was resampled from (post pond-reconciliation, below).
	# _seed_rivers reads these so the fill's seeds ride the smooth curve at
	# ~_DESCENT_STEP spacing instead of re-quantizing it through the 12m
	# trace samples — same purity as levels[] itself (plan-backed callers all
	# shape against the canonical trace-owned region).
	var descents: Array = []
	var lvl: float = trace.beds[0] + SURFACE_RIDE
	if trace.source_pool != null:
		lvl = minf(lvl, trace.source_pool.surface_y())
	levels[0] = lvl
	if region == null:
		# OLD instant bed-chase fallback, unchanged (see the region-optional
		# note above): no terrain at all, so there is nothing to shape a span
		# against either — span detection needs a ground CLAMP just as much
		# as the ordinary per-segment hug does.
		for i in range(1, n):
			lvl = minf(lvl, trace.beds[i] + SURFACE_RIDE)
			levels[i] = lvl
	else:
		# r3 Task 12: two passes. First, the naive monotone chase over beds[]
		# ALONE (no region, no shaping) — a pure function of the trace's own
		# data, exactly the region==null fallback above. This `raw` sequence
		# is what span detection reads (see _find_descent_spans): it is where
		# the trace WANTS to end up, before any terrain-hugging or easing
		# decides how it gets there.
		var raw := PackedFloat32Array()
		raw.resize(n)
		raw[0] = levels[0]
		for i in range(1, n):
			raw[i] = minf(raw[i - 1], trace.beds[i] + SURFACE_RIDE)
		var arclen := PackedFloat32Array()
		arclen.resize(n)
		for i in range(1, n):
			arclen[i] = arclen[i - 1] + trace.points[i - 1].distance_to(trace.points[i])
		var spans: Array = _find_descent_spans(raw, arclen)
		var i: int = 1
		var span_idx: int = 0
		while i < n:
			if span_idx < spans.size() and int(spans[span_idx].lo) == i - 1:
				var lo: int = spans[span_idx].lo
				var hi: int = spans[span_idx].hi
				var shaped: Dictionary = _shape_descent_span(
					region, trace, lo, hi, levels[lo], raw[hi], arclen)
				var samples: PackedFloat32Array = shaped.samples
				for k in range(lo + 1, hi + 1):
					levels[k] = samples[k - lo]
				var walk: Dictionary = _dense_span_points(trace, lo, hi, arclen)
				descents.append({"lo": lo, "hi": hi, "pos": walk.pos,
					"w": walk.w, "lvl": shaped.dense})
				i = hi + 1
				span_idx += 1
			else:
				var target: float = minf(levels[i - 1], trace.beds[i] + SURFACE_RIDE)
				levels[i] = _descend_segment(region, trace.points[i - 1], trace.points[i], levels[i - 1], target)
				i += 1
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
			# r3 Task 12 follow-up (seeding): mirror the raise into the cached
			# dense descent curves — seeds read THOSE (see _seed_rivers), so a
			# dense tail left below ps would seed water below the pond it
			# feeds, exactly what the per-sample raise above forbids. Each
			# dense curve is monotone non-increasing, so its below-ps values
			# are a trailing contiguous run — maxf over every value raises
			# exactly that run (everything above ps is untouched by maxf) and
			# keeps the curve monotone; the same argument the per-sample
			# backward walk relies on, applied dense.
			for d: Dictionary in descents:
				var dl: PackedFloat32Array = d.lvl
				for k in dl.size():
					dl[k] = maxf(dl[k], ps)
				d["lvl"] = dl
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
			# r3 Task 12 follow-up (seeding): mirror into the dense cache. Only
			# the trace's own LAST sample was just overwritten (hugged down
			# toward ps), so only a span that ends exactly at that sample can
			# disagree — pin its final dense value down to the same hugged
			# level (minf keeps the curve monotone: lowering the last value of
			# a non-increasing sequence cannot break it). The step this leaves
			# in the dense tail is the SAME step the per-sample profile now
			# carries at n-1 — a genuine cliff at the shore, welded by the
			# fill's relaxation exactly as the comment above describes.
			for d: Dictionary in descents:
				if int(d.hi) == n - 1:
					var dl: PackedFloat32Array = d.lvl
					if dl.size() > 0:
						dl[dl.size() - 1] = minf(dl[dl.size() - 1], levels[n - 1])
						d["lvl"] = dl
	var out := {"levels": levels, "descents": descents}
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
##
## r3 Task 12 (round-4 addendum): this per-SEGMENT hug is now used only for
## segments OUTSIDE a descent span (see _find_descent_spans/
## _shape_descent_span, both called from profile()) — ordinary reaches,
## exactly the "gentle terrain" case this docstring already describes, where
## end_target never moves far from start_lvl and hugging essentially never
## engages. Segments INSIDE a span are shaped by _shape_descent_span instead:
## chasing each segment's own LOCAL end_target (as this function does) is
## exactly the behaviour the owner rejected for a real multi-segment
## descent — end_target itself follows the storey-quantized bed sample by
## sample, so even a perfectly-smooth per-segment ease reproduces a
## staircase across several segments (smootherstep's own zero-slope
## endpoints reset the curve flat at every trace sample). This function's
## own code is otherwise unchanged.
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


## r3 Task 12: maximal DESCENT SPANS over the naive, region-independent
## target chase `raw` (profile()'s own `raw[i] = min(raw[i-1], beds[i] +
## SURFACE_RIDE)`, i.e. exactly what profile() would produce with no
## terrain-aware shaping at all — see profile()'s own two-pass comment). A
## span [lo, hi] is a run of trace-sample indices across which `raw` is
## actively dropping, merging across any FLAT gap shorter than
## DESCENT_POOL_GAP (a storey ledge mid-slope, not a real landing — see that
## constant's own derivation) so the whole stretch between two GENUINE flat
## reaches becomes ONE span. `raw` (not the shaped `levels`) is deliberately
## the signal read here: span detection must not depend on shaping decisions
## made for an EARLIER span on the same trace, and `raw` is a pure function
## of trace.beds alone, independent of any of that.
## Returns Array of {lo: int, hi: int}, ordered by lo ascending, non-
## overlapping (each ends before the next begins — see the `i = hi + 1`
## resume below). Empty when the trace never drops (a flat/joined trace, or
## one still short of its first descent).
static func _find_descent_spans(raw: PackedFloat32Array, arclen: PackedFloat32Array) -> Array:
	var n: int = raw.size()
	var spans: Array = []
	var i: int = 1
	while i < n:
		if raw[i - 1] - raw[i] <= EPS:
			i += 1
			continue
		var lo: int = i - 1
		var hi: int = i
		while hi + 1 < n:
			if raw[hi] - raw[hi + 1] > EPS:
				hi += 1
				continue
			# raw goes flat starting at hi -- measure how far the flat run
			# reaches before deciding whether it is a real pool.
			var flat_end: int = hi
			while flat_end + 1 < n and raw[flat_end] - raw[flat_end + 1] <= EPS:
				flat_end += 1
			if arclen[flat_end] - arclen[hi] >= DESCENT_POOL_GAP or flat_end + 1 >= n:
				break   # a genuine pool (or the trace ends) -- span ends at hi
			hi = flat_end + 1   # short blip -- absorb it, keep descending
		spans.append({"lo": lo, "hi": hi})
		i = hi + 1
	return spans


## r3 Task 12 (round-4), reshaped r3 Task 12a (sill-riding envelope): shapes
## ONE descent span [lo, hi] (trace-sample indices) as ONE continuous, C1
## curve from `anchor_start` (the level already HELD at lo — the flat pool
## immediately upstream, already resolved by profile()'s own walk up to this
## point) to `anchor_end` (the naive `raw[hi]` target — the flat pool
## immediately downstream). This is the owner's reversal of run-2's
## terrain-hugging descent (see this task's brief): the ramp is a pure
## function of arc length between the two anchors and the ground it must
## clear — ground is never the shaping signal for the DROP itself, only for
## where the curve is forced to bulge up and ride over a sill (see
## _dense_span_curve), so intermediate storey ledges inside the span no
## longer echo into the water surface as steps, AND no longer poke through
## it either (see DESCENT_CLAMP's own comment for why the round-4 pipeline's
## post-clamp re-smooth broke that second guarantee).
## anchor_start/anchor_end are ALSO floored against their own sample's
## ground (defensive — profile()'s callers already keep both safely above
## ground by construction, but this function does not need to trust that).
## Split into two: _dense_span_curve (the actual shaping, at _DESCENT_STEP
## resolution — the granularity the brief's own smoothness oracle measures,
## "second differences... per 4m sample", finer than a trace's own
## TRACE_STEP=12m sample spacing) and this wrapper, which floors the anchors
## against ground and resamples the dense curve down to profile()'s
## contractual one-level-per-trace-sample shape. Kept separate so the dense
## curve itself is directly testable (test_descent_is_smooth_pool_to_pool)
## without reaching through the coarser resample.
## Returns {"samples": PackedFloat32Array (one level per trace sample
## lo..hi, size hi-lo+1; index 0 is trace.points[lo], last is
## trace.points[hi]), "dense": PackedFloat32Array (the _DESCENT_STEP-spaced
## shaped curve those samples were resampled FROM — steps+1 values on
## _dense_span_points' k-grid)}. The dense curve rides along because the
## fill's seeding now consumes it directly (r3 Task 12 follow-up — see
## _seed_rivers): seeds must carry the smooth curve's own values, not the
## coarser per-sample resample, or the 12m-granularity lowest-wins disc
## competition re-quantizes the ramp right back into steps.
static func _shape_descent_span(region, trace: RiverTrace, lo: int, hi: int,
		anchor_start: float, anchor_end: float, arclen: PackedFloat32Array) -> Dictionary:
	var ground_lo: float = TerrainSurfaceField.surface_y(region, trace.points[lo].x, trace.points[lo].y)
	var ground_hi: float = TerrainSurfaceField.surface_y(region, trace.points[hi].x, trace.points[hi].y)
	anchor_start = maxf(anchor_start, ground_lo + DESCENT_CLAMP)
	anchor_end = maxf(anchor_end, ground_hi + DESCENT_CLAMP)
	var span_len: float = arclen[hi] - arclen[lo]
	if span_len < 0.001:
		var flat := PackedFloat32Array()
		flat.resize(hi - lo + 1)
		flat.fill(anchor_start)
		# degenerate dense twin: _dense_span_points' k-grid for a zero-length
		# span is steps=1 -> 2 samples, both at trace.points[lo]
		return {"samples": flat, "dense": PackedFloat32Array([anchor_start, anchor_start])}
	var smoothed: PackedFloat32Array = _dense_span_curve(region, trace, lo, hi, anchor_start, anchor_end, arclen)
	var steps: int = smoothed.size() - 1
	# Resample the dense (fixed _DESCENT_STEP-spaced) curve at each trace
	# sample's OWN arc offset -- profile()'s levels[] contract is one entry
	# per trace point, not per dense substep.
	var out := PackedFloat32Array()
	out.resize(hi - lo + 1)
	out[0] = anchor_start
	out[hi - lo] = anchor_end
	for idx in range(lo + 1, hi):
		var d2: float = arclen[idx] - arclen[lo]
		var kf: float = clampf(d2 / _DESCENT_STEP, 0.0, float(steps))
		var k0: int = int(floor(kf))
		var k1: int = mini(k0 + 1, steps)
		var tt: float = kf - float(k0)
		out[idx - lo] = lerpf(smoothed[k0], smoothed[k1], tt)
	return {"samples": out, "dense": smoothed}


## r3 Task 12a: the dense, _DESCENT_STEP-spaced, FULLY SHAPED curve for span
## [lo,hi] — the smooth monotone UPPER ENVELOPE of (straight pool-to-pool
## ease) ∨ (ground + DESCENT_CLAMP), fit THROUGH a set of KNOTS rather than
## clamped-then-corrected (see DESCENT_CLAMP's own comment for why a
## post-clamp correction pass is what broke the round-4 version of this
## function). `anchor_start`/`anchor_end` are taken as given (already floored
## against ground by the caller — see _shape_descent_span); called directly
## (bypassing the coarser trace-sample resample) by test_water_field.gd's
## test_descent_is_smooth_pool_to_pool, which is what "second differences...
## per 4m sample" actually measures.
## Two steps:
##  1. _find_descent_knots discovers the knot set: the two anchors, plus
##     every ground contact the naive straight (2-knot) ease would under-run
##     — iterated to a fixpoint (a knot can shift where the NEXT under-run is
##     found, but never removes a knot, so the search only ever adds; see
##     that function's own docstring for the termination argument).
##  2. _eval_descent_knots fits ONE monotone cubic Hermite spline (Fritsch-
##     Carlson tangents) through every knot — provably monotone and C1 by
##     construction (see that function's own docstring for the proof) — and
##     NOTHING runs afterward to disturb the fit. The knots themselves are
##     the only ground consultation; once placed, they ARE the curve.
## Returns steps+1 samples (steps = ceil(span_len/_DESCENT_STEP)) at arc
## offsets 0, _DESCENT_STEP, 2*_DESCENT_STEP, ..., span_len from
## trace.points[lo]; index 0 == anchor_start exactly, last == anchor_end
## exactly (both are the first/last knot by construction — see
## _find_descent_knots). World positions come from _dense_span_points — the
## SAME k-grid walk the fill's dense seeding reads (r3 Task 12 follow-up),
## one implementation so curve levels and seed positions can never drift
## apart.
static func _dense_span_curve(region, trace: RiverTrace, lo: int, hi: int,
		anchor_start: float, anchor_end: float, arclen: PackedFloat32Array) -> PackedFloat32Array:
	var pos: PackedVector2Array = _dense_span_points(trace, lo, hi, arclen).pos
	var steps: int = pos.size() - 1
	var ground := PackedFloat32Array()
	ground.resize(steps + 1)
	for k in range(steps + 1):
		ground[k] = TerrainSurfaceField.surface_y(region, pos[k].x, pos[k].y)
	var knots: Array = _find_descent_knots(ground, steps, anchor_start, anchor_end)
	var dense: PackedFloat32Array = _eval_descent_knots(knots, steps)
	dense[0] = anchor_start
	dense[steps] = anchor_end
	return dense


## r3 Task 12a: discovers the knot set for one descent span's dense
## _DESCENT_STEP grid (indices 0..steps against `ground`, the rendered
## terrain sampled at each — see _dense_span_curve). Starts from JUST the two
## span anchors (k=0 -> anchor_start, k=steps -> anchor_end) and repeatedly:
##  1. evaluates the monotone curve through the CURRENT knot set
##     (_eval_descent_knots);
##  2. scans for maximal runs of dense indices where that curve under-runs
##     ground + DESCENT_CLAMP (a 1e-4 slack absorbs float noise at an exact
##     touch);
##  3. for each such run, inserts ONE new knot at the run's own highest
##     `ground + DESCENT_CLAMP` point — the single point most likely to pull
##     the WHOLE run clear in one shot (it is at least as tall as every
##     other point in the run), a fast-convergence heuristic, not a hard
##     per-insertion guarantee: inserting an interior knot can shift its
##     NEIGHBOURS' own Fritsch-Carlson tangents too (see
##     _descent_knot_tangents), so correctness does not rest on any single
##     insertion clearing its run — it rests on the OUTER loop, which
##     re-scans the FRESH curve (step 1, above) against EVERY dense index
##     again next pass and keeps adding knots until a full scan finds zero
##     violations;
## and repeats until that fixpoint (a pass adds no knot). TERMINATION: knots
## are only ever ADDED, never removed or moved, and there are at most
## `steps - 1` interior dense indices that could ever become one (each index
## becomes a knot at most once — see the `is_knot` guard below) — so the
## outer loop runs at most `steps - 1` times even in the worst case
## (`guard`'s own budget is one wider, `steps + 2`, purely so an off-by-one
## in this argument fails LOUD, as an assert-shaped print, rather than
## silently under-iterating); empirically (this task's report) real spans
## converge in a single pass.
## A new knot's value is `ground + DESCENT_CLAMP` at its own point, CLAMPED
## into [next-knot's value, previous-knot's value] before insertion — the
## span's upstream/downstream neighbours in the knot list at the moment of
## insertion, which by induction already bracket every value in between
## (base case: the two anchors bracket everything, by profile()'s own
## monotone chase; inductive step: a new knot is only ever inserted STRICTLY
## between two existing knots and clamped to their own values). This is what
## keeps the KNOT VALUES themselves monotone non-increasing by construction —
## the property _eval_descent_knots' own monotonicity proof depends on —
## without needing to trust that `ground + DESCENT_CLAMP` itself happens to
## be monotone (it isn't; the terrain is storey-jagged).
## Returns Array of {k: int, val: float} ordered by k ascending, first entry
## always {k: 0, val: anchor_start}, last always {k: steps, val: anchor_end}.
static func _find_descent_knots(ground: PackedFloat32Array, steps: int,
		anchor_start: float, anchor_end: float) -> Array:
	var knots: Array = [{"k": 0, "val": anchor_start}, {"k": steps, "val": anchor_end}]
	var guard: int = steps + 2
	while guard > 0:
		guard -= 1
		var curve: PackedFloat32Array = _eval_descent_knots(knots, steps)
		var is_knot := {}
		for kn: Dictionary in knots:
			is_knot[int(kn.k)] = true
		var added := false
		var k: int = 1
		while k < steps:
			if is_knot.has(k) or curve[k] >= ground[k] + DESCENT_CLAMP - 0.0001:
				k += 1
				continue
			var run_end: int = k
			while run_end + 1 < steps and not is_knot.has(run_end + 1) \
					and curve[run_end + 1] < ground[run_end + 1] + DESCENT_CLAMP - 0.0001:
				run_end += 1
			var peak_k: int = k
			# The knot's stored value is ground + DESCENT_CLAMP (uniform floor,
			# now 0.10 > EPS so a floor-pinned vert reads strictly wet — see
			# DESCENT_CLAMP's docstring). Every candidate in the run shares the
			# same constant offset, so it cannot change WHICH point is the peak
			# (a constant shift preserves argmax) or the tie-break below.
			var peak_v: float = ground[k] + DESCENT_CLAMP
			for kk in range(k, run_end + 1):
				var fv: float = ground[kk] + DESCENT_CLAMP
				if fv >= peak_v:   # ">=", not ">": a TIE prefers the LATER (more downstream) point
					peak_v = fv
					peak_k = kk
			var insert_at: int = knots.size()
			for i in range(knots.size()):
				if int(knots[i].k) > peak_k:
					insert_at = i
					break
			peak_v = clampf(peak_v, knots[insert_at].val, knots[insert_at - 1].val)
			knots.insert(insert_at, {"k": peak_k, "val": peak_v})
			added = true
			k = run_end + 1
		if not added:
			break
	return knots


## r3 Task 12a: evaluates the piecewise curve through `knots` (Array of
## {k, val}, k ascending, first/last at 0/steps — see _find_descent_knots) at
## every dense index 0..steps, as a MONOTONE CUBIC HERMITE spline with
## Fritsch-Carlson tangents (Fritsch & Carlson, "Monotone Piecewise Cubic
## Interpolation," SIAM J. Numer. Anal. 17(2), 1980) — the brief's OTHER
## sanctioned option alongside plain smoothstep segments. Chosen over a
## zero-slope-at-every-knot scheme (every consecutive pair independently
## smootherstep-eased) because forcing the curve to a dead stop at EVERY
## ground-contact knot, not just the two flat-pool anchors, concentrates
## curvature into a shorter usable arc either side of each knot — measured
## regression: it pushed one real 12m trace-sample hop on the site chute to
## 4.04m, over test_profiles_monotone_and_continuous's own 4.02 ceiling.
## Letting the curve keep flowing (non-zero slope) through an interior sill
## knot is also the physically sensible shape — water riding over a
## submerged ridge doesn't pause there — and spreads the same total drop
## over more effective arc length (measured: max per-trace-sample drop
## 2.80m vs 4.04m, same span, same knots — see this task's report).
## _descent_knot_tangents computes one tangent per knot; both OUTER
## (anchor) tangents are pinned to zero (C1 with the flat pools either side
## of the span), interior tangents follow the standard FC rule.
## PROOF OF C1: cubic Hermite basis functions are C1 by construction WHEN
## consecutive segments agree on the tangent at their shared knot — which
## they do here by definition (`tangents[seg]` is read once per knot, used
## as the outgoing m1 of the segment ending there and the incoming m0 of
## the segment starting there).
## PROOF OF MONOTONICITY (Fritsch-Carlson's own sufficient condition): a
## cubic Hermite segment with secant slope Δ=(y1-y0)/h and endpoint tangents
## (m0,m1) is monotone on [0,1] whenever m0/Δ and m1/Δ both lie in [0,3].
## _descent_knot_tangents guarantees this for EVERY segment: an interior
## tangent m_i is either exactly 0 (always safe — (0, anything in [0,3]) is
## inside the FC region) or shares the sign of both flanking secants
## delta[i-1]/delta[i] (the sign-disagreement branch already zeroed it
## otherwise) with |m_i| <= 3*min(|delta[i-1]|, |delta[i]|) <= 3*|delta[i-1]|
## AND <= 3*|delta[i]| simultaneously (a min is <= either operand) — exactly
## m_i/delta[i-1] and m_i/delta[i] both in [0,3]. The two OUTER tangents are
## pinned to 0, trivially in-range against their own single flanking Δ. Knot
## VALUES are monotone non-increasing by construction (see
## _find_descent_knots' own proof), so Δ <= 0 for every segment — combined
## with the tangent bound above, every segment is monotone non-increasing,
## and segments agree exactly at every shared knot, so the concatenated
## curve is monotone non-increasing end to end. No post-hoc clamp pass is
## needed or run (contrast the round-4 version's final `minf` sweep) — see
## DESCENT_CLAMP's own comment for why a pass like that is exactly the
## mechanism that broke sill-riding before.
static func _eval_descent_knots(knots: Array, steps: int) -> PackedFloat32Array:
	var tangents: PackedFloat32Array = _descent_knot_tangents(knots)
	var out := PackedFloat32Array()
	out.resize(steps + 1)
	for seg in range(knots.size() - 1):
		var k0: int = knots[seg].k
		var k1: int = knots[seg + 1].k
		var y0: float = knots[seg].val
		var y1: float = knots[seg + 1].val
		var m0: float = tangents[seg]
		var m1: float = tangents[seg + 1]
		var h: float = float(k1 - k0)
		for k in range(k0, k1 + 1):
			var t: float = 0.0 if k1 == k0 else float(k - k0) / h
			var t2: float = t * t
			var t3: float = t2 * t
			var hb00: float = 2.0 * t3 - 3.0 * t2 + 1.0
			var hb10: float = t3 - 2.0 * t2 + t
			var hb01: float = -2.0 * t3 + 3.0 * t2
			var hb11: float = t3 - t2
			out[k] = hb00 * y0 + hb10 * h * m0 + hb01 * y1 + hb11 * h * m1
	return out


## r3 Task 12a: one Fritsch-Carlson tangent per knot (see _eval_descent_knots
## for the monotonicity proof this feeds). `delta[i]` is the secant slope of
## segment i (knot i to knot i+1), in value-per-dense-INDEX units (uniform
## _DESCENT_STEP spacing, so this is the true slope up to a constant global
## scale — the Hermite evaluator multiplies back by the segment's own `h`,
## so the scale cancels exactly). Both outer tangents are 0 (the span's two
## anchors are flat pools — C1 with the water either side of this span, same
## contract the round-4 version's smootherstep ease already guaranteed).
## Every interior tangent is either 0 (at a local extremum in the KNOT
## sequence — one flanking secant flat, or the two disagreeing in sign; a
## flat secant is reachable in practice, e.g. two adjacent knots clamped to
## the same value, and is always safe to zero — see _eval_descent_knots' own
## proof for why (0, anything in [0,3]) is always inside the monotone
## region; a sign DISAGREEMENT cannot actually occur here since knot values
## are monotone non-increasing by construction, so every delta is already
## <= 0, but the guard is kept for robustness/reuse) or the average of its
## two flanking secants, magnitude-limited to 3x the SMALLER of their
## magnitudes — the textbook Fritsch-Carlson sufficient condition (see
## _eval_descent_knots' own proof for why this specific bound is what keeps
## every segment monotone).
static func _descent_knot_tangents(knots: Array) -> PackedFloat32Array:
	var m: int = knots.size() - 1
	var delta := PackedFloat32Array()
	delta.resize(m)
	for i in range(m):
		var h: float = float(int(knots[i + 1].k) - int(knots[i].k))
		delta[i] = (float(knots[i + 1].val) - float(knots[i].val)) / h
	var tangents := PackedFloat32Array()
	tangents.resize(knots.size())
	tangents[0] = 0.0
	tangents[knots.size() - 1] = 0.0
	for i in range(1, knots.size() - 1):
		var d0: float = delta[i - 1]
		var d1: float = delta[i]
		if d0 == 0.0 or d1 == 0.0 or (d0 > 0.0) != (d1 > 0.0):
			tangents[i] = 0.0
			continue
		var mi: float = (d0 + d1) * 0.5
		var min_d: float = minf(absf(d0), absf(d1))
		if absf(mi) > 3.0 * min_d:
			mi = signf(mi) * 3.0 * min_d
		tangents[i] = mi
	return tangents


## r3 Task 12 follow-up (seeding): world positions + channel half-widths for
## span [lo,hi] on the SAME k-grid _dense_span_curve shapes levels on
## (steps = ceil(span_len/_DESCENT_STEP); arc offsets span_len*k/steps from
## trace.points[lo]) — factored out so the curve's own ground sampling and
## the fill's dense seed placement (_seed_rivers) read one identical walk;
## two copies of the seg_i-advance loop would inevitably drift. Widths are
## lerped between the two flanking trace samples' own widths (widths grow
## linearly downstream — WaterPlan._trace — so lerp is exact, not an
## approximation). A PURE function of the trace alone (no region, no plan):
## seed positions must be identical for every chunk whose fill window
## overlaps this trace, or the border-weld/fill-determinism oracles break
## (test_fill_is_deterministic_across_chunks / test_wet_agreement_across_
## all_chunk_borders).
static func _dense_span_points(trace: RiverTrace, lo: int, hi: int,
		arclen: PackedFloat32Array) -> Dictionary:
	var span_len: float = arclen[hi] - arclen[lo]
	var steps: int = maxi(1, int(ceil(span_len / _DESCENT_STEP)))
	var pos := PackedVector2Array()
	pos.resize(steps + 1)
	var w := PackedFloat32Array()
	w.resize(steps + 1)
	var seg_i: int = lo
	for k in range(steps + 1):
		var target_arc: float = arclen[lo] + span_len * float(k) / float(steps)
		while seg_i < hi - 1 and arclen[seg_i + 1] < target_arc:
			seg_i += 1
		var seg_start: float = arclen[seg_i]
		var seg_end: float = arclen[seg_i + 1]
		var seg_t: float = 0.0 if seg_end - seg_start < 0.001 else \
			clampf((target_arc - seg_start) / (seg_end - seg_start), 0.0, 1.0)
		pos[k] = trace.points[seg_i].lerp(trace.points[seg_i + 1], seg_t)
		w[k] = lerpf(trace.widths[seg_i], trace.widths[seg_i + 1], seg_t)
	return {"pos": pos, "w": w}


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
##    search but with NO flood/margin competition — a point claims water
##    when it is within a channel sample's width or a pond's footprint, OR
##    up to CLAIM_FEATHER (8m) past that edge (m < CLAIM_FEATHER, not a
##    literal m < 0 — see _channel_membership_level's own margin math and
##    Minor 4, final-review-run2.md), smallest-margin wins among those. This
##    never fabricates flood coverage outside the window; it just answers
##    "is this point at/near the carved channel/pond," which is always safe
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
## shader item). grade_at is unbounded on purpose; r3 Task 7's own caller
## (WaterSkin._triggers' STEEP_UNSWIMMABLE gate) reads it raw as a magnitude
## threshold, not a display value — any FUTURE caller that needs a
## display-safe range is responsible for clamping it itself.
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
## came from) walking the trace polyline at `step` spacing — shared
## ground-truth for steep_spans' terrain scan. Segment-local t=0 is shared
## with the previous segment's t=1 (no duplicate sample at sample points),
## so the array is one continuous along-channel walk, exactly what
## _steep_scan's sliding window needs to see a drop that straddles a trace
## sample boundary.
##
## Minor 8 (final-review-run2.md, pairs with C1): steep_spans' own rect gate
## (grown by TILE, plus base_p per Minor 5) already discards any span whose
## BOTH ends fall outside the window — walking the WHOLE ~2640m trace's
## ground every chunk build was mostly wasted work over out-of-window
## ground the caller was going to throw away anyway (C1 fixed the separate,
## more serious bug where profile()'s CACHED result depended on that
## out-of-window data; this is the pure performance follow-up: don't walk
## it at all when a caller-scoped rect is available). `clip_rect` is
## optional (null = walk the whole trace, UNCHANGED — steep_spans' own
## hand-built-fixture callers and any future caller with no natural window
## keep exactly today's behaviour): when supplied, this function first
## builds the (cheap) positions-only walk, finds the first/last sample
## index whose position falls inside `clip_rect` GROWN BY ONE MORE 24m
## WINDOW (window_n * step — _steep_scan's own sliding-window lookahead: a
## triggering run just inside the rect's own edge still needs a FULL 24m of
## ground data ahead of it to correctly measure the drop, or the scan would
## silently truncate a real cliff's window at the clip boundary), and only
## pays the expensive TerrainSurfaceField.surface_y call for that
## CONTIGUOUS sub-range (no gaps — a gap would corrupt _steep_scan's
## sliding-window index semantics). Behaviour inside the (doubly-grown)
## window is IDENTICAL to the unclipped walk — this only skips computing
## ground the caller could never have used.
static func _channel_ground_walk(tr: RiverTrace, region, step: float, clip_rect = null) -> Dictionary:
	var grounds := PackedFloat32Array()
	var pos := PackedVector2Array()
	var seg_of := PackedInt32Array()
	var n: int = tr.points.size()
	if n == 0:
		return {"grounds": grounds, "pos": pos, "seg_of": seg_of}
	# Full positions-only walk first (cheap — no surface_y calls yet) so a
	# clip range can be found before paying for any ground sample.
	var all_pos := PackedVector2Array([tr.points[0]])
	var all_seg_of := PackedInt32Array([0])
	for i in range(1, n):
		var a: Vector2 = tr.points[i - 1]
		var b: Vector2 = tr.points[i]
		var seg_len: float = a.distance_to(b)
		var steps: int = maxi(1, int(ceil(seg_len / step)))
		for k in range(1, steps + 1):
			var t: float = float(k) / float(steps)
			all_pos.append(a.lerp(b, t))
			all_seg_of.append(i - 1)
	var lo_idx := 0
	var hi_idx := all_pos.size() - 1
	if clip_rect != null:
		var window_n: int = maxi(1, roundi(24.0 / step))
		var padded: Rect2 = clip_rect.grow(float(window_n) * step)
		lo_idx = -1
		hi_idx = -1
		for i in all_pos.size():
			if padded.has_point(all_pos[i]):
				if lo_idx < 0:
					lo_idx = i
				hi_idx = i
		if lo_idx < 0:
			# No sample anywhere on this trace falls in the padded window —
			# nothing steep_spans could ever report for this trace/chunk.
			return {"grounds": grounds, "pos": pos, "seg_of": seg_of}
	for i in range(lo_idx, hi_idx + 1):
		grounds.append(TerrainSurfaceField.surface_y(region, all_pos[i].x, all_pos[i].y))
		pos.append(all_pos[i])
		seg_of.append(all_seg_of[i])
	return {"grounds": grounds, "pos": pos, "seg_of": seg_of}


## Steep terrain stretches along every river channel in c, whose LIP (`p`) OR
## BASE (`base_p`) lies inside rect (grown by one tile so chunk-border spans
## appear for both neighbouring chunks — Minor 5, final-review-run2.md:
## lip-only gating dropped a span whose base sits in this chunk but whose lip
## lies >TILE outside the rect, leaving the plunge-churn band baked into one
## chunk and not its neighbour, a CUSTOM0 seam at the border for any steep
## stretch taller than the lip-to-base horizontal run) — the terrain-scan
## replacement for the old bed-cut-derived fall_cuts (Phase 2a: falls are a
## PROFILE SHAPE now, not a cut object; this feeds ONLY the shader churn band
## and (later) mist, never geometry — see the file header and profile()'s own
## docstring). Each
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
		var walk: Dictionary = _channel_ground_walk(tr, region, _DESCENT_STEP, grown)
		var spans: Array = _steep_scan(walk.grounds, _DESCENT_STEP)
		if spans.is_empty():
			continue
		var prof: Dictionary = profile(tr, region)
		for span: Dictionary in spans:
			var lo: int = span.lo
			var hi: int = span.hi
			var p: Vector2 = walk.pos[lo]
			var base_pos: Vector2 = walk.pos[hi]
			# Minor 5 (final-review-run2.md): gating on the LIP alone dropped a
			# span whose base (plunge) sits in THIS chunk but whose lip lies
			# >TILE outside the grown rect — the plunge-churn shader band then
			# baked in one chunk and not its neighbour, a CUSTOM0 seam at the
			# border for any steep stretch taller than the lip-to-base
			# horizontal run (~24m). Include the span when EITHER end is
			# in-window — the correct rect test for a span that straddles a
			# chunk border, matching how a river SAMPLE itself is windowed
			# (any endpoint in range keeps it) rather than only its start.
			if not (grown.has_point(p) or grown.has_point(base_pos)):
				continue
			var dirv: Vector2 = (base_pos - p)
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
			var bot_lvl: float = _sample_level(tr, walk.seg_of[hi], base_pos, region)
			# base_p (Phase 2b addition): the world position at the span's own
			# base/plunge end — exposed alongside `p` (the lip) so a future
			# shader/mist-baking consumer can measure "near the base"
			# directly instead of "far downstream of the lip," which for a
			# tall span is not the same distance at all. Purely additive: no
			# existing reader destructures this dict positionally.
			out.append({"p": p, "dir": dirv, "across": Vector2(-dirv.y, dirv.x),
				"half": tr.widths[seg_i] + CLAIM_FEATHER,
				"top": maxf(top_lvl, bot_lvl), "bottom": minf(top_lvl, bot_lvl),
				"drop": span.drop, "base_p": base_pos})
	return out
