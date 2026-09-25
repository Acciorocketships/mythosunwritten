extends GutTest

func test_half_storey_skywalks_join_the_inhabited_mass_with_complete_courses() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"),program)
	var plan := spatial.compiled_fabric_cache()
	var courses: Array[FabricUnit] = []
	for unit: FabricUnit in plan.units:
		if plan.recipe(unit.recipe_id).has_tag(&"grounded_masonry_course"):
			courses.append(unit)
	assert_eq(courses.size(),2,"Both complete half-storey endpoint gaps need integrated masonry instead of a planter on struts")
	assert_eq(WarrenSpatialFabricCompiler.validation_errors(plan),PackedStringArray())
	_check_contacts_and_connectivity(spatial,plan,courses)


func _check_contacts_and_connectivity(spatial: WarrenSpatialPlan,
		plan: SettlementFabricPlan, courses: Array[FabricUnit]) -> void:
	var catalog := EnvironmentCatalog.load_default()
	var payload := SettlementFabricAssembler.payload(plan)
	var body: Dictionary = {}
	var room_list: Array[WarrenRoomStamp] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			room_list.append(room)
			for cell: Vector3i in room.private_cells: body[cell] = true
	for course: FabricUnit in courses:
		var recipe := plan.recipe(course.recipe_id)
		var wall_faces := PackedVector3Array()
		var adjacent_faces := PackedVector3Array()
		for asset: StringName in payload.batches:
			var batch: Dictionary = payload.batches[asset]
			for index in batch.ids.size():
				var owner := StringName(String(batch.ids[index]).get_slice("/",0))
				if course.visual_seam_ids.has(owner):
					adjacent_faces.append_array(_faces(catalog,asset,batch.transforms[index]))
		for placement: Dictionary in recipe.placements:
			var faces := _faces(catalog,placement.asset_id,course.transform()*placement.transform)
			wall_faces.append_array(faces)
			var low := Vector3(INF,INF,INF)
			var high := Vector3(-INF,-INF,-INF)
			for point: Vector3 in faces:
				low = low.min(point)
				high = high.max(point)
			assert_almost_eq(high.y-low.y,1.5,.002,"The complete native stock fills one band")
			for height: float in [low.y,high.y]:
				var point := Vector3((low.x+high.x)*.5,height,(low.z+high.z)*.5)
				assert_true(_hits(adjacent_faces,point-Vector3.UP*.002,point+Vector3.UP*.002),
					"Masonry wall %s end at %s meets an actual neighboring slab/floor" % [placement.id,point])
		var center := (course.transform()*recipe.local_bounds).get_center()
		for direction: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
			assert_true(_hits(wall_faces,center,center+direction*12.0),
				"The support course closes each of its four sides with native masonry")
		for local: Vector3i in recipe.occluder_cells:
			body[FabricRecipe.transform_cell(local,course.lattice_origin,course.yaw_quarters)] = true
		for unit: FabricUnit in plan.units:
			if not plan.recipe(unit.recipe_id).has_tag(&"flat_roof_garden"): continue
			assert_false(WarrenSpatialFabricCompiler._aabb_overlaps_volume(
				course.bounds,unit.bounds),"The closed support course cannot retain an inaccessible planter")
	var first_span: WarrenRoomStamp = null
	for room: WarrenRoomStamp in room_list:
		if room.stable_id == &"spatial.maze_bridge.00.room00": first_span = room
	assert_not_null(first_span)
	if first_span == null: return
	var visited := {first_span.private_cells[0]:true}
	var queue: Array[Vector3i] = [first_span.private_cells[0]]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
			var next := cell+direction
			if body.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	var connected_rooms := 0
	for room: WarrenRoomStamp in room_list:
		connected_rooms += int(visited.has(room.private_cells[0]))
		if String(room.stable_id).begins_with("spatial.maze_bridge."):
			assert_true(visited.has(room.private_cells[0]),"Both occupied spans belong to the same constructed mass")
	assert_eq(connected_rooms,27,"The warren becomes one connected group; the separate roofed house remains freestanding")


