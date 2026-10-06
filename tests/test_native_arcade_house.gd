extends GutTest
const HOUSE = preload("res://scripts/terrain/features/villages/grammar/PureVillageArcadeHouse.gd")
const REVIEW = preload("res://tests/harness/suntail/native_arcade_house_review.gd")
const ORACLE = preload("res://tests/fixtures/native_prefab_reconstruction.gd")


func _triangles(node: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for v: Vector3 in mesh.mesh.get_faces():
			result.append(mesh.global_transform * v)
	return result


func _hit(triangles: PackedVector3Array, a: Vector3, b: Vector3) -> bool:
	for i in range(0, triangles.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				a, b, triangles[i], triangles[i + 1], triangles[i + 2]
			)
			!= null
		):
			return true
	return false


func test_authored_house_is_an_exact_derivation():
	var source: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/native_streethouse8c_derivation.json")
	)
	var derived := REVIEW.document(HOUSE.derive())
	assert_eq(derived.parts.size(), source.parts.size())
	for i in source.parts.size():
		assert_eq(derived.parts[i].module, source.parts[i].module)
		assert_eq(derived.parts[i].materials, source.parts[i].materials)
		for j in 16:
			assert_almost_eq(
				float(derived.parts[i].matrix[j]), float(source.parts[i].matrix[j]), 0.0001
			)


func test_short_and_tall_variants_close_the_native_roof_and_upper_walls():
	for spec: Array in [[1, "Window_1_2"], [2, ""], [2, "Window_1_2"], [2, "Window_5_2"]]:
		var house := REVIEW.instantiate(HOUSE.derive(spec[0], spec[1]))
		add_child(house)
		var tris := _triangles(house)
		var eave: float = 6.0 + spec[0] * 3.0
		for x in [-2.8, -1.5, -.5, .5, 1.5, 2.8]:
			for z in [-2.8, -1.5, 0., 1.5, 3., 4.0]:
				assert_true(
					_hit(tris, Vector3(x, eave + 7, z), Vector3(x, eave - .1, z)),
					"Native roof remains closed at %s/%s" % [spec, Vector2(x, z)]
				)
		var wall_heights := [6.6, 7.8, 8.7]
		if spec[0] == 2:
			wall_heights.append_array([9.6, 10.8, 11.7])
		for y in wall_heights:
			for z in [-2.8, -1., .5, 2., 3.8]:
				for side in [-1, 1]:
					assert_true(
						_hit(tris, Vector3(side * 5., y, z), Vector3(side * 2.5, y, z)),
						"Upper side enclosure %s" % Vector3(side, y, z)
					)
			for x in [-2.7, -1., .5, 2.7]:
				assert_true(_hit(tris, Vector3(x, y, 5.0), Vector3(x, y, 4.0)), "Front enclosure")
				assert_true(_hit(tris, Vector3(x, y, -4.0), Vector3(x, y, -3.0)), "Rear enclosure")
		# The arcade remains open beneath its boarded inhabited floor.
		assert_false(
			_hit(tris, Vector3(0, 1, 5), Vector3(0, 1, 2)), "Keep the covered public recess"
		)
		assert_true(
			_hit(tris, Vector3(0, 5.5, 3), Vector3(0, 6.5, 3)),
			"Arcade ceiling remains a real floor"
		)
		house.free()


func test_seeded_choices_preserve_low_projections_but_clear_short_eaves():
	var seen := {}
	for seed_value in 20:
		var choice := HOUSE.sample(seed_value)
		assert_eq(choice, HOUSE.sample(seed_value))
		seen[str(choice)] = true
		var parts := HOUSE.derive(choice.upper_storeys, choice.upper_side_window)
		var lower_bays := 0
		var arch_count := 0
		for part: Dictionary in parts:
			if part.module == "Arch_End_30x60":
				arch_count += 1
			if part.module == "Window_19_2":
				if choice.upper_storeys == 1:
					assert_lt(
						part.transform.origin.y,
						6.0,
						"Hood cannot occupy the shortened roof attachment"
					)
				if part.transform.origin.y < 6:
					lower_bays += 1
		assert_eq(lower_bays, 1, "The lower outcropping remains")
		assert_eq(arch_count, 6, "Complete native arcade and balcony supports remain")
	assert_eq(seen.size(), 4)


