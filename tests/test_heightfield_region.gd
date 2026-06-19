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
