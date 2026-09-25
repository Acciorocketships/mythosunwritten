extends GutTest

func test_default_population_includes_tiny_ground_settlements() -> void:
	assert_eq(VillageProgram.production_tier(0.10), &"hamlet",
		"a small house collection must not require the warren grammar")
	assert_eq(VillageProgram.production_tier(0.70), &"village")
	assert_eq(VillageProgram.production_tier(0.99), &"town")

func test_small_square_has_complete_supported_houses_and_central_focus() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new(storeys, levels))
	for seed_value in range(1, 13):
		for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var town := VillageHamletConstruction.solve(terrain, seed_value,
				StringName("hamlet.%d" % seed_value), Vector2.ZERO, direction,
				&"orange", program, null)
			assert_true(town.accepted, "seed %d direction %s: %s" % [seed_value, direction, town.reason])
			if not town.accepted:
				print(town.candidate_audit)
				continue
			assert_true(town.validate(program, &"hamlet"))
			assert_between(town.ground_settlement.placements.size(), 3, 6)
			assert_null(town.volumetric_spatial)
			assert_false(town.requires_outskirts())
			assert_true(VillageOccupancy.new().first_conflict(town.volumes).is_empty())
			for house: VillageMassingPlacement in town.ground_settlement.placements:
				assert_true(house.ground_accessible)
				assert_almost_eq(house.street_contact_y, 0.0, 0.001)
				assert_lte(house.solid_max_y - house.solid_min_y, 12.0)

func test_crossroads_keep_all_real_road_handoffs_clear() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var heights: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			heights[Vector2i(x,z)] = 0
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new(heights, heights))
	var ground := FeatureGroundField.new([], [], 0.0)
	ground._connection_masks[Vector2i.ZERO] = 15
	ground._connection_masks[Vector2i.RIGHT] = 2
	ground._connection_masks[Vector2i.LEFT] = 1
	ground._connection_masks[Vector2i.DOWN] = 8
	ground._connection_masks[Vector2i.UP] = 4
	for seed_value in range(1, 13):
		var town := VillageHamletConstruction.solve(terrain, seed_value,
			StringName("crossroads.%d" % seed_value), Vector2.ZERO, Vector2.DOWN,
			&"blue", program, ground)
		assert_true(town.accepted, "crossroads %d: %s" % [seed_value, town.candidate_audit])
		if town.accepted:
			assert_true(town.validate(program, &"hamlet"))

func test_canonical_records_publish_tiny_houses_without_a_second_outskirts_pass() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var heights: Dictionary = {}
	for z in range(-24,25):
		for x in range(-24,25): heights[Vector2i(x,z)] = 0
	var region := HeightfieldRegion.new(heights,heights)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._region = region
	water._coverage = Rect2(-576,-576,1152,1152)
	var frame := VillageFrame.from_mask({"id":&"hamlet.production","cell":Vector2i.ZERO},
		0,region,water)
	var checked := 0
	for seed_value in range(1,17):
		var plan := VillagePlan.new(seed_value,program)
		if plan._tier(frame) != &"hamlet": continue
		var record := plan.record_for(frame)
		assert_true(record.validate(program), "world seed %d" % seed_value)
		assert_true(record.urban_fabric.accepted, String(record.urban_fabric.reason))
		assert_null(record.outskirts)
		assert_between(record.urban_fabric.ground_settlement.placements.size(),3,6)
		assert_gt(record.payload.instance_count,3)
		assert_true(record.payload.batches.has(record.urban_fabric.fabric_audit.focal_asset))
		checked += 1
	assert_gt(checked,4)

func test_distant_roads_do_not_enlarge_a_tiny_square() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var heights: Dictionary = {}
	for z in range(-12,13):
		for x in range(-12,13): heights[Vector2i(x,z)] = 0
	var terrain := VillageTerrainView.from_region(HeightfieldRegion.new(heights,heights))
	var distant := FeatureGroundField.new([],[],0.0)
	distant._connection_masks[Vector2i(100,100)] = 15
	var local := VillageHamletConstruction.solve(terrain,3,&"local",Vector2.ZERO,
		Vector2.DOWN,&"blue",program,null)
	var remote := VillageHamletConstruction.solve(terrain,3,&"remote",Vector2.ZERO,
		Vector2.DOWN,&"blue",program,distant)
	assert_true(local.accepted and remote.accepted)
	assert_eq(local.fabric_audit.square_radius,remote.fabric_audit.square_radius)
	assert_lt(float(remote.fabric_audit.square_radius),18.0)
