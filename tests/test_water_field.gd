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
