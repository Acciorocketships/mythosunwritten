extends GutTest

func test_river_corpus_is_frequent_long_and_geographically_extensive() -> void:
	for seed_v in [991177, 2697992464, 314159]:
		# This is a production density ratchet. Use the same landform amplitude
		# as the streamed world instead of the retired 22 m terrain setting.
		var water := TerrainWorldTuning.make_water(seed_v)
		var count := 0
		var long_count := 0
		var length_sum := 0.0
		var extent_sum := 0.0
		for z in range(-4, 5):
			for x in range(-4, 5):
				var t := water.river_for(Vector2i(x, z), 0)
				if t == null:
					continue
				count += 1
				var length := float(t.points.size() - 1) * WaterPlan.TRACE_STEP
				length_sum += length
				extent_sum += t.bounds().size.length()
				long_count += int(length >= 2000.0)
				for p in t.points:
					assert_lte(p.distance_to(t.points[0]), WaterPlan.TRACE_REACH + 0.01,
						"arc length cannot escape the finite discovery halo")
		assert_gte(count, 30, "at least 30 spring districts in the 81-district corpus")
		assert_gt(float(long_count) / maxi(count, 1), 0.9, "over 90% of headwaters run at least two kilometres")
		assert_gt(length_sum / maxi(count, 1), 2500.0, "mean river length exceeds 2.5km")
		assert_gt(extent_sum / maxi(count, 1), 2000.0, "rivers span the landscape rather than coil in one basin")

func test_channel_core_crosses_terrain_diagonals_with_finite_width() -> void:
	# The farthest centre of a cell touched by a centreline is half a tile's
	# diagonal away. Test actual quantized excavation at both diagonal phases.
	var water := WaterPlan.new(77, 22.0, 8)
	for sign_v in [-1.0, 1.0]:
		var corner := Vector2(1020, 1020)
		var axis := Vector2(1, sign_v).normalized()
		var t := RiverTrace.new()
		t.source_cell = Vector2i(100, int(sign_v))
		t.points = PackedVector2Array([corner - axis * 60.0, corner + axis * 60.0])
		t.beds = PackedFloat32Array([4.0, 4.0])
		t.widths = PackedFloat32Array([WaterPlan.W_MIN, WaterPlan.W_MIN])
		var buckets: Dictionary = {}
		for z in [42, 43]:
			for x in [42, 43]:
				buckets[Vector2i(x, z)] = [[t, 0], [t, 1]]
		water._region_cache[Vector2i(1, 1)] = {"rivers": [t], "ponds": [], "buckets": buckets}
		for cell: Vector2i in buckets:
			var p := Vector2(cell) * WaterPlan.TILE
			var height := water.noise_h(p) - water.carve_at_cell(cell.x, cell.y)
			assert_lte(roundf(height / 4.0) * 4.0, 4.0,
				"both off-diagonal bridge cells excavate below the river surface")

func test_terminal_lakes_have_varied_bounded_elongation() -> void:
	var water := WaterPlan.new(991177, 22.0, 8)
	var smallest := INF
	var largest := 0.0
	for i in 12:
		var lake := water._make_pond(Vector2(1800 + i * 73, 2400 - i * 51), 3000.0)
		assert_gte(lake.aspect_ratio, 0.5)
		assert_lte(lake.aspect_ratio, 0.9)
		smallest = minf(smallest, lake.radius)
		largest = maxf(largest, lake.radius)
		for angle in 32:
			assert_lte(lake.radius_at(float(angle) * TAU / 32.0), lake.bound_radius(),
				"elongated shores remain inside the discovery and carving bound")
	assert_gt(largest - smallest, 20.0, "equal-length rivers can end in visibly different-sized lakes")

func test_production_channel_has_no_dry_diagonal_interruptions() -> void:
	WaterField._profiles.clear()
	WaterField._trace_regions.clear()
	var water := WaterPlan.new(991177, 22.0, 8)
	var plan := HeightfieldPlan.new(991177, 22.0, 8, "mean", 3)
	plan.set_water_plan(water)
	var trace := water.river_for(Vector2i(-3, -4))
	assert_not_null(trace)
	var contexts: Dictionary = {}
	var checked := 0
	for i in range(3, mini(trace.points.size() - 1, 65), 2):
		var p: Vector2 = (trace.points[i] + trace.points[i + 1]) * 0.5
		var chunk := Vector2i((p / 192.0).floor())
		if not contexts.has(chunk):
			var region := plan.compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
			contexts[chunk] = WaterField.ctx(water, chunk, region)
		var ctx: Dictionary = contexts[chunk]
		for offset in [Vector2.ZERO, Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
			checked += 1
			assert_true(WaterField.wet(ctx, ctx.region, p + offset),
				"the realized river has finite wet width at %s" % (p + offset))
	assert_gt(checked, 40, "real production channel spans many rendered terrain cells")
	WaterField._profiles.clear()
	WaterField._trace_regions.clear()

func test_profile_cache_cannot_mix_different_rivers_with_the_same_source_cell() -> void:
	WaterField._profiles.clear()
	var a := RiverTrace.new()
	a.source_cell = Vector2i(321, 654)
	a.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	a.beds = PackedFloat32Array([4.0, 4.0])
	a.widths = PackedFloat32Array([20.0, 20.0])
	var b := RiverTrace.new()
	b.source_cell = a.source_cell
	b.points = a.points
	b.beds = PackedFloat32Array([12.0, 12.0])
	b.widths = a.widths
	var first: Dictionary = WaterField.profile(a)
	var second: Dictionary = WaterField.profile(b)
	assert_almost_eq(second.levels[0] - first.levels[0], 8.0, 0.001,
		"new worlds and frozen review fixtures cannot inherit another trace's cached level")
	WaterField._profiles.clear()
