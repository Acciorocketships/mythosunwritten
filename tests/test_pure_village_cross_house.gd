extends "res://tests/test_pure_village_cross_roof.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")


func test_extended_host_perimeter_is_closed_below_the_attic() -> void:
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 3)]:
		var house := House.instantiate(dimensions.x, dimensions.y)
		add_child(house)
		var triangles := _triangles(house, false)
		for axis in 2:
			var edge := dimensions[axis] * 3.0 + (3.0 if axis == 0 else 1.5)
			for end: int in [-1, 1]:
				for side: int in [-1, 1]:
					for index in range(int((edge - 3) * 4)):
						var along := end * (3.125 + index * .25)
						for y in [.15, 1.5, 2.85]:
							var at := (
								Vector3(along, y, side * 3.0)
								if axis == 0
								else Vector3(side * 3.0, y, along)
							)
							at.x -= .125
							var normal := Vector3.BACK if axis == 0 else Vector3.RIGHT
							assert_true(
								_hit(triangles, at - normal * .25, at + normal * .25),
								"Open host side %s at %s" % [dimensions, at]
							)
				for index in 24:
					for y in [.15, 1.5, 2.85]:
						var across := -2.875 + index * .25
						var at := (
							Vector3(end * edge, y, across)
							if axis == 0
							else Vector3(across, y, end * edge)
						)
						at.x -= .125
						var normal := Vector3.RIGHT if axis == 0 else Vector3.BACK
						assert_true(
							_hit(triangles, at - normal * .25, at + normal * .25),
							"Open host end %s at %s" % [dimensions, at]
						)
		house.free()


func test_seeded_openings_keep_corner_ownership_and_one_coherent_window_family() -> void:
	var seen: Dictionary = {}
	for seed_value in 20:
		var choices := House.sample(seed_value, 2, 1)
		assert_eq(choices, House.sample(seed_value, 2, 1))
		seen[str(choices)] = true
		var source := House.derive(2, 1)
		var sampled := House.derive(2, 1, choices)
		assert_eq(
			sampled.size(), source.size() + 2, "Two native posts retain short-wing corner ownership"
		)
		var doors := 0
		var windows: Dictionary = {}
		for index in source.size():
			assert_eq(source[index].transform, sampled[index].transform)
			if not source[index].has("facade_slot"):
				assert_eq(
					source[index].module,
					sampled[index].module,
					"Corner/return/roof ownership retained"
				)
			elif sampled[index].module == "Door_3_1":
				doors += 1
			else:
				windows[sampled[index].module] = true
		assert_eq(doors, 1)
		assert_eq(windows.size(), 1)
	assert_gt(seen.size(), 5)


func test_actual_window_glass_clears_compound_eaves_and_valleys() -> void:
	for dimensions: Vector2i in [Vector2i(2, 1), Vector2i(1, 2)]:
		var roof := Roof.instantiate(dimensions.x, dimensions.y)
		add_child(roof)
		var triangles := _triangles(roof)
		for family in ["Window_1_2", "Window_12_2"]:
			var blocked := 0
			var checked := 0
			for part in House.derive(dimensions.x, dimensions.y):
				if not part.has("facade_slot"):
					continue
				var window: Node3D = (
					load("res://assets/PureVillage/Models/Architecture/%s.glb" % family)
					. instantiate()
				)
				add_child(window)
				window.transform = part.transform
				var outward: Vector3 = window.basis.z
				for mesh: MeshInstance3D in window.find_children(
					"*", "MeshInstance3D", true, false
				):
					for surface in mesh.mesh.get_surface_count():
						if not mesh.get_active_material(surface).resource_name.to_lower().contains(
							"glass"
						):
							continue
						var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[
							Mesh.ARRAY_VERTEX
						]
						for vertex in vertices:
							var at := mesh.global_transform * vertex
							checked += 1
							if _hit(triangles, at + outward * .01, at + outward * 2):
								blocked += 1
				window.free()
			assert_gt(checked, 0)
			assert_eq(
				blocked, 0, "Source glazing remains visible below compound roof at %s" % dimensions
			)
		roof.free()


func test_sampled_short_wing_corners_retain_full_height_native_timber() -> void:
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		var house := House.instantiate(
			dimensions.x, dimensions.y, House.sample(31, dimensions.x, dimensions.y)
		)
		add_child(house)
		var timber := PackedVector3Array()
		var beams := 0
		for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			if not String(mesh.name).begins_with("Wood_Beam_3x30_2"):
				continue
			beams += 1
			for vertex in mesh.mesh.get_faces():
				timber.append(mesh.global_transform * vertex)
		assert_eq(beams, 2, "One native post for each replaced short-wing end owner")
		for end: int in [-1, 1]:
			for y in [.05, 1.5, 2.95]:
				var at := Vector3(
					end * 3.0 - .125, y, end * (dimensions.y * 3 + (1.5 if end == 1 else 1.375))
				)
				var diagonal := Vector3(.4, 0, .4)
				assert_true(
					_hit(timber, at - diagonal, at + diagonal), "Timber corner absent at %s" % at
				)
		house.free()
