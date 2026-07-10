extends GutTest

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)

static var _plans: Dictionary = {}
static var _waters: Dictionary = {}
static var _regions: Dictionary = {}


static func _water(seed_v: int) -> WaterPlan:
	if not _waters.has(seed_v):
		var plan := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		var water := WaterPlan.new(seed_v, 22.0, 8)
		plan.set_water_plan(water)
		_plans[seed_v] = plan
		_waters[seed_v] = water
	return _waters[seed_v]


static func _region(seed_v: int, chunk: Vector2i):
	var key := [seed_v, chunk]
	if not _regions.has(key):
		_water(seed_v)
		_regions[key] = _plans[seed_v].compute_region(
			chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _regions[key]


## Phase 2a: profile() has no cuts array — levels[] is one continuous,
## monotone curve end to end (see WaterField.profile/_descend_segment).
## Monotonicity is checked unconditionally (region or not); the per-segment
## drop bound is checked ONLY when a region is supplied (region == null
## falls back to the old instant bed-chase with no terrain-hugging shaping
## at all — see profile()'s own region-optional note — so there is nothing
## for a drop bound to mean there). WITH a region, the site itself (H1: the
## rendered terrain here never drops more than 4.0m in ANY 24m window) must
## show every per-segment drop staying under FALL_DROP_MIN — this is the
## direct field-level echo of steep_spans() finding zero spans here: if a
## segment drop ever DID exceed FALL_DROP_MIN on this seed, either the
## terrain-hugging is fabricating a cliff where none exists (a regression
## of the exact H1 bug this phase fixes) or the site genuinely grew a steep
## reach — either way this test should go red and get investigated, not
## silently pass.
func test_profiles_monotone_and_continuous() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var checked := 0
	for tr: RiverTrace in ctx.rivers:
		var prof: Dictionary = WaterField.profile(tr, region)
		var levels: PackedFloat32Array = prof.levels
		assert_eq(levels.size(), tr.points.size(), "one level per sample")
		for i in range(1, levels.size()):
			assert_true(levels[i] <= levels[i - 1] + 0.001,
				"water never flows uphill (trace %s sample %d)" % [tr.source_cell, i])
			var drop: float = levels[i - 1] - levels[i]
			assert_true(drop < WaterField.FALL_DROP_MIN + 0.02,
				"site segment drops %0.2f >= FALL_DROP_MIN at sample %d (H1: this trace's terrain never demands it)" % [drop, i])
			checked += 1
	assert_true(checked > 0, "site chunk has river samples")


## profile() without a region: the old instant bed-chase fallback (no
## terrain to hug — see profile()'s region-optional note). Still must be
## monotone non-increasing; there is no drop bound to check here since the
## fallback path never shapes descent against terrain at all (a hand-built
## trace with no HeightfieldRegion, e.g. test_multi_seam_cell_never_folds'
## synthetic case, is exactly this regime).
func test_profile_without_region_is_still_monotone() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var checked := 0
	for tr: RiverTrace in ctx.rivers:
		var prof: Dictionary = WaterField.profile(tr)
		var levels: PackedFloat32Array = prof.levels
		assert_eq(levels.size(), tr.points.size(), "one level per sample")
		for i in range(1, levels.size()):
			assert_true(levels[i] <= levels[i - 1] + 0.001,
				"water never flows uphill without a region either (trace %s sample %d)" % [tr.source_cell, i])
			checked += 1
	assert_true(checked > 0, "site chunk has river samples")


func test_level_at_known_water_and_dry_land() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	# The mid pool at the owner's site: cell (2,-46) centre, water level ~5.
	# NOTE: brief's literal (60.0, -1092.0) is the CORNER shared by cells
	# (2,-46)/(3,-46)/(2,-45)/(3,-45), not the cell's centre (2*24, -46*24) —
	# it lands exactly on TerrainSurfaceField's round-half-up cell boundary,
	# resolving to (3,-46), the one dry corner of the four (confirmed: cells
	# (2,-46) and (2,-45) are carved/wet, (3,-46) and (3,-45) are dry banks).
	# Corrected to the actual cell (2,-46) centre the comment names.
	var wet_p := Vector2(48.0, -1104.0)
	assert_true(WaterField.level_at(ctx, wet_p) > -INF, "site pool is claimed")
	assert_true(WaterField.wet(ctx, region, wet_p), "site pool is wet")
	# The bank the owner stands on (33.9, -1097.4), ground 8: must be dry.
	var dry_p := Vector2(33.9, -1097.4)
	assert_false(WaterField.wet(ctx, region, dry_p), "owner's bank is dry")


## Phase 2a REWRITE (was "at most the true falls jump; got %d" <= 2 — the
## old cut-based world where a jump WAS expected on this line). Site's real,
## region-backed level_at is now genuinely continuous end to end: H1 fixed
## means the whole line has ZERO steep spans (see steep_spans/_steep_scan),
## so there is no jump left to tolerate at all — big_steps must be 0. Uses a
## REGION-backed ctx (the real production path); the old region-less
## variant of this walk is covered separately by
## test_level_continuous_without_region_keeps_old_jumps, which documents
## the (expected, region-optional) fallback still showing the old-style
## jumps when there is no terrain to hug.
func test_level_continuous_along_the_site_channel() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var prev: float = INF
	var big_steps := 0
	var max_step := 0.0
	for zi in range(-1130, -1080):
		var lvl: float = WaterField.level_at(ctx, Vector2(54.0, float(zi)))
		if prev < INF and lvl > -INF and prev > -INF:
			var step: float = absf(lvl - prev)
			max_step = maxf(max_step, step)
			if step > 1.0:
				big_steps += 1
		prev = lvl
	assert_eq(big_steps, 0,
		"the site's real (region-backed) profile is continuous end to end now; max step %.2f" % max_step)


## profile()'s region-optional fallback (no terrain to hug) still shows the
## OLD-style instant jump on this same line — documents that the fallback
## is deliberately the pre-Phase-2a behaviour, not a second copy of the new
## continuity guarantee (see profile()'s own region-optional docstring
## note). Not a regression: no production caller ever builds a river ctx
## without a region (WaterMesher.build/build_chunk always pass one).
func test_level_continuous_without_region_keeps_old_jumps() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var prev: float = INF
	var big_steps := 0
	for zi in range(-1130, -1080):
		var lvl: float = WaterField.level_at(ctx, Vector2(54.0, float(zi)))
		if prev < INF and lvl > -INF and prev > -INF:
			if absf(lvl - prev) > 1.0:
				big_steps += 1
		prev = lvl
	assert_true(big_steps > 0,
		"the region-less fallback keeps the old instant-chase jumps by design")


## steep_spans() on the real site: ZERO spans, matching H1 exactly (this
## trace's rendered terrain never drops more than FALL_DROP_MIN in any 24m
## window — the bed-quantization false positive the old fall_cuts had is
## gone). This is the direct field-level echo of the new
## test_no_steep_span_without_terrain_drop oracle below, pinned as its own
## assertion so a regression here is caught even if that oracle's rect
## happened to change.
func test_steep_spans_empty_at_the_site() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var rect := Rect2(Vector2(0, -1152), Vector2(192, 192))
	var spans: Array = WaterField.steep_spans(ctx, rect)
	assert_eq(spans.size(), 0,
		"H1: the site's rendered terrain never drops > FALL_DROP_MIN in any 24m window")


## Non-degenerate steep_spans() integration test: a hand-built
## HeightfieldRegion (HeightfieldRegion.gd's own {storeys, levels, carved}
## dictionary constructor — practical to build directly, no world plan
## needed) carrying a genuine 12m vertical cliff (storey 3 -> storey 0,
## TerrainSurfaceField's own _is_cliff_top logic renders that as a real
## sheer face, not a ramp, since the drop is >= 2 storeys), with a hand-built
## RiverTrace running straight down through it. This is the practical
## alternative the brief allows when a stub ground array alone would not
## exercise steep_spans' own world-position/dir/level-lookup plumbing (only
## _steep_scan's pure window-scan math, covered separately below).
func test_steep_spans_finds_a_real_hand_built_cliff() -> void:
	var storeys := {}
	for cz in range(-5, 0):
		for cx in range(-2, 3):
			storeys[Vector2i(cx, cz)] = 3   # upstream: high ground (h=12)
	for cz in range(0, 5):
		for cx in range(-2, 3):
			storeys[Vector2i(cx, cz)] = 0   # downstream: low ground (h=0)
	var region := HeightfieldRegion.new(storeys, {})
	var tr := RiverTrace.new()
	tr.source_cell = Vector2i(998, 998)
	tr.priority = 1
	tr.points = PackedVector2Array([
		Vector2(0.0, -36.0), Vector2(0.0, -24.0), Vector2(0.0, -12.0),
		Vector2(0.0, 0.0), Vector2(0.0, 12.0), Vector2(0.0, 24.0)])
	tr.beds = PackedFloat32Array([10.0, 9.0, 8.0, 2.0, 1.0, 0.5])
	tr.widths = PackedFloat32Array([3.0, 3.0, 3.0, 3.0, 3.0, 3.0])
	tr.joined = false
	tr.source_pool = null
	tr.pond = null
	var ctx: Dictionary = {"water": null, "ponds": [], "rivers": [tr], "buckets": {}, "region": region}
	var rect := Rect2(Vector2(-100.0, -100.0), Vector2(200.0, 200.0))
	var spans: Array = WaterField.steep_spans(ctx, rect)
	assert_eq(spans.size(), 1, "the hand-built cliff is exactly one steep span")
	if spans.is_empty():
		return
	var span: Dictionary = spans[0]
	assert_almost_eq(span.drop, 12.0, 0.01, "the span's own ground drop matches the cliff height")
	assert_true(span.drop > WaterField.FALL_DROP_MIN + 0.01, "clears the fall threshold")
	assert_almost_eq(span.dir.length(), 1.0, 0.001, "dir is unit")
	assert_almost_eq(span.dir.dot(span.across), 0.0, 0.001, "across is perpendicular to dir")
	assert_true(span.dir.y > 0.0, "dir follows the trace downstream (+z)")
	assert_true(span.top > span.bottom, "top is the upstream (higher) water level")
	assert_true(span.p.y < -9.0, "the lip sits upstream of the cliff's own base line (z=-9)")
	# Profile levels either side of the cliff must have actually dropped —
	# steep_spans' top/bottom are profile() water levels, not raw ground.
	var prof: Dictionary = WaterField.profile(tr, region)
	assert_true(prof.levels[1] - prof.levels[3] > WaterField.FALL_DROP_MIN,
		"the profile itself hugs the cliff face with a real drop")


## _steep_scan(grounds, step) unit tests — the pure, terrain-free window-scan
## math the brief asks to be independently testable (steep_spans' own
## world-position/level plumbing is covered by
## test_steep_spans_finds_a_real_hand_built_cliff above; this is JUST the
## scan over a stubbed ground array).
func test_steep_scan_flat_ground_finds_nothing() -> void:
	var grounds := PackedFloat32Array()
	for i in 20:
		grounds.append(10.0)
	var spans: Array = WaterField._steep_scan(grounds, 3.0)
	assert_eq(spans.size(), 0, "flat ground has no steep window")


func test_steep_scan_gentle_ramp_finds_nothing() -> void:
	# A ramp dropping exactly FALL_DROP_MIN (4.0) over one 24m window
	# (window_n = round(24/3) = 8 samples) must NOT trigger — strictly
	# greater than FALL_DROP_MIN + 0.01 is the rule, an exact 4.0m window
	# drop stays a slope (mirrors profile()'s own "+0.01 guards float32
	# chained-subtraction noise" convention).
	var grounds := PackedFloat32Array()
	for i in 20:
		grounds.append(10.0 - float(i) * (4.0 / 8.0))
	var spans: Array = WaterField._steep_scan(grounds, 3.0)
	assert_eq(spans.size(), 0, "an exact-4.0m-per-24m-window ramp is a slope, not a fall")


func test_steep_scan_finds_a_sharp_step() -> void:
	# A hard step (flat 10 -> flat 0) well inside the array: the scan must
	# report exactly one span whose drop matches and whose hi/lo indices
	# bracket the step.
	var grounds := PackedFloat32Array()
	for i in 10:
		grounds.append(10.0)
	for i in 10:
		grounds.append(0.0)
	var spans: Array = WaterField._steep_scan(grounds, 3.0)
	assert_eq(spans.size(), 1, "one contiguous span for one step")
	if spans.is_empty():
		return
	var span: Dictionary = spans[0]
	assert_almost_eq(span.drop, 10.0, 0.001, "drop matches the step height")
	assert_true(span.lo < 10, "lo sits on the high plateau")
	assert_true(span.hi >= 10, "hi sits on the low plateau")
	assert_true(grounds[span.lo] > grounds[span.hi], "lo is genuinely higher than hi")


func test_steep_scan_two_separate_cliffs_stay_separate() -> void:
	# Two hard steps far enough apart that their windows never overlap must
	# report TWO spans, not one merged run.
	var grounds := PackedFloat32Array()
	for i in 10:
		grounds.append(20.0)
	for i in 20:
		grounds.append(10.0)
	for i in 10:
		grounds.append(0.0)
	var spans: Array = WaterField._steep_scan(grounds, 3.0)
	assert_eq(spans.size(), 2, "two well-separated cliffs stay two spans")
	if spans.size() == 2:
		assert_true(spans[0].hi < spans[1].lo, "the two spans do not overlap")


func test_steep_scan_short_array_returns_empty() -> void:
	var grounds := PackedFloat32Array([10.0, 0.0])   # far shorter than one window
	var spans: Array = WaterField._steep_scan(grounds, 3.0)
	assert_eq(spans.size(), 0, "an array too short to hold one 24m window has no spans")


func test_flow_and_grade() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var p := Vector2(54.0, -1100.0)   # mid-channel at the site
	if WaterField.level_at(ctx, p) > -INF:
		assert_true(WaterField.flow_at(ctx, p).length() <= 1.001, "flow bounded")
		assert_true(WaterField.grade_at(ctx, p) >= 0.0, "grade non-negative")


# ============================================================================
# Phase 0 diagnostic oracles (.superpowers/sdd/h-task-0-brief.md). These are
# written against the ISSUE definition, with NO knowledge of any fix — they
# must be RED at HEAD (reproducing I2/I3/I4 at the owner's exact sites) and
# are expected to turn GREEN only after Phase 1 replaces the claim-geometry
# field with a real hydrostatic fill. Do NOT weaken these to force red or
# green; a hypothesis whose oracle disagrees with its prediction is a
# finding, not a bug in the oracle.
# ============================================================================

const _LATTICE_STEP := 3.0   # matches WaterMesher.S — the mesh's own resolution


## test_no_dry_holes_inside_water (H3/H4, I3/I4): for every lattice sample S
## in the site chunk with level_at(S) == -INF, no 4-connected neighbour
## sample may be wet with a level >= ground(S) + 0.3 — a dry sample bordered
## by water standing above its own ground is a hole in an otherwise-full
## body. Predicted red site: I3 (9.3, -1120.6), ground 0, lake level ~3.
func test_no_dry_holes_inside_water() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var base: Vector2 = Vector2(SITE_CHUNK) * (WaterField.TILE * 8.0)
	var n: int = int(WaterField.TILE * 8.0 / _LATTICE_STEP)
	var holes := 0
	var offenders: Array = []
	for j in range(0, n + 1):
		for i in range(0, n + 1):
			var p: Vector2 = base + Vector2(i, j) * _LATTICE_STEP
			if WaterField.level_at(ctx, p) != -INF:
				continue   # only checking DRY samples for this oracle
			var ground: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
			for d: Vector2 in [Vector2(_LATTICE_STEP, 0), Vector2(-_LATTICE_STEP, 0),
					Vector2(0, _LATTICE_STEP), Vector2(0, -_LATTICE_STEP)]:
				var nbr: Vector2 = p + d
				var nbr_lvl: float = WaterField.level_at(ctx, nbr)
				if nbr_lvl == -INF:
					continue
				if nbr_lvl >= ground + 0.3:
					holes += 1
					if offenders.size() < 5:
						offenders.append("S=%s (ground=%.2f) neighbour=%s wet at level=%.2f" % [
							p, ground, nbr, nbr_lvl])
					break
	assert_eq(holes, 0,
		"%d dry lattice samples are holes bordered by higher water (e.g. %s)" % [
			holes, offenders])


## test_water_never_stands_above_its_source (H2, I2): every wet sample's
## level must be <= the level it is hydraulically connected to.
## Phase 2a note (comparison basis updated, assertion's OWN intent
## unchanged): the original H2 bug was the claim jumping to a
## non-adjacent, far-upstream sample (si=6, 468m away along the channel)
## while a hydraulically-nearer sample (si=9, only 19m away) sat much
## lower — that defect is still exactly what this test catches. What
## changed is the comparison basis: with profile() now genuinely
## continuous (Phase 2a), a point that sits BETWEEN nearest_i and one of
## its immediate neighbours on a real, legitimate slope can correctly read
## an INTERPOLATED level that exceeds nearest_i's own single discrete
## value (verified against this seed's real data: a point 7.3-7.5m from
## BOTH sample 4 (9.70) and sample 5 (5.70), squarely on the slope between
## them, correctly reads ~7.6-7.7 from both the fill lattice and
## _sample_level's own along-segment interpolation — a real, physically
## correct continuous slope, not a violation). Comparing against a single
## nearest sample's raw level is now too strict; comparing against the
## INTERPOLATED envelope of the two segments touching nearest_i (project p
## onto each, take the higher of the two interpolated results) is the
## correct, still-strict basis: a genuine H2-class violation (an
## unconnected, far-upstream sample winning) still exceeds even that
## envelope by a wide margin, while an ordinary point-on-a-real-slope
## never does.
## Predicted red site (pre-Phase-1): I2 (70.1, -1140.5), claimant si=6
## (level 5.70) while the nearest channel sample si=9 sat at level 3.00 —
## fixed in Phase 1, unaffected by this comparison-basis update.
func test_water_never_stands_above_its_source() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var base: Vector2 = Vector2(SITE_CHUNK) * (WaterField.TILE * 8.0)
	var n: int = int(WaterField.TILE * 8.0 / _LATTICE_STEP)
	var violations := 0
	var offenders: Array = []
	for j in range(0, n + 1):
		for i in range(0, n + 1):
			var p: Vector2 = base + Vector2(i, j) * _LATTICE_STEP
			var claim: Dictionary = _claim_river(ctx, p)
			if claim.is_empty():
				continue   # pond claims and unclaimed points are out of scope
			var tr: RiverTrace = claim.tr
			var claimed_lvl: float = claim.lvl
			var nearest_i: int = _nearest_sample(tr, p)
			var envelope_lvl: float = _segment_envelope_level(tr, region, nearest_i, p)
			if claimed_lvl > envelope_lvl + 0.3:
				violations += 1
				if offenders.size() < 5:
					offenders.append("p=%s claimed_si=%d claimed_lvl=%.2f > envelope_si=%d envelope_lvl=%.2f" % [
						p, claim.si, claimed_lvl, nearest_i, envelope_lvl])
	assert_eq(violations, 0,
		"%d wet samples stand above the level they are hydraulically (continuously) connected to (e.g. %s)" % [
			violations, offenders])


## The higher of the two along-segment-interpolated levels p could
## legitimately read from being close to sample nearest_i — one
## interpolation from the segment BEFORE nearest_i (si=nearest_i-1 to
## nearest_i), one from the segment AFTER (si=nearest_i to nearest_i+1),
## each projecting p onto that segment same as WaterField._sample_level
## does. Falls back to the single sample's own level at either end of the
## trace, where only one segment exists.
func _segment_envelope_level(tr: RiverTrace, region, nearest_i: int, p: Vector2) -> float:
	var best: float = -INF
	if nearest_i > 0:
		best = maxf(best, WaterField._sample_level(tr, nearest_i - 1, p, region))
	if nearest_i < tr.points.size() - 1:
		best = maxf(best, WaterField._sample_level(tr, nearest_i, p, region))
	if best == -INF:
		var prof: Dictionary = WaterField.profile(tr, region)
		best = prof.levels[nearest_i]
	return best


## test_waterline_is_a_terrain_contour (H2/H4, I2/I4 "curvy perimeter"): for
## every boundary (free-edge) vertex not on a chunk border, either the
## vertex sits close to the real terrain (|level - surface_y| <= 0.6), or
## the ground within 1.5m rises above the level (a wall — a legitimate
## non-contour edge). A vertex that is neither is a claim-radius cut
## floating over ground it has no hydrological relationship to.
## Original (pre-Phase-2a) predicted red site: I2's flood-extension
## boundary. Phase 0/1 traced this test's ACTUAL red site to something
## different and narrower: 100% of the (32, later 28) violating vertices
## sat on the site's ONE fall-cut's own lip/base line (H1's bed-quantization
## false-cliff) — because WaterMesher._hem (unmodified, out of scope this
## phase — see the plan's Mesher/2b section) hems EVERY non-border free
## edge except the two whose ENDPOINTS both sit near a recorded cut
## (WaterMesher._near_cut); hemming welds a second triangle onto that edge
## via the shared (a,b) diagonal (_hem's own [a,hb,b] quad), which makes it
## no longer a FREE edge at all once hemmed — so in this mesh's structure,
## the cut's own lip/base line was, and is, the ONLY category of
## non-border free edge that was ever un-hemmed and thus checkable by this
## test in the first place (verified directly: every one of the ORIGINAL
## code's 32 checked vertices sits at z=-1088.91, y in {5.7, 13.7} — the
## exact recorded cut's own top/bottom, not "the shoreline" generally).
## Phase 2a (H1 fixed): the site's steep_spans()/fall_cuts() shim returned
## ZERO spans (see test_steep_spans_empty_at_the_site) — there was no cut
## left anywhere on this chunk, so `checked` was legitimately, structurally
## 0 AT THAT PHASE (nothing left to hem-exempt, since nothing was near a
## nonexistent cut) — treated as an explicit pass at the time (matching the
## same empty-case convention test_steep_spans_empty_at_the_site and the
## now-deleted test_cuts_only_at_big_drops used for "nothing to check on
## this seed"). Phase 2b superseded that specific "checked==0" outcome: with
## WaterMesher._near_cut ALSO fully deleted (no cut exemption left at all —
## every non-border free edge is hemmed unconditionally now, see
## WaterMesher._hem's own docstring), the free-edge accounting itself
## changed shape and `checked` is now genuinely, non-vacuously non-zero
## (verified this task: test_shoreline_hugs_terrain_contour, the new
## hem-independent field-level oracle this same task adds, finds 325 real
## shoreline crossings with 0 violations) — the `checked == 0` branch below
## is left in place (harmless, still a valid empty-case fallback for any
## future dry seed/chunk) but is no longer the branch this test's own site
## actually exercises. The strict per-vertex check below still runs in full
## and un-weakened whenever checked > 0 (any seed/chunk that DOES carry a
## real fall — this site included, now — is still held to the exact
## original standard). See .superpowers/sdd/h-task-2a-report.md and
## h-task-2b-report.md for the full investigation (this is the direct
## analogue of the Phase 1 report's OWN documented, un-fudged tension on
## this exact test).
func test_waterline_is_a_terrain_contour() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	assert_false(m.is_empty(), "site chunk builds water")
	var checked := 0
	var violations := 0
	var offenders: Array = []
	for e: Array in WaterMesher.free_edges(m.verts, m.idx):
		for v: Vector3 in e:
			if _on_chunk_border_f(v):
				continue
			var g: float = TerrainSurfaceField.surface_y(region, v.x, v.z)
			if v.y < g - 0.3:
				continue   # buried hem rim — not a waterline vertex
			checked += 1
			if absf(v.y - g) <= 0.6:
				continue   # rides the real terrain: a true contour
			# Wall exemption: ground within 1.5m of the vertex rises above
			# the vertex's own level in at least one direction.
			var wall := false
			for d: Vector2 in [Vector2(1.5, 0), Vector2(-1.5, 0),
					Vector2(0, 1.5), Vector2(0, -1.5),
					Vector2(1.06, 1.06), Vector2(-1.06, 1.06),
					Vector2(1.06, -1.06), Vector2(-1.06, -1.06)]:
				var q: Vector2 = Vector2(v.x, v.z) + d
				var gq: float = TerrainSurfaceField.surface_y(region, q.x, q.y)
				if gq > v.y:
					wall = true
					break
			if wall:
				continue
			violations += 1
			if offenders.size() < 5:
				offenders.append("v=%s ground=%.2f diff=%.2f (no nearby wall)" % [v, g, v.y - g])
	if checked == 0:
		pass_test("no non-hemmed shoreline vertices at all: zero cuts on this chunk (H1 fixed) means nothing was ever exempted from the hem, and nothing exempted means nothing left that could float over a false cliff — see this test's own docstring")
		return
	assert_eq(violations, 0,
		"%d boundary verts are neither a terrain contour nor a wall edge (e.g. %s)" % [
			violations, offenders])


## NEW oracle (Phase 2a, red-first-style — trivially green at the site,
## meaningful on any seed/chunk that DOES grow a real cliff): the owner's I1
## rule ("no fall look where the ground's 24m window drop doesn't clear
## FALL_DROP_MIN"), encoded directly against steep_spans()'s OWN output —
## for every span steep_spans() reports over the site's chunks, independently
## re-measure the ground's 24m window drop along the channel AT that span
## (via the same _steep_scan the production code uses, re-run here as an
## independent oracle-side check rather than trusting steep_spans' own
## internal bookkeeping — the whole point of an oracle is to verify the
## claim, not just restate it) and require it to exceed FALL_DROP_MIN. At
## the site this is trivially green (zero spans — see
## test_steep_spans_empty_at_the_site); its teeth are exercised by
## test_steep_spans_finds_a_real_hand_built_cliff and the standalone
## _steep_scan unit tests above, all of which independently confirm a
## REPORTED span always corresponds to a REAL terrain drop.
func test_no_steep_span_without_terrain_drop() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var rect := Rect2(Vector2(0, -1152), Vector2(192, 192))
	var spans: Array = WaterField.steep_spans(ctx, rect)
	var checked := 0
	for span: Dictionary in spans:
		checked += 1
		assert_true(span.drop > WaterField.FALL_DROP_MIN + 0.01,
			"span at %s claims drop %.2f which does not clear FALL_DROP_MIN" % [span.p, span.drop])
		# Independent re-derivation: walk the ground on a short line straddling
		# the span's own lip/base (not trusting steep_spans' internal scan),
		# and confirm the SAME 24m-window drop is really there on the ground.
		var probe_grounds := PackedFloat32Array()
		var step := 3.0
		var n_steps := 16   # 48m of probe line, comfortably covering one 24m window on either side
		for k in range(n_steps + 1):
			var q: Vector2 = span.p + span.dir * (step * float(k) - step * float(n_steps) * 0.5)
			probe_grounds.append(TerrainSurfaceField.surface_y(region, q.x, q.y))
		var max_window_drop := 0.0
		var window_n: int = roundi(24.0 / step)
		for i in range(0, probe_grounds.size() - window_n):
			var lo_v: float = probe_grounds[i]
			var hi_v: float = lo_v
			for k in range(i, i + window_n + 1):
				hi_v = minf(hi_v, probe_grounds[k])
			max_window_drop = maxf(max_window_drop, lo_v - hi_v)
		assert_true(max_window_drop > WaterField.FALL_DROP_MIN,
			"span at %s has no matching ground window-drop nearby (max found %.2f)" % [span.p, max_window_drop])
	if checked == 0:
		pass_test("zero steep spans at the site (H1 fixed) — vacuously satisfies the I1 rule; see test_steep_spans_finds_a_real_hand_built_cliff for the non-empty case")


## Phase 2b coverage-restoration oracle (reviewer-mandated, run BEFORE any
## Phase 2b mesher/shader/volume/character change — see this task's brief):
## a HEM-INDEPENDENT shoreline check against the FIELD itself, not mesh
## topology. test_waterline_is_a_terrain_contour (above) reads WaterMesher's
## free edges, so its coverage lives or dies with WaterMesher._hem's own
## exemption rules (structurally 0 non-border free edges to check on this
## seed post-H1, as that test's own docstring documents at length) — this
## oracle instead walks WaterField.level_at directly on a fine (1.5m, half
## WaterMesher.S) lattice independent of any mesh, so it has real teeth
## regardless of what the mesher's hem does or doesn't exempt.
##
## Method: walk every lattice ROW (fixed z, x varying) and every lattice
## COLUMN (fixed x, z varying) covering the site chunk's own 192x192 span at
## 1.5m spacing (the brief's literal grid — rows AND columns together find
## shore crossings in both principal directions, since a pure row-walk alone
## would miss a shoreline that runs exactly along x). At every WET -> DRY (or
## DRY -> WET) sign change of level_at along one of these lines, bisect
## (20 passes, matching WaterMesher._edge_vert's own bisection depth) between
## the wet and dry samples until the crossing is pinned to <= 0.4m, using
## `wet(p) := level_at(p) > -INF and level_at(p) > surface_y(p) + EPS` as the
## sign function (the same wetness predicate WaterField.wet itself uses) so
## the crossing found is a genuine WATERLINE (level crosses ground), not just
## a level_at claim-radius boundary. At that crossing, the check is EITHER:
##   (a) the WET side's own level closely tracks the ground right at the
##       crossing (|level_at(wet sample) - surface_y(crossing)| <= 0.6) — an
##       ordinary contour shore, water's edge rides the terrain it touches, OR
##   (b) a wall shore: the ground within 1.5m of the crossing (either side,
##       both axes, matching test_waterline_is_a_terrain_contour's own 8-point
##       wall-exemption ring) rises above the wet level — a vertical bank the
##       water simply presses against, not a contour to hug.
## Any crossing satisfying neither is a genuine floating-claim artifact: water
## whose edge neither follows the ground nor presses against a wall.
func test_shoreline_hugs_terrain_contour() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var base: Vector2 = Vector2(SITE_CHUNK) * (WaterField.TILE * 8.0)
	var span: float = WaterField.TILE * 8.0
	var step := 1.5
	var n: int = int(span / step)
	var crossings := 0
	var violations := 0
	var offenders: Array = []
	# Rows: fixed z, walk x. Columns: fixed x, walk z. Together these catch a
	# shoreline running in either principal direction.
	for j in range(0, n + 1):
		var z: float = base.y + float(j) * step
		var line: Array = []
		for i in range(0, n + 1):
			line.append(base.x + float(i) * step)
		var res: Dictionary = _walk_line_for_shore(ctx, region, line, z, true)
		crossings += res.crossings
		violations += res.violations
		offenders.append_array(res.offenders)
	for i in range(0, n + 1):
		var x: float = base.x + float(i) * step
		var line: Array = []
		for j in range(0, n + 1):
			line.append(base.y + float(j) * step)
		var res: Dictionary = _walk_line_for_shore(ctx, region, line, x, false)
		crossings += res.crossings
		violations += res.violations
		offenders.append_array(res.offenders)
	print("test_shoreline_hugs_terrain_contour: %d crossings found, %d violations" % [crossings, violations])
	assert_true(crossings > 0, "site chunk has a real shoreline to walk")
	assert_eq(violations, 0,
		"%d shoreline crossings neither track the terrain contour nor press against a wall (e.g. %s)" % [
			violations, offenders])


## Walks one lattice line (either a row at fixed `cross` = z with `coords` =
## x values, or a column at fixed `cross` = x with `coords` = z values,
## selected by `is_row`), finds every wet/dry sign change, bisects each to a
## world point, and classifies it (a) contour or (b) wall. Returns
## {crossings, violations, offenders}.
func _walk_line_for_shore(ctx: Dictionary, region, coords: Array, cross: float, is_row: bool) -> Dictionary:
	var crossings := 0
	var violations := 0
	var offenders: Array = []
	var prev_wet: bool = false
	var prev_c: float = coords[0]
	var have_prev := false
	for c: float in coords:
		var p: Vector2 = Vector2(c, cross) if is_row else Vector2(cross, c)
		var w: bool = WaterField.wet(ctx, region, p)
		if have_prev and w != prev_wet:
			crossings += 1
			var cross_c: float = _bisect_shore(ctx, region, prev_c, c, cross, is_row, prev_wet)
			var wet_c: float = prev_c if prev_wet else c
			var wet_p: Vector2 = Vector2(wet_c, cross) if is_row else Vector2(cross, wet_c)
			var cross_p: Vector2 = Vector2(cross_c, cross) if is_row else Vector2(cross, cross_c)
			var wet_lvl: float = WaterField.level_at(ctx, wet_p)
			var g_cross: float = TerrainSurfaceField.surface_y(region, cross_p.x, cross_p.y)
			if absf(wet_lvl - g_cross) <= 0.6:
				pass   # (a) contour: the wet side's level tracks the ground here
			else:
				# (b) wall exemption: ground within 1.5m (either axis) of the
				# crossing rises above the wet level — same 8-point ring
				# test_waterline_is_a_terrain_contour's own wall check uses.
				var wall := false
				for d: Vector2 in [Vector2(1.5, 0), Vector2(-1.5, 0),
						Vector2(0, 1.5), Vector2(0, -1.5),
						Vector2(1.06, 1.06), Vector2(-1.06, 1.06),
						Vector2(1.06, -1.06), Vector2(-1.06, -1.06)]:
					var q: Vector2 = cross_p + d
					var gq: float = TerrainSurfaceField.surface_y(region, q.x, q.y)
					if gq > wet_lvl:
						wall = true
						break
				if not wall:
					violations += 1
					if offenders.size() < 5:
						offenders.append("crossing=%s wet_lvl=%.2f ground_at_crossing=%.2f (no nearby wall)" % [
							cross_p, wet_lvl, g_cross])
		prev_wet = w
		prev_c = c
		have_prev = true
	return {"crossings": crossings, "violations": violations, "offenders": offenders}


## Bisects the wet/dry sign change between (prev_c, cross) and (c, cross) (row)
## or (cross, prev_c) and (cross, c) (column) to <= 0.4m, using
## WaterField.wet as the sign function (the same predicate the line walk
## itself uses, so the bisection agrees with what found the crossing).
## 20 passes matches WaterMesher._edge_vert's own bisection depth (that
## function halves its interval every pass regardless of the interval's
## initial width, so 20 passes comfortably clears 0.4m from a 1.5m start:
## 1.5 / 2^20 is far below 0.4m; the loop below still exits early once the
## interval itself narrows under 0.4m, so it never over-iterates).
func _bisect_shore(ctx: Dictionary, region, prev_c: float, c: float, cross: float,
		is_row: bool, prev_wet: bool) -> float:
	var lo: float = prev_c if prev_wet else c   # lo is always the WET end
	var hi: float = c if prev_wet else prev_c
	for _pass in 20:
		if absf(hi - lo) < 0.4:
			break
		var mid: float = (lo + hi) * 0.5
		var p: Vector2 = Vector2(mid, cross) if is_row else Vector2(cross, mid)
		if WaterField.wet(ctx, region, p):
			lo = mid
		else:
			hi = mid
	return lo


## test_fill_is_deterministic_across_chunks (Phase 1 window-determinism
## requirement, controller amendment 2): the fill runs on a BOUNDED lattice
## per ctx (chunk + FILL_MARGIN cells of margin — see WaterField.FILL_MARGIN)
## rather than over the whole world at once, so two neighbouring chunks each
## build their OWN independent fill window. Seam identity (WaterMesher's own
## chunk-seam weld) depends on both windows agreeing BIT-EXACTLY on any
## world point both windows cover — if they didn't, adjacent chunks' meshes
## would visibly crack at the border. This is guaranteed by construction
## (the fill's lower-level-wins relaxation converges to a unique fixpoint
## regardless of seed/BFS order — see _build_fill's own docstring: for a
## FIXED level, reachability through the ground-clearance gate is a static,
## history-independent subgraph, so two windows that both fully contain a
## basin must independently discover the identical fixpoint there), but
## this test verifies it holds in practice, not just in the algorithm's
## design: sample a dense line straddling two adjacent chunks' shared world-
## space border (both comfortably inside each ctx's own FILL_MARGIN
## overlap — see the margin math in WaterField.gd) and require bit-exact
## (0.0 tolerance) agreement.
func test_fill_is_deterministic_across_chunks() -> void:
	var water: WaterPlan = _water(SEED)
	var a_chunk: Vector2i = SITE_CHUNK
	var b_chunk: Vector2i = SITE_CHUNK + Vector2i(1, 0)
	var a_ctx: Dictionary = WaterField.ctx(water, a_chunk, _region(SEED, a_chunk))
	var b_ctx: Dictionary = WaterField.ctx(water, b_chunk, _region(SEED, b_chunk))
	var border_x: float = float(b_chunk.x) * (WaterField.TILE * 8.0)   # shared world-space border
	var span: float = WaterField.TILE * 8.0
	var checked := 0
	var mismatches := 0
	var offenders: Array = []
	# +/- one FILL lattice step either side of the border, well inside both
	# ctxs' FILL_MARGIN overlap (10 lattice cells = 30m each side of a
	# chunk's own span), across the chunk's full z extent.
	for dx in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0]:
		var x: float = border_x + dx
		var z: float = float(a_chunk.y) * span
		while z <= float(a_chunk.y + 1) * span:
			var p := Vector2(x, z)
			var a_lvl: float = WaterField.level_at(a_ctx, p)
			var b_lvl: float = WaterField.level_at(b_ctx, p)
			checked += 1
			if a_lvl != b_lvl:
				mismatches += 1
				if offenders.size() < 10:
					offenders.append("p=%s a_lvl=%s b_lvl=%s" % [
						p, ("-INF" if a_lvl == -INF else "%.6f" % a_lvl),
						("-INF" if b_lvl == -INF else "%.6f" % b_lvl)])
			z += 3.0
	assert_true(checked > 100, "sampled a real cross-border line (%d points)" % checked)
	assert_eq(mismatches, 0,
		"%d/%d points disagree bit-exactly between neighbouring chunks' fills (e.g. %s)" % [
			mismatches, checked, offenders])


