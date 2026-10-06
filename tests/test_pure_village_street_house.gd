extends GutTest
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageStreetHouse.gd")


func _triangles(root: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var local := mesh.mesh.get_faces()
		for vertex: Vector3 in local:
			out.append(mesh.global_transform * vertex)
	return out


func _hit(vertices: PackedVector3Array, a: Vector3, b: Vector3) -> bool:
	for index in range(0, vertices.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				a, b, vertices[index], vertices[index + 1], vertices[index + 2]
			)
			!= null
		):
			return true
	return false


func test_new_lengths_keep_roof_side_rows_and_projecting_floor_closed() -> void:
	for bays in [2, 3, 4]:
		var house := House.instantiate(bays, House.sample(7, bays) if bays == 3 else {})
		add_child(house)
		var triangles := _triangles(house)
		var half_length: float = bays * 1.5
		# Probe the actual triangles, including module joints and the extended cap.
		for z_index in range(bays * 6 + 2):
			var z := -half_length + .125 + z_index * .5
			for x in [-.75, .75]:
				assert_true(
					_hit(triangles, Vector3(x, 11, z), Vector3(x, 6, z)),
					"Roof gap at %s bays, %s" % [bays, Vector2(x, z)]
				)
		for z_index in range(bays * 6):
			var z := -half_length + .25 + z_index * .5
			for y in [1.25, 4.25]:
				for side in [-1, 1]:
					assert_true(
						_hit(triangles, Vector3(side * 3.0, y, z), Vector3(side * 1.0, y, z)),
						"Side wall gap at %s" % Vector3(side, y, z)
					)
		for x in [-1.25, -.5, .5, 1.25]:
			assert_true(
				_hit(
					triangles, Vector3(x, 2.5, half_length + .5), Vector3(x, 3.5, half_length + .5)
				),
				"Projecting underside stays boarded"
			)
		house.free()


func test_sampled_facades_preserve_structural_connections_and_coherent_window_family() -> void:
	var seen: Dictionary = {}
	for seed_value in range(20):
		var choices := House.sample(seed_value, 3)
		assert_eq(choices, House.sample(seed_value, 3))
		seen[str(choices)] = true
		var families: Dictionary = {}
		var rows: Dictionary = {}
		for slot: String in choices:
			if choices[slot] not in House.FACADE_PROJECTIONS:
				families[choices[slot]] = true
			rows[slot.get_slice("/", 0) + "/" + slot.get_slice("/", 1)] = true
		assert_lte(families.size(), 2, "Coordinated lower/upper window families")
		for slot: String in choices:
			if slot.contains("/upper/"):
				assert_eq(choices[slot], "Window_1_2", "Keep high narrow windows out of roof eaves")
		assert_eq(
			rows.size(), 3, "Both ground sides and the formerly blank upper side have windows"
		)
		var source := House.derive(3)
		var sampled := House.derive(3, choices)
		assert_eq(source.size(), sampled.size(), "Replace bays rather than adding overlays")
		for index in source.size():
			assert_eq(
				source[index].transform, sampled[index].transform, "No change to structural fit"
			)
			if not source[index].has("facade_slot"):
				assert_eq(
					source[index].module, sampled[index].module, "Keep end trim, roof and supports"
				)
	assert_gt(seen.size(), 5, "Different seeds give different compatible layouts")


func test_projecting_bays_are_seeded_complete_lower_panels() -> void:
	var projected := 0
	var ordinary := 0
	for seed_value in 32:
		var choices := House.sample(seed_value, 2)
		var on_face := {}
		for part: Dictionary in House.derive(2, choices):
			if part.module not in House.FACADE_PROJECTIONS:
				continue
			assert_true(part.facade_slot.contains("/lower/"))
			assert_almost_eq(part.transform.origin.y, 0.0, .0001)
			var face: String = part.facade_slot.get_slice("/", 0)
			assert_false(on_face.has(face), "At most one projecting bay per lower frontage")
			on_face[face] = true
		projected += int(not on_face.is_empty())
		ordinary += int(on_face.is_empty())
	assert_gt(projected, 0, "Sampling must produce actual projecting bays")
	assert_gt(ordinary, 0, "Keep unprojected houses in the distribution")
	for part: Dictionary in House.derive(2):
		assert_false(
			part.module in House.FACADE_PROJECTIONS,
			"The exact source reconstruction remains available"
		)


