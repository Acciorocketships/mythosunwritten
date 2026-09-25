extends GutTest

func test_native_house_reservation_cannot_hold_the_photographed_soil_shelf() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/13-floating-lawn/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var skin := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	for x in 2:
		for z in 4:
			var cell := Vector3i(x,3,z)
			assert_false(skin.retained.has(cell),"The source shelf over public air has no complete native jamb at its prefab end")
			assert_false(skin.capped_ground.has(cell),"Removing the unsupported stone must also remove turf and its generated soffit")
	var houses := 0
	for unit: FabricUnit in fabric.units:
		if program.recipe(unit.recipe_id).has_tag(&"prefab_anchor"): houses += 1
	assert_eq(houses,3,"All three complete native houses survive")

func test_private_reservation_alone_is_not_an_earth_crown_jamb() -> void:
	for yaw in 4:
		var grid := WarrenSpatialGrid.new(Vector3i(-4,0,-4),Vector3i(9,6,9))
		var axis := FabricRecipe.transform_direction(Vector3i.RIGHT,yaw)
		var air := Vector3i(0,2,0)
		var claim := grid.begin_transaction(&"public")
		assert_true(claim.assign_use([air] as Array[Vector3i],WarrenSpatialGrid.Use.PUBLIC_AIR,&"public"))
		assert_true(claim.assign_use([air+axis] as Array[Vector3i],WarrenSpatialGrid.Use.PRIVATE_VOLUME,&"reserved.prefab"))
		assert_true(claim.commit())
		var walls := {air-axis:true}
		var crown := {air+Vector3i.UP:true}
		assert_false(WarrenSpatialFabricCompiler._retained_tunnel_has_opposing_bearings(grid,air,crown,walls,{}))
		walls[air+axis]=true
		assert_true(WarrenSpatialFabricCompiler._retained_tunnel_has_opposing_bearings(grid,air,crown,walls,{}),"Two real complete jambs retain an ordinary tunnel crown")