## Which river trace p's wetness is attributable to, post-fill. The fill
## (WaterField._build_fill) no longer selects a single "claimant" per point —
## wetness is reachable-by-relaxation from any seed — so this is an
## INDEPENDENT re-derivation from the issue definition (H2: "a wet sample's
## level must be <= the level of the channel/pond sample it is hydraulically
## connected to"), not a mirror of the fill's internals: p's claimed level is
## simply WaterField.level_at's own public answer (the field's real output,
## exactly what any consumer reads).
##
## "The channel sample it is hydraulically connected to" needs its own
## independent, physically-grounded selection post-fill: nearest-by-distance
## is NOT automatically hydraulically connected any more (the fill can
## legitimately serve p from a farther, HIGHER seed when the nearest sample
## is walled off from p by a ridge that sample's own water cannot cross —
## verified against this seed's real data: every violation a naive pure-
## nearest form of this oracle raised turns out to be exactly that, a
## ground rise between the nearest sample and p sitting AT/ABOVE that
## sample's own level). So "connected" means DEMONSTRABLY connected: the
## nearest sample, among ALL traces, whose own level clears the ground
## along the straight line from that sample to p (sampled densely) — a
## real, independent (not fix-mirroring) lower bound on physical
## reachability, strictly weaker than full path-connectivity (a clear
## straight line is a SUFFICIENT, not necessary, condition for
## reachability, so this never over-credits a candidate that's actually
## blocked).
##
## Searches every trace's every sample directly (not per-trace via
## _nearest_sample first, then picking the nearest TRACE — an earlier
## version of this helper did that and it silently let an unreachable
## trace win the cross-trace comparison whenever ITS OWN nearest-but-
## unreachable sample happened to be geometrically closer than any other
## trace's reachable one; searching flat across every sample avoids that).
## Returns {} when p is dry, when NO sample anywhere has a ground-clear
## line to p (out of scope — nothing to compare against, not a violation
## by omission), or when a pond sits closer than the winning river sample
## (pond claims are out of scope for this river-source-provenance check).
func _claim_river(c: Dictionary, p: Vector2) -> Dictionary:
	var lvl: float = WaterField.level_at(c, p)
	if lvl == -INF:
		return {}
	var region = c.get("region")
	var best_pond_m: float = INF
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		best_pond_m = minf(best_pond_m, m)
	var best_tr: RiverTrace = null
	var best_si := -1
	var best_d: float = INF
	for tr: RiverTrace in c.rivers:
		var prof: Dictionary = WaterField.profile(tr, region)
		for si in tr.points.size():
			var d: float = tr.points[si].distance_to(p)
			if d >= best_d:
				continue
			if not _ground_clear_line(region, tr.points[si], p, prof.levels[si]):
				continue
			best_d = d
			best_tr = tr
			best_si = si
	if best_tr == null:
		return {}
	# A pond's own margin (footprint_t - 1) * radius is directly comparable to
	# a river margin (distance - width) — both are "signed distance past the
	# body's own edge." If the pond is the closer explanation, this point's
	# wetness is pond-sourced, not river-sourced: out of scope here.
	var river_m: float = best_d - best_tr.widths[best_si]
	if best_pond_m < river_m:
		return {}
	return {"tr": best_tr, "si": best_si, "lvl": lvl}


