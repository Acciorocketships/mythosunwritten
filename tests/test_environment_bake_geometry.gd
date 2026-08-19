extends GutTest

func _box_instance(name: String, position: Vector3, size: Vector3,
		material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	return instance

func test_merge_bakes_transforms_and_combines_shared_material_surfaces() -> void:
	var root := Node3D.new()
	var material := StandardMaterial3D.new()
	root.add_child(_box_instance("B", Vector3(2.0, 0.0, 0.0),
		Vector3.ONE, material))
	root.add_child(_box_instance("A", Vector3.ZERO, Vector3.ONE, material))
	var correction := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.0),
		Vector3.ZERO)
	var merged := EnvironmentBakeGeometry.merge_pieces(root, correction)
	assert_not_null(merged)
	assert_eq(merged.get_surface_count(), 1,
		"instances sharing one material become one draw surface")
	assert_almost_eq(merged.get_aabb().position.x, -1.0, 0.001)
	assert_almost_eq(merged.get_aabb().size.x, 6.0, 0.001,
		"wrapper transforms and the pack correction are baked into vertices")
	root.free()

func test_merge_keeps_distinct_materials_as_distinct_surfaces() -> void:
	var root := Node3D.new()
	root.add_child(_box_instance("A", Vector3.ZERO, Vector3.ONE,
		StandardMaterial3D.new()))
	root.add_child(_box_instance("B", Vector3.RIGHT * 2.0, Vector3.ONE,
		StandardMaterial3D.new()))
	var merged := EnvironmentBakeGeometry.merge_pieces(root,
		Transform3D.IDENTITY)
	assert_not_null(merged)
	assert_eq(merged.get_surface_count(), 2)
	root.free()

func test_merge_can_exclude_a_reviewed_source_mesh_by_stable_path() -> void:
	var root := Node3D.new()
	var material := StandardMaterial3D.new()
	root.add_child(_box_instance("Keep", Vector3.ZERO, Vector3.ONE,
		material))
	root.add_child(_box_instance("ClosedDoor", Vector3.RIGHT * 10.0,
		Vector3.ONE, material))
	var merged := EnvironmentBakeGeometry.merge_pieces(root,
		Transform3D.IDENTITY, ["ClosedDoor"])
	assert_not_null(merged)
	assert_almost_eq(merged.get_aabb().position.x, -0.5, 0.001)
	assert_almost_eq(merged.get_aabb().size.x, 1.0, 0.001,
		"excluded leaves affect neither visual geometry nor derived collision")
	root.free()

func test_building_trimesh_uses_the_complete_merged_triangle_soup() -> void:
	var root := Node3D.new()
	root.add_child(_box_instance("Shell", Vector3.ZERO,
		Vector3(4.0, 3.0, 5.0), StandardMaterial3D.new()))
	var merged := EnvironmentBakeGeometry.merge_pieces(root,
		Transform3D.IDENTITY)
	var shape := EnvironmentBakeGeometry.building_trimesh(merged)
	assert_not_null(shape)
	assert_eq(shape.get_faces().size(),
		EnvironmentBakeGeometry.triangle_faces(merged).size())
	assert_true(shape.backface_collision,
		"interior floors and walls must collide from their walkable side")
	root.free()


func test_axis_clip_keeps_authored_outer_end_and_opens_exact_party_seam() \
		-> void:
	var root := Node3D.new()
	root.add_child(_box_instance("Roof", Vector3.ZERO,
		Vector3(2.0, 1.0, 4.0), StandardMaterial3D.new()))
	var source := EnvironmentBakeGeometry.merge_pieces(root,
		Transform3D.IDENTITY)
	root.free()
	var clipped := EnvironmentBakeGeometry.clip_axis_range(source,
		Vector3.AXIS_Z, -1.0, 2.0)
	assert_not_null(clipped)
	if clipped == null:
		return
	assert_almost_eq(clipped.get_aabb().position.z, -1.0, 0.0001)
	assert_almost_eq(clipped.get_aabb().end.z, 2.0, 0.0001)
	var faces := EnvironmentBakeGeometry.triangle_faces(clipped)
	assert_gt(faces.size(), 0)
	var authored_end_triangle_count := 0
	var invented_seam_triangle_count := 0
	for index in range(0, faces.size(), 3):
		var all_authored_end := true
		var all_party_seam := true
		for corner in 3:
			all_authored_end = all_authored_end \
				and is_equal_approx(faces[index + corner].z, 2.0)
			all_party_seam = all_party_seam \
				and is_equal_approx(faces[index + corner].z, -1.0)
		authored_end_triangle_count += int(all_authored_end)
		invented_seam_triangle_count += int(all_party_seam)
	assert_gt(authored_end_triangle_count, 0,
		"the uncut authored gable/end face must survive")
	assert_eq(invented_seam_triangle_count, 0,
		"the semantic join stays open for its touching neighbour")


