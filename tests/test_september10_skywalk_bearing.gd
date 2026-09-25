extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_photographed_skywalk_has_a_real_lower_bearing_at_its_free_end() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september10-skywalk-source.txt"), program)
	var plan := spatial.compiled_fabric_cache()
	var end := plan.unit(&"spatial.fabric.spatial.maze_bridge_end.00.01.room00")
	assert_not_null(end)
	if end == null: return
	var payload := SettlementFabricAssembler.payload(plan)
	# This end is separated from its lower house by the latter's one-band
	# roof reservation. Neither that empty reservation nor the bridge that
	# this end must support can supply its missing vertical load path.
	var count := 0
	for unit: FabricUnit in plan.units:
		if not String(unit.stable_id).begins_with(String(end.stable_id) + "/ground-frame/"): continue
		var recipe := plan.recipe(unit.recipe_id)
		var faces := PackedVector3Array()
		for placement: Dictionary in recipe.placements:
			var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
			for piece: EnvironmentVisualPiece in visual.pieces:
				faces.append_array(unit.transform() * (placement.transform as Transform3D) * piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh))
		var low := INF
		var high := -INF
		for vertex: Vector3 in faces:
			low = minf(low, vertex.y)
			high = maxf(high, vertex.y)
		assert_almost_eq(high - low, 1.5, .002, "One complete native course closes the reserved band")
		var center := (unit.transform() * recipe.local_bounds).get_center()
		var contacts := [false, false]
		for asset: StringName in payload.batches:
			var batch: Dictionary = payload.batches[asset]
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			for index in batch.ids.size():
				if String(batch.ids[index]).contains("/ground-frame/"): continue
				var pose: Transform3D = batch.transforms[index]
				var bounds := pose * catalog.descriptor(asset).measured_aabb
				if center.x < bounds.position.x or center.x > bounds.end.x or center.z < bounds.position.z or center.z > bounds.end.z: continue
				for piece: EnvironmentVisualPiece in visual.pieces:
					var other_faces := pose * piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh)
					for sample in 2:
						var point := Vector3(center.x, low if sample == 0 else high, center.z)
						for face in range(0, other_faces.size(), 3):
							if Geometry3D.segment_intersects_triangle(point + Vector3.DOWN * .002, point + Vector3.UP * (.17 if sample == 0 else .002), other_faces[face], other_faces[face+1], other_faces[face+2]) != null:
								contacts[sample] = true
		assert_true(contacts[0], "The lower end meets an actual native ceiling/roof panel")
		assert_true(contacts[1], "The upper end meets the actual endpoint floor")
		count += 1
	assert_eq(count, 4, "The unsupported endpoint needs its complete corner frame")
	assert_eq(WarrenSpatialFabricCompiler.validation_errors(plan), PackedStringArray())
