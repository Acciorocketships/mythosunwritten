extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_photographed_house_fills_its_reserved_space_beneath_the_public_deck() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september9-thin-turf-source.txt"),program)
	var filled := 0
	for y in [2,3]:
		for z in [0,1]:
			for x in [2,3]:
				filled += int(spatial.grid.use_at(Vector3i(x,y,z))==WarrenSpatialGrid.Use.PRIVATE_VOLUME)
	assert_eq(filled,8,"The complete room continues to the existing public ceiling; no little gable sits underneath")
	for z in [0,1]:
		for x in [2,3]:
			var floor := Vector3i(x,4,z)
			assert_eq(spatial.grid.use_at(floor),WarrenSpatialGrid.Use.PUBLIC_AIR)
			assert_eq(int(spatial.grid.face_claim(floor,Vector3i.DOWN).get("kind",-1)),WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR)
	for unit: FabricUnit in spatial.compiled_fabric_cache().units:
		if String(unit.stable_id).begins_with("spatial.roof.spatial.parcel.maze.house.000."):
			assert_false(spatial.compiled_fabric_cache().recipe(unit.recipe_id).has_tag(&"pitched_roof"))
	assert_eq(WarrenSpatialFabricCompiler.validation_errors(spatial.compiled_fabric_cache()),PackedStringArray())

func test_public_ceiling_requires_complete_same_height_coverage_in_four_orientations() -> void:
	for quarter in 4:
		var source := WarrenMazeSourcePlan.new(77,WarrenVillageScaleProfile.for_id(&"standard"),null,null)
		var volume := WarrenVolumePlan.new(&"ceiling",77,null)
		volume._sealed = true
		var columns: Array[Vector2i] = []
		for point: Vector2 in [Vector2(2,0),Vector2(3,0),Vector2(2,1),Vector2(3,1)]:
			var rotated := point.rotated(quarter*PI*0.5).round()
			var column := Vector2i(rotated)
			columns.append(column)
			source.passage_kinds[Vector3i(column.x,4,column.y)] = &"spine"
			for z in 2:
				for x in 2:
					var cell := Vector3i(column.x*2+x,4,column.y*2+z)
					volume._exact_route_surface_set[WarrenVolumePlan._cell_key(cell)] = cell
		var plot := {"kind":WarrenMazeSourcePlan.PLOT_HOUSE,"floor":0,"top":4,"cells":columns}
		assert_true(WarrenMazeBlockPartitioner.plot_has_public_ceiling(source,plot,volume))
		assert_eq(WarrenMazeBlockPartitioner.plot_roof_band_span(source,plot,volume),Vector2i(4,4))
		var parcel := WarrenBuildingParcel.new(&"covered",columns,0,4,Vector3i.ZERO,columns[0],Vector2i.LEFT,0,true)
		parcel.public_ceiling = true
		assert_eq(parcel.storey_count(),2)
		assert_eq(parcel.roof_base_band(),4)
		var covered_signature := parcel.deterministic_signature()
		parcel.public_ceiling = false
		assert_eq(parcel.storey_count(),1)
		assert_ne(parcel.deterministic_signature(),covered_signature)
		var missing := Vector3i(columns[0].x*2,4,columns[0].y*2)
		volume._exact_route_surface_set.erase(WarrenVolumePlan._cell_key(missing))
		assert_false(WarrenMazeBlockPartitioner.plot_has_public_ceiling(source,plot,volume),"Partial coverage retains a weather roof")
		assert_eq(WarrenMazeBlockPartitioner.plot_roof_band_span(source,plot,volume),Vector2i(2,4))
		volume._exact_route_surface_set[WarrenVolumePlan._cell_key(missing+Vector3i.UP)] = missing+Vector3i.UP
		assert_false(WarrenMazeBlockPartitioner.plot_has_public_ceiling(source,plot,volume),"A staggered upper route is not one complete ceiling")
		volume._exact_route_surface_set[WarrenVolumePlan._cell_key(missing)] = missing
		plot.top = 5
		assert_false(WarrenMazeBlockPartitioner.plot_has_public_ceiling(source,plot,volume),"An odd band cannot become a complete extra storey")
