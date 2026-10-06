extends GutTest


func test_public_retaining_courses_use_the_same_native_stone_as_citadel_walls() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	KitSubstitution.prepare(catalog, kit)
	for legacy: StringName in [
		&"sfv.fabric.wall.rock.plain.001", &"sfv.fabric.wall.rock.retaining.001"
	]:
		var source := EnvironmentInstancePayload.new()
		source.add(legacy, Transform3D.IDENTITY, Color.WHITE, &"public-retaining/test")
		var result := KitSubstitution.apply(source)
		assert_eq(
			result.asset_ids(),
			[&"pure_village.stone.retaining_half"],
			"Public stone must match the adjoining native retaining masonry"
		)
		var before: AABB = catalog.descriptor(legacy).measured_aabb
		var union := AABB()
		var first := true
		for id: StringName in result.asset_ids():
			for pose: Transform3D in result.batches[id].transforms:
				var box: AABB = pose * catalog.descriptor(id).measured_aabb
				union = box if first else union.merge(box)
				first = false
		assert_almost_eq(
			union.position,
			before.position,
			Vector3.ONE * 0.001,
			"Keep the accepted support envelope"
		)
		assert_almost_eq(
			union.end, before.end, Vector3.ONE * 0.001, "Keep the walking-floor contact"
		)
	assert_eq(
		kit.asset(&"plinth.stone"),
		&"suntail.stone.stone_base",
		"Individual Suntail house footings keep their own family"
	)
