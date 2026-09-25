extends GutTest

func test_photographed_stone_inside_corner_closes_at_the_wall_ends() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for turn in 4:
		var plan := SettlementFabricPlan.new(&"september10.stone-corner")
		plan.set_asset_visual_bounds(program.asset_visual_bounds)
		for id: StringName in [&"room.tower.base.rock", &"room.tower.base.rock.closed", &"room.row.base.blue.closed"]:
			plan.register_recipe(program.recipe(id))
		var a := FabricUnit.new(&"a",&"room.tower.base.rock",Vector3i(6,0,-1),3)
		a.suppressed_placement_ids.assign([&"west"])
		var b := FabricUnit.new(&"b",&"room.tower.base.rock.closed",Vector3i(8,0,-3),3)
		b.suppressed_placement_ids.assign([&"south"])
		var c := FabricUnit.new(&"c",&"room.row.base.blue.closed",Vector3i(6,0,-4),3)
		c.suppressed_placement_ids.assign([&"back.1",&"east.0"])
		for unit: FabricUnit in [a,b,c]:
			unit.lattice_origin = FabricRecipe.transform_cell(unit.lattice_origin,Vector3i.ZERO,turn)
			unit.yaw_quarters = posmod(unit.yaw_quarters+turn,4)
			plan.append_constructed_unit(unit)
		assert_true(plan.finish_construction())
		var inverse := Transform3D(Basis(Vector3.UP,-turn*PI*0.5),Vector3.ZERO)
		var faces := PackedVector3Array()
		for placement: Dictionary in plan.expanded_placements():
			var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
			for piece: EnvironmentVisualPiece in visual.pieces:
				faces.append_array(inverse*placement.transform*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
		for y in [0.4,1.0,1.6,2.2,2.8]:
			var corner := Vector3(11.25,y,-3.75)
			var closed := false
			for i in range(0,faces.size(),3):
				if Geometry3D.segment_intersects_triangle(corner+Vector3(.1,0,.1),corner-Vector3(.35,0,.35),faces[i],faces[i+1],faces[i+2]) != null:
					closed = true
					break
			assert_true(closed,"The wall ends must meet a finished corner, not expose a deep rear pocket")

func test_doorway_rear_recess_meets_its_return_wall_in_every_orientation() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for turn in 4:
		var plan := SettlementFabricPlan.new(&"september10.door-return")
		var recipe := program.recipe(&"room.tower.base.orange")
		plan.set_asset_visual_bounds(program.asset_visual_bounds)
		plan.register_recipe(recipe)
		var unit := FabricUnit.new(&"room", recipe.recipe_id, Vector3i.ZERO, turn)
		plan.append_constructed_unit(unit)
		assert_true(plan.finish_construction())
		var faces := PackedVector3Array()
		var door := Transform3D.IDENTITY
		for placement: Dictionary in plan.expanded_placements():
			if not String(placement.asset_id).begins_with("sfv.fabric.wall."): continue
			if placement.asset_id == SettlementFabricProgram.WOOD_DOOR_CLOSED:
				door = placement.transform
			var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
			for piece: EnvironmentVisualPiece in visual.pieces:
				faces.append_array(placement.transform * piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh))
		for hand in [-1.0,1.0]:
			for y in [0.4,1.0,1.6,2.2,2.8]:
				var a := door * Vector3(hand*1.55,y,-0.53)
				var b := door * Vector3(hand*0.9,y,-0.53)
				var closed := false
				for i in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2]) != null:
						closed = true
						break
				assert_true(closed,"The native doorway rear recess must meet its return: turn %d hand %d y %.1f" % [turn,hand,y])

func test_closed_door_housing_finishes_both_sides_of_the_projecting_frame() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for suffix in ["", ".mirror_x", ".course_open", ".mirror_x.course_open"]:
		var asset := StringName("sfv.fabric.wall.wood.door.closed.001" + suffix)
		var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
		var faces := PackedVector3Array()
		for piece: EnvironmentVisualPiece in visual.pieces:
			faces.append_array(piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh))
		for hand in [-1.0, 1.0]:
			for y in [0.4, 1.5, 2.8]:
				for z in [-0.45, 0.0, 0.3]:
					var closed := false
					for i in range(0, faces.size(), 3):
						if Geometry3D.segment_intersects_triangle(Vector3(hand*1.6,y,z), Vector3(hand*1.3,y,z), faces[i], faces[i+1], faces[i+2]) != null:
							closed = true
							break
					assert_true(closed, "%s hand %d y %.1f z %.2f: native frame side must close its projecting housing" % [asset,hand,y,z])

func test_door_housing_retains_native_bounds_and_central_doorwork() -> void:
	var source_root: Node = load("res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Door/SFV_Door_Wall_Wooden_001_1.fbx").instantiate()
	var source := EnvironmentBakeGeometry.merge_pieces(source_root, Transform3D.IDENTITY)
	var catalog := EnvironmentCatalog.load_default()
	var visual: EnvironmentVisual = load(catalog.descriptor(SettlementFabricProgram.WOOD_DOOR_CLOSED).visual_path)
	var vertices := PackedVector3Array()
	for piece: EnvironmentVisualPiece in visual.pieces:
		vertices.append_array(piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh))
	var box := source.get_aabb().grow(0.00002)
	var contained := true
	for vertex: Vector3 in vertices: contained = contained and box.has_point(vertex)
	assert_true(contained, "The complete native housing must stay inside the original door envelope")
	var original := _central_door_triangles(EnvironmentBakeGeometry.triangle_faces(source))
	var finished := _central_door_triangles(vertices)
	assert_gt(original.size(), 100, "Check actual leaf, hinges and central arch triangles")
	var preserved := true
	for key: String in original: preserved = preserved and finished.has(key)
	assert_true(preserved, "Finishing the end strips must preserve the central authored door triangles")
	source_root.free()

func _central_door_triangles(faces: PackedVector3Array) -> Dictionary:
	var result := {}
	for i in range(0, faces.size(), 3):
		var keys := PackedStringArray()
		for j in 3:
			var vertex := faces[i+j]
			# The authored leaf and arch lie inside |X| < 0.80 m. The old
			# 1.30 m window also included the housing flanks, replaced by P37.
			if absf(vertex.x) >= 0.85: break
			keys.append("%.5f/%.5f/%.5f" % [vertex.x,vertex.y,vertex.z])
		if keys.size() != 3: continue
		keys.sort()
		result[";".join(keys)] = true
	return result