func test_axis_mirror_reflects_joinery_without_a_negative_runtime_scale() \
		-> void:
	var source := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in [
			Vector3(-2.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
			Vector3(-2.0, 1.0, 0.0),
	]:
		surface.set_normal(Vector3.BACK)
		surface.set_tangent(Plane(Vector3.RIGHT, 1.0))
		surface.set_uv(Vector2(vertex.x, vertex.y))
		surface.add_vertex(vertex)
	surface.commit(source)
	var mirrored := EnvironmentBakeGeometry.mirror_axis(source,
		Vector3.AXIS_X)
	assert_not_null(mirrored)
	if mirrored == null:
		return
	assert_almost_eq(mirrored.get_aabb().position.x, -1.0, 0.0001)
	assert_almost_eq(mirrored.get_aabb().end.x, 2.0, 0.0001,
		"the one-sided source post moves to the opposite end")
	var arrays := mirrored.surface_get_arrays(0)
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert_eq(indices.slice(0, 3), PackedInt32Array([0, 2, 1]),
		"mirroring reverses triangle winding for ordinary back-face culling")
	assert_almost_eq(normals[0].dot(Vector3.BACK), 1.0, 0.0001,
		"reflected normals keep the authored face direction")
	assert_almost_eq(tangents[0], -1.0, 0.0001)
	assert_almost_eq(tangents[3], -1.0, 0.0001)


func test_ground_contacts_follow_disjoint_feet_not_the_full_visual_bounds() -> void:
	var piece := EnvironmentVisualPiece.new()
	var feet := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for centre: Vector3 in [Vector3(-2.0, 0.0, 0.0),
			Vector3(2.0, 0.0, 0.0)]:
		for vertex: Vector3 in [
			centre + Vector3(-0.25, 0.0, -0.25),
			centre + Vector3(0.25, 0.0, -0.25),
			centre + Vector3(0.25, 0.0, 0.25),
			centre + Vector3(-0.25, 0.0, -0.25),
			centre + Vector3(0.25, 0.0, 0.25),
			centre + Vector3(-0.25, 0.0, 0.25),
		]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2.ZERO)
			surface.add_vertex(vertex)
	surface.commit(feet)
	piece.mesh = feet
	var pieces: Array[EnvironmentVisualPiece] = [piece]
	var contacts := EnvironmentBakeGeometry.ground_contact_points(pieces,
		0.0, 0.1, 0.5)
	assert_gt(contacts.size(), 0)
	var has_left := false
	var has_right := false
	var has_middle := false
	for point: Vector2 in contacts:
		has_left = has_left or point.x < -1.0
		has_right = has_right or point.x > 1.0
		has_middle = has_middle or absf(point.x) < 1.0
	assert_true(has_left)
	assert_true(has_right)
	assert_false(has_middle,
		"empty span between structural feet remains an overhang opportunity")

func test_ramp_box_encodes_slope_in_rotation_not_nonuniform_transform_scale() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 1.5, 3.0)
	var piece := EnvironmentBakeGeometry.ramp_box(mesh, Vector2.DOWN, 0.24)
	assert_not_null(piece)
	var shape := piece.shape as BoxShape3D
	assert_not_null(shape)
	assert_almost_eq(shape.size.x, 2.0, 0.001)
	assert_almost_eq(shape.size.y, 0.24, 0.001)
	assert_almost_eq(shape.size.z, sqrt(3.0 * 3.0 + 1.5 * 1.5), 0.001)
	var scale := piece.local_transform.basis.get_scale()
	assert_almost_eq(scale.x, 1.0, 0.001)
	assert_almost_eq(scale.y, 1.0, 0.001)
	assert_almost_eq(scale.z, 1.0, 0.001,
		"collision-bearing stair transforms rotate but never stretch")
	assert_almost_eq(piece.local_transform.basis.determinant(), 1.0, 0.001)
	assert_gt(piece.local_transform.basis.z.y, 0.0,
		"the authored low-to-high direction controls the upward ramp axis")

func test_resource_gates_report_the_exact_exceeded_metric() -> void:
	var metrics := {
		"mesh_bytes": 400,
		"visual_triangles": 120,
		"collision_triangles": 120,
		"surface_count": 2,
		"collision_piece_count": 1,
	}
	assert_eq(EnvironmentBakeBudget.validate(metrics, {
		"max_mesh_bytes": 400,
		"max_visual_triangles": 120,
		"max_collision_triangles": 120,
		"max_surfaces": 2,
		"max_collision_pieces": 1,
	}), "")
	assert_eq(EnvironmentBakeBudget.validate(metrics, {
		"max_collision_triangles": 119,
	}), "collision_triangles exceeds max_collision_triangles (120 > 119)")
	assert_eq(EnvironmentBakeBudget.validate(metrics, {
		"max_surfaces": -1,
	}), "max_surfaces must be a non-negative integer")
