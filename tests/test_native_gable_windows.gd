extends "res://tests/test_pure_village_cross_roof.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")


func test_round_gable_glazing_clears_host_timber_and_roof_at_every_end() -> void:
	for dimensions in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 3)]:
		var house := House.instantiate(dimensions.x, dimensions.y)
		add_child(house)
		var triangles := _triangles(house, false)
		var details := House.gable_details(House.derive(dimensions.x, dimensions.y))
		assert_eq(details.size(), 4)
		for part in details:
			var window: Node3D = (
				load("res://assets/PureVillage/Models/Architecture/WindowSolo_6.glb").instantiate()
			)
			add_child(window)
			window.transform = part.transform
			var checked := 0
			var blocked := 0
			for mesh: MeshInstance3D in window.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					if not mesh.get_active_material(surface).resource_name.to_lower().contains(
						"glass_out"
					):
						continue
					# GLB primitives may share a vertex buffer. Only indexed exterior
					# glazing is an exterior visibility obligation; Glass_In faces
					# the solid backing of this authored surface-mounted window.
					var arrays := mesh.mesh.surface_get_arrays(surface)
					var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					for index: int in indices:
						var vertex := positions[index]
						var at := mesh.global_transform * vertex
						checked += 1
						if _hit(triangles, at + window.basis.z * .005, at + window.basis.z * 2):
							blocked += 1
			assert_gt(checked, 0)
			assert_eq(blocked, 0, "Gable glass must not be crossed by a host beam or verge")
			window.free()
		house.free()


func test_runtime_reflection_preserves_shape_with_positive_instance_winding() -> void:
	var compiler = preload(
		"res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd"
	)
	var catalog := EnvironmentCatalog.load_default()
	var source := catalog.descriptor(&"pure_village.native.roof_base_30x30_1")
	var mirrored := catalog.descriptor(&"pure_village.native.roof_base_30x30_1.mirror_x")
	assert_not_null(mirrored)
	if mirrored == null:
		return
	var source_visual: EnvironmentVisual = load(source.visual_path)
	var mirrored_visual: EnvironmentVisual = load(mirrored.visual_path)
	var original_pose := Transform3D(
		Basis(Vector3.UP, .7).scaled_local(Vector3(-2, 2, 2)), Vector3(12, 7, -3)
	)
	var canonical: Dictionary = compiler.placement("Roof_Base_30x30_1", original_pose)
	assert_gt(canonical.transform.basis.determinant(), 0.0)
	var original_points := {}
	for point in source_visual.pieces[0].mesh.get_faces():
		var at: Vector3 = original_pose * point
		original_points[Vector3i((at * 10000).round())] = true
	var reflected_points := {}
	for point in mirrored_visual.pieces[0].mesh.get_faces():
		var at: Vector3 = canonical.transform * point
		reflected_points[Vector3i((at * 10000).round())] = true
	assert_eq(original_points, reflected_points, "Baking reflection must preserve world geometry")
