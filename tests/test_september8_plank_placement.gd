extends GutTest

func test_door_course_top_participates_in_floor_ownership() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var recipe := program.recipe(&"room.slim.base.orange")
	assert_true(recipe.facade_top_assets.has(&"sfv.fabric.wall.wood.door.closed.001"),
		"A doorway's tiny below-datum foot must not exclude its flat course top")

func test_photographed_balcony_and_door_have_no_shared_top_triangles() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var fixture := preload("res://tests/fixtures/frozen_maze_source.gd")
	var plan := fixture.spatial(fixture.read("res://tests/fixtures/september7-manual-source.txt"),program).compiled_fabric_cache()
	var door := {}
	var floor_panel := {}
	for placement: Dictionary in plan.expanded_placements():
		var id := String(placement.stable_id)
		if id.ends_with("spatial.parcel.maze.house.014.part00.room00/front.0"): door=placement
		if id.ends_with("spatial.parcel.maze.house.014.part00.room00/cap.0.0"): floor_panel=placement
	assert_false(door.is_empty())
	assert_false(floor_panel.is_empty())
	if door.is_empty() or floor_panel.is_empty(): return
	var measure := preload("res://tests/test_reported_facade_floor_caps.gd").new()
	var wall_faces := measure._horizontal_faces(catalog,door)
	for cap: Dictionary in plan.wall_cap_surfaces:
		if String(cap.stable_id).begins_with(String(door.stable_id)+"/cap."):
			wall_faces.append_array(measure._payload_faces(cap))
	assert_lt(measure._shared_area(measure._horizontal_faces(catalog,floor_panel),wall_faces),0.00001,
		"The complete photographed door cap, including any retained fragments, has a single surface owner")
	measure.free()

func test_single_floor_module_is_centered_on_its_owned_cell() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cells: Array[Vector3i] = [Vector3i(-3,4,2)]
	var payload := EnvironmentInstancePayload.new()
	SettlementFabricAssembler._append_plank_tiles(payload,cells,PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT)
	var asset := SettlementFabricAssembler.PLANK_SINGLE
	var pose: Transform3D = payload.batches[asset].transforms[0]
	var actual := pose*catalog.descriptor(asset).measured_aabb
	var expected := Vector3(cells[0])*FabricRecipe.CELL_SIZE
	assert_almost_eq(actual.get_center().x,expected.x,0.005,"A singleton has no half-cell lattice phase")
	assert_almost_eq(actual.get_center().z,expected.z,0.005,"The asset pivot correction is independent of the cell centre")

func test_mixed_board_sizes_do_not_overlap_or_expose_half_cell_holes() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cells: Array[Vector3i] = [Vector3i(0,4,0),Vector3i(1,4,0),Vector3i(0,4,1),Vector3i(1,4,1),Vector3i(-1,4,0)]
	var payload := EnvironmentInstancePayload.new()
	SettlementFabricAssembler._append_plank_tiles(payload,cells,PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT)
	var rectangles: Array[Rect2] = []
	for asset: StringName in payload.batches:
		for pose: Transform3D in payload.batches[asset].transforms:
			var bounds := pose*catalog.descriptor(asset).measured_aabb
			rectangles.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
	assert_eq(rectangles.size(),2)
	assert_lt(rectangles[0].intersection(rectangles[1]).get_area(),0.01,
		"A large floor and its neighboring singleton must not share a strip of visible planks")