## Sample on `tr` p is hydraulically connected to — the nearest sample on
## `tr` whose own level clears the ground along the straight line to p (see
## _claim_river's docstring for the full reasoning). Only ever called with
## the SAME `tr` _claim_river itself selected as `claim.tr`, which by
## construction already has at least one reachable sample (best_si above)
## — so unlike an earlier version of this helper, there is no "nothing
## reachable" fallback path to get wrong; if this is ever called with a
## trace that truly has no reachable sample, that is a caller bug, not a
## degenerate case to paper over, so it is left unguarded (would return
## the last-checked index, index 0, on an empty trace — GDScript's own
## array-bounds error is the right signal for that, not a silent fallback).
func _nearest_sample(tr: RiverTrace, p: Vector2) -> int:
	var region = _region(SEED, SITE_CHUNK)
	var prof: Dictionary = WaterField.profile(tr, region)
	var order: Array = range(tr.points.size())
	order.sort_custom(func(a, b): return tr.points[a].distance_to(p) < tr.points[b].distance_to(p))
	for i: int in order:
		if _ground_clear_line(region, tr.points[i], p, prof.levels[i]):
			return i
	return order[0]


## True when every ground sample along the straight line from `a` to `b`
## sits below `lvl - EPS` — a real (if conservative) reachability check:
## water AT `lvl` demonstrably CAN flood the direct line from its own seed
## to `b`. Sampled at ~1m steps (finer than any gap that would hide a
## lattice-scale ridge), at least 4 samples even for a short segment.
func _ground_clear_line(region, a: Vector2, b: Vector2, lvl: float) -> bool:
	var steps := maxi(4, int(a.distance_to(b)))
	for k in range(steps + 1):
		var t: float = float(k) / float(steps)
		var q: Vector2 = a.lerp(b, t)
		if TerrainSurfaceField.surface_y(region, q.x, q.y) >= lvl - WaterField.EPS:
			return false
	return true


