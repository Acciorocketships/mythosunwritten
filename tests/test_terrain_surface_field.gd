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

func test_level_t_junction_has_one_shared_seam_profile():
	# Reported level-lip shape (seed 2697992464 around cells (1,-61)..(1,-64)),
	# reduced to its smallest height pattern. A=(1,0), level 2, slopes south to
	# B=(1,1), level 1. B also slopes west to C=(0,1), level 0. Both A and B own
	# vertices on their shared z=12 seam, so they must compute the SAME Y at every
	# x sample. The old cell-local patch made A's edge a flat 4.5m while B's copy
	# dipped toward C, leaving the original photographed 0.5m lip.
	var plan := Plan.new(0, 64.0, 12, "mean")
	plan.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 1: return 4.1
		if cx == 1 and cz == 1: return 4.9
		return 5.6)
	var r := plan.compute_region(0, 0, 8)
	assert_eq(r.level_at(1, 0), 2, "A is level 2")
	assert_eq(r.level_at(1, 1), 1, "B is level 1")
	assert_eq(r.level_at(0, 1), 0, "C is level 0")
	for x in range(12, 37, 3):
		var from_a := Field.surface_y_in_cell(r, float(x), 12.0, 1, 0)
		var from_b := Field.surface_y_in_cell(r, float(x), 12.0, 1, 1)
		assert_almost_eq(from_a, from_b, 0.0001,
			"both tiles own one seam profile at x=%d (A %.3f, B %.3f)" % [x, from_a, from_b])

func test_level_surfaces_agree_across_every_non_cliff_edge_at_reported_seed():
	# Exact owner screenshot seed and neighbourhood. Test every sampled boundary
	# around both F3 pins, not only the synthetic T-junction above. Storey cliff
	# tops intentionally own a vertical discontinuity; every other edge must be
	# single-valued before the mesher sees it.
	var plan := Plan.new(2697992464, 22.0, 8, "mean", 3)
	var r := plan.compute_region(1, -63, 6)
	for cz in range(-67, -58):
		for cx in range(-2, 5):
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if Field.is_flat_cell(r, cx, cz) or Field.is_flat_cell(r, cx + d.x, cz + d.y):
					continue
				var bx := float(cx) * Field.TILE + float(d.x) * Field.HALF
				var bz := float(cz) * Field.TILE + float(d.y) * Field.HALF
				for i in 9:
					var t := (float(i) / 8.0) * 2.0 - 1.0
					var x := bx + float(d.y) * Field.HALF * t
					var z := bz + float(d.x) * Field.HALF * t
					var mine := Field.surface_y_in_cell(r, x, z, cx, cz)
					var theirs := Field.surface_y_in_cell(r, x, z, cx + d.x, cz + d.y)
					assert_almost_eq(mine, theirs, 0.0001,
						"reported seed seam (%d,%d)->%s sample %d" % [cx, cz, d, i])

func test_every_ordinary_edge_is_single_valued_across_varied_fields():
	# The invariant behind the fix is field-wide, not seed-specific. Exercise
	# ordinary storey and level slopes from several unrelated deterministic
	# fields. Only an edge explicitly classified as an exposed flat cliff may
	# have two heights (the rock skirt owns that vertical face).
	for world_seed in [17, 4242, 918273]:
		var plan := Plan.new(world_seed, 40.0, 8, "mean", 3)
		var r := plan.compute_region(0, 0, 7)
		for cz in range(-5, 5):
			for cx in range(-5, 5):
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					if Field.is_exposed_edge(r, cx, cz, d) \
						or Field.is_exposed_edge(r, cx + d.x, cz + d.y, -d):
						continue
					var bx := float(cx) * Field.TILE + float(d.x) * Field.HALF
					var bz := float(cz) * Field.TILE + float(d.y) * Field.HALF
					for i in 5:
						var t := (float(i) / 4.0) * 2.0 - 1.0
						var x := bx + float(d.y) * Field.HALF * t
						var z := bz + float(d.x) * Field.HALF * t
						var mine := Field.surface_y_in_cell(r, x, z, cx, cz)
						var theirs := Field.surface_y_in_cell(r, x, z, cx + d.x, cz + d.y)
						assert_almost_eq(mine, theirs, 0.0001,
							"seed %d ordinary seam (%d,%d)->%s sample %d" % [
								world_seed, cx, cz, d, i])

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

