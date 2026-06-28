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

func test_slope_ramps_over_full_half_cell():
	# A 1-storey slope must ramp the WHOLE half-cell like the old SlopeProfile.edge_height
	# (4m drop over CELL=12u ≈ 18°), NOT cram it into the outer ~6u (≈34°, angular & hard
	# to climb). At the half-way point (x=6 toward the lower +x edge) the surface should be
	# ~half-dropped (≈2.0), and it must already be descending well before the outer band.
	var r := _region()   # cell (0,0)=4.0, neighbours 0.0
	assert_almost_eq(Field.surface_y(r, 6.0, 0.0), 2.0, 0.3, "half-way along the slope is ~half-dropped")
	assert_lt(Field.surface_y(r, 3.0, 0.0), 3.9, "already descending in the inner half (gentle full-width ramp)")

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

func _region_cliff():
	# cell (0,0) at storey 3 (12m); +x neighbour at storey 0 (a 3-storey cliff). max_step=3.
	var plan := Plan.new(0, 32.0, 8, "mean", 3)
	plan.set_raw_height_override(func(cx, cz):
		return 12.0 if cx <= 0 else 0.0)
	return plan.compute_region(0, 0, 8)

func test_cliff_top_is_flat_to_edge():
	var r: HeightfieldRegion = _region_cliff()
	# Across the whole cell toward the +x cliff edge the top stays at 12.0 (no ramp).
	assert_almost_eq(Field.surface_y(r, 0.0, 0.0), 12.0, 0.01)
	assert_almost_eq(Field.surface_y(r, 11.9, 0.0), 12.0, 0.01, "flat right up to the cliff edge")

func test_one_storey_neighbour_still_ramps():
	# Reuse the existing 1-storey region: it must still slope (SP1 behaviour preserved).
	var r := _region()    # cell (0,0)=4.0, neighbours 0.0  (from earlier tests)
	assert_lt(Field.surface_y(r, 11.9, 0.0), 4.0, "1-storey drop still ramps")

const RealPlan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

func test_no_cell_makes_a_dipping_slope_over_one_storey():
	# Owner round 5: a cell must never produce a "dipping slope" that spans more than one storey
	# (4m). A cliff top is flat; a non-cliff cell only ramps DOWN ≤1 storey (no up-ramp bulge to
	# a higher cliff). So every cell's surface range is ≤4m. Checked across several real seeds.
	for seed in [1, 7, 13, 42, 99, 20260628]:
		var plan := RealPlan.new(seed, 22.0, 8, "mean", 3)
		var region = plan.compute_region(0, 0, 16)
		for cz in range(-7, 8):
			for cx in range(-7, 8):
				var lo := 1e9
				var hi := -1e9
				for oz in [-11.0, -5.0, 0.0, 5.0, 11.0]:
					for ox in [-11.0, -5.0, 0.0, 5.0, 11.0]:
						var y := Field.surface_y(region, cx * 24.0 + ox, cz * 24.0 + oz)
						lo = minf(lo, y)
						hi = maxf(hi, y)
				assert_lte(hi - lo, 4.05,
					"seed %d cell (%d,%d) surface spans >1 storey (dipping slope)" % [seed, cx, cz])
