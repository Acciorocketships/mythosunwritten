extends GutTest

func test_photographed_half_roofs_present_native_gables_to_the_street() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/07-platform/current-source.txt"),program).compiled_fabric_cache()
	var world := Transform3D(Basis.from_scale(Vector3(-2,2,-2)),Vector3(-214.5,8.08,-944.5))
	var faces := PackedVector3Array()
	var roofs := 0
	for entry: Dictionary in fabric.expanded_placements():
		if not String(entry.stable_id).begins_with("spatial.roof.spatial.parcel.maze.house.000.part00.room00.tile00/"): continue
		roofs += 1
		var visual: EnvironmentVisual = load(catalog.descriptor(entry.asset_id).visual_path)
		for piece: EnvironmentVisualPiece in visual.pieces:
			faces.append_array(EnvironmentBakeGeometry.triangle_faces(piece.mesh,world * entry.transform * piece.local_transform))
	assert_eq(roofs,2,"Both original half-depth crowns remain")
	for x: float in [-204,-210]:
		for y: float in [14.9,15.7,16.5]:
			var closed := false
			for i in range(0,faces.size(),3):
				if Geometry3D.segment_intersects_triangle(Vector3(x,y,-967.01),Vector3(x,y,-966.89),faces[i],faces[i+1],faces[i+2]) != null:
					closed = true
					break
			assert_true(closed,"The street-facing native gable must close at %s/%s" % [x,y])


func test_wall_backed_roof_selection_rotates_without_changing_native_stock() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for family in ["orange","blue"]:
		for width in [2,4,6]:
			for yaw in 4:
				for wall_side in [-1,1]:
					var origin := Vector3i(4,3,-7)
					var grid := _backing_grid(origin,yaw,width,wall_side,2,width)
					var admitted := 0
					for hand in ["negative","positive"]:
						var recipe := program.recipe(StringName("roof.partial.gable.%s.%d.%s" % [family,width,hand]))
						var unit := FabricUnit.new(&"roof",recipe.recipe_id,origin,yaw)
						if WarrenSpatialFabricCompiler._unit_has_site_conflict(grid,unit,recipe): continue
						admitted += 1
						var faces := PackedVector3Array()
						for entry: Dictionary in recipe.placements:
							var visual: EnvironmentVisual = load(catalog.descriptor(entry.asset_id).visual_path)
							for piece: EnvironmentVisualPiece in visual.pieces:
								faces.append_array(EnvironmentBakeGeometry.triangle_faces(piece.mesh,unit.transform()*entry.transform*piece.local_transform))
						var start := unit.transform()*Vector3(.75,.8,-wall_side*.751)
						var end := unit.transform()*Vector3(.75,.8,-wall_side*.699)
						var closed := false
						for i in range(0,faces.size(),3):
							if Geometry3D.segment_intersects_triangle(start,end,faces[i],faces[i+1],faces[i+2])!=null:
								closed=true
								break
						assert_true(closed,"%s width %d yaw %d wall %d: admitted roof exposes native gable" % [family,width,yaw,wall_side])
					assert_eq(admitted,1,"Exactly one complete native hand faces outward")


func test_short_or_partial_wall_does_not_claim_a_complete_roof_end() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var recipe := program.recipe(&"roof.partial.gable.orange.4.positive")
	var origin := Vector3i(4,3,-7)
	for yaw in 4:
		var unit := FabricUnit.new(&"roof",recipe.recipe_id,origin,yaw)
		for grid in [_backing_grid(origin,yaw,4,1,1,4),_backing_grid(origin,yaw,4,1,2,3)]:
			assert_false(WarrenSpatialFabricCompiler._half_gable_faces_wall(grid,unit,recipe),"Incomplete backing cannot decide the gable's orientation")


func _backing_grid(origin: Vector3i, yaw: int, width: int, side: int, bands: int, covered: int) -> WarrenSpatialGrid:
	var grid := WarrenSpatialGrid.new(Vector3i(-8,0,-18),Vector3i(25,9,25))
	var cells: Array[Vector3i] = []
	for x in mini(width,covered):
		for y in bands:
			cells.append(FabricRecipe.transform_cell(Vector3i(x,y,side),origin,yaw))
	var transaction := grid.begin_transaction(&"wall")
	assert_true(transaction.assign_use(cells,WarrenSpatialGrid.Use.PRIVATE_VOLUME,&"upper-room"))
	assert_true(transaction.commit())
	return grid
