extends GutTest

func test_catalogue_is_complete_and_consistent() -> void:
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		assert_true(TerrainRegimeCatalog.PARAMS.has(a), "params for %s" % a)
		assert_true(TerrainRegimeCatalog.SETPIECE_DENSITY.has(a), "densities for %s" % a)
		assert_true(TerrainRegimeCatalog.PARAMS[a].has("base_level_st"), "base level for %s" % a)
		for name: String in TerrainRegimeCatalog.PARAMS[a]:
			var r: Array = TerrainRegimeCatalog.PARAMS[a][name]
			assert_lte(float(r[0]), float(r[1]), "%s.%s range" % [a, name])
		for kind: StringName in TerrainRegimeCatalog.SETPIECE_DENSITY[a]:
			assert_true(TerrainRegimeCatalog.SETPIECE_PARAMS.has(kind), "setpiece %s" % kind)
	for biome: StringName in Helper.BIOME_NAMES:
		assert_true(TerrainRegimeCatalog.AFFINITY.has(biome), "affinity for %s" % biome)
		for a: StringName in TerrainRegimeCatalog.AFFINITY[biome]:
			assert_has(TerrainRegimeCatalog.ARCHETYPES, a)

func test_draw_respects_ranges_and_scales_only_lengths() -> void:
	var spec := {"wave_m": [10.0, 20.0], "rise_st": [1.0, 2.0], "frac": [0.2, 0.4]}
	for i in 200:
		var d := TerrainRegimeCatalog.draw(7, Vector2i(i, -i), 5, spec, 1.5)
		assert_between(d.wave_m, 15.0, 30.0)
		assert_between(d.rise_st, 1.0, 2.0)
		assert_between(d.frac, 0.2, 0.4)
	assert_eq(TerrainRegimeCatalog.draw(7, Vector2i(3, 4), 5, spec, 1.0),
		TerrainRegimeCatalog.draw(7, Vector2i(3, 4), 5, spec, 1.0))

func test_grouped_parameters_share_a_draw() -> void:
	var spec := {"a": [0.0, 1.0, "g"], "b": [0.0, 1.0, "g"]}
	for i in 50:
		var d := TerrainRegimeCatalog.draw(11, Vector2i(i, 2 * i), 3, spec, 1.0)
		assert_eq(d.a, d.b)

func test_choose_follows_biome_affinity() -> void:
	var counts := {}
	var n := 4000
	for i in n:
		var a := TerrainRegimeCatalog.choose({&"twilight_marsh": 1.0}, (i + 0.5) / n)
		counts[a] = counts.get(a, 0) + 1
	var table: Dictionary = TerrainRegimeCatalog.AFFINITY[&"twilight_marsh"]
	var total := 0.0
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		total += maxf(TerrainRegimeCatalog.AFFINITY_FLOOR, float(table.get(a, 0.0)))
	var expected := maxf(TerrainRegimeCatalog.AFFINITY_FLOOR, float(table[&"low_flats"])) / total
	assert_almost_eq(float(counts[&"low_flats"]) / n, expected, 0.01)