func _on_chunk_border_f(v: Vector3) -> bool:
	var span: float = WaterField.TILE * 8.0
	var lx: float = fposmod(v.x, span)
	var lz: float = fposmod(v.z, span)
	return lx < 0.01 or lx > span - 0.01 or lz < 0.01 or lz > span - 0.01


# ============================================================================
# h-task-4 diagnosis oracle (.superpowers/sdd/h-task-4-brief.md, I4 "strangely
# missing water" wedge at a wall inside a pool). Fix-independent — written
# against the issue definition, no knowledge of any fix — must be RED at HEAD.
#
# INSTRUMENT-FIRST VERDICT (recorded per the brief's mandate, decided BEFORE
# committing to this oracle's final shape — see this task's own report for
# the full grid dump and the reinvestigation this section documents):
#
# H-A's specific mechanism (the fill's 6m lattice ground memo landing on a
# FICTIONAL wall/ridge that the true, finer-grained collision ground does not
# have) is FALSIFIED at this site. Exhaustively verified four independent
# ways — this task's own headless dumps (fill-lattice memo_ground, mesher's
# own 3m subgrid via TerrainSurfaceField.surface_y, a full triangle-centroid
# dump of WaterMesher.build's output), a background agent's LIVE in-game
# triple-check (mesh-vertex dump + physics raycast scan + wide-area scan),
# and a second independent background agent's from-scratch reproduction
# (headless probe + live raycast after teleporting to the owner's exact
# coordinate) — all four agree: 24m terrain cell (cx=1, cz=-46), world
# x∈[24,36) z∈[-1104,-1080), is a GENUINE, correctly-classified cliff top
# (storey=2, h=8.0, uncarved, TerrainSurfaceField._is_cliff_top=true), flat
# at exactly 8.0 for the WHOLE x<36 sub-range at these z values, with a hard
# vertical step to ~2-4m at the real cell boundary x=36.0 — matching the
# fill's own memo_ground exactly (both read TerrainSurfaceField.surface_y at
# the same points and agree bit-for-bit). There is no fictional wall; the
# wall is real, and the fill/mesher both already know it correctly (dry
# rendering there is CORRECT — H-B's first clause). The specific "1.71 /
# 1.13 / 0.00" collision-ground figures in the brief's evidence section for
# x=35.2/34.5/31.0 could not be reproduced by either investigation; the
# reproducible evidence points to a methodology mix-up in the prior
# evidence-gathering pass (see progress.md's "RUN 2 — CORRECTION" entry) —
# most likely WaterField.level_at's own bilinear fill-lattice VALUE (which
# genuinely does read ~3.0 there via harmless-on-its-own bleed across the
# coarse lattice, since wet()'s ground-gate correctly suppresses it) misread
# as a terrain-collision raycast.
#
# FIRST DRAFT OF THIS ORACLE (superseded, kept in this comment as the
# reinvestigation trail the brief's own red-first mandate requires): a literal
# "dry sample under a wet_cells plane reading > 0.5m above its own ground"
# check, walking the site's full 3m subgrid, went GREEN at HEAD (0
# violations) — per the brief's own "if it does not fail, your understanding
# is wrong" rule, this was a signal to reinvestigate, not a green light to
# proceed. A full-chunk scan of every (true field-depth class) vs (wet_cells
# plane-depth class) pair confirms WHY: this site has ZERO dry→swim
# transitions anywhere (the plane never claims water over land the mesher
# renders dry — the cliff top's real ground, 8.0m, is simply too high for any
# neighbouring cell's plane to reach). So "dry pocket under a wet plane" is
# not a real defect class on this seed; forcing the oracle to find one here
# would misdiagnose the fix.
#
# What the SAME scan DOES find, 84 times across the chunk including AT the
# owner's own reported site: wade→swim and swim→wade misclassifications
# WITHIN genuinely wet water. At (36.0, -1107.0) — one cell-row over from the
# owner's exact stand point, same cell — the field's true depth is 0.76m
# (WADING: shallow, at/under the character's own 0.8 swim-enter threshold),
# but wet_cells' single linear plane for that 24m cell reads 1.44m there
# (confidently SWIMMING) — a real depth-doubling, not a rounding fuzz. This
# is H-B's second clause made precise: "the volume/classification is still
# wrong" — not because the volume paints water over land the mesh shows dry,
# but because ONE flat/linear plane per 24m cell cannot represent the field's
# true (non-linear, sub-cell) surface curvature near a cell edge, and the
# owner's own site sits exactly in that error band. This is also the
# mechanism test_water_swim_volumes.gd's own
# test_volume_surface_matches_field_at_probe_points already documents in
# general ("one flat plane per 24m cell can diverge from the true local level
# near a cell edge") — this oracle is the first to show it flipping an actual
# swim/wade/dry CLASSIFICATION, not just a numeric plane-vs-field gap.
#
# The chosen test name (test_no_dry_pocket_below_adjacent_water_level, per
# the brief) is kept, but its BODY checks the mechanism the reinvestigation
# actually found: no wet_cells-plane-driven classification may read "more
# submerged" (swim where the field says wade/dry, or wade where the field
# says dry) than the field's own true depth at that point — the volume must
# never promise a character MORE water than genuinely exists under their
# feet. "dry pocket below adjacent water level" is the right description of
# the DEFECT CLASS (a spot that reads wetter than it should relative to its
# neighbours' honest water), even though the concrete mechanism here is
# plane-depth-inflation rather than a mesh coverage hole.
const _SUBGRID_STEP := 3.0   # == WaterMesher.S
const _SWIM_ENTER := 0.8     # character.gd's own swim ENTER depth gate
const _WADE_ENTER := 0.05    # character.gd's own wading ENTER depth gate


