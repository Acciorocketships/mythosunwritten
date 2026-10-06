extends GutTest
const Oracle = preload("res://tests/fixtures/native_prefab_reconstruction.gd")


func test_house16c_modular_derivation_reconstructs_every_authored_mesh_and_material() -> void:
	_assert_reconstruction("res://tests/fixtures/native_house16c_derivation.json")


func test_renamed_finial_preserves_the_complete_house11c() -> void:
	_assert_reconstruction("res://tests/fixtures/native_house11c_derivation.json")


func test_native_storefronts_keep_their_door_leaves_and_glazing() -> void:
	for fixture: String in [
		"res://tests/fixtures/native_house6b_derivation.json",
		"res://tests/fixtures/native_streethouse8c_derivation.json"
	]:
		_assert_reconstruction(fixture)


func _assert_reconstruction(fixture: String) -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var reference: Node3D = load("res://" + String(doc.source).trim_prefix("res://")).instantiate()
	add_child_autofree(reference)
	var generated := Oracle.instantiate(doc, reference)
	add_child_autofree(generated)
	var remaining := reference.find_children("*", "MeshInstance3D", true, false)
	var actual := generated.find_children("*", "MeshInstance3D", true, false)
	assert_eq(
		actual.size(),
		remaining.size(),
		"No dropped or duplicated mesh, including stairs and moving door leaves"
	)
	for mesh: MeshInstance3D in actual:
		var match_index := -1
		for index in remaining.size():
			var other: MeshInstance3D = remaining[index]
			if mesh.mesh.get_surface_count() != other.mesh.get_surface_count():
				continue
			if not (mesh.global_transform * mesh.get_aabb()).is_equal_approx(
				other.global_transform * other.get_aabb()
			):
				continue
			match_index = index
			break
		assert_gte(match_index, 0, "Authored world pose: " + String(mesh.name))
		if match_index < 0:
			continue
		var expected: MeshInstance3D = remaining.pop_at(match_index)
		for surface in mesh.mesh.get_surface_count():
			assert_eq(mesh.get_active_material(surface), expected.get_active_material(surface))
			var a := mesh.mesh.surface_get_arrays(surface)
			var b := expected.mesh.surface_get_arrays(surface)
			assert_eq(a[Mesh.ARRAY_INDEX], b[Mesh.ARRAY_INDEX])
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var expected_vertices: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
			assert_eq(vertices.size(), expected_vertices.size())
			var error := 0.0
			for i in mini(vertices.size(), expected_vertices.size()):
				error = maxf(
					error,
					(mesh.global_transform * vertices[i]).distance_to(
						expected.global_transform * expected_vertices[i]
					)
				)
			assert_lt(error, .0002, "Every original vertex retains its world position")
	assert_eq(remaining.size(), 0, "Entire prefab is represented by modular stock")
