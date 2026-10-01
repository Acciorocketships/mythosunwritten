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
