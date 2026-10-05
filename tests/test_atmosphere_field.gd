extends GutTest

func test_neighbouring_fog_chunks_have_identical_edges() -> void:
	var plan := TerrainWorldTuning.make_heightfield(2697992464)
	var region := plan.compute_region(8, 4, 14)
	var west := BiomeAtmosphereField.compute(Vector2i.ZERO, region, plan.world_seed)
	var east := BiomeAtmosphereField.compute(Vector2i.RIGHT, region, plan.world_seed)
	for z in BiomeAtmosphereField.GRID:
		assert_eq(west.fog[z * 13 + 12], east.fog[z * 13], "shared extinction and hue")
		assert_eq(west.mist_shape[z * 13 + 12], east.mist_shape[z * 13], "shared vertical shape and glow")
		assert_almost_eq(west.ground[z * 13 + 12], east.ground[z * 13], 0.00001, "shared ground datum")

func test_atmosphere_is_resource_free_deterministic_and_grounded() -> void:
	var plan := TerrainWorldTuning.make_heightfield(2697992464)
	var region := plan.compute_region(28, 4, 14)
	var a := BiomeAtmosphereField.compute(Vector2i(3, 0), region, plan.world_seed)
	var b := BiomeAtmosphereField.compute(Vector2i(3, 0), region, plan.world_seed)
	assert_eq(a, b)
	for recipe: StringName in a.points:
		for point: Vector3 in a.points[recipe]:
			var world: Vector3 = point + a.origin
			assert_almost_eq(world.y, TerrainTileField.surface_y(region, world.x, world.z) + 2.5, 0.0001)
			assert_between(point.x, 0.0, 192.0)
			assert_between(point.z, 0.0, 192.0)
	assert_lte(a.orbs.size(), 4, "bounded moving lights per chunk")

func test_biome_boundaries_are_continuous_at_walking_speed() -> void:
	var largest := 0.0
	for z in range(-12, 13):
		for x in range(-12, 13):
			var p := Vector3(x * 79.0, 0, z * 83.0)
			var a := Helper.biome_weights5(p, 2697992464)
			var b := Helper.biome_weights5(p + Vector3(1, 0, 1), 2697992464)
			for id: StringName in a:
				largest = maxf(largest, absf(a[id] - b[id]))
	assert_lt(largest, 0.04, "one walking step cannot switch a biome")
	assert_eq(Helper.biome_at(Vector3.ZERO, 2697992464), &"meadow", "clear spawn")

func test_islands_preserve_ground_without_raising_or_flooding_it() -> void:
	var pond := PondStamp.new(Vector2.ZERO, 110.0, 99, 4, 3.5)
	pond.island_radius = 28.0
	pond.island_offset = Vector2(24, 0)
	assert_eq(pond.carve_at(pond.island_offset, 20.0), 0.0)
	assert_gt(pond.carve_at(Vector2(-40, 0), 20.0), 5.0)
	pond.peninsula = true
	assert_eq(pond.carve_at(Vector2(85, 0), 20.0), 0.0, "shore-connected retained spine")

func test_every_new_biome_has_a_distinct_name_and_complete_ecology() -> void:
	var names: Dictionary = {}
	for id: StringName in BiomeRegistry.biome_ids():
		var profile := BiomeRegistry.profile(id)
		assert_false(names.has(profile.display_name))
		names[profile.display_name] = true
		assert_false(profile.display_name.is_empty())
		assert_false(profile.particles.is_empty())
	assert_eq(names.size(), 7)

func test_scrolling_ground_lookup_preserves_overlapping_world_samples() -> void:
	var first := BiomeGroundMap.samples(Vector2(-1536, -1536), 2697992464)
	var next := BiomeGroundMap.samples(Vector2(-768, -1536), 2697992464)
	assert_eq(first.size(), 4, "Material response shares the canonical scrolling field")
	for layer in first.size():
		assert_eq(first[layer].size(), 65 * 65)
		for z in range(0, 65, 8):
			for x in range(0, 49, 8):
				assert_eq(first[layer][z * 65 + x + 16], next[layer][z * 65 + x],
					"scrolling a render lookup cannot change the colour or biome of a world point")


func test_rivers_and_ground_share_the_new_production_height_input() -> void:
	for seed in [991177, 2697992464]:
		var water := TerrainWorldTuning.make_water(seed)
		var natural := TerrainWorldTuning.make_heightfield(seed)
		for z in range(-8, 9):
			for x in range(-8, 9):
				var cell := Vector2i(x * 7, z * 9)
				var p := Vector2(cell) * HeightfieldPlan.POINT
				assert_almost_eq(water.noise_h(p), natural.raw_height(cell.x, cell.y), 0.00001,
					"river carving must measure the same new landforms as terrain")


class RaisedWater:
	extends WaterFieldContext
	func level_at(_point: Vector2) -> float:
		return 40.0

func test_wetland_particles_float_above_water_instead_of_the_lake_bed() -> void:
	var plan := TerrainWorldTuning.make_heightfield(2697992464)
	var region := plan.compute_region(4, 4, 14)
	var data := BiomeAtmosphereField.compute(Vector2i.ZERO, region,
		plan.world_seed, RaisedWater.new())
	for height: float in data.ground:
		assert_almost_eq(height, 40.0, 0.0001, "Mist rests on the water surface, not the submerged bed")
	var checked := 0
	for recipe: StringName in data.points:
		for point: Vector3 in data.points[recipe]:
			assert_almost_eq(point.y, 42.5, 0.0001)
			checked += 1
	assert_gt(checked, 0)
