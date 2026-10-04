extends GutTest

# Phase 3d: batched region computation must equal the per-cell reference path.

func test_region_storey_and_level_match_reference() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 48.0, 8, "mean")
	var region: HeightfieldRegion = plan.compute_region(7, -3, 4)
	for cz in range(-4, 5):
		for cx in range(-4, 5):
			var rcx: int = 7 + cx
			var rcz: int = -3 + cz
			assert_eq(region.storey_at(rcx, rcz), plan.storey_at(rcx, rcz),
				"batched storey == reference at (%d,%d)" % [rcx, rcz])
			assert_eq(region.level_at(rcx, rcz), plan.level_at(rcx, rcz),
				"batched level == reference at (%d,%d)" % [rcx, rcz])

func test_region_surface_height_and_tile_plan_match_reference() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(99, 60.0, 10, "mean")
	var region: HeightfieldRegion = plan.compute_region(0, 0, 3)
	for cz in range(-3, 4):
		for cx in range(-3, 4):
			assert_almost_eq(region.surface_height(cx, cz), plan.surface_height(cx, cz), 0.0001,
				"batched surface_height == reference at (%d,%d)" % [cx, cz])
			var rtp: Dictionary = region.tile_plan(cx, cz)
			var ptp: Dictionary = plan.tile_plan(cx, cz)
			assert_eq(rtp["storey"], ptp["storey"], "tile_plan storey matches")
			assert_eq(rtp["level"], ptp["level"], "tile_plan level matches")

func test_region_covers_one_tile_of_neighbours_beyond_radius() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 48.0, 8, "mean")
	var region: HeightfieldRegion = plan.compute_region(0, 0, 2)
	assert_eq(region.storey_at(3, 0), plan.storey_at(3, 0), "neighbour ring (radius+1) is valid")

func test_region_is_keyed_by_twelve_metre_points() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(4242, 48.0, 8, "mean")
	var region: HeightfieldRegion = plan.compute_region(2, -1, 3)
	assert_eq(region.terrain_tile_size(), 12.0, "a region reports its lattice pitch")
	assert_true(region.has_surface_point(2, -1), "a computed point has a surface")
	assert_false(region.has_surface_point(2000, 2000), "a far point has none")
	assert_eq(region.certified_points, Rect2i(Vector2i(-1, -4), Vector2i(7, 7)),
		"the certified interior is a rectangle of points")

func test_rect_region_matches_square_region_and_reference() -> void:
	var plan: HeightfieldPlan = HeightfieldPlan.new(99, 60.0, 10, "mean", 3)
	var square: HeightfieldRegion = plan.compute_region(1, 2, 3)
	var rect: HeightfieldRegion = plan.compute_rect_region(Rect2i(Vector2i(-2, -1), Vector2i(7, 7)))
	assert_eq(rect.certified_points, square.certified_points)
	for z in range(-1, 6):
		for x in range(-2, 5):
			assert_eq(rect.storey_at(x, z), square.storey_at(x, z), "storey (%d,%d)" % [x, z])
			assert_eq(rect.level_at(x, z), square.level_at(x, z), "level (%d,%d)" % [x, z])
			assert_eq(rect.storey_at(x, z), plan.storey_at(x, z), "reference storey (%d,%d)" % [x, z])

func test_native_control_heights_are_per_point() -> void:
	var region := HeightfieldRegion.new({Vector2i(0, 0): 0, Vector2i(1, 0): 0}, {Vector2i(0, 0): 0, Vector2i(1, 0): 0})
	region.native_control_heights[Vector2i(1, 0)] = 9.0
	assert_eq(region.surface_height(0, 0), 0.0, "an unrelated point keeps its natural height")
	assert_eq(region.surface_height(1, 0), 9.0, "the override applies to exactly its point")
	assert_eq(region.storey_at(1, 0), 2)
	assert_eq(region.level_at(1, 0), 1)


## Owner review, October 1 (seed 2697992464, the road at (696, 1146)): a road
## ran beside an 8 m wall 4 m from its edge; the cliff dressing met the road's
## keep-out in a sheer cut. Road verges lower such a point to one storey above
## the road, so the nearest wall rising from it is one point back.
static func _verge_region(carved := {}) -> HeightfieldRegion:
	var storeys := {}
	var levels := {}
	for z in range(-6, 7):
		for x in range(-6, 7):
			# The road runs along x = 0 (points), a cliff rises at x >= 1.
			storeys[Vector2i(x, z)] = 3 if x <= 0 else (6 if x == 1 else 7)
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels, carved)

static func _road_masks() -> Dictionary:
	var masks := {}
	for c in range(-2, 3):
		masks[Vector2i(0, c)] = 4 | 8   # route cells along +z / -z
	return masks

func test_road_verges_lower_a_cliff_beside_the_road() -> void:
	var region := _verge_region().with_road_verges(_road_masks())
	for z in range(-4, 5):
		assert_eq(region.storey_at(1, z), 4, "the verge at z=%d is one storey above the road" % z)
		assert_true(TerrainTileField.is_walkable_edge(region, Vector2i(0, z), Vector2i(1, 0)),
			"no cliff edge touches the road at z=%d" % z)
		assert_eq(region.storey_at(2, z), 7, "the cliff stands one point back")
		assert_true(TerrainTileField.is_cliff_edge(region, Vector2i(1, z), Vector2i(1, 0)))

func test_road_verges_never_raise_and_keep_water_and_existing_controls() -> void:
	# A road on the high side keeps its drop.
	var storeys := {}
	var levels := {}
	for z in range(-6, 7):
		for x in range(-6, 7):
			storeys[Vector2i(x, z)] = 6 if x <= 0 else 2
			levels[Vector2i(x, z)] = 0
	var high := HeightfieldRegion.new(storeys, levels)
	assert_same(high.with_road_verges(_road_masks()), high, "nothing to lower: the region itself")
	# Water points and points another control owns are left alone.
	var region := _verge_region({Vector2i(1, 0): true})
	region.native_control_heights[Vector2i(1, 2)] = 24.0
	var verged := region.with_road_verges(_road_masks())
	assert_eq(verged.storey_at(1, 0), 6, "a water point keeps its height")
	assert_eq(verged.storey_at(1, 2), 6, "a controlled point keeps its control")
	assert_eq(verged.storey_at(1, 1), 4)