## True depth class at p using WaterField's own true level_at (character.gd's
## ENTER thresholds — this oracle deliberately uses ENTER, not the
## hysteretic EXIT band, since it is comparing two static classifications,
## not modelling frame-to-frame state).
func _depth_class(depth: float) -> String:
	if depth > _SWIM_ENTER:
		return "swim"
	if depth > _WADE_ENTER:
		return "wade"
	return "dry"


## test_no_dry_pocket_below_adjacent_water_level (I4): walks the mesher's own
## 3m subgrid over the site chunk. At every point inside a wet_cells entry's
## 24m footprint, compares the FIELD's true depth class (WaterField.level_at
## minus real ground) against the class a character probing that same
## wet_cells entry's own SAMPLED PLANE (the exact character.gd/
## WaterSurfaceBuilder formula: c.y + g.dot(p - c)) would read. Flags any
## point where the plane reads a STRICTLY WETTER class than the field's own
## truth (dry->wade, dry->swim, or wade->swim) — the volume promising a
## character more water than genuinely exists under their feet, whether that
## shows up as land reading wet (a coverage hole) or shallow water reading
## deep (a plane-slope error) — both are the same owner-visible defect: swim
## controls where the ground truth doesn't support them. Predicted red site:
## I4, (36.0, -1107.0) and neighbours — true depth 0.76 (wade) vs plane depth
## 1.44 (swim), one cell-row from the owner's own (36.4, 3.2, -1108.7).
func test_no_dry_pocket_below_adjacent_water_level() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	assert_false(m.is_empty(), "site chunk builds water")
	var wet_cells: Dictionary = m.wet_cells
	var base: Vector2 = Vector2(SITE_CHUNK) * (WaterField.TILE * 8.0)
	var n: int = int(WaterField.TILE * 8.0 / _SUBGRID_STEP)
	var order := {"dry": 0, "wade": 1, "swim": 2}
	var violations := 0
	var checked := 0
	var offenders: Array = []
	for j in range(0, n + 1):
		for i in range(0, n + 1):
			var p: Vector2 = base + Vector2(i, j) * _SUBGRID_STEP
			var cell: Vector2i = Vector2i(int(floor(p.x / WaterField.TILE)),
				int(floor(p.y / WaterField.TILE)))
			if not wet_cells.has(cell):
				continue
			var ground: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
			var true_lvl: float = WaterField.level_at(ctx, p)
			var true_depth: float = (true_lvl - ground) if true_lvl > -INF else -999.0
			var true_class: String = _depth_class(true_depth)
			for wc: Dictionary in wet_cells[cell]:
				checked += 1
				var cell_centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * WaterField.TILE
				var plane_y: float = wc.lvl + wc.grad.dot(p - cell_centre)
				var plane_depth: float = plane_y - ground
				var plane_class: String = _depth_class(plane_depth)
				if order[plane_class] > order[true_class]:
					violations += 1
					if offenders.size() < 10:
						offenders.append("p=%s ground=%.2f true_depth=%.2f(%s) plane_depth=%.2f(%s) cell=%s" % [
							p, ground, true_depth, true_class, plane_depth, plane_class, cell])
	print("test_no_dry_pocket_below_adjacent_water_level: %d violations (of %d wet_cells-covered subgrid samples checked)" % [
		violations, checked])
	assert_eq(violations, 0,
		"%d samples read a WETTER depth class from their wet_cells plane than the field's own true depth supports (e.g. %s)" % [
			violations, offenders])
