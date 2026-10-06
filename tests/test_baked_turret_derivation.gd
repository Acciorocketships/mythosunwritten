extends GutTest


func test_baked_turret_house_preserves_source_bounds_material_bindings_and_collision() -> void:
	var original: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/native_house16c_derivation.json")
	)
	var baked: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://terrain/environment/grammar/house16c.json")
	)
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	assert_eq(baked.parts.size(), original.parts.size())
	for index in baked.parts.size():
		var part: Dictionary = baked.parts[index]
		var id := StringName(part.asset_id)
		var descriptor := catalog.descriptor(id)
		assert_not_null(descriptor, String(id))
		if descriptor == null:
			continue
		assert_gt(descriptor.collision_piece_count, 0, "Every native part keeps physical geometry")
		assert_true(cache.prepare([id]))
		var visual := cache.visual(id)
		var instance: Node3D = (
			load("res://assets/PureVillage/Models/Architecture/" + part.module + ".glb")
			. instantiate()
		)
		add_child(instance)
		instance.transform = _pose(original.parts[index].matrix)
		var expected := AABB()
		var first := true
		for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
			var box := mesh.global_transform * mesh.get_aabb()
			expected = box if first else expected.merge(box)
			first = false
		var actual := _pose(part.matrix) * descriptor.measured_aabb
		assert_almost_eq(actual.position, expected.position, Vector3.ONE * .0002)
		assert_almost_eq(actual.size, expected.size, Vector3.ONE * .0002)
		var names: Dictionary = {}
		for row: Array in part.materials:
			for name: String in row:
				names[name] = true
		var actual_names: Dictionary = {}
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				actual_names[piece.mesh.surface_get_material(surface).resource_name] = true
		assert_eq(actual_names, names, "All authored surface materials survive baking")
		assert_gt(
			_pose(part.matrix).basis.determinant(),
			0.0,
			"Reflections are baked, not negative renderer transforms"
		)
		instance.free()


func _pose(m: Array) -> Transform3D:
	return Transform3D(
		Basis(Vector3(m[0], m[1], m[2]), Vector3(m[4], m[5], m[6]), Vector3(m[8], m[9], m[10])),
		Vector3(m[12], m[13], m[14])
	)
