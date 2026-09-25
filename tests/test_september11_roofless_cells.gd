extends GutTest

const PHOTO_ROOM := &"spatial.parcel.maze.bridge.00.end.1.lower.part01.room00"

func test_photographed_slab_is_only_the_borne_column_beneath_the_upper_house() -> void:
	var rooms: Array[Dictionary] = []
	if OS.get_environment("STORY_QA_ROOFLESS_ORIGINAL") == "1":
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-11-manual/05-floating/baseline-payload.bin",FileAccess.READ).get_var()
		rooms.assign(data.rooms)
	else:
		var spatial := _spatial()
		for building: WarrenBuildingVolume in spatial.buildings:
			for room: WarrenRoomStamp in building.room_records:
				rooms.append({"id":room.stable_id,"cells":room.private_cells})
	var target: Dictionary = {}
	var occupied: Dictionary = {}
	for room: Dictionary in rooms:
		if StringName(room.id) == PHOTO_ROOM:
			target = room
		for cell: Vector3i in room.cells:
			occupied[cell] = room.id
	assert_false(target.is_empty())
	if target.is_empty(): return
	var bottom := 2147483647
	var top := -2147483648
	for cell: Vector3i in target.cells:
		bottom = mini(bottom,cell.y)
		top = maxi(top,cell.y)
	for cell: Vector3i in target.cells:
		if cell.y != bottom: continue
		assert_true(occupied.has(cell-Vector3i.UP),
			"Photographed slab column %s must stand on an actual lower room" % cell)
		var carries_upper := false
		for other: Vector3i in occupied:
			if other.x == cell.x and other.z == cell.z and other.y > top:
				carries_upper = true
				break
		assert_true(carries_upper,
			"Flat column %s is useful bearing beneath the upper house, not an unused roofless projection" % cell)


func test_photographed_remaining_slab_has_complete_native_closure() -> void:
	var spatial := _spatial()
	var plan := spatial.compiled_fabric_cache()
	var roof := plan.unit(StringName("spatial.roof.%s" % PHOTO_ROOM))
	assert_not_null(roof)
	if roof == null: return
	var recipe := plan.recipe(roof.recipe_id)
	var faces := PackedVector3Array()
	var catalog := EnvironmentCatalog.load_default()
	for placement: Dictionary in recipe.placements:
		var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
		for piece: EnvironmentVisualPiece in visual.pieces:
			faces.append_array(roof.transform()*placement.transform*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
	var checked := 0
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.stable_id != PHOTO_ROOM: continue
			var box := FabricRecipe._bounds_for_cells(room.private_cells)
			for x in 5:
				for z in 5:
					var point := Vector3(lerpf(box.position.x+.05,box.end.x-.05,float(x)/4.0),
						box.end.y,lerpf(box.position.z+.05,box.end.z-.05,float(z)/4.0))
					var hit := false
					for index in range(0,faces.size(),3):
						if Geometry3D.segment_intersects_triangle(point-Vector3.UP*.3,point+Vector3.UP*.3,
							faces[index],faces[index+1],faces[index+2]) != null:
							hit = true
							break
					assert_true(hit,"Actual native slab closes sample %s" % point)
					checked += 1
	assert_eq(checked,25)
	assert_eq(int(plan.audit.modular_box_roofless_house_count),0)
	assert_eq(int(plan.audit.maze_unclaimed_platform_cap_count),0)


func _spatial() -> WarrenSpatialPlan:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	return frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"),program)
