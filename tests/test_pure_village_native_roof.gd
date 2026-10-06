extends GutTest
const Grammar = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")


func test_two_bay_derivation_reconstructs_authored_roof_and_gable_geometry() -> void:
	_compare_reference("House_1", 2)


func test_same_rule_reconstructs_longer_authored_house_without_retuning() -> void:
	_compare_reference("House_4", 3)


func test_native_shell_reconstructs_whole_house_four() -> void:
	_compare_reference("House_4", 3, true)


func test_projected_roof_reconstructs_native_street_house_end_caps_and_gables() -> void:
	_compare_reference("StreetHouse_1", 2)


func test_complete_projected_street_house_reconstructs_every_authored_mesh() -> void:
	_compare_reference("StreetHouse_1", 2, true)


func test_cross_roof_reconstructs_authored_valley_junctions() -> void:
	_compare_reference("House_5", 1)


func test_compound_shell_reconstructs_source_walls_and_roof() -> void:
	_compare_reference("House_5", 1, false, true)


func _compare_reference(
	house: String, bays: int, whole_house: bool = false, cross_shell: bool = false
) -> void:
	var reference: Node3D = (
		load("res://assets/PureVillage/Models/Houses/%s.glb" % house).instantiate()
	)
	var generated := (
		(
			preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeHouse.gd")
			. instantiate(bays)
		)
		if whole_house
		else Grammar.instantiate(bays, 3.0)
	)
	if house == "StreetHouse_1" and whole_house:
		generated.free()
		generated = (
			preload("res://scripts/terrain/features/villages/grammar/PureVillageStreetHouse.gd")
			. instantiate(bays)
		)
	elif house == "StreetHouse_1":
		generated.free()
		generated = (
			preload("res://scripts/terrain/features/villages/grammar/PureVillageJettyRoof.gd")
			. instantiate(bays, 6.0)
		)
	if house == "House_5":
		generated.free()
		generated = (
			preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossRoof.gd")
			. instantiate()
		)
	if cross_shell:
		generated.free()
		generated = (
			preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")
			. instantiate()
		)
	add_child_autofree(reference)
	add_child_autofree(generated)
	var wanted: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in reference.find_children("*", "MeshInstance3D", true, false):
		if (
			whole_house
			or (cross_shell and String(mesh.name).begins_with("Wall_"))
			or String(mesh.name).begins_with("Roof_")
			or String(mesh.name).begins_with("Wall_Cut")
			or String(mesh.name).begins_with("Wall_Peak")
			or (
				house == "House_5"
				and (String(mesh.name).contains("_30x10_") or String(mesh.name).contains("_15x10_"))
			)
		):
			wanted.append(mesh)
	var actual := generated.find_children("*", "MeshInstance3D", true, false)
	assert_eq(actual.size(), wanted.size(), "No missing/excess components, including end closures")
	for expected: MeshInstance3D in wanted:
		var best: MeshInstance3D = null
		var distance := INF
		for candidate: MeshInstance3D in actual:
			if candidate.mesh.get_surface_count() != expected.mesh.get_surface_count():
				continue
			if (
				String(candidate.name).get_slice("_LOD", 0)
				!= String(expected.name).get_slice("_LOD", 0)
			):
				continue
			var d := candidate.global_position.distance_to(expected.global_position)
			if d < distance:
				best = candidate
				distance = d
		assert_not_null(best, String(expected.name))
		if best == null:
			continue
		actual.erase(best)
		var max_error := 0.0
		for surface in expected.mesh.get_surface_count():
			var source := expected.mesh.surface_get_arrays(surface)
			var result := best.mesh.surface_get_arrays(surface)
			assert_eq(result[Mesh.ARRAY_INDEX], source[Mesh.ARRAY_INDEX], "Exact triangle topology")
			var a: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
			var b: PackedVector3Array = result[Mesh.ARRAY_VERTEX]
			assert_eq(a.size(), b.size())
			if a.size() != b.size():
				continue
			for vertex in a.size():
				max_error = maxf(
					max_error,
					(expected.global_transform * a[vertex]).distance_to(
						best.global_transform * b[vertex]
					)
				)
			var em := expected.get_active_material(surface)
			var bm := best.get_active_material(surface)
			assert_eq(bm.resource_name, em.resource_name, "Authored material assignment")
			assert_eq(bm.albedo_color, em.albedo_color)
			assert_eq(bm.roughness, em.roughness)
			assert_eq(bm.metallic, em.metallic)
			for slot in [
				BaseMaterial3D.TEXTURE_ALBEDO,
				BaseMaterial3D.TEXTURE_NORMAL,
				BaseMaterial3D.TEXTURE_ROUGHNESS
			]:
				var et: Texture2D = em.get_texture(slot)
				var bt: Texture2D = bm.get_texture(slot)
				assert_eq(
					bt.resource_path if bt else "",
					et.resource_path if et else "",
					"Same source texture"
				)
			assert_eq(
				result[Mesh.ARRAY_TEX_UV], source[Mesh.ARRAY_TEX_UV], "Unchanged authored UVs"
			)
		assert_lt(
			max_error,
			0.0002,
			"World-space triangles match within source quaternion rounding: %s" % expected.name
		)
	assert_true(actual.is_empty(), "Every generated mesh explained by reference")


func test_length_changes_all_courses_ridges_and_end_closures_together() -> void:
	for bays in [1, 3, 4, 6]:
		var parts := Grammar.derive(bays, 0.0)
		assert_eq(parts.size(), 5 * bays + 18)
		var ends: Dictionary = {}
		for part: Dictionary in parts:
			assert_true(
				(part.transform as Transform3D).basis.get_scale().is_equal_approx(Vector3.ONE),
				"Native geometry never stretched"
			)
			if String(part.module).begins_with("Wall_Cut"):
				ends[snappedf(part.transform.origin.x, .001)] = true
		assert_eq(ends.size(), 2)
		assert_true(ends.has(-bays * 1.5 + .125))
		assert_true(ends.has(bays * 1.5 + .125))
