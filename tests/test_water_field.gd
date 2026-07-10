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


func test_profiles_monotone_and_continuous() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var checked := 0
	for tr: RiverTrace in ctx.rivers:
		var prof: Dictionary = WaterField.profile(tr)
		var levels: PackedFloat32Array = prof.levels
		assert_eq(levels.size(), tr.points.size(), "one level per sample")
		for i in range(1, levels.size()):
			assert_true(levels[i] <= levels[i - 1] + 0.001,
				"water never flows uphill (trace %s sample %d)" % [tr.source_cell, i])
			var drop: float = levels[i - 1] - levels[i]
			if not prof.cuts.has(i - 1):
				assert_true(drop < WaterField.FALL_DROP_MIN + 0.02,
					"continuous stretch drops %0.2f >= FALL_DROP_MIN at sample %d" % [drop, i])
			checked += 1
		# Window bound: with no cut inside a 2-sample span (i, i+1), the whole
		# span's drop must also stay under the threshold — a multi-sample
		# cliff that never trips the per-step bound above must still be
		# caught by the lookahead window in WaterField.profile().
		for i in range(0, levels.size() - 2):
			if not prof.cuts.has(i) and not prof.cuts.has(i + 1):
				var window_drop: float = levels[i] - levels[i + 2]
				assert_true(window_drop <= WaterField.FALL_DROP_MIN + 0.02,
					"window drops %0.2f >= FALL_DROP_MIN across samples %d..%d" % [window_drop, i, i + 2])
	assert_true(checked > 0, "site chunk has river samples")


func test_cuts_only_at_big_drops() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var total_cuts := 0
	for tr: RiverTrace in ctx.rivers:
		var prof: Dictionary = WaterField.profile(tr)
		for ci in prof.cuts:
			total_cuts += 1
			var drop: float = prof.levels[ci] - prof.levels[ci + 1]
			assert_true(drop > WaterField.FALL_DROP_MIN + 0.009,
				"cut %d drops only %0.2f" % [ci, drop])
	if total_cuts == 0:
		pass_test("no >4m windows near the site on this seed")


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


func test_level_continuous_away_from_cuts() -> void:
	# Walk 1 m steps along the site channel: |level step| must stay < 1.0
	# except when a cut lies between the two probes.
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
	# The site has 2 real falls on this line historically (9->5, 5->3 was a
	# weir and must now be CONTINUOUS, so at most the >4m cuts remain).
	assert_true(big_steps <= 2, "at most the true falls jump; got %d" % big_steps)


func test_fall_cuts_geometry() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	var rect := Rect2(Vector2(0, -1152), Vector2(192, 192))
	var cuts: Array = WaterField.fall_cuts(ctx, rect)
	assert_true(cuts.size() >= 1, "the site keeps its big falls")
	for cut: Dictionary in cuts:
		assert_true(cut.top - cut.bottom > WaterField.FALL_DROP_MIN - 0.001,
			"every cut is a true fall (drop %.2f)" % (cut.top - cut.bottom))
		assert_almost_eq(cut.dir.length(), 1.0, 0.001, "dir is unit")
		assert_almost_eq(cut.dir.dot(cut.across), 0.0, 0.001, "across is perpendicular")


## Degenerate case: a trace whose last bed sample still sits > FALL_DROP_MIN
## above its terminal pond's surface (profile() then appends a cut at
## ci == n-1, where the "normal" j = mini(ci+1, n-1) collapses to ci itself
## — no downstream sample to derive dir/across from). fall_cuts() must
## special-case this: dir comes from the trace's LAST SEGMENT instead, top
## is the trace's own final level, and bottom is the pond's surface. Hand-
## built trace + pond — no world plan needed, so this stays fast.
func test_fall_cuts_pond_terminal_degenerate() -> void:
	var tr := RiverTrace.new()
	tr.source_cell = Vector2i(999, 999)
	tr.priority = 1
	tr.points = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.0, 12.0), Vector2(0.0, 24.0)])
	# Steps of 2.0m each (bed) -> raw level steps of 2.0m, both under
	# FALL_DROP_MIN, so no mid-trace cut is placed; the final level still
	# lands well above the pond, tripping the pond-tail cut at ci == n-1.
	tr.beds = PackedFloat32Array([20.0, 18.0, 16.0])
	tr.widths = PackedFloat32Array([3.0, 3.0, 3.0])
	tr.joined = false
	tr.source_pool = null
	# Pond surface sits far enough below the trace's last raw level
	# (16.0 + SURFACE_RIDE = 18.2) that the drop clears FALL_DROP_MIN (4.0).
	var pond := PondStamp.new(Vector2(0.0, 36.0), 5.0, 42, 3, 2.0)  # surface_y() = 11.0
	tr.pond = pond
	var ctx: Dictionary = {"water": null, "ponds": [], "rivers": [tr], "buckets": {}}
	var rect := Rect2(Vector2(-100.0, -100.0), Vector2(200.0, 200.0))
	var cuts: Array = WaterField.fall_cuts(ctx, rect)
	assert_eq(cuts.size(), 1, "the pond-terminal drop emits exactly one cut")
	var cut: Dictionary = cuts[0]
	assert_almost_eq(cut.dir.length(), 1.0, 0.001, "dir is unit, not the zero vector")
	assert_almost_eq(cut.dir.dot(cut.across), 0.0, 0.001, "across is perpendicular to dir")
	assert_true(cut.top - cut.bottom > WaterField.FALL_DROP_MIN,
		"the recorded drop clears FALL_DROP_MIN (%.2f)" % (cut.top - cut.bottom))
	# dir must follow the trace's last segment (straight +Z here), not some
	# degenerate zero-length "normal" between ci and itself.
	assert_almost_eq(cut.dir.x, 0.0, 0.001, "dir.x follows the last segment")
	assert_almost_eq(cut.dir.y, 1.0, 0.001, "dir.y follows the last segment")
	assert_almost_eq(cut.p.x, 0.0, 0.001, "p stays at the last point")
	assert_almost_eq(cut.p.y, 24.0, 0.001, "p stays at the last point")
	assert_almost_eq(cut.bottom, pond.surface_y(), 0.001, "bottom is the pond's surface")


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
## level must be <= the level of the channel/pond sample it is
## hydraulically connected to. Current build's claim provenance: a wet
## point's claimant is a specific (trace, sample_i) pair; the sample on
## that SAME trace nearest the point in world space is what the point is
## physically "connected to" in the channel. If the claimed level exceeds
## that nearest sample's own level, the claim jumped to a non-adjacent
## (upstream, higher) sample — water standing above its own source.
## Predicted red site: I2 (70.1, -1140.5), claimant si=6 (level 5.70) while
## the nearest channel sample si=9 sits at level 3.00.
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
			var prof: Dictionary = WaterField.profile(tr)
			var nearest_lvl: float = prof.levels[nearest_i]
			if claimed_lvl > nearest_lvl + 0.3:
				violations += 1
				if offenders.size() < 5:
					offenders.append("p=%s claimed_si=%d claimed_lvl=%.2f > nearest_si=%d nearest_lvl=%.2f" % [
						p, claim.si, claimed_lvl, nearest_i, nearest_lvl])
	assert_eq(violations, 0,
		"%d wet samples stand above their hydraulically nearest channel sample (e.g. %s)" % [
			violations, offenders])