func test_walkability_is_derived_from_the_rendered_boundary():
	var slope := _region()
	assert_true(Field.is_walkable_edge(slope, Vector2i.ZERO, Vector2i.RIGHT),
		"an ordinary one-storey slope is walkable")
	assert_true(Field.is_walkable_edge(slope, Vector2i.RIGHT, Vector2i.LEFT),
		"edge ownership is symmetric")

	var cliff: HeightfieldRegion = _region_cliff()
	assert_false(Field.is_walkable_edge(cliff, Vector2i.ZERO, Vector2i.RIGHT),
		"a rendered cliff face is not walkable")
	assert_false(Field.is_walkable_edge(cliff, Vector2i.RIGHT, Vector2i.LEFT),
		"the low owner sees the same blocked edge")

	var level_plan := Plan.new(0, 32.0, 8, "mean")
	level_plan.set_raw_height_override(func(cx, cz):
		return 4.9 if cx <= 0 else 4.1)
	var level_region := level_plan.compute_region(0, 0, 8)
	assert_true(Field.is_walkable_edge(level_region, Vector2i.ZERO, Vector2i.RIGHT),
		"sub-storey level slopes are walkable")

func test_walkability_matches_exposed_edges_across_varied_fields():
	for world_seed in [17, 4242, 918273]:
		var plan := Plan.new(world_seed, 40.0, 8, "mean", 3)
		var region := plan.compute_region(-9, 7, 7)
		for cz in range(-14, -3):
			for cx in range(2, 13):
				for d in [Vector2i.RIGHT, Vector2i.DOWN]:
					var expected := not Field.is_exposed_edge(region, cx, cz, d) \
						and not Field.is_exposed_edge(region, cx + d.x, cz + d.y, -d)
					assert_eq(Field.is_walkable_edge(region, Vector2i(cx, cz), d), expected,
						"flat, slope, cliff, inner, diagonal, and higher-flat edges share one fact")
					assert_eq(Field.is_walkable_edge(region, Vector2i(cx, cz) + d, -d), expected,
						"walkability is translation- and direction-symmetric")

func test_inner_corner_stays_flat_not_a_slope():
	# Owner: a concave inner corner must be a vertical cliff, not a dipping slope. The high corner
	# cell (0,0) has level cardinal arms and a 1-storey diagonal pocket (1,1) that the arms wall.
	# Its SE quadrant must stay FLAT at the cell height (the cliff face spans the drop), NOT ramp
	# down into the notch.
	var plan := Plan.new(0, 32.0, 8, "mean", 3)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 8.0
		if cx == 2 and cz == 1: return 0.0
		if cx == 1 and cz == 2: return 0.0
		if cx == 2 and cz == 2: return 0.0
		return 12.0)
	var r = plan.compute_region(0, 0, 8)
	assert_almost_eq(Field.surface_y(r, 11.0, 11.0), 12.0, 0.05, "inner-corner cell stays flat into the notch corner")

func test_no_slope_dip_when_a_cardinal_arm_is_higher():
	# Owner's slope "discontinuity": a cell dipped toward a lower DIAGONAL even though one adjoining
	# cardinal arm was HIGHER (a cliff walls down to the cell) — which cracked the shared edge with
	# the flat neighbour. The cell must stay FLAT toward that corner. (0,0)=storey4; diagonal (1,1)=3
	# (1 lower); +x arm (1,0)=5 (HIGHER, a cliff); +z arm (0,1)=4 (level).
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 12.0   # lower diagonal
		if cx == 1 and cz == 0: return 20.0   # HIGHER +x arm (a cliff)
		if cx == 0 and cz == 2: return 8.0    # gives the level +z arm (0,1) its own ≥2 drop → flat cliff top
		return 16.0)                           # the cell and its level +z arm
	var r = plan.compute_region(0, 0, 8)
	assert_almost_eq(Field.surface_y_in_cell(r, 11.5, 11.5, 0, 0), 16.0, 0.05, "no dip toward the diagonal when an arm is higher")
	# the surface is continuous across the shared +z edge with the level (flat) arm (0,1) — no crack:
	assert_almost_eq(Field.surface_y_in_cell(r, 11.5, 12.0, 0, 0), Field.surface_y_in_cell(r, 11.5, 12.0, 0, 1), 0.05, "slope continuous across the shared edge")

