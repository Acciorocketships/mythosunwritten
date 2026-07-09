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
	assert_true(checked > 0, "site chunk has river samples")


func test_cuts_only_at_big_drops() -> void:
	var water: WaterPlan = _water(SEED)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK)
	for tr: RiverTrace in ctx.rivers:
		var prof: Dictionary = WaterField.profile(tr)
		for ci in prof.cuts:
			var drop: float = prof.levels[ci] - prof.levels[ci + 1]
			assert_true(drop > WaterField.FALL_DROP_MIN + 0.009,
				"cut %d drops only %0.2f" % [ci, drop])


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
