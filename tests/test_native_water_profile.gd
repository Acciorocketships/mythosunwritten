extends GutTest
## WaterField.profile's terrain-shaped branch in C# (NativeWaterProfile.cs):
## on real rivers of two seeds the native profile, read from the trace's
## natural corridor or from a region that already certifies it, equals the
## GDScript over _trace_owned_region exactly (levels and every descent array).
const F := preload("res://scripts/native/NativeWaterFill.gd")


func test_profiles_match_gdscript_on_real_rivers() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(F.enabled); return
	assert_true(F.enabled, "parity gate passed")
	var compared := 0
	var shaped := 0
	var spans := 0
	for spec: Array in [[2697992464, Rect2(-2400, -2300, 2400, 2400)], [3046246887, Rect2(-2400, -2400, 4800, 4800)]]:
		var seed: int = spec[0]
		var water := TerrainWorldTuning.make_water(seed)
		var plan := TerrainWorldTuning.make_heightfield(seed, water)
		var caller := plan.compute_region(0, 0, 1)   # plan-backed, certifies no trace
		var rivers: Array = water.bodies_in_rect(spec[1]).rivers
		var count := mini(rivers.size(), 16)
		for k in count:
			var trace: RiverTrace = rivers[k]
			WaterField._trace_regions.clear()
			var served := F.profiles_served
			var native := WaterField._profile_compute(trace, caller, true, true)
			var used := F.profiles_served - served
			WaterField._trace_regions.clear()
			var expected := WaterField._profile_compute(trace, caller, true, false)
			var label := "seed %d trace %d (%d points)" % [seed, k, trace.points.size()]
			assert_eq(native.levels, expected.levels, label + ": levels")
			assert_eq(var_to_bytes(native.descents), var_to_bytes(expected.descents), label + ": descents")
			# A region that already certifies the trace supplies its corners.
			if k % 4 == 0 and used > 0:
				var owned := plan.compute_rect_region(WaterField._trace_point_domain(trace))
				WaterField._trace_regions.clear()
				var from_region := WaterField._profile_compute(trace, owned, true, true)
				assert_eq(from_region.levels, expected.levels, label + ": levels from a certifying region")
				assert_eq(var_to_bytes(from_region.descents), var_to_bytes(expected.descents),
					label + ": descents from a certifying region")
			compared += 1
			shaped += used
			spans += expected.descents.size()
		WaterField._trace_regions.clear()
	assert_gte(compared, 30, "about 30 real traces")
	assert_gte(shaped, 20, "most real traces descend and take the native path")
	assert_gt(spans, 0, "descent spans are exercised")
	gut.p("compared %d traces, %d native, %d descent spans" % [compared, shaped, spans])


## Production scale (max_storeys 120, max_step 3: clamp radii up to 39) on
## sparse corridors, one point and a diagonal line of 3 x 3 blocks, over a cone
## of targets whose pit only the outermost clamp disks reach, at exactly their
## radius. Kept here, not in the runtime gate (which runs the same cones at 12
## storeys). A radius one shorter fails this test.
func test_corridor_terrain_at_production_scale_reaches_a_pit_at_the_clamp_radius() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"): pass_test("standard editor"); return
	assert_eq(F.cone_case(3, 120, false), "", "one point")
	assert_eq(F.cone_case(3, 120, true), "", "a diagonal line of 3 x 3 blocks")
	assert_eq(F.cone_case(1, 120, true), "", "max_step 1")


## The runtime gate runs three random corridor cases; this runs twelve
## (every aggregation with max_step 1-3, rare and frequent pits).
func test_corridor_terrain_matches_the_region_kernel_on_random_terraces() -> void:
	F.setup()
	if not ClassDB.class_exists(&"CSharpScript"): pass_test("standard editor"); return
	var rng := RandomNumberGenerator.new(); rng.seed = 20261008
	assert_eq(F.corridor_random(rng, 12), "")
