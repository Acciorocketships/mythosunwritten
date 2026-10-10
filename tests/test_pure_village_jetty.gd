extends GutTest
const Jetty = preload("res://scripts/terrain/features/villages/grammar/PureVillageJetty.gd")


func test_native_projecting_front_floor_brackets_and_left_return_reconstruct() -> void:
	var reference: Node3D = (
		load("res://assets/PureVillage/Models/Houses/StreetHouse_1.glb").instantiate()
	)
	var generated := Jetty.instantiate(Transform3D(Basis.IDENTITY, Vector3(0, 3, 3)))
	add_child_autofree(reference)
	add_child_autofree(generated)
	var actual := generated.find_children("*", "MeshInstance3D", true, false)
	var checked := 0
	for expected: MeshInstance3D in reference.find_children("*", "MeshInstance3D", true, false):
		var name := String(expected.name)
		var selected := (
			name.begins_with("Window_3_1")
			or name.begins_with("Floor_Down_")
			or name.begins_with("Support_4")
		)
		selected = (
			selected
			or (
				name.begins_with("Wall_End_10x30")
				and expected.global_position.x < 0
				and expected.global_position.y > 2
			)
		)
		if not selected:
			continue
		var best: MeshInstance3D = null
		var distance := INF
		for candidate: MeshInstance3D in actual:
			if String(candidate.name).get_slice("_LOD", 0) != name.get_slice("_LOD", 0):
				continue
			var d := candidate.global_position.distance_to(expected.global_position)
			if d < distance:
				best = candidate
				distance = d
		assert_not_null(best, name)
		if best == null:
			continue
		actual.erase(best)
		checked += 1
		var error := 0.0
		assert_eq(best.mesh.get_surface_count(), expected.mesh.get_surface_count())
		for surface in expected.mesh.get_surface_count():
			var a := expected.mesh.surface_get_arrays(surface)
			var b := best.mesh.surface_get_arrays(surface)
			assert_eq(a[Mesh.ARRAY_INDEX], b[Mesh.ARRAY_INDEX])
			var av: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
			assert_eq(av.size(), bv.size())
			if av.size() != bv.size():
				continue
			for vertex in av.size():
				error = maxf(
					error,
					(expected.global_transform * av[vertex]).distance_to(
						best.global_transform * bv[vertex]
					)
				)
		assert_lt(error, .0002, name)
	assert_eq(checked, 8, "Front panel and shutters, two floor halves, two supports, left return")


func test_room_connection_contract_and_return_extents() -> void:
	var recipe := Jetty.derive()
	assert_true(recipe.requires_host)
	assert_true(recipe.requires_roof)
	assert_eq(recipe.room, AABB(Vector3(-1.5, 0, 0), Vector3(3, 3, 1)))
	var root := Jetty.instantiate()
	add_child_autofree(root)
	var returns := 0
	for module: Node3D in root.get_children():
		if not String(module.get_meta("native_module")).begins_with("Wall_End_10x30"):
			continue
		returns += 1
		var mesh: MeshInstance3D = module.find_children("*", "MeshInstance3D", true, false)[0]
		var box := mesh.global_transform * mesh.get_aabb()
		assert_lt(absf(box.position.z), .01, "Both returns start at the host face")
		assert_gt(box.end.z, 1.0, "Native front corner timber closes the window seam")
	assert_eq(returns, 2)


func test_continuous_host_side_is_not_duplicated_by_jetty_return() -> void:
	var recipe := Jetty.derive([1])
	assert_eq(recipe.host_owned_returns, [1])
	var returns := 0
	var supports := 0
	for part: Dictionary in recipe.parts:
		if part.module == "Wall_End_10x30_1":
			returns += 1
			assert_lt(part.transform.origin.x, 0.0, "Only the independent left return is emitted")
		if part.module == "Support_4":
			supports += 1
	assert_eq(returns, 1)
	assert_eq(supports, 2, "Sharing a side wall does not drop either bearing bracket")
