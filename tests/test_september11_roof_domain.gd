extends GutTest


func test_complete_crown_realizes_the_tight_options_reserved_before_selection() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := preload("res://tests/fixtures/frozen_maze_source.gd").read(
		"res://tests/fixtures/september11-unified-roof-source.txt")
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	var spatial := WarrenVolumetricSolver.from_volume(volume, -1, program, true)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var room: WarrenRoomStamp
	for building: WarrenBuildingVolume in spatial.buildings:
		for candidate: WarrenRoomStamp in building.room_records:
			if candidate.stable_id == &"spatial.residual.01.room00":
				room = candidate
	assert_not_null(room)
	if room == null:
		return
	var reserved := WarrenSpatialFabricCompiler._pitched_roof_domain(
		room, source.world_seed, {}, true, true)
	var actual := WarrenSpatialFabricCompiler._pitched_roof_domain(
		room, source.world_seed, {"flat_roof": true}, true, false)
	for option: Dictionary in reserved:
		assert_true(actual.has(option),
			"A complete exposed crown must realize its reserved option %s" % option)
	var fabric := WarrenSpatialFabricCompiler.generate(spatial, program, true)
	assert_not_null(fabric, WarrenSpatialFabricCompiler.last_failure)