## test_waterline_is_a_terrain_contour (H2/H4, I2/I4 "curvy perimeter"): for
## every boundary (free-edge) vertex not on a chunk border, either the
## vertex sits close to the real terrain (|level - surface_y| <= 0.6), or
## the ground within 1.5m rises above the level (a wall — a legitimate
## non-contour edge). A vertex that is neither is a claim-radius cut
## floating over ground it has no hydrological relationship to.
## Predicted red site: I2's flood-extension boundary (a straight claim-
## radius cut, not a terrain contour).
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
	assert_true(checked > 20, "site has a real shoreline (%d verts)" % checked)
	assert_eq(violations, 0,
		"%d boundary verts are neither a terrain contour nor a wall edge (e.g. %s)" % [
			violations, offenders])


## Which river trace/sample claims p, re-deriving level_at's own selection
## (level_at only returns the winning level, not its identity) — kept in
## lockstep with WaterField.level_at's structure. Returns {} when a pond
## wins or nothing claims p (out of scope for the source-provenance check).
func _claim_river(c: Dictionary, p: Vector2) -> Dictionary:
	var region = c.get("region")
	var best_m: float = INF
	var best_lvl: float = -INF
	var best_is_river := false
	var best_tr: RiverTrace = null
	var best_si := -1
	var gy: float = INF
	var have_gy := false
	for pond: PondStamp in c.ponds:
		var m: float = (pond.footprint_t(p) - 1.0) * pond.radius
		if m >= best_m:
			continue
		var ok: bool = m < WaterField.CLAIM_FEATHER
		var lvl: float = pond.surface_y()
		if not ok and region != null and m <= WaterField.CLAIM_FEATHER + WaterField.FLOOD_EXT:
			if not have_gy:
				gy = TerrainSurfaceField.surface_y(region, p.x, p.y)
				have_gy = true
			ok = gy < lvl - WaterField.EPS and gy > lvl - WaterField.FLOOD_DEPTH_MAX
		if ok:
			best_m = m
			best_lvl = lvl
			best_is_river = false
	var cell := Vector2i(int(floor(p.x / WaterField.TILE)), int(floor(p.y / WaterField.TILE)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var b: Array = c.buckets.get(cell + Vector2i(dx, dz), [])
			for ref: Vector2i in b:
				var tr: RiverTrace = c.rivers[ref.x]
				var si: int = ref.y
				var d: float = p.distance_to(tr.points[si])
				var m: float = d - tr.widths[si]
				if m >= best_m:
					continue
				var ok: bool = m < WaterField.CLAIM_FEATHER
				if not ok and (region == null or m > WaterField.CLAIM_FEATHER + WaterField.FLOOD_EXT):
					continue
				var lvl: float = WaterField._sample_level(tr, si, p)
				if not ok:
					if not have_gy:
						gy = TerrainSurfaceField.surface_y(region, p.x, p.y)
						have_gy = true
					ok = gy < lvl - WaterField.EPS and gy > lvl - WaterField.FLOOD_DEPTH_MAX
				if ok:
					best_m = m
					best_lvl = lvl
					best_is_river = true
					best_tr = tr
					best_si = si
	if not best_is_river:
		return {}
	return {"tr": best_tr, "si": best_si, "lvl": best_lvl}


func _nearest_sample(tr: RiverTrace, p: Vector2) -> int:
	var best_d := INF
	var best_i := 0
	for i in tr.points.size():
		var d: float = tr.points[i].distance_to(p)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _on_chunk_border_f(v: Vector3) -> bool:
	var span: float = WaterField.TILE * 8.0
	var lx: float = fposmod(v.x, span)
	var lz: float = fposmod(v.z, span)
	return lx < 0.01 or lx > span - 0.01 or lz < 0.01 or lz > span - 0.01
