extends GutTest
const PATH := "res://terrain/environment/grammar/materials/planks.tres"


func _source() -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "Panel"
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	add_child_autofree(root)
	return root


func test_binding_changes_only_requested_instance_material_not_geometry() -> void:
	var root := _source()
	var panel: MeshInstance3D = root.get_node("Panel")
	var source := panel.mesh
	var other := MeshInstance3D.new()
	other.mesh = source
	root.add_child(other)
	var bounds := panel.get_aabb()
	assert_true(
		EnvironmentBakeGeometry.bind_materials(
			root, [{"path": "Panel", "surface": 0, "material": PATH}]
		)
	)
	assert_eq(panel.get_active_material(0), load(PATH))
	assert_null(other.get_active_material(0))
	assert_eq(panel.mesh, source)
	assert_eq(panel.get_aabb(), bounds)


func test_invalid_or_duplicate_binding_is_atomic() -> void:
	for invalid: Dictionary in [
		{"path": "missing", "surface": 0, "material": PATH},
		{"path": "Panel", "surface": 4, "material": PATH},
		{"path": "Panel", "surface": 0, "material": PATH}
	]:
		var root := _source()
		assert_false(
			EnvironmentBakeGeometry.bind_materials(
				root, [{"path": "Panel", "surface": 0, "material": PATH}, invalid]
			)
		)
		assert_null((root.get_node("Panel") as MeshInstance3D).get_active_material(0))
