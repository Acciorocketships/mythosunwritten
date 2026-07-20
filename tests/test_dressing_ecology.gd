extends GutTest

func test_habitat_coverage_has_true_empty_and_filled_extremes() -> void:
	assert_eq(DressingEcology.suitability(0.5, 0.0,
		DressingHabitatLayer.Preference.INTERIOR, 0.08), 0.0)
	assert_eq(DressingEcology.suitability(0.5, 1.0,
		DressingHabitatLayer.Preference.INTERIOR, 0.08), 1.0)
	assert_eq(DressingEcology.suitability(0.5, 0.0,
		DressingHabitatLayer.Preference.EXTERIOR, 0.08), 1.0)
	assert_eq(DressingEcology.suitability(0.5, 1.0,
		DressingHabitatLayer.Preference.EXTERIOR, 0.08), 0.0)

func test_shared_habitat_channel_is_correlated_without_set_order() -> void:
	var point := Vector2(183.5, -92.25)
	var a := DressingEcology.habitat01(point, 9981,
		DressingCompiler.stable_id_hash(&"woodland_canopy"), 120.0)
	var b := DressingEcology.habitat01(point, 9981,
		DressingCompiler.stable_id_hash(&"woodland_canopy"), 120.0)
	var other := DressingEcology.habitat01(point, 9981,
		DressingCompiler.stable_id_hash(&"rocky_exposure"), 120.0)
	assert_eq(a, b)
	assert_ne(a, other)

func test_patch_field_produces_both_dense_habitat_and_real_clearings() -> void:
	var channel := DressingCompiler.stable_id_hash(&"test_patch")
	var dense := 0
	var clear := 0
	for z in 28:
		for x in 28:
			var value := DressingEcology.habitat01(Vector2(x, z) * 18.0,
				71351, channel, 96.0)
			var amount := DressingEcology.suitability(value, 0.42,
				DressingHabitatLayer.Preference.INTERIOR, 0.06)
			if amount > 0.98:
				dense += 1
			elif amount < 0.02:
				clear += 1
	assert_gt(dense, 20, "habitat has dense interiors")
	assert_gt(clear, 20, "habitat has true negative space, not merely lower probability")

func test_community_roll_is_spatial_and_seed_stable() -> void:
	var point := Vector2(70.0, 130.0)
	var channel := DressingCompiler.stable_id_hash(&"forest_species")
	var first := DressingEcology.community_roll(point, 4242, channel, 72.0)
	assert_eq(first, DressingEcology.community_roll(point, 4242, channel, 72.0))
	assert_ne(first, DressingEcology.community_roll(point + Vector2(500.0, 0.0),
		4242, channel, 72.0))

func test_shared_land_mask_contains_broad_clearings_and_connected_path_bands() -> void:
	var blocked := 0
	var occupied := 0
	var feathered := 0
	for z in 64:
		for x in 64:
			var amount := DressingEcology.land_occupancy01(Vector2(x, z) * 8.0, 71351)
			if amount <= 0.001:
				blocked += 1
			elif amount >= 0.999:
				occupied += 1
			else:
				feathered += 1
	assert_gt(blocked, 150, "the world has genuinely empty clearings/pathways")
	assert_gt(occupied, 1200, "exclusion does not erase the landscape")
	assert_gt(feathered, 50, "path and clearing edges feather instead of aliasing")

func test_tree_stature_and_mushroom_colonies_are_explicit_content_data() -> void:
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var program := DressingCompiler.compile(index, EnvironmentCatalog.load_default())
	assert_not_null(program)
	var by_id: Dictionary = {}
	for set_data: Dictionary in program.sets:
		by_id[set_data.id] = set_data
	var trees: Dictionary = by_id[&"ambient.tree"]
	var stature: Dictionary = {}
	for choice: Dictionary in trees.choices:
		stature[choice.asset_id] = choice.scale_multiplier
	assert_gt(stature[&"lpfv.tree.07"], 1.8,
		"one full-canopy conifer is a landmark tree")
	assert_gt(stature[&"lpfv.tree.02"], 1.3,
		"a broad-canopy variety grows into a tall canopy tree")
	assert_almost_eq(stature[&"lpfv.tree.04"], 1.0, 0.001,
		"small tree varieties retain their natural tier")
	var patch: Dictionary = by_id[&"ambient.mushroom.patch"]
	var single: Dictionary = by_id[&"ambient.mushroom.single"]
	assert_gt(patch.fill_per_cell[1], single.fill_per_cell[1] * 12.0,
		"colonies are locally dense while isolated mushrooms stay rare")

func test_compiled_sets_expose_direct_biome_fill_and_habitat_layers() -> void:
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var program := DressingCompiler.compile(index, EnvironmentCatalog.load_default())
	assert_not_null(program)
	var by_id: Dictionary = {}
	for set_data: Dictionary in program.sets:
		by_id[set_data.id] = set_data
	var tree: Dictionary = by_id[&"ambient.tree"]
	var rock: Dictionary = by_id[&"ambient.rock_large"]
	assert_gt(tree.fill_per_cell[1], tree.fill_per_cell[0],
		"deep forest directly authors a higher tree fill than meadow")
	assert_gt(rock.fill_per_cell[2], rock.fill_per_cell[0],
		"highland directly authors a higher rock fill than meadow")
	assert_gt(tree.habitat_layers.size(), 0)
	assert_gt(tree.community_scale, 0.0)