func test_cell_below_a_cliff_stays_flat_and_the_cliff_walls_down():
	# Vertical cliffs: a cell one storey below a flat CLIFF TOP does NOT ramp up to meet it (that
	# lean-to ramp produced mounds/spikes). It stays flat at its OWN height and the cliff walls down
	# to it. (0,0)=4 (storey1); +x neighbour (1,0)=8 (storey2 cliff top, drops ≥2 to (2,0)=0).
	var plan := Plan.new(0, 32.0, 8, "mean", 3)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 0: return 8.0    # the cliff top
		if cx == 2 and cz == 0: return 0.0    # makes (1,0) a cliff top (≥2 drop)
		return 4.0)
	var r = plan.compute_region(0, 0, 8)
	assert_true(Field._is_cliff_top(r, 1, 0), "the +x neighbour is a cliff top")
	assert_almost_eq(Field.surface_y(r, 11.5, 0.0), 4.0, 0.05, "cell stays flat at its height (no up-ramp)")
	assert_true(Field._is_wall_edge(r, 1, 0, Vector2i(-1, 0)), "the cliff walls down to it (a vertical cliff)")

func test_no_mound_where_a_cell_sits_below_a_diagonal_cliff():
	# Owner's "weird mound": a storey-1 cell with a higher diagonal cliff-top neighbour used to bulge
	# UP toward it (the diagonal up-ramp) while dropping on its other corners — a mound. With no
	# up-ramp it stays at its own height. (0,0)=4; diagonal (1,1)=8 is a cliff top; (0,0) also has a
	# lower diagonal (-1,1)=0. The surface over (0,0) must never exceed its own height (4).
	var plan := Plan.new(0, 32.0, 8, "mean", 3)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 8.0    # higher diagonal
		if cx == 2 and cz == 2: return 0.0    # makes (1,1) a cliff top
		if cx == -1 and cz == 1: return 0.0   # a lower diagonal (the other corner)
		return 4.0)
	var r = plan.compute_region(0, 0, 8)
	for oz in [-11.0, -6.0, 0.0, 6.0, 11.0]:
		for ox in [-11.0, -6.0, 0.0, 6.0, 11.0]:
			assert_lte(Field.surface_y(r, ox, oz), 4.05, "no mound: surface never rises above the cell height")

# sample_baked(bake_cell(...)) must equal surface_y_in_cell(...) for every
# point, including pinned points past the cell edge (the mesher evaluates
# quad corners as-if belonging to the quad's own cell).
func test_baked_sampler_matches_surface_y_in_cell():
	var plan := HeightfieldPlan.new(4242, 40.0, 8, "mean", 3)
	var region: HeightfieldRegion = plan.compute_region(0, 0, 8)
	seed(12345)
	for cell_x in range(-6, 7):
		for cell_z in range(-6, 7):
			var baked := TerrainSurfaceField.bake_cell(region, cell_x, cell_z)
			for k in 8:
				var x := float(cell_x) * 24.0 + randf_range(-14.0, 14.0)
				var z := float(cell_z) * 24.0 + randf_range(-14.0, 14.0)
				assert_almost_eq(
					TerrainSurfaceField.sample_baked(baked, cell_x, cell_z, x, z),
					TerrainSurfaceField.surface_y_in_cell(region, x, z, cell_x, cell_z),
					0.0001,
					"cell (%d,%d) at (%.2f,%.2f)" % [cell_x, cell_z, x, z])
