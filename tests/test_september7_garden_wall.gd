extends GutTest

func test_roof_clearance_and_wall_enclosure_remain_separate_in_every_direction() -> void:
	for turn in 4:
		var direction := FabricRecipe.transform_cell(Vector3i.RIGHT,Vector3i.ZERO,turn)
		var index := SettlementFabricAssembler.STONE_FACE_DIRECTIONS.find(direction)
		var retained := {Vector3i.ZERO:SettlementFabricAssembler.MAZE_STONE_TAG}
		var solids := {direction:true,Vector3i.UP:true}
		var exposed := SettlementFabricAssembler.exposed_maze_stone_faces(retained,solids,{}, {})
		assert_true(exposed.has(Vector4i(0,0,0,index)),"roof reservations leave a vertical wall")
		var up_index := SettlementFabricAssembler.STONE_FACE_DIRECTIONS.find(Vector3i.UP)
		assert_false(exposed.has(Vector4i(0,0,0,up_index)),"horizontal support ownership is unchanged")
		exposed=SettlementFabricAssembler.exposed_maze_stone_faces(retained,solids,{}, {direction:true})
		assert_false(exposed.has(Vector4i(0,0,0,index)),"an inhabited neighbor closes the seam")

func test_reported_garden_wall_closes_air_above_neighbor_roof() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program)
	var plan := spatial.compiled_fabric_cache()
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(plan)
	for z in [-4,-3]:
		assert_true(transaction.solids.has(Vector3i(6,3,z)),"the neighboring roof keeps its clearance reservation")
		assert_true(transaction.shell.exposed.has(Vector4i(5,3,z,1)),"roof air cannot hide the garden wall")
		assert_eq(transaction.shell.treatments[Vector4i(5,3,z,1)],SettlementFabricAssembler.SkinTreatment.FACADE,"the full retained bank owns a continuous upper facade course")
	assert_false(transaction.shell.exposed.has(Vector4i(5,1,-4,1)),"the neighboring inhabited room already closes the lower seam")
	var payload := SettlementFabricAssembler.terrace_retaining_payload(plan)
	var faces := PackedVector3Array()
	for asset: StringName in payload.batches:
		var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
		for pose: Transform3D in payload.batches[asset].transforms:
			if (pose.origin-Vector3(8,4.5,-5.25)).length()>5.0: continue
			for piece: EnvironmentVisualPiece in visual.pieces:
				for vertex: Vector3 in piece.mesh.get_faces(): faces.append(pose*piece.local_transform*vertex)
	for z in [-6.0,-4.5]:
		for y in [3.2,4.0,5.2,5.85]:
			var closed := false
			for offset in range(0,faces.size(),3):
				if Geometry3D.segment_intersects_triangle(Vector3(8.5,y,z),Vector3(7.5,y,z),faces[offset],faces[offset+1],faces[offset+2]) != null:
					closed=true
					break
			assert_true(closed,"actual wall triangles close the photographed garden at y=%s z=%s" % [y,z])