func test_baked_assemblies_preserve_native_bounds_and_closed_roofs():
	for spec: Array in [[1, "Window_1_2"], [2, ""], [2, "Window_1_2"], [2, "Window_5_2"]]:
		var parts := HOUSE.derive(spec[0], spec[1])
		var source := REVIEW.instantiate(parts)
		var baked := REVIEW.instantiate_baked(parts)
		add_child(source)
		add_child(baked)
		var native_tris := _triangles(source)
		var baked_tris := _triangles(baked)
		var native_bounds := AABB(native_tris[0], Vector3.ZERO)
		var baked_bounds := AABB(baked_tris[0], Vector3.ZERO)
		for v in native_tris:
			native_bounds = native_bounds.expand(v)
		for v in baked_tris:
			baked_bounds = baked_bounds.expand(v)
		assert_lt(native_bounds.position.distance_to(baked_bounds.position), .001)
		assert_lt(native_bounds.end.distance_to(baked_bounds.end), .001)
		var eave: float = 6.0 + spec[0] * 3.0
		for x in [-2.8, -1.5, -.5, .5, 1.5, 2.8]:
			for z in [-2.8, -1.5, 0., 1.5, 3., 4.0]:
				assert_true(_hit(baked_tris, Vector3(x, eave + 7, z), Vector3(x, eave - .1, z)))
		source.free()
		baked.free()


func test_arcade_site_preserves_recessed_ground_entry_in_all_orientations():
	var site_rule = preload("res://scripts/terrain/features/villages/grammar/NativeArcadeSite.gd")
	var compiler = preload(
		"res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd"
	)
	var catalog := EnvironmentCatalog.load_default()
	var arrival := Vector3(24, 8, -42)
	for scale_value in [1.0, 2.0]:
		for outward in [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]:
			var site: Dictionary = site_rule.place(
				catalog, 1, "Window_1_2", scale_value, arrival, outward
			)
			assert_true(site.ok, site.reason)
			if not site.ok:
				continue
			assert_eq(site.entry_route[0], arrival)
			assert_almost_eq(site.door.origin.y, arrival.y, .0001)
			assert_lt((site.door.origin - arrival).dot(outward), -3.0 * scale_value)
			assert_almost_eq((site.door.origin - arrival).cross(outward).length(), 0.0, .0001)
			assert_gt(site.bearing_bounds.size(), 0)
			for corner in 8:
				assert_lte((site.envelope.get_endpoint(corner) - arrival).dot(outward), -.74)
			var compiled: Dictionary = compiler.compile(
				site.parts, catalog, site.pose, &"arcade.site", site.envelope.grow(.01)
			)
			assert_true(compiled.ok, compiled.reason)
	assert_false(site_rule.place(catalog, 1, "Window_5_2", 2.0, arrival, Vector3.BACK).ok)
	assert_false(site_rule.place(catalog, 1, "", 2.0, arrival, Vector3.UP).ok)


func test_arcade_recipe_keeps_all_parts_and_reserves_its_real_envelope():
	var recipe_rule = preload(
		"res://scripts/terrain/features/villages/grammar/NativeHouseRecipe.gd"
	)
	var catalog := EnvironmentCatalog.load_default()
	for spec: Array in [[1, "Window_1_2"], [2, ""], [2, "Window_1_2"], [2, "Window_5_2"]]:
		var recipe: FabricRecipe = recipe_rule.arcade(catalog, &"arcade.test", spec[0], spec[1])
		assert_not_null(recipe)
		if recipe == null:
			continue
		assert_eq(recipe.placements.size(), HOUSE.derive(spec[0], spec[1]).size())
		assert_gt(recipe.terrain_bearing_cells.size(), 0)
		assert_gt(recipe.solid_cells.size(), 0)
		assert_true(recipe.headroom_cells.has(Vector3i.ZERO))


func test_varied_arcades_use_complete_middle_front_window_bays():
	for spec: Array in [[1, "Window_1_2"], [2, ""], [2, "Window_1_2"], [2, "Window_5_2"]]:
		var parts := HOUSE.derive(spec[0], spec[1])
		var front_bays: Array[Dictionary] = []
		for part in parts:
			var position: Vector3 = part.transform.origin
			if (
				absf(position.y - 3.0) < .0001
				and absf(position.z - 1.375) < .0001
				and absf(absf(position.x) - 1.5) < .0001
			):
				front_bays.append(part)
		assert_eq(front_bays.size(), 2)
		for part in front_bays:
			assert_eq(part.module, "Wall_Middle1_30x30_1" if spec[1] == "" else "Window_1_2")
			assert_true(part.transform.basis.is_equal_approx(Basis.IDENTITY))
		# Probe the real wall surface at the newly substituted course, including
		# both joints and the spaces around the window openings.
		var house := REVIEW.instantiate_baked(parts)
		add_child(house)
		var tris := _triangles(house)
		for x in [-2.8, -2., -.5, 0., .5, 2., 2.8]:
			for y in [3.2, 3.8, 4.5, 5.4, 5.8]:
				assert_true(
					_hit(tris, Vector3(x, y, 1.9), Vector3(x, y, .9)),
					"Middle course remains enclosed"
				)
		house.free()
