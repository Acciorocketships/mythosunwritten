extends GutTest
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeHouse.gd")


func test_seeded_openings_are_repeatable_and_replace_solid_bays() -> void:
	var signatures: Dictionary = {}
	for seed_value in range(16):
		var choices := House.sample(seed_value, 3)
		assert_eq(choices, House.sample(seed_value, 3))
		signatures[str(choices)] = true
		assert_eq(choices.values().count(&"door"), 1)
		assert_false(choices.values().has(&"window"), "Stone samples use stone-backed openings")
		for face in ["south", "north", "west", "east"]:
			var openings := 0
			for key in choices:
				if String(key).begins_with(face + "/") and choices[key] != &"solid":
					openings += 1
			assert_gt(openings, 0, "Each exposed face has an opening")
		var pieces := House.derive(3, choices)
		var panels := 0
		var doors := 0
		var entrances := 0
		for piece: Dictionary in pieces:
			if piece.module in House.OPENINGS.values():
				panels += 1
			if piece.module == "Door_9_1":
				doors += 1
			if piece.module == "WallStone_BottomEntrance_Middle_15x30":
				entrances += 1
		assert_eq(panels, 10, "Exactly one complete panel per bay; no wall behind opening")
		assert_eq(doors, 1)
		assert_eq(entrances, 1, "Door and its foundation opening change together")
	assert_gt(signatures.size(), 8)


func test_native_door_and_stone_window_match_authored_bay_interfaces() -> void:
	var reference: Node3D = load("res://assets/PureVillage/Models/Houses/House_1.glb").instantiate()
	var generated := House.instantiate(2, {"west/0": &"door", "west/1": &"stone_window"})
	add_child_autofree(reference)
	add_child_autofree(generated)
	var actual := generated.find_children("*", "MeshInstance3D", true, false)
	var checked := 0
	for expected: MeshInstance3D in reference.find_children("*", "MeshInstance3D", true, false):
		if not (
			String(expected.name).begins_with("Door_9_1")
			or String(expected.name).begins_with("Window_14_1")
		):
			continue
		var match_mesh: MeshInstance3D = null
		for candidate: MeshInstance3D in actual:
			if (
				String(candidate.name).get_slice("_LOD", 0)
				== String(expected.name).get_slice("_LOD", 0)
			):
				match_mesh = candidate
				break
		assert_not_null(match_mesh, String(expected.name))
		if match_mesh == null:
			continue
		checked += 1
		assert_eq(match_mesh.mesh.get_surface_count(), expected.mesh.get_surface_count())
		var error := 0.0
		for surface in expected.mesh.get_surface_count():
			var a := expected.mesh.surface_get_arrays(surface)
			var b := match_mesh.mesh.surface_get_arrays(surface)
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
						match_mesh.global_transform * bv[vertex]
					)
				)
		assert_lt(error, .0002, "Frame, recessed wall, and moving door retain native alignment")
	assert_gte(checked, 3, "Door frame, moving leaf, and stone window checked")
