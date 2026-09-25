extends GutTest

func test_public_air_alone_cannot_hold_a_cantilevered_soil_bed() -> void:
	for enclosed: bool in [false, true]:
		var grid := WarrenSpatialGrid.new(Vector3i(-4, 0, -4), Vector3i(9, 6, 9))
		var envelope := WarrenVolumeEnvelope.new()
		for x in range(-2, 3):
			for z in range(-2, 3):
				envelope.height_bands[Vector2i(x, z)] = 6
		var source := WarrenSpatialPlan.new(&"soil-support", 1, grid)
		source.source_volume = WarrenVolumePlan.new(&"soil-support", 1, envelope)
		var carve := grid.begin_transaction(&"public")
		assert_true(carve.assign_use([Vector3i(0, 2, 0)] as Array[Vector3i],
			WarrenSpatialGrid.Use.PUBLIC_AIR, &"public"))
		assert_true(carve.commit())
		var cells: Dictionary = {Vector3i(0, 3, 0): true}
		for y in range(4):
			cells[Vector3i(-1, y, 0)] = true
			if enclosed: cells[Vector3i(1, y, 0)] = true
		var result := WarrenSpatialFabricCompiler._supported_retained_maze_cells(
			source, null, {}, cells, {})
		assert_eq(result.supported.has(Vector3i(0, 3, 0)), enclosed,
			"A real tunnel crown needs opposing jambs; public air alone is not support")
		for y in range(4):
			assert_true(result.supported.has(Vector3i(-1, y, 0)))

func test_a_distant_wall_cannot_bear_a_disconnected_tunnel_crown() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-4, 0, -4), Vector3i(9, 6, 9))
	var carve := grid.begin_transaction(&"public")
	assert_true(carve.assign_use([Vector3i(0,2,0),Vector3i(1,2,0)] as Array[Vector3i],
		WarrenSpatialGrid.Use.PUBLIC_AIR,&"public"))
	assert_true(carve.commit())
	var crown := {Vector3i(0,3,0):true}
	var walls := {Vector3i(-1,2,0):true,Vector3i(2,2,0):true}
	assert_false(WarrenSpatialFabricCompiler._retained_tunnel_has_opposing_bearings(
		grid,Vector3i(0,2,0),crown,walls,{}),"The crown must reach both jambs without an uncovered gap")
	crown[Vector3i(1,3,0)] = true
	assert_true(WarrenSpatialFabricCompiler._retained_tunnel_has_opposing_bearings(
		grid,Vector3i(0,2,0),crown,walls,{}),"A complete two-cell roof remains legal")