func _faces(catalog: EnvironmentCatalog, asset: StringName, pose: Transform3D) -> PackedVector3Array:
	var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
	var out := PackedVector3Array()
	for piece: EnvironmentVisualPiece in visual.pieces:
		out.append_array(pose*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
	return out


func _hits(faces: PackedVector3Array, start: Vector3, end: Vector3) -> bool:
	for index in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(start,end,faces[index],faces[index+1],faces[index+2]) != null:
			return true
	return false


func test_masonry_course_refuses_missing_lower_bearing_and_protected_air() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"),program)
	var courses := WarrenSpatialFabricCompiler._ground_bearing_masonry_courses(spatial,program)
	assert_eq(courses.size(),2)
	if courses.is_empty(): return
	var gap := (courses[0].cells as Array[Vector3i])[0]
	var lower := gap+Vector3i.DOWN
	var base: WarrenRoomStamp = null
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.private_cells.has(lower): base = room
	assert_not_null(base)
	if base == null: return
	var original_cells := base.private_cells.duplicate()
	base.private_cells.erase(lower)
	assert_eq(WarrenSpatialFabricCompiler._ground_bearing_masonry_courses(spatial,program).size(),1,
		"One missing real lower ceiling must refuse the complete course")
	base.private_cells.assign(original_cells)
	for use: int in [WarrenSpatialGrid.Use.PUBLIC_AIR,WarrenSpatialGrid.Use.DAYLIGHT_AIR]:
		var grid := WarrenSpatialGrid.new(spatial.grid.minimum,spatial.grid.size)
		var tx := grid.begin_transaction(&"protected")
		assert_true(tx.assign_use([gap] as Array[Vector3i],use,&"route"))
		assert_true(tx.commit())
		spatial.grid = grid
		assert_eq(WarrenSpatialFabricCompiler._ground_bearing_masonry_courses(spatial,program).size(),1,
			"A complete upper and lower room cannot erase protected air")


func test_native_masonry_course_has_no_open_corner_rays() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for kind: String in ["tower","slim","row","square","long"]:
		var recipe := program.recipe(StringName("foundation.masonry.course."+kind))
		assert_not_null(recipe)
		if recipe == null: continue
		var faces := PackedVector3Array()
		for placement: Dictionary in recipe.placements:
			faces.append_array(_faces(catalog,placement.asset_id,placement.transform))
		var center := recipe.local_bounds.get_center()
		var misses: Array[String] = []
		for height: float in [-.14,.2,.6,1.0,1.32]:
			var point := Vector3(center.x,height,center.z)
			for angle in range(360):
				var direction := Vector3(sin(deg_to_rad(float(angle))),0.0,cos(deg_to_rad(float(angle))))
				if not _hits(faces,point,point+direction*24.0):
					misses.append("%d/%s" % [angle,height])
		assert_eq(misses,[] as Array[String],"Actual native %s wall triangles must close all face and corner joints" % kind)

		# Opposite-face rays span the actual shell from outside. A ray from the
		# centre can miss a near corner hole by hitting a distant wall behind it.
		var footprint := FabricRecipe._bounds_for_cells(recipe.occluder_cells)
		var openings: Array[String] = []
		for height: float in [-.14,.2,.6,1.0,1.32]:
			for step in range(1,100):
				var fraction := float(step)/100.0
				for along_x: bool in [true,false]:
					var start := Vector3(footprint.position.x-1.0,height,
						lerpf(footprint.position.z,footprint.end.z,fraction)) if along_x else Vector3(
						lerpf(footprint.position.x,footprint.end.x,fraction),height,footprint.position.z-1.0)
					var end := start+Vector3(footprint.size.x+2.0,0,0) if along_x else start+Vector3(0,0,footprint.size.z+2.0)
					if not _hits(faces,start,end): openings.append("%s/%d/%s" % [height,step,along_x])
		assert_eq(openings,[] as Array[String],"Every measured %s shell cross-section must be closed" % kind)

		var face_openings: Array[String] = []
		for height: float in [-.14,.2,.6,1.0,1.32]:
			for step in range(1,100):
				var fraction := float(step)/100.0
				for outward: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
					var point := Vector3(footprint.end.x if outward.x > 0 else footprint.position.x,
						height,lerpf(footprint.position.z,footprint.end.z,fraction)) if outward.x != 0 else Vector3(
						lerpf(footprint.position.x,footprint.end.x,fraction),height,
						footprint.end.z if outward.z > 0 else footprint.position.z)
					if not _hits(faces,point-outward*.75,point+outward*.1):
						face_openings.append("%s/%d/%s" % [height,step,outward])
		assert_eq(face_openings,[] as Array[String],"The near %s face must close independently of the opposite wall" % kind)
