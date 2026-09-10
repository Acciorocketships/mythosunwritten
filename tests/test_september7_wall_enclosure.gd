extends GutTest

# The two original room facts at the first photograph's diagonal contact.
# Testing each room alone misses the passage between their recessed skins.
func test_reported_diagonal_room_contact_blocks_the_unintended_slit() -> void:
	for rotation in 4: _assert_joint(false,rotation)

func test_reported_gallery_inside_corner_blocks_the_unintended_slit() -> void:
	for rotation in 4: _assert_joint(true,rotation)

func _assert_joint(concave: bool, rotation: int) -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var plan := SettlementFabricPlan.new(&"september7.diagonal")
	plan.set_asset_visual_bounds(program.asset_visual_bounds)
	for id: StringName in [&"room.slim.base.orange", &"room.row.base.orange"]:
		plan.register_recipe(program.recipe(id))
	var bridge := FabricUnit.new(&"bridge", &"room.slim.base.orange", Vector3i(-4,4,1),2)
	bridge.suppressed_placement_ids.assign([&"north"])
	if concave:
		bridge.lattice_origin = Vector3i(-3,4,-4)
		bridge.yaw_quarters = 0
		bridge.suppressed_placement_ids.assign([&"east.0",&"east.1",&"west.0",&"west.1"])
	var house := FabricUnit.new(&"house", &"room.row.base.orange",Vector3i(-5,4,-3),1)
	house.suppressed_placement_ids.assign([&"back.1",&"east.0",&"front.1"])
	for unit: FabricUnit in [bridge,house]:
		unit.lattice_origin=FabricRecipe.transform_cell(unit.lattice_origin,Vector3i.ZERO,rotation)
		unit.yaw_quarters=posmod(unit.yaw_quarters+rotation,4)
	plan.append_constructed_unit(bridge)
	plan.append_constructed_unit(house)
	assert_true(plan.finish_construction())
	var faces := PackedVector3Array()
	var joint_faces := PackedVector3Array()
	for placement: Dictionary in plan.expanded_placements():
		var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
		for piece: EnvironmentVisualPiece in visual.pieces:
			var pose: Transform3D = Transform3D(Basis(Vector3.UP,-rotation*PI*0.5),Vector3.ZERO) * placement.transform * piece.local_transform
			for vertex: Vector3 in piece.mesh.get_faces():
				faces.append(pose * vertex)
				if String(placement.stable_id).begins_with("facade-joint/"): joint_faces.append(pose*vertex)
	for y in [6.35,7.05,8.65]:
		var corner := Vector3(-6.75,y,-3.75 if concave else -0.75)
		var a := corner + Vector3(-0.45,0,0.45)
		var b := corner + Vector3(0.45,0,-0.45)
		if concave:
			a = corner + Vector3(0.6,0,0.6)
			b = corner - Vector3(0.75,0,0.75)
		var closed := false
		for offset in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(a,b,faces[offset],faces[offset+1],faces[offset+2]) != null:
				closed = true
				break
		assert_true(closed,"the diagonal joint must block the slit at y=%s" % y)

	if concave:
		var rear_camera := Vector3(-5.6326,8.51,-7.9439)
		var photographed_body := Vector3(-7.0037997,7.05,-4.1898333)
		assert_true(_ray_hits(faces,rear_camera,photographed_body),"the side-view slit must also be enclosed")
		var player := Vector2(-6.9,-4.15)
		var distance := INF
		for offset in range(0,joint_faces.size(),3):
			var hits: Array[Vector2] = []
			for edge in 3:
				var a := joint_faces[offset+edge]
				var b := joint_faces[offset+(edge+1)%3]
				if (a.y<6.35)==(b.y<6.35): continue
				var p := a.lerp(b,(6.35-a.y)/(b.y-a.y))
				hits.append(Vector2(p.x,p.z))
			if hits.size()==2:
				distance=minf(distance,player.distance_to(Geometry2D.get_closest_point_to_segment(player,hits[0],hits[1])))
		assert_gte(distance,0.225,"the new return must clear the photographed player's capsule")

func test_reported_stone_step_has_a_supported_return_to_the_diagonal_house() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var source := frozen.read("res://tests/fixtures/september7-manual-source.txt")
	var spatial := frozen.spatial(source,program)
	var plan := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.terrace_retaining_payload(plan)
	var faces := PackedVector3Array()
	for asset: StringName in payload.batches:
		var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
		for pose: Transform3D in payload.batches[asset].transforms:
			if (pose.origin-Vector3(5.5,1.5,-1.5)).length()>5.0: continue
			for piece: EnvironmentVisualPiece in visual.pieces:
				for vertex: Vector3 in piece.mesh.get_faces(): faces.append(pose*piece.local_transform*vertex)
	for y in [1.65,2.25,2.85]:
		var closed := false
		for offset in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(Vector3(4.9,y,-1.5),Vector3(6.0,y,-1.5),faces[offset],faces[offset+1],faces[offset+2])!=null:
				closed=true
				break
		assert_true(closed,"the photographed low masonry notch must join the taller diagonal facade at y=%s" % y)
	for y in [0.35,1.65,2.85]:
		assert_true(_ray_hits(faces,Vector3(4.8,y,-1.2),Vector3(5.7,y,-0.3)),"the room/stone contact must close the complete lower and upper bands")

func _ray_hits(faces: PackedVector3Array,a: Vector3,b: Vector3) -> bool:
	for offset in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(a,b,faces[offset],faces[offset+1],faces[offset+2])!=null: return true
	return false

func test_masonry_return_requires_bearing_and_both_facade_ends_in_every_orientation() -> void:
	for turn in 4:
		var lower := Vector3i.ZERO
		var taller := FabricRecipe.transform_cell(Vector3i(0,1,-1),Vector3i.ZERO,turn)
		var diagonal_house := FabricRecipe.transform_cell(Vector3i(-1,1,1),Vector3i.ZERO,turn)
		var retained := {lower:true,taller:true}
		var rooms := {diagonal_house:true}
		assert_eq(SettlementFabricAssembler.masonry_room_returns(retained,rooms,{}).instance_count,2,"one wall and one house-end joint")
		assert_eq(SettlementFabricAssembler.masonry_room_returns({taller:true},rooms,{}).instance_count,0,"no return without its lower bearing")
		assert_eq(SettlementFabricAssembler.masonry_room_returns(retained,{},{}).instance_count,0,"an ordinary terrace step stays open")
		assert_eq(SettlementFabricAssembler.masonry_room_returns(retained,rooms,{Vector3i.UP:true}).instance_count,0,"an owned walking surface cannot become a return wall")