func test_projecting_window_glass_is_not_buried_by_neighboring_walls_or_the_roof() -> void:
	var checked := 0
	for bays in [2, 3]:
		var choices := {"west/lower/0": "Window_5_2", "east/lower/0": "Window_5_2"}
		var parts := House.derive(bays, choices)
		var house := House.instantiate(bays, choices)
		add_child(house)
		for i in parts.size():
			if parts[i].module not in House.FACADE_PROJECTIONS:
				continue
			var window: Node3D = house.get_child(i)
			var other := PackedVector3Array()
			for j in house.get_child_count():
				if j != i:
					other.append_array(_triangles(house.get_child(j)))
			var outward: Vector3 = parts[i].transform.basis * Vector3.BACK
			for mesh: MeshInstance3D in window.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					if not mesh.get_active_material(surface).resource_name.contains("Glass_Out"):
						continue
					var arrays := mesh.mesh.surface_get_arrays(surface)
					var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					# Only referenced glass triangles, not unused positions shared
					# with another material in the imported vertex buffer.
					for t in range(0, ids.size(), 3):
						var centre := (
							mesh.global_transform
							* ((points[ids[t]] + points[ids[t + 1]] + points[ids[t + 2]]) / 3)
						)
						assert_false(
							_hit(other, centre + outward * .01, centre + outward * 2),
							"The complete projecting bay must retain an unobstructed opening"
						)
						checked += 1
		house.free()
	assert_gt(checked, 0)


func test_upper_window_compatibility_uses_visible_glazing_below_real_eave() -> void:
	var roof: Node3D = (
		preload("res://scripts/terrain/features/villages/grammar/PureVillageJettyRoof.gd")
		. instantiate(3, 6)
	)
	add_child(roof)
	var triangles := _triangles(roof)
	var blocked: Dictionary = {}
	for module_name in ["Window_1_2", "Window_12_2"]:
		var window: Node3D = (
			load("res://assets/PureVillage/Models/Architecture/%s.glb" % module_name).instantiate()
		)
		add_child(window)
		window.transform = Transform3D(Basis(Vector3.UP, PI * .5), Vector3(1.5, 3, -2))
		var hits := 0
		var checked := 0
		for mesh: MeshInstance3D in window.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface)
				if not material.resource_name.to_lower().contains("glass"):
					continue
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[
					Mesh.ARRAY_VERTEX
				]
				for vertex: Vector3 in vertices:
					var world := mesh.global_transform * vertex
					checked += 1
					if _hit(triangles, world + Vector3.RIGHT * .01, world + Vector3.RIGHT * 2):
						hits += 1
		assert_gt(checked, 0, "Check source glass, not the panel bounds")
		blocked[module_name] = hits
		window.free()
	roof.free()
	assert_eq(blocked["Window_1_2"], 0, "Shuttered upper glass remains visible below the eave")
	assert_gt(
		blocked["Window_12_2"], 0, "The high narrow window actually intersects the eave sightline"
	)


func test_rear_jetty_is_a_closed_supported_room_with_a_complete_extended_roof() -> void:
	for bays in [2, 3, 4]:
		var house := House.instantiate(bays, House.sample(7, bays), true)
		add_child(house)
		var triangles := _triangles(house)
		var rear: float = -bays * 1.5
		for offset in [.1, .4, .8]:
			for x in [-1.25, -.5, .5, 1.25]:
				assert_true(
					_hit(triangles, Vector3(x, 2.5, rear - offset), Vector3(x, 3.5, rear - offset)),
					"Complete boarded underside"
				)
				assert_true(
					_hit(triangles, Vector3(x, 11, rear - offset), Vector3(x, 6, rear - offset)),
					"Extended native roof covers the whole room"
				)
			for height in [3.25, 4.25, 5.75]:
				for side in [-1, 1]:
					assert_true(
						_hit(
							triangles,
							Vector3(side * 2.0, height, rear - offset),
							Vector3(side * 1.0, height, rear - offset)
						),
						"Both projecting room returns are closed"
					)
		for height in [6.25, 6.75]:
			for x in [-.75, .75]:
				assert_true(
					_hit(triangles, Vector3(x, height, rear - 1.5), Vector3(x, height, rear - .5)),
					"Gable follows the displaced upper facade"
				)
		house.free()


func test_rear_jetty_glazing_is_clear_of_the_complete_host() -> void:
	var checked := 0
	for bays in [2, 3]:
		var parts := House.derive(bays, House.sample(7, bays), true)
		var house := House.instantiate(bays, House.sample(7, bays), true)
		add_child(house)
		for index in parts.size():
			var part: Dictionary = parts[index]
			if part.module != "Window_3_1" or part.transform.origin.z > 0:
				continue
			var other := PackedVector3Array()
			for j in house.get_child_count():
				if j != index:
					other.append_array(_triangles(house.get_child(j)))
			for mesh: MeshInstance3D in house.get_child(index).find_children(
				"*", "MeshInstance3D", true, false
			):
				for surface in mesh.mesh.get_surface_count():
					if not mesh.get_active_material(surface).resource_name.contains("Glass_Out"):
						continue
					var arrays := mesh.mesh.surface_get_arrays(surface)
					var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for i in range(0, ids.size(), 3):
						var centre: Vector3 = (
							mesh.global_transform
							* ((vertices[ids[i]] + vertices[ids[i + 1]] + vertices[ids[i + 2]]) / 3)
						)
						assert_false(
							_hit(
								other, centre + Vector3.FORWARD * .01, centre + Vector3.FORWARD * 2
							)
						)
						checked += 1
		house.free()
	assert_gt(checked, 0, "Exercise real referenced exterior glass triangles")
