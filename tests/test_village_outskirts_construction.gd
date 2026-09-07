extends GutTest

func test_reported_town_builds_connected_nonoverlapping_ground_houses_once() -> void:
	var seed_value := 2697992464
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value,water)
	var fields := WorldFieldBlockCache.new(heightfield,water,program.query_margin,
		program.shore_distance_limit,program.field_cache_cap)
	var terrain := VillageTerrainView.from_fields(fields)
	var urban := VillageWarrenFabricSolver.solve(terrain,
		VillagePlan.warren_seed_for_cell(seed_value,Vector2i(11,12)),
		&"reported-town",Vector2(264,288),Vector2.DOWN,program.villages,seed_value)
	assert_true(urban.accepted)
	if not urban.accepted: return
	terrain = terrain.with_terrain_grades([urban.terrain_grade])
	var start := Time.get_ticks_msec()
	var outskirts := VillageOutskirtsConstruction.generate(terrain,&"reported-town",
		Vector2(264,288),Vector2.DOWN,&"village",&"blue",program.villages,urban,null)
	print("FRONTAGE_CONSTRUCTION ms=",Time.get_ticks_msec()-start," houses=",outskirts.placements.size()," branches=",outskirts.branch_count)
	assert_gte(outskirts.placements.size(),6,"the ground-house neighborhood must remain populated")
	assert_true(outskirts.validate(program.villages.outskirts_program,&"village"),
		"completed geometry is audited here, not used to reject runtime houses")
	var physical_urban: Array[VillageOccupancyVolume] = []
	for volume: VillageOccupancyVolume in urban.volumes:
		if volume.role != VillageOccupancy.Role.GROUND_EXCLUSIVE: physical_urban.append(volume)
	assert_eq(VillageOccupancy.first_cross_conflict(outskirts.volumes,physical_urban),{},
		"all built lanes and houses must clear the urban construction")
	for i in outskirts.placements.size():
		var house := outskirts.placements[i]
		for j in range(i+1,outskirts.placements.size()):
			assert_false(house.solid_shape().intersects(outskirts.placements[j].solid_shape()))
		for shape: FeatureGroundShape in urban.surfaces:
			assert_false(house.support_shape().intersects(shape),"house must not overlap the town path")
		for shape: FeatureGroundShape in outskirts.surfaces:
			assert_false(house.support_shape().intersects(shape),
				"the complete painted junction must clear the house base: %s / %s" % [house.stable_key,shape.stable_id])
		var pad_height := house.floor_y - VillageTerrainSurvey.FLOOR_GUARD
		var bounds := house.support_shape().bounds()
		for point: Vector2 in [bounds.position,bounds.end,bounds.get_center(),
				Vector2(bounds.position.x,bounds.end.y),Vector2(bounds.end.x,bounds.position.y)]:
			assert_almost_eq(urban.terrain_grade.surface_y(point,terrain.surface_y(point)),pad_height,0.02,
				"the entire building base must meet its constructed ground pad")
		assert_eq(outskirts.audit[i].placement_count,1)
