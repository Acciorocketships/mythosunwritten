extends GutTest


func test_new_foundation_cannot_regrade_previously_sealed_ground() -> void:
	var original := TerrainGradePatch.new(&"sealed", {Vector2i.ZERO: 5.0}, Vector2.ZERO, 3.0)
	assert_null(original.with_foundation_pads([
		{"area": Rect2(-1,-1,2,2), "height": 4.0}], true))
	assert_eq(original.surface_y(Vector2.ZERO, 0), 5.0)
	var accepted := original.with_foundation_pads([
		{"area": Rect2(-1,-1,2,2), "height": 5.0}], true)
	assert_not_null(accepted)
	assert_eq(accepted.height_bounds(Rect2(-1,-1,2,2), Vector2(0,9)), Vector2(5,5))


func test_collar_uses_one_natural_length_slope_not_fine_cell_ripples() -> void:
	var patch := TerrainGradePatch.new(&"profile", {Vector2i.ZERO: 5.0}, Vector2.ZERO, 3.0)
	for index in range(1, 48):
		var distance := index * 0.25
		var expected := lerpf(5.0, 4.0, TerrainSurfaceField.transition_weight(distance))
		assert_almost_eq(patch.surface_y(Vector2(1.5 + distance, 0), 4.0), expected, 0.00001,
			"construction snapping must not shorten or restart the terrain curve")
	assert_almost_eq(patch.surface_y(Vector2(7.5, 0), 4), 4.5, 0.00001)


func test_unequal_pad_collars_do_not_switch_nearest_owner_at_a_ridge() -> void:
	var patch := TerrainGradePatch.new(&"two.pads",
		{Vector2i(-2,0): 4.0, Vector2i(2,0): 5.0}, Vector2.ZERO, 3.0)
	var previous := patch.surface_y(Vector2(-1, 5), 4.5)
	for index in range(1, 201):
		var x := -1.0 + index * 0.01
		var height := patch.surface_y(Vector2(x, 5), 4.5)
		assert_lt(absf(height - previous), 0.004,
			"a change of nearest owner must not create a narrow ridge")
		previous = height
	for x in range(-10, 11):
		var area := Rect2(Vector2(x, 3.7), Vector2(0.8, 1.9))
		var interval := patch.height_bounds(area, Vector2(4.5,4.5))
		for dz in 5:
			for dx in 5:
				var height := patch.surface_y(area.position + area.size * Vector2(dx,dz) / 4.0, 4.5)
				assert_true(height >= interval.x - 0.00001 and height <= interval.y + 0.00001,
					"foundation bounds must include all continuously blended boundary owners")


func test_grade_pins_claimed_cell_and_leaves_distant_nature_unchanged() -> void:
	var patch := TerrainGradePatch.new(&"test", {Vector2i.ZERO: 5.0},
		Vector2(1.5, -1.5), 3.0)
	for z in range(-6, 7):
		for x in range(-6, 7):
			var p := Vector2(1.5, -1.5) + Vector2(x, z) * 0.25
			assert_almost_eq(patch.surface_y(p, 4.0), 5.0, 0.00001)
	assert_eq(patch.surface_y(Vector2(30, 30), 3.25), 3.25)
	assert_eq(patch.height_bounds(Rect2(0, -3, 3, 3), Vector2(2, 9)),
		Vector2(5, 5), "a plateau has exact foundation bounds")


func test_grade_keeps_distinct_ground_bands_and_welds_cell_seams() -> void:
	var patch := TerrainGradePatch.new(&"bands",
		{Vector2i.ZERO: 4.0, Vector2i(1, 0): 7.0}, Vector2.ZERO, 3.0)
	assert_eq(patch.surface_y(Vector2.ZERO, 0), 4.0)
	assert_eq(patch.surface_y(Vector2(3, 0), 0), 7.0)
	for z in range(-6, 7):
		var left := patch.surface_y(Vector2(1.5 - 0.00001, z * 0.25), 0)
		var right := patch.surface_y(Vector2(1.5 + 0.00001, z * 0.25), 0)
		assert_almost_eq(left, right, 0.00001)


func test_baked_and_direct_ground_agree_and_bounds_enclose_collar() -> void:
	var levels: Dictionary = {}
	var storeys: Dictionary = {}
	for z in range(-3, 4):
		for x in range(-3, 4):
			storeys[Vector2i(x, z)] = 1
			levels[Vector2i(x, z)] = 0
	var natural := HeightfieldRegion.new(storeys, levels)
	var patch := TerrainGradePatch.new(&"offset", {Vector2i.ZERO: 5.08},
		Vector2(1.5, 1.5), 3.0)
	var region := natural.with_terrain_grades([patch])
	var bounds := TerrainTileField.height_bounds(region, Rect2(-12, -12, 24, 24))
	for z in range(-24, 25):
		for x in range(-24, 25):
			var px := x * 0.5
			var pz := z * 0.5
			var owner := Vector2i(TerrainTileField.point_of(px, region),
				TerrainTileField.point_of(pz, region))
			var height := TerrainTileField.surface_y(region, px, pz)
			assert_almost_eq(TerrainTileField.sample_baked(
				TerrainTileField.bake_point(region, owner), owner, px, pz, region),
				height, 0.00001)
			assert_true(height >= bounds.x - 0.00001 and height <= bounds.y + 0.00001)
	assert_eq(TerrainTileField.surface_y(natural, 1.5, 1.5), 4.0,
		"grading never mutates the shared natural planning region")


## The target controls go through TerrainTileField on a half-pitch lattice whose
## claim-edge and claim-corner points are the minimum of the claims meeting
## there. The lower claim therefore stays flat over its whole footprint and the
## transition to a higher claim lies wholly inside the higher claim (the lower
## pad controls the transition, as ordinary terrain always did).
func test_the_lower_claim_stays_flat_and_owns_no_transition() -> void:
	var patch := TerrainGradePatch.new(&"bands",
		{Vector2i.ZERO: 4.0, Vector2i(1, 0): 7.0, Vector2i(0, 1): 4.0, Vector2i(1, 1): 7.0},
		Vector2.ZERO, 3.0)
	for z in range(-15, 31):
		for x in range(-15, 16):
			assert_eq(patch.surface_y(Vector2(x * 0.1, z * 0.1), 0.0), 4.0,
				"the lower claim is flat at (%.1f, %.1f)" % [x * 0.1, z * 0.1])
	var previous := 4.0
	for i in range(1, 16):
		var height := patch.surface_y(Vector2(1.5 + i * 0.1, 1.5), 0.0)
		assert_gte(height, previous, "the higher claim rises monotonically from its edge")
		previous = height
	assert_eq(patch.surface_y(Vector2(3.0, 1.5), 0.0), 7.0)
	assert_eq(patch.height_bounds(Rect2(-1.5, -1.5, 3.0, 6.0), Vector2(0, 9)), Vector2(4, 4),
		"the lower claim's bounds are exact")
