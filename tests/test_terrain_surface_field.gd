extends GutTest
const Field := preload("res://scripts/terrain/field/TerrainSurfaceField.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

# A synthetic region: cell (0,0) at storey 1 (height 4.0), everything else storey 0.
func _region() -> HeightfieldRegion:
	var plan := Plan.new(0, 32.0, 8, "mean")
	plan.set_raw_height_override(func(cx, cz):
		return 4.0 if (cx == 0 and cz == 0) else 0.0)
	return plan.compute_region(0, 0, 8)

func test_flat_at_cell_centre():
	var r := _region()
	# At the centre of cell (0,0) the surface equals that cell's plateau height.
	assert_almost_eq(Field.surface_y(r, 0.0, 0.0), r.surface_height(0, 0), 0.001)
	# At the centre of a neighbour cell, its own height.
	assert_almost_eq(Field.surface_y(r, 24.0, 0.0), r.surface_height(1, 0), 0.001)

func test_flat_interior_is_constant():
	var r := _region()
	# Within the inner half of cell (0,0) the top is flat (no ramp yet near centre).
	assert_almost_eq(Field.surface_y(r, 2.0, -2.0), r.surface_height(0, 0), 0.001)

func test_ramps_down_to_lower_cardinal():
	var r := _region()   # cell (0,0)=4.0, neighbours=0.0
	# Moving from cell (0,0) centre toward the +x edge, height descends monotonically
	# from 4.0 to 0.0 (the east neighbour's height) at the shared edge x=12.
	var prev := Field.surface_y(r, 0.0, 0.0)
	for i in range(1, 13):
		var y := Field.surface_y(r, float(i), 0.0)
		assert_lte(y, prev + 0.0001, "monotonic non-increasing toward lower edge")
		prev = y
	assert_almost_eq(Field.surface_y(r, 12.0, 0.0), 0.0, 0.01, "meets neighbour height at edge")

func test_lower_cell_flat_toward_higher_neighbour():
	var r := _region()
	# The east neighbour (1,0)=0.0 does NOT rise toward its higher neighbour (0,0):
	# its surface stays at 0.0 right up to the shared edge (seen from the low side).
	assert_almost_eq(Field.surface_y(r, 13.0, 0.0), 0.0, 0.001)
	assert_almost_eq(Field.surface_y(r, 23.999, 0.0), 0.0, 0.001)

func test_shared_edge_agrees_from_both_cells():
	var r := _region()
	# Sampled exactly on the boundary the value is single (cell assignment via round),
	# and approaching from both sides converges to the same height ⇒ no seam.
	var from_high := Field.surface_y(r, 11.99, 0.0)
	var from_low := Field.surface_y(r, 12.01, 0.0)
	assert_almost_eq(from_high, from_low, 0.05, "no discontinuity across the cell seam")

func _region_convex() -> HeightfieldRegion:
	# cell (0,0) high; the +x, +z, and +x+z neighbours are all lower → convex corner.
	var plan := Plan.new(0, 32.0, 8, "mean")
	plan.set_raw_height_override(func(cx, cz):
		return 4.0 if (cx <= 0 and cz <= 0) else 0.0)
	return plan.compute_region(0, 0, 8)

func _region_concave() -> HeightfieldRegion:
	# Only the diagonal (+x,+z) neighbour is lower; both cardinals equal height → concave.
	var plan := Plan.new(0, 32.0, 8, "mean")
	plan.set_raw_height_override(func(cx, cz):
		return 0.0 if (cx == 1 and cz == 1) else 4.0)
	return plan.compute_region(0, 0, 8)

func test_convex_corner_reaches_floor_at_vertex():
	var r := _region_convex()
	# At the far +x+z vertex of cell (0,0) the surface reaches the lower height.
	assert_almost_eq(Field.surface_y(r, 12.0, 12.0), 0.0, 0.05)

func test_convex_corner_edges_still_mate():
	var r := _region_convex()
	# Along the +x edge midline (z=0) it still descends to 0 at x=12 (edge seam intact).
	assert_almost_eq(Field.surface_y(r, 12.0, 0.0), 0.0, 0.05)

func test_concave_corner_only_far_vertex_dips():
	var r := _region_concave()
	# Cardinal edges of cell (0,0) toward equal-height neighbours stay flat...
	assert_almost_eq(Field.surface_y(r, 12.0, 0.0), 4.0, 0.05)
	assert_almost_eq(Field.surface_y(r, 0.0, 12.0), 4.0, 0.05)
	# ...only the far +x+z corner dips toward the lower diagonal cell.
	assert_lt(Field.surface_y(r, 11.5, 11.5), 4.0)
