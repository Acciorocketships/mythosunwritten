extends GutTest

func test_bridge_endpoint_rejects_stair_clearance_in_its_bearing() -> void:
	var massif := WarrenMassif.new(4)
	var column := Vector2i(0,-2)
	massif.columns[column]={"base":0,"top":12,"terrace":12}
	var excavation := WarrenExcavation.new(4)
	var columns := [column]
	assert_true(WarrenMazeCarver._bridge_foundation_is_direct(massif,excavation,{},columns,6,9))
	# The old source carve leaves band five solid, but the fine stair clearance
	# from band three to four reserves it. That band cannot carry a lower house.
	var spec := {"from":Vector3i(0,3,-3),"to":Vector3i(0,4,0)}
	excavation.transitions.append(spec)
	assert_false(WarrenMazeCarver._bridge_foundation_is_direct(massif,excavation,{},columns,6,9))
	assert_true(WarrenMazeCarver._bridge_foundation_is_direct(massif,excavation,{},columns,7,9),"A bearing above the complete clearance remains valid")
	excavation.transitions.clear()
	excavation.lanes.append({"transitions":[spec]})
	assert_false(WarrenMazeCarver._bridge_foundation_is_direct(massif,excavation,{},columns,6,9))
	excavation.lanes.clear()
	excavation.loop_edges.append(spec)
	assert_false(WarrenMazeCarver._bridge_foundation_is_direct(massif,excavation,{},columns,6,9))

func test_reported_large_town_builds_with_supported_bridge_endpoints() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(4,{},program,WarrenVillageScaleProfile.for_id(&"large"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
