extends GutTest

func test_composes_feature_limits_assets_and_priorities() -> void:
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default(), {
		"max_asset_reach": 12.0,
		"max_ground_shape_reach": 8.0,
		"maximum_clearance": 3.5,
		"referenced_asset_ids": [&"village.test.b", &"village.test.a"],
	})
	assert_not_null(program)
	assert_not_null(program.paths)
	assert_not_null(program.villages)
	assert_eq(program.maximum_clearance, 3.5)
	assert_eq(program.query_margin, program.paths.query_margin)
	assert_eq(program.record_discovery_radius, 159.5)
	assert_eq(program.geometry_halo, 1)
	assert_eq(program.surface_priorities[FeatureGroundField.WORN_PATH],
		FeatureGroundField.PATH_PRIORITY)
	assert_eq(program.referenced_asset_ids, [
		&"sfv.arch.001", &"sfv.arch.002", &"sfv.bridge.001",
		&"sfv.entrance_arch.001", &"sfv.light_pole.001",
		&"village.test.a", &"village.test.b",
	])

func test_invalid_family_prevents_partial_composition() -> void:
	assert_null(FeatureProgram.compile(EnvironmentCatalog.load_default(), {
		"max_asset_reach": 49.0,
	}))
	assert_push_error("record radius exceeds settlement inset")
