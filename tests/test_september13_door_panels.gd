extends GutTest

func _faces(asset: StringName) -> PackedVector3Array:
	var visual: EnvironmentVisual = load(EnvironmentCatalog.load_default().descriptor(asset).visual_path)
	var out := PackedVector3Array()
	for piece: EnvironmentVisualPiece in visual.pieces:
		out.append_array(piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
	return out

func _first_hit(faces: PackedVector3Array, a: Vector3, b: Vector3) -> float:
	var distance := INF
	for index in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(a,b,faces[index],faces[index+1],faces[index+2])
		if hit != null: distance = minf(distance,a.distance_to(hit))
	return distance

func test_door_side_housing_keeps_native_wall_relief_instead_of_a_protruding_flat_strip() -> void:
	# Match actual native horizontal wall stock at full normal depth. Only its
	# width fits the doorway's side; relief must agree with neighboring walls.
	var stock_node: Node = load("res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Walls/SFV_Wall_Wooden_M_005.fbx").instantiate()
	var stock := EnvironmentBakeGeometry.merge_pieces(stock_node,Transform3D.IDENTITY)
	stock_node.free()
	var box := EnvironmentCatalog.load_default().descriptor(SettlementFabricProgram.WOOD_DOOR_CLOSED).measured_aabb
	var stock_box := stock.get_aabb()
	for suffix: String in ["", ".mirror_x", ".course_open", ".mirror_x.course_open"]:
		var faces := _faces(StringName(String(SettlementFabricProgram.WOOD_DOOR_CLOSED)+suffix))
		for hand: float in [-1,1]:
			var normal := Vector3.RIGHT*hand
			var basis := Basis(Vector3.UP.cross(normal)*box.size.z/stock_box.size.x,Vector3.UP*box.size.y/stock_box.size.y,normal)
			var pose := Transform3D(basis,Vector3(hand*1.5,box.position.y,box.get_center().z)-basis*Vector3(stock_box.get_center().x,stock_box.position.y,stock_box.end.z))
			var reflected := EnvironmentBakeGeometry.transform_mesh(EnvironmentBakeGeometry.mirror_axis(stock,Vector3.AXIS_X),Transform3D(Basis.IDENTITY,Vector3(2*stock_box.get_center().x,0,0))) if hand < 0 else stock
			var expected := pose*EnvironmentBakeGeometry.triangle_faces(reflected)
			for y: float in [.6,1.2,1.8]:
				for z: float in [-.25,0,.25,.45]:
					var a := Vector3(hand*1.6,y,z)
					var b := Vector3(hand*.85,y,z)
					assert_almost_eq(_first_hit(faces,a,b),_first_hit(expected,a,b),.0002,"Housing plaster and timber must retain native depth: %s hand %d y %.1f z %.2f"%[suffix,hand,y,z])

func test_replacement_housing_does_not_open_previously_closed_room_sightlines() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var plan := SettlementFabricPlan.new(&"housing-closure")
	plan.set_asset_visual_bounds(program.asset_visual_bounds)
	var recipe := program.recipe(&"room.tower.base.orange")
	plan.register_recipe(recipe)
	plan.append_constructed_unit(FabricUnit.new(&"room",recipe.recipe_id,Vector3i.ZERO,0))
	assert_true(plan.finish_construction())
	var old_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/39-door-panels/before-assets.json"))
	var before := PackedVector3Array()
	var after := PackedVector3Array()
	for entry: Dictionary in plan.expanded_placements():
		for phase in 2:
			var visual: EnvironmentVisual = load(old_assets[str(entry.asset_id)]) if phase == 0 and old_assets.has(str(entry.asset_id)) else load(catalog.descriptor(entry.asset_id).visual_path)
			for piece: EnvironmentVisualPiece in visual.pieces:
				var faces: PackedVector3Array = entry.transform*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh)
				if phase == 0: before.append_array(faces)
				else: after.append_array(faces)
	var old_blocked := 0
	var newly_open := []
	# Interior-to-exterior rays cross the actual joined shell. A previous probe
	# at X=+/-1.49 instead grazed outside the native recessed side profile.
	# It reported 26 exterior silhouette changes, not holes into the room.
	for index in 181:
		var angle := deg_to_rad(lerpf(-60,60,float(index)/180))
		for level in 15:
			var y := lerpf(.1,2.9,float(level)/14)
			var a := Vector3(0,y,0)
			var b := a+Vector3(0,0,5).rotated(Vector3.UP,angle)
			if _first_hit(before,a,b) == INF: continue
			old_blocked += 1
			if _first_hit(after,a,b) == INF: newly_open.append(Vector2(index,y))
	assert_gt(old_blocked,2000,"Sample the actual formerly closed room around the doorway and both joined corners")
	assert_eq(newly_open.size(),0,"No new through-view across the joined shell: %s"%str(newly_open))
