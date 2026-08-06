extends GutTest


class WetHalfPlane extends WaterFieldContext:
	func covers(_point: Vector2) -> bool:
		return true

	func is_wet(point: Vector2) -> bool:
		return point.x > 0.0


func _flat_region() -> HeightfieldRegion:
	return _region(func(_cell: Vector2i) -> int: return 0)


func _terraced_region() -> HeightfieldRegion:
	return _region(func(cell: Vector2i) -> int:
		if cell.x <= -1:
			return 0
		if cell.x == 0:
			return 1
		return 2)


func _region(storey_for: Callable) -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-8, 9):
		for x in range(-8, 9):
			var cell := Vector2i(x, z)
			storeys[cell] = storey_for.call(cell)
			levels[cell] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_flat_survey_is_deterministic_and_naturally_supported() -> void:
	var region := _flat_region()
	var a := VillageTerrainSurvey.discover(VillageTerrainView.from_region(region),
		Vector2.ZERO,
		Vector2(4.5, 6.0), Vector2.RIGHT, 24.0, 48)
	var b := VillageTerrainSurvey.discover(VillageTerrainView.from_region(region),
		Vector2.ZERO,
		Vector2(4.5, 6.0), Vector2.RIGHT, 24.0, 48)
	assert_eq(a.size(), 48)
	assert_eq(a.size(), b.size())
	for index in a.size():
		assert_true(a[index].is_valid())
		assert_true(a[index].is_naturally_supported())
		assert_eq(a[index].candidate_key, b[index].candidate_key)
		assert_eq(a[index].anchor, b[index].anchor)
		assert_almost_eq(a[index].floor_y, b[index].floor_y, 0.0001)
	assert_almost_eq(a[0].vertical_span, 0.0, 0.0001)
	assert_eq(a[0].elevation_band_count, 1)


func test_terraced_survey_prefers_compact_useful_relief() -> void:
	var region := _terraced_region()
	var perches := VillageTerrainSurvey.discover(VillageTerrainView.from_region(
		region), Vector2.ZERO,
		Vector2(3.0, 3.0), Vector2.RIGHT, 42.0, 128)
	assert_false(perches.is_empty())
	var best := VillageTerrainSurvey.best_core(perches)
	assert_not_null(best)
	assert_gte(best.vertical_span,
		VillageTerrainSurvey.MIN_USEFUL_VERTICAL_SPAN)
	assert_lte(best.vertical_span,
		VillageTerrainSurvey.MAX_USEFUL_VERTICAL_SPAN)
	assert_gte(best.elevation_band_count, 3,
		"the compact neighbourhood exposes irregular terrain opportunities")
	assert_gt(best.useful_relief_score, 0.5)
	assert_lte(best.distance_from_arrival,
		VillageTerrainSurvey.DEFAULT_SEARCH_RADIUS)


func test_structural_variants_expand_after_the_bounded_terrain_result() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var profile := program.massing_program.vertical_profile
	var base := VillageTerrainSurvey.discover(VillageTerrainView.from_region(
		_terraced_region()), Vector2.ZERO, Vector2(3.0, 3.0),
		Vector2.RIGHT, 42.0, 32)
	var datum_y := VillageTerrainView.from_region(_terraced_region()).surface_y(
		Vector2.ZERO) + VillageTerrainSurvey.FLOOR_GUARD
	var expanded := VillageTerrainSurvey.expand_structural_variants(base,
		datum_y, profile, 2)
	assert_eq(base.size(), 32)
	assert_eq(expanded.size(), 96)
	for index in base.size():
		var base_index := index * 3
		assert_same(expanded[base_index], base[index])
		assert_eq(expanded[base_index + 1].architectural_band, 1)
		assert_eq(expanded[base_index + 2].architectural_band, 2)
		assert_almost_eq(expanded[base_index + 1].floor_y,
			profile.floor_for_band(datum_y, 1), 0.0001)
		assert_almost_eq(expanded[base_index + 2].floor_y,
			profile.floor_for_band(datum_y, 2), 0.0001)


func test_water_rejects_every_candidate_whose_footprint_crosses_it() -> void:
	var perches := VillageTerrainSurvey.discover(VillageTerrainView.from_region(
		_flat_region(), WetHalfPlane.new()), Vector2.ZERO, Vector2(3.0, 3.0),
		Vector2.RIGHT, 24.0, 128)
	assert_false(perches.is_empty())
	for perch: VillageTerrainPerch in perches:
		assert_lte(perch.anchor.x + perch.half_extents.x, 0.001,
			"water qualification covers the complete oriented footprint")


func test_survey_uses_conservative_bounds_without_mutating_the_region() -> void:
	var region := _terraced_region()
	var before: Dictionary = {}
	for z in range(-3, 4):
		for x in range(-3, 4):
			before[Vector2i(x, z)] = region.tile_plan(x, z)
	var perches := VillageTerrainSurvey.discover(VillageTerrainView.from_region(
		region), Vector2.ZERO,
		Vector2(3.0, 4.5), Vector2.RIGHT, 30.0, 64)
	for perch: VillageTerrainPerch in perches:
		var axes := [Vector2(cos(perch.yaw), -sin(perch.yaw)),
			Vector2(sin(perch.yaw), cos(perch.yaw))]
		var aabb_half: Vector2 = (axes[0] as Vector2).abs() \
			* perch.half_extents.x + (axes[1] as Vector2).abs() \
			* perch.half_extents.y
		var bounds := TerrainSurfaceField.height_bounds(region,
			Rect2(perch.anchor - aabb_half, aabb_half * 2.0))
		assert_almost_eq(perch.minimum_y, bounds.x, 0.0001)
		assert_almost_eq(perch.maximum_y, bounds.y, 0.0001)
	for cell: Vector2i in before:
		assert_eq(region.tile_plan(cell.x, cell.y), before[cell],
			"terrain survey must be read-only")
