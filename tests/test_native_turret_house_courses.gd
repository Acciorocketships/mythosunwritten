extends GutTest
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageTurretHouse.gd")


func test_source_and_repeat_keep_complete_closed_wall_and_tower_courses() -> void:
	var source := House.derive()
	var extended := House.derive(1)
	var repeated: Array[Dictionary] = []
	var catalog := EnvironmentCatalog.load_default()
	var shifted := 0
	for part in extended:
		assert_not_null(catalog.descriptor(part.asset_id))
		assert_gt(part.transform.basis.determinant(), 0.0)
		if part.get("role", &"") == &"course_window":
			continue
		if part.has("repeated_course"):
			repeated.append(part)
			continue
		var original: Dictionary = source.filter(func(p: Dictionary) -> bool: return p.source_node == part.source_node)[0]
		assert_eq(
			part.asset_id,
			original.asset_id,
			"Material variants remain attached to structural roles"
		)
		assert_eq(part.transform.basis, original.transform.basis, "No stretching native geometry")
		var delta: Vector3 = part.transform.origin - original.transform.origin
		assert_true(delta == Vector3.ZERO or delta == Vector3.UP * 3)
		if delta.y > 0:
			shifted += 1
	assert_eq(repeated.size(), 12, "Eleven facade pieces and the full round turret course")
	assert_gt(shifted, 30, "The whole crown assembly follows the new storey")
	var tower_repeats := 0
	for part in repeated:
		if part.module == "StoneTower_Window_30x30":
			tower_repeats += 1
		var original: Dictionary = source.filter(func(p: Dictionary) -> bool: return p.source_node == part.source_node)[0]
		var bounds: AABB = catalog.descriptor(part.asset_id).measured_aabb
		var lower: AABB = original.transform * bounds
		var upper: AABB = part.transform * bounds
		assert_lte(
			upper.position.y - lower.end.y,
			.01,
			"Native course ends meet or overlap their authored trim; no missing horizontal strip"
		)
	assert_eq(tower_repeats, 1, "Exactly one complete shaft course continues to the raised cap")
	assert_eq(House.derive(0), source, "The original remains a reproducible special case")


func test_sampler_contains_the_authored_case_and_the_complete_course_variation() -> void:
	var seen: Dictionary = {}
	for seed_value in 16:
		var choices := House.sample(seed_value)
		assert_eq(choices, House.sample(seed_value))
		seen[choices.extra_upper_storeys] = true
	assert_eq(seen.size(), 2)


func test_new_course_glass_is_visible_outside_all_baked_geometry() -> void:
	var parts := House.derive(1)
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var checked := 0
	var blocked := 0
	var windows := 0
	for part in parts:
		if part.get("role", &"") != &"course_window":
			continue
		windows += 1
		var visual := cache.visual(part.asset_id)
		var points: Dictionary = {}
		for piece: EnvironmentVisualPiece in visual.pieces:
			for surface in piece.mesh.get_surface_count():
				if piece.mesh.surface_get_material(surface).resource_name != "Glass_Out":
					continue
				var arrays := piece.mesh.surface_get_arrays(surface)
				for index: int in arrays[Mesh.ARRAY_INDEX]:
					points[part.transform * piece.local_transform * arrays[Mesh.ARRAY_VERTEX][index]] = true
		for at: Vector3 in points:
			checked += 1
			var a: Vector3 = at + part.transform.basis.z.normalized() * .005
			var b: Vector3 = at + part.transform.basis.z.normalized() * 2
			var hit := false
			for obstacle in parts:
				if obstacle == part:
					continue
				var bounds: AABB = (
					obstacle.transform * catalog.descriptor(obstacle.asset_id).measured_aabb
				)
				if bounds.intersects_segment(a, b) == null:
					continue
				for piece: EnvironmentVisualPiece in cache.visual(obstacle.asset_id).pieces:
					var pose: Transform3D = obstacle.transform * piece.local_transform
					var vertices := piece.mesh.get_faces()
					for i in range(0, vertices.size(), 3):
						if (
							Geometry3D.segment_intersects_triangle(
								a,
								b,
								pose * vertices[i],
								pose * vertices[i + 1],
								pose * vertices[i + 2]
							)
							!= null
						):
							hit = true
							break
					if hit:
						break
				if hit:
					break
			if hit:
				blocked += 1
	assert_eq(windows, 5)
	assert_gt(checked, 0)
	assert_eq(blocked, 0, "No plaster, beam, neighbouring facade or roof obscures new glazing")
