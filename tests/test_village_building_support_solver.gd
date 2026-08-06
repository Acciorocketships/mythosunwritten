extends GutTest


func _terraced_region() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			var cell := Vector2i(x, z)
			storeys[cell] = 0 if x <= -1 else (1 if x == 0 else 2)
			levels[cell] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_support_mode_and_skirt_follow_terrain_opportunity() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var terrain := VillageTerrainView.from_region(_terraced_region())
	var massing := VillageMassingSolver.solve(terrain, Vector2.ZERO,
		Vector2.RIGHT, program, &"village")
	assert_true(massing.accepted, String(massing.reason))
	var natural_count := 0
	var retained_count := 0
	var skirt_count := 0
	for placement: VillageMassingPlacement in massing.placements:
		var stable_id := StringName("test.%s" % placement.stable_key)
		var spec := program.assets[placement.asset_id] as VillageAssetSpec
		var support := VillageBuildingSupportSolver.solve(terrain, stable_id,
			placement, spec, program)
		assert_true(support.accepted,
			"%s: %s" % [placement.stable_key, support.reason])
		assert_true(support.validate())
		assert_eq(support.floor_y, placement.floor_y,
			"support compilation must preserve the massing elevation")
		var skirt := VillageSkirtDeckSolver.solve(terrain, stable_id,
			placement, spec, support)
		assert_true(skirt.accepted,
			"%s: %s" % [placement.stable_key, skirt.reason])
		assert_true(skirt.validate(placement.perch.is_naturally_supported()))
		if placement.perch.is_naturally_supported():
			natural_count += 1
			assert_eq(support.mode,
				VillageBuildingSupportPlan.Mode.NATURAL_FOUNDATION)
			assert_true(skirt.cells.is_empty(),
				"ground-bearing buildings never acquire a decorative skirt")
		else:
			retained_count += 1
			assert_eq(support.mode,
				VillageBuildingSupportPlan.Mode.ROCK_CORE)
			for cell: VillageTimberCell in skirt.cells:
				var core_shape := FeatureGroundShape.oriented_rect(
					support.core.centre, support.core.half_extents,
					float(support.core.angle))
				assert_false(core_shape.contains(cell.centre),
					"core-supported cells cannot become skirt deck")
			skirt_count += skirt.cells.size()
	assert_gt(natural_count, 0)
	assert_gt(retained_count, 0)
	assert_gt(skirt_count, 0)
