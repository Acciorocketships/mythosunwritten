extends GutTest


func test_reserved_native_frames_survive_kit_replacement_with_exact_support_bounds() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := WarrenVolumetricSolver.generate(
		7, {}, program, WarrenVillageScaleProfile.for_id(&"standard")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	var payload := KitVillageBuildings.legacy_payload_without(fabric, built.replaced_units)
	payload.append_from(built.payload)
	payload = KitSubstitution.apply(payload)
	var expected: Dictionary = {}
	var frames := 0
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"arcade_overhang_support":
			continue
		frames += 1
		var prefix := "spatial.fabric.%s.component" % feature.stable_id
		var count := 0
		for part: Dictionary in fabric.expanded_placements():
			if not String(part.stable_id).begins_with(prefix):
				continue
			count += 1
			assert_eq(part.asset_id, &"sfv.deck.pillar.001")
			expected[part.stable_id] = (
				(part.transform as Transform3D) * catalog.descriptor(part.asset_id).measured_aabb
			)
		assert_eq(count, 4, "Retain all four measured native corner supports")
	assert_gt(frames, 0, "Fixture must exercise real reserved overhangs")
	var seen: Dictionary = {}
	var pieces: Dictionary = {}
	for asset_id: StringName in payload.asset_ids():
		var batch: Dictionary = payload.batches[asset_id]
		for index in batch.ids.size():
			var id: StringName = batch.ids[index]
			var owner := StringName(String(id).split("/tile")[0])
			if not expected.has(owner):
				continue
			assert_false(pieces.has(id), "No duplicate frame member")
			pieces[id] = true
			var actual: AABB = (
				(batch.transforms[index] as Transform3D)
				* catalog.descriptor(asset_id).measured_aabb
			)
			seen[owner] = (seen[owner] as AABB).merge(actual) if seen.has(owner) else actual
			assert_true(batch.collision_enabled[index], "Rendered support keeps collision")
	assert_eq(seen.size(), expected.size(), "Kit conversion must not erase the structural frame")
	for id: StringName in expected:
		if not seen.has(id):
			continue
		var actual: AABB = seen[id]
		assert_lt(
			actual.position.distance_to((expected[id] as AABB).position),
			0.001,
			"Measured support foot/corner"
		)
		assert_lt(
			actual.end.distance_to((expected[id] as AABB).end),
			0.001,
			"Tiled native members reach the full support top/corner"
		)
