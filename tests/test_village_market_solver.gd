extends GutTest


func _flat_region() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-8, 9):
		for x in range(-8, 9):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_market_is_a_connected_orthogonal_alley_loop_lined_with_stalls() -> void:
	var village_program := VillageProgram.compile({},
		EnvironmentCatalog.load_default())
	var plan := VillageMarketSolver.solve(VillageTerrainView.from_region(
		_flat_region()), &"test.settlement", Vector2.ZERO, Vector2.RIGHT,
		&"village", &"blue", village_program)
	assert_true(plan.accepted, String(plan.reason))
	assert_true(plan.validate(village_program.market_program, &"village"))
	assert_gte(plan.stalls.size(),
		village_program.market_program.minimum_stalls(&"village"))
	assert_gte(plan.links.size(), 6)
	assert_gte(plan.surfaces.size(), plan.links.size())
	for link: VillageCirculationLink in plan.links:
		for index in range(1, link.control_points.size()):
			var delta := link.control_points[index] \
				- link.control_points[index - 1]
			assert_true(is_zero_approx(delta.x) or is_zero_approx(delta.z),
				"market alleys turn at right angles")
	for stall: VillageMarketStall in plan.stalls:
		assert_true(stall.is_valid())
		assert_lt(stall.service_front.distance_to(Vector2.ZERO),
			stall.transform.origin.length() + 12.0,
			"reviewed service fronts remain associated with the central market")


func test_market_output_is_deterministic() -> void:
	var village_program := VillageProgram.compile({},
		EnvironmentCatalog.load_default())
	var terrain := VillageTerrainView.from_region(_flat_region())
	var a := VillageMarketSolver.solve(terrain, &"test.settlement",
		Vector2.ZERO, Vector2.RIGHT, &"town", &"orange", village_program)
	var b := VillageMarketSolver.solve(terrain, &"test.settlement",
		Vector2.ZERO, Vector2.RIGHT, &"town", &"orange", village_program)
	assert_true(a.accepted, String(a.reason))
	assert_eq(a.stalls.size(), b.stalls.size())
	for index in a.stalls.size():
		assert_eq(a.stalls[index].stable_key, b.stalls[index].stable_key)
		assert_eq(a.stalls[index].asset_id, b.stalls[index].asset_id)
		assert_eq(a.stalls[index].transform, b.stalls[index].transform)
