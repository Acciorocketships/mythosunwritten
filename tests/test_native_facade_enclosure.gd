extends GutTest
const Audit = preload("res://tests/fixtures/native_facade_enclosure.gd")
const Recipe = preload("res://scripts/terrain/features/villages/grammar/NativeHouseRecipe.gd")


func test_native_wall_is_seen_but_private_air_is_not_a_fictitious_facade() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var recipe := Recipe.street(catalog, &"native.audit", 2, 7)
	assert_not_null(recipe)
	if recipe == null:
		return
	for yaw in 4:
		var plan := preload("res://tests/fixtures/native_house_plan.gd").build(recipe, catalog, yaw)
		var surfaces := Audit.build(plan, catalog)
		assert_gt(surfaces.size(), 0)
		var exercised := false
		for part: Dictionary in recipe.placements:
			if not String(part.asset_id).begins_with("pure_village.native.door_"):
				continue
			var pose: Transform3D = plan.units[0].transform() * part.transform
			assert_true(
				Audit.blocks_ray(surfaces, pose * Vector3(0, 1, 1), pose * Vector3(0, 1, -1))
			)
			assert_false(
				Audit.blocks_ray(surfaces, pose * Vector3(0, 1, -.6), pose * Vector3(0, 1, -1))
			)
			exercised = true
		assert_true(exercised)
