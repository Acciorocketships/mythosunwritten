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


func test_every_retained_building_gets_one_atomic_fixed_rock_core() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var terrain := VillageTerrainView.from_region(_terraced_region())
	var massing := VillageMassingSolver.solve(terrain, Vector2.ZERO,
		Vector2.RIGHT, program, &"village")
	assert_true(massing.accepted, String(massing.reason))
	var retained_count := 0
	for placement: VillageMassingPlacement in massing.placements:
		if placement.perch.is_naturally_supported():
			continue
		retained_count += 1
		var spec := program.assets[placement.asset_id] as VillageAssetSpec
		var support := VillageRockCoreSolver.solve(terrain,
			StringName("test.%s" % placement.stable_key), placement,
			spec, program)
		assert_true(support.accepted,
			"%s: %s" % [placement.stable_key, support.reason])
		assert_true(support.validate())
		assert_gt(support.pieces.size(), 0)
		assert_gt(support.volumes.size(), 0)
		for piece: Dictionary in support.pieces:
			assert_eq((piece.transform as Transform3D).basis.get_scale(),
				Vector3.ONE,
				"rock collision modules must never be stretched")
	assert_gt(retained_count, 0)
