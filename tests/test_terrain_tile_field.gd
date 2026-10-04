extends GutTest

## Dual-grid terrain tiles (docs/superpowers/specs/2026-09-30-dual-grid-terrain-tiles-design.md):
## heights live on 12 m lattice points; each tile's shape is a function of its
## four corners (and the edge categories those corners imply).

const Tile := preload("res://scripts/terrain/field/TerrainTileField.gd")
const Region := preload("res://tests/fixtures/tile_point_region.gd")
const EPS := 0.0001

var _saved_end: int


func before_each() -> void:
	_saved_end = Tile.cliff_end
	Tile.cliff_end = Tile.CliffEnd.E2


func after_each() -> void:
	Tile.cliff_end = _saved_end


static func _s(t: float) -> float:
	return SlopeProfile.smootherstep(t)


static func _bilinear(a: float, b: float, c: float, d: float, u: float, v: float) -> float:
	var su := _s(u)
	var sv := _s(v)
	return lerpf(lerpf(a, b, su), lerpf(d, c, su), sv)


func test_slope_only_tile_is_bilinear_smootherstep_of_its_corners() -> void:
	# Property 3: every non-saddle tile whose crossings are all slopes (at most
	# one storey apart) is exactly today's quarter-cell formula.
	var cases := [[0.0, 4.0, 4.0, 0.0], [0.0, 4.0, 5.0, 3.0], [2.0, 2.0, 5.0, 2.0],
		[4.0, 5.0, 7.0, 6.0], [0.0, 1.0, 3.0, 2.0], [4.0, 4.0, 4.0, 0.0]]
	for h: Array in cases:
		var region = Region.tile(h[0], h[1], h[2], h[3])
		for iu in 7:
			for iv in 7:
				var u := float(iu) / 6.0
				var v := float(iv) / 6.0
				assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, u, v),
					_bilinear(h[0], h[1], h[2], h[3], u, v), EPS, "%s at %s,%s" % [h, u, v])


func test_one_storey_step_spans_the_whole_tile_with_the_smootherstep_profile() -> void:
	var region = Region.tile(4.0, 0.0, 0.0, 4.0)
	assert_almost_eq(Tile.surface_y(region, 0.0, 6.0), 4.0, EPS)
	assert_almost_eq(Tile.surface_y(region, 6.0, 6.0), 2.0, EPS)
	assert_almost_eq(Tile.surface_y(region, 3.0, 6.0), 4.0 - 4.0 * _s(0.25), EPS)
	assert_almost_eq(Tile.surface_y(region, 12.0, 6.0), 0.0, EPS)


func test_pure_cliff_tiles_take_the_nearest_corner_height() -> void:
	# Outer, straight and inner corners with every crossing a cliff: the
	# marching-squares outline has its crossings at the edge midpoints, so each
	# 6 m quadrant is flat at its own corner's height. Exact under both cliff-end
	# rules (a layer that crosses only cliffs has no slope end), including at far
	# quadrant points right beside the tile centre.
	var points := [[0.2, 0.3, 0], [0.8, 0.1, 1], [0.7, 0.9, 2], [0.1, 0.6, 3],
		[0.48, 0.48, 0], [0.52, 0.48, 1], [0.52, 0.52, 2], [0.48, 0.52, 3],
		[0.52, 0.02, 1], [0.98, 0.52, 2], [0.48, 0.98, 3], [0.02, 0.48, 0],
		[0.50002, 0.51, 2], [0.49998, 0.51, 3], [0.50002, 0.49, 1], [0.49998, 0.49, 0],
		[0.51, 0.50002, 2], [0.51, 0.49998, 1], [0.49, 0.50002, 3], [0.49, 0.49998, 0]]
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2]:
		Tile.cliff_end = mode
		for h: Array in [[8.0, 0.0, 0.0, 0.0], [8.0, 0.0, 0.0, 8.0], [8.0, 8.0, 0.0, 8.0],
				[16.0, 8.0, 0.0, 8.0], [0.0, 8.0, 8.0, 8.0], [0.0, 0.0, 8.0, 0.0]]:
			var region = Region.tile(h[0], h[1], h[2], h[3])
			var gap: float = maxf(maxf(h[0], h[1]), maxf(h[2], h[3])) - minf(minf(h[0], h[1]), minf(h[2], h[3]))
			for q: Array in points:
				assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, q[0], q[1]), float(h[q[2]]), 1e-6 * gap,
					"mode %s %s quadrant %s at %s,%s" % [mode, h, q[2], q[0], q[1]])


func test_three_storey_cliff_is_one_vertical_wall_at_the_tile_midline() -> void:
	var region = Region.tile(12.0, 0.0, 0.0, 12.0)
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.4999, 0.5), 12.0, EPS)
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.5001, 0.5), 0.0, EPS)
	var walls: Array = Tile.wall_segments(region, Rect2(1.0, 1.0, 10.0, 10.0))
	assert_eq(walls.size(), 2, "two 6 m half segments on the x = 6 midline")
	for wall: Dictionary in walls:
		assert_almost_eq(wall.a.x, 6.0, EPS)
		assert_almost_eq(wall.b.x, 6.0, EPS)
		assert_almost_eq(wall.top.x, 12.0, EPS)
		assert_almost_eq(wall.bottom.x, 0.0, EPS)
		assert_eq(wall.high, Vector2i(0, wall.high.y))


func test_slope_saddle_keeps_the_two_high_corners_separate() -> void:
	var region = Region.tile(4.0, 0.0, 4.0, 0.0)
	var centre := Tile.tile_y(region, Vector2i.ZERO, 0.5, 0.5)
	assert_almost_eq(centre, 4.0 * 0.25, EPS, "max of the two bumps, not their sum")
	# On every edge the saddle equals the ordinary slope profile.
	for i in 9:
		var t := float(i) / 8.0
		assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, t, 0.0), 4.0 * (1.0 - _s(t)), EPS)
		assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 1.0, t), 4.0 * _s(t), EPS)


func test_cliff_saddle_is_two_squares_touching_at_the_centre() -> void:
	var region = Region.tile(8.0, 0.0, 8.0, 0.0)
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.25, 0.25), 8.0, EPS)
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.75, 0.75), 8.0, EPS)
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.75, 0.25), 0.0, EPS)
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.25, 0.75), 0.0, EPS)


func test_level_steps_are_slopes() -> void:
	var region = Region.tile(3.0, 0.0, 0.0, 3.0)
	assert_eq(Tile.edge_category(region, Vector2i(0, 0), Vector2i(1, 0)), Tile.EdgeCategory.LEVEL)
	assert_true(Tile.is_walkable_edge(region, Vector2i(0, 0), Vector2i(1, 0)))
	assert_almost_eq(Tile.surface_y(region, 6.0, 3.0), 1.5, EPS)


func test_edge_categories_follow_the_two_endpoints() -> void:
	var region = Region.new({Vector2i(1, 0): 0.0, Vector2i(2, 0): 4.0,
		Vector2i(3, 0): 13.0, Vector2i(4, 0): 13.0})
	assert_eq(Tile.edge_category(region, Vector2i(3, 0), Vector2i(1, 0)), Tile.EdgeCategory.FLAT)
	assert_eq(Tile.edge_category(region, Vector2i(1, 0), Vector2i(1, 0)), Tile.EdgeCategory.SLOPE)
	assert_eq(Tile.edge_category(region, Vector2i(2, 0), Vector2i(1, 0)), Tile.EdgeCategory.CLIFF)
	assert_false(Tile.is_walkable_edge(region, Vector2i(3, 0), Vector2i(-1, 0)))


func test_e2_cliff_end_walls_to_the_tile_centre_then_shortens() -> void:
	# Bottom edge a-b is a cliff (0 vs 8), top edge d-c a slope (8 vs 4).
	var region = Region.tile(8.0, 0.0, 4.0, 8.0)
	# A full wall on the lower half of the midline, high side level.
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.49, 0.2), 8.0, EPS)
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.2, 0.45), 8.0, EPS)
	var low := Tile.tile_y(region, Vector2i.ZERO, 0.51, 0.2)
	assert_lt(low, 1.0, "the low side of the wall")
	# The top edge is exactly the neighbour's slope profile.
	for i in 9:
		var t := float(i) / 8.0
		assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, t, 1.0), lerpf(8.0, 4.0, _s(t)), EPS)
	# The high side stays level beside the full wall (no E1-style dip).
	for iv in 6:
		var y := Tile.tile_y(region, Vector2i.ZERO, 0.2, float(iv) / 10.0)
		assert_almost_eq(y, 8.0, EPS)
	# Past the centre the wall shortens smoothly to nothing at the slope edge.
	var previous := INF
	for iv in range(5, 11):
		var v := float(iv) / 10.0
		var jump := Tile.tile_y(region, Vector2i.ZERO, 0.4999, v) - Tile.tile_y(region, Vector2i.ZERO, 0.5001, v)
		assert_lt(jump, previous + EPS, "the wall only shortens toward the slope edge")
		previous = jump
	assert_almost_eq(previous, 0.0, 0.01, "no wall left at the slope edge")
	# ...nor within the last fifth of the tile: a road crossing the slope edge
	# (4 m wide) meets no step.
	for iv in range(81, 101):
		var v := float(iv) / 100.0
		var jump := Tile.tile_y(region, Vector2i.ZERO, 0.4999, v) - Tile.tile_y(region, Vector2i.ZERO, 0.5001, v)
		assert_almost_eq(jump, 0.0, 0.01, "no wall at v = %.2f" % v)
	# No notch beside the wall's end (owner review, October 1): the former
	# fan, centimetres wide there, dropped the plateau by metres within the
	# last metre before the wall line. The high side may descend no steeper
	# than a one-storey slope does.
	for iv in range(5, 11):
		var v := float(iv) / 10.0
		var crease := Tile.tile_y(region, Vector2i.ZERO, 0.45, v) - Tile.tile_y(region, Vector2i.ZERO, 0.4999, v)
		assert_lt(crease, 0.8, "a crease beside the wall's end at v = %.1f" % v)


func test_e1_cliff_end_shortens_the_wall_across_the_tile() -> void:
	Tile.cliff_end = Tile.CliffEnd.E1
	# Bottom edge a-b is a cliff, top edge d-c a one-storey slope.
	var region = Region.tile(8.0, 0.0, 4.0, 8.0)
	var jump_bottom := Tile.tile_y(region, Vector2i.ZERO, 0.4999, 0.0) \
		- Tile.tile_y(region, Vector2i.ZERO, 0.5001, 0.0)
	var jump_mid := Tile.tile_y(region, Vector2i.ZERO, 0.4999, 0.5) \
		- Tile.tile_y(region, Vector2i.ZERO, 0.5001, 0.5)
	assert_almost_eq(jump_bottom, 8.0, 0.01)
	assert_between(jump_mid, 0.5, 7.5, "the wall shortens across the tile")
	assert_lt(Tile.tile_y(region, Vector2i.ZERO, 0.25, 0.5), 8.0, "the high side dips")


func test_shared_edges_are_seamless_over_random_fields() -> void:
	var rng := RandomNumberGenerator.new()
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2]:
		Tile.cliff_end = mode
		rng.seed = 42
		for trial in 40:
			var heights := {}
			for j in 3:
				for i in 3:
					heights[Vector2i(i, j)] = float(rng.randi_range(0, 3)) * 4.0 + float(rng.randi_range(0, 3))
			var region = Region.new(heights)
			for k in 13:
				var t := float(k) / 12.0
				# vertical shared edge x = 12 between tiles (0,j) and (1,j)
				for j in 2:
					assert_almost_eq(Tile.tile_y(region, Vector2i(0, j), 1.0, t),
						Tile.tile_y(region, Vector2i(1, j), 0.0, t), EPS, "x-seam %s" % heights)
				for i in 2:
					assert_almost_eq(Tile.tile_y(region, Vector2i(i, 0), t, 1.0),
						Tile.tile_y(region, Vector2i(i, 1), t, 0.0), EPS, "z-seam %s" % heights)


func test_tiles_stay_within_their_corner_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2]:
		Tile.cliff_end = mode
		for trial in 60:
			var h: Array[float] = []
			for c in 4:
				h.append(float(rng.randi_range(0, 3)) * 4.0 + float(rng.randi_range(0, 3)))
			var region = Region.tile(h[0], h[1], h[2], h[3])
			for iu in 9:
				for iv in 9:
					var y := Tile.tile_y(region, Vector2i.ZERO, float(iu) / 8.0, float(iv) / 8.0)
					assert_between(y, h.min() - EPS, h.max() + EPS)


func test_surface_y_on_side_resolves_a_wall_to_its_owner() -> void:
	var region = Region.tile(8.0, 0.0, 0.0, 8.0)
	assert_almost_eq(Tile.surface_y_on_side(region, 6.0, 3.0, Vector2i(0, 0)), 8.0, EPS)
	assert_almost_eq(Tile.surface_y_on_side(region, 6.0, 3.0, Vector2i(1, 0)), 0.0, EPS)
	# A point past the owner's dual cell is clamped onto its border.
	assert_almost_eq(Tile.surface_y_on_side(region, 9.0, 3.0, Vector2i(0, 0)), 8.0, EPS)


func test_baked_sampler_matches_surface_y_on_side() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var heights := {}
	for j in range(-1, 4):
		for i in range(-1, 4):
			heights[Vector2i(i, j)] = float(rng.randi_range(0, 3)) * 4.0 + float(rng.randi_range(0, 2))
	var region = Region.new(heights)
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2]:
		Tile.cliff_end = mode
		for pj in range(0, 3):
			for pi in range(0, 3):
				var p := Vector2i(pi, pj)
				var baked := Tile.bake_point(region, p)
				for k in 49:
					var x := 12.0 * pi - 6.0 + 12.0 * float(k % 7) / 6.0
					var z := 12.0 * pj - 6.0 + 12.0 * float(k / 7) / 6.0
					assert_almost_eq(Tile.sample_baked(baked, p, x, z, region),
						Tile.surface_y_on_side(region, x, z, p), EPS)


func test_height_bounds_contain_dense_samples() -> void:
	var rng := RandomNumberGenerator.new()
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2]:
		Tile.cliff_end = mode
		rng.seed = 5
		var heights := {}
		for j in range(-1, 5):
			for i in range(-1, 5):
				heights[Vector2i(i, j)] = float(rng.randi_range(0, 3)) * 4.0 + float(rng.randi_range(0, 3))
		var region = Region.new(heights)
		for rect in [Rect2(1.0, 2.0, 7.0, 5.0), Rect2(-3.0, 4.5, 30.0, 17.0), Rect2(13.0, 13.0, 2.0, 2.0)]:
			var bounds := Tile.height_bounds(region, rect)
			for iz in 25:
				for ix in 25:
					var x: float = rect.position.x + rect.size.x * float(ix) / 24.0
					var z: float = rect.position.y + rect.size.y * float(iz) / 24.0
					var y := Tile.surface_y(region, x, z)
					assert_between(y, bounds.x - EPS, bounds.y + EPS, "mode %s %s at %s,%s" % [mode, rect, x, z])


func test_height_bounds_are_sound_on_pure_cliff_fields() -> void:
	# Heights in multiples of 8 m: every crossing is a cliff. Small rects inside
	# each quadrant, beside the tile centre, must bound the samples taken there.
	var rng := RandomNumberGenerator.new()
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2]:
		Tile.cliff_end = mode
		rng.seed = 9
		var heights := {}
		for j in range(-1, 5):
			for i in range(-1, 5):
				heights[Vector2i(i, j)] = float(rng.randi_range(0, 3)) * 8.0
		var region = Region.new(heights)
		for tj in 3:
			for ti in 3:
				for q in 4:
					var x0 := 12.0 * ti + (6.5 if (q & 1) == 1 else 0.5) + 0.0
					var z0 := 12.0 * tj + (6.5 if (q >> 1) == 1 else 0.5)
					# Quadrant-local rect hugging the centre corner.
					var rx := x0 + (0.0 if (q & 1) == 1 else 4.0)
					var rz := z0 + (0.0 if (q >> 1) == 1 else 4.0)
					var rect := Rect2(rx, rz, 1.0, 1.0)
					var bounds := Tile.height_bounds(region, rect)
					for iz in 5:
						for ix in 5:
							var x := rx + float(ix) / 4.0
							var z := rz + float(iz) / 4.0
							assert_between(Tile.surface_y(region, x, z), bounds.x - EPS, bounds.y + EPS,
								"mode %s tile %s,%s quadrant %s at %s,%s" % [mode, ti, tj, q, x, z])


func test_height_bounds_are_exact_on_a_flat_or_single_slope_footprint() -> void:
	var flat = Region.new({}, 4.0)
	assert_eq(Tile.height_bounds(flat, Rect2(-4.0, -3.0, 8.0, 6.0)), Vector2(4.0, 4.0))
	var slope = Region.tile(4.0, 0.0, 0.0, 4.0)
	var bounds := Tile.height_bounds(slope, Rect2(0.0, 1.0, 6.0, 4.0))
	assert_almost_eq(bounds.x, 2.0, EPS)
	assert_almost_eq(bounds.y, 4.0, EPS)


func test_surface_y_takes_the_high_index_side_on_a_midline_wall() -> void:
	# The u > 0.5 corner owns the midline, for positive and negative coordinates.
	assert_eq(Tile.point_of(6.0), 1)
	assert_eq(Tile.point_of(-6.0), 0)
	assert_eq(Tile.point_of(5.999), 0)
	assert_eq(Tile.point_of(-6.001), -1)
	var east = Region.tile(12.0, 0.0, 0.0, 12.0)
	assert_almost_eq(Tile.surface_y(east, 6.0, 3.0), 0.0, EPS, "x = 6: point 1 (low) owns the wall")
	var west = Region.new({Vector2i(-1, 0): 0.0, Vector2i(-1, 1): 0.0,
		Vector2i(0, 0): 12.0, Vector2i(0, 1): 12.0}, 0.0)
	assert_almost_eq(Tile.surface_y(west, -6.0, 3.0), 12.0, EPS, "x = -6: point 0 (high) owns the wall")


func test_wall_segments_e2_cliff_end_shortens_on_the_upper_half() -> void:
	# Bottom edge a-b is a cliff, the top edge a slope: the full wall covers the
	# lower half of the x = 6 midline, the upper half carries the shortening
	# wall, down to nothing at the slope edge.
	var region = Region.tile(8.0, 0.0, 4.0, 8.0)
	var lower: Array = Tile.wall_segments(region, Rect2(5.0, 1.0, 2.0, 4.0))
	assert_eq(lower.size(), 1)
	assert_eq(lower[0].a, Vector2(6.0, 0.0))
	assert_eq(lower[0].b, Vector2(6.0, 6.0))
	assert_eq(lower[0].high, Vector2i(0, 0))
	assert_eq(lower[0].low, Vector2i(1, 0))
	assert_almost_eq(lower[0].top.x, 8.0, EPS)
	assert_almost_eq(lower[0].bottom.x, 0.0, EPS)
	var upper: Array = Tile.wall_segments(region, Rect2(5.0, 7.0, 2.0, 4.0))
	assert_eq(upper.size(), 1)
	assert_eq(upper[0].high, Vector2i(0, 1))
	assert_almost_eq(upper[0].top.x - upper[0].bottom.x, lower[0].top.y - lower[0].bottom.y, 0.05,
		"the wall continues across the tile centre")
	assert_almost_eq(upper[0].top.y - upper[0].bottom.y, 0.0, 0.01, "nothing at the slope edge")


func test_wall_segments_cliff_saddle_has_four_half_segments_at_the_centre() -> void:
	var region = Region.tile(8.0, 0.0, 8.0, 0.0)
	var walls: Array = Tile.wall_segments(region, Rect2(4.0, 4.0, 4.0, 4.0))
	assert_eq(walls.size(), 4)
	var highs := {}
	for wall: Dictionary in walls:
		assert_almost_eq(wall.top.x, 8.0, EPS)
		assert_almost_eq(wall.bottom.x, 0.0, EPS)
		assert_true(wall.a == Vector2(6.0, 6.0) or wall.b == Vector2(6.0, 6.0), "every half meets the centre")
		highs[wall.high] = true
		assert_almost_eq(Vector2(wall.high).distance_to(Vector2(wall.low)), 1.0, EPS)
		assert_eq(wall.normal, (Vector2(wall.low) - Vector2(wall.high)))
	assert_eq(highs.size(), 2, "only the two high corners own walls")
	assert_true(highs.has(Vector2i(0, 0)) and highs.has(Vector2i(1, 1)))


func test_wall_segments_name_the_high_owner_when_p_is_the_low_side() -> void:
	var region = Region.tile(0.0, 8.0, 8.0, 0.0)
	var walls: Array = Tile.wall_segments(region, Rect2(5.0, 1.0, 2.0, 10.0))
	assert_eq(walls.size(), 2)
	for wall: Dictionary in walls:
		assert_eq(wall.high.x, 1)
		assert_eq(wall.low.x, 0)
		assert_eq(wall.normal, Vector2(-1.0, 0.0))
		assert_almost_eq(wall.top.x, 8.0, EPS)
		assert_almost_eq(wall.bottom.x, 0.0, EPS)


func test_wall_segments_find_walls_on_a_rect_edge_at_the_midline() -> void:
	var region = Region.tile(12.0, 0.0, 0.0, 12.0)
	assert_eq(Tile.wall_segments(region, Rect2(6.0, 1.0, 5.0, 10.0)).size(), 2, "rect starts on x = 6")
	assert_eq(Tile.wall_segments(region, Rect2(1.0, 1.0, 5.0, 10.0)).size(), 2, "rect ends on x = 6")


# --- owner-side bounds (kernel) ------------------------------------------------------

func test_height_bounds_on_side_exclude_the_neighbouring_top_of_a_wall() -> void:
	var region = Region.tile(12.0, 0.0, 0.0, 12.0)   # straight cliff on x = 6
	var west := Rect2(2.0, 1.0, 4.0, 4.0)            # inside point 0's dual cell, touching x = 6
	var east := Rect2(6.0, 1.0, 4.0, 4.0)            # inside point 1's dual cell
	assert_eq(Tile.height_bounds_on_side(region, west, Vector2i(0, 0)), Vector2(12.0, 12.0))
	assert_eq(Tile.height_bounds_on_side(region, east, Vector2i(1, 0)), Vector2(0.0, 0.0))
	assert_eq(Tile.height_bounds(region, Rect2(4.0, 1.0, 4.0, 4.0)), Vector2(0.0, 12.0),
		"the plain bound sees both tops")


func test_height_bounds_on_side_are_sound_over_random_fields() -> void:
	var rng := RandomNumberGenerator.new()
	for mode in [Tile.CliffEnd.E1, Tile.CliffEnd.E2]:
		Tile.cliff_end = mode
		rng.seed = 21
		var heights := {}
		for j in range(-1, 4):
			for i in range(-1, 4):
				heights[Vector2i(i, j)] = float(rng.randi_range(0, 3)) * 4.0 + float(rng.randi_range(0, 3))
		var region = Region.new(heights)
		for owner: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 2)]:
			var cx := 12.0 * owner.x
			var cz := 12.0 * owner.y
			for rect: Rect2 in [Rect2(cx - 6.0, cz - 6.0, 12.0, 12.0), Rect2(cx - 6.0, cz - 2.0, 3.0, 4.0),
					Rect2(cx + 1.0, cz + 2.0, 5.0, 4.0), Rect2(cx - 6.0, cz - 6.0, 6.0, 6.0)]:
				var bounds := Tile.height_bounds_on_side(region, rect, owner)
				for iz in 13:
					for ix in 13:
						var x: float = rect.position.x + rect.size.x * float(ix) / 12.0
						var z: float = rect.position.y + rect.size.y * float(iz) / 12.0
						assert_between(Tile.surface_y_on_side(region, x, z, owner), bounds.x - EPS, bounds.y + EPS,
							"mode %s owner %s %s at %s,%s" % [mode, owner, rect, x, z])


# --- point lattice, border profiles and one-sided bounds ------------------------------

func test_point_lattice_and_transition_weight() -> void:
	assert_eq(Tile.SPACING, 12.0)
	assert_eq(Tile.spacing(), 12.0)
	assert_eq(Tile.point_of(5.99), 0)
	assert_eq(Tile.point_of(6.0), 1)
	assert_eq(Tile.point_of(-6.0), 0)
	assert_almost_eq(Tile.transition_weight(6.0), 0.5, EPS, "a slope spans the whole 12 m tile")
	assert_almost_eq(Tile.transition_weight(12.0), 1.0, EPS)


func test_edge_predicates_follow_the_points() -> void:
	var region = Region.tile(12.0, 4.0, 4.0, 12.0)
	# (0,0)=12 (1,0)=4: two storeys -> cliff; (0,0)-(0,1): both 12 -> flat.
	assert_true(Tile.is_cliff_edge(region, Vector2i(0, 0), Vector2i(1, 0)))
	assert_true(Tile.is_wall_edge(region, Vector2i(0, 0), Vector2i(1, 0)))
	assert_false(Tile.is_wall_edge(region, Vector2i(1, 0), Vector2i(-1, 0)), "the low side carries no wall")
	assert_false(Tile.is_cliff_edge(region, Vector2i(0, 0), Vector2i(0, 1)))
	assert_false(Tile.is_walkable_edge(region, Vector2i(0, 0), Vector2i(1, 0)))
	assert_false(Tile.is_walkable_edge(region, Vector2i(1, 0), Vector2i(-1, 0)))
	assert_true(Tile.is_walkable_edge(region, Vector2i(0, 0), Vector2i(0, 1)))


func test_is_exposed_edge_on_a_straight_cliff() -> void:
	# Points with i <= 0 stand at 12, points with i >= 1 at 0: a straight wall on x = 6.
	var heights := {}
	for j in range(-2, 3):
		heights[Vector2i(0, j)] = 12.0
		heights[Vector2i(-1, j)] = 12.0
	var region = Region.new(heights, 0.0)
	for j in range(-1, 2):
		assert_true(Tile.is_exposed_edge(region, Vector2i(0, j), Vector2i(1, 0)), "the high side of the wall is exposed")
		assert_false(Tile.is_exposed_edge(region, Vector2i(1, j), Vector2i(-1, 0)), "the low side is not")
		assert_false(Tile.is_exposed_edge(region, Vector2i(0, j), Vector2i(0, 1)), "a border along a flat neighbour is not")
		assert_false(Tile.is_exposed_edge(region, Vector2i(0, j), Vector2i(-1, 0)))
	# A one-storey slope is no wall: the neighbour never falls EXPOSE_EPS below a flat own border.
	var slope = Region.new({Vector2i(0, 0): 4.0, Vector2i(0, 1): 4.0, Vector2i(0, -1): 4.0}, 0.0)
	assert_false(Tile.is_exposed_edge(slope, Vector2i(0, 0), Vector2i(1, 0)), "own border already slopes away")


func test_edge_profile_runs_along_pdir() -> void:
	# A wall on x = 6 whose low side steps up toward +z: the neighbour profile
	# must start low (-pdir end, z = -6) and end high (+pdir end, z = +6).
	var region = Region.new({Vector2i(0, -1): 12.0, Vector2i(0, 0): 12.0, Vector2i(0, 1): 12.0,
		Vector2i(1, -1): 0.0, Vector2i(1, 0): 0.0, Vector2i(1, 1): 4.0}, 0.0)
	var d := Vector2i(1, 0)
	var profile := Tile.edge_profile(region, Vector2i(0, 0), d, 8)
	assert_eq(profile.size(), 9)
	assert_almost_eq(profile[0], Tile.surface_y_on_side(region, 6.0, -6.0, Vector2i(1, 0)), EPS)
	assert_almost_eq(profile[8], Tile.surface_y_on_side(region, 6.0, 6.0, Vector2i(1, 0)), EPS)
	assert_almost_eq(profile[0], 0.0, EPS)
	assert_gt(profile[8], profile[0] + 0.5, "ordered from -z to +z (pdir = (d.y, d.x))")
	var own := Tile.own_edge_profile(region, Vector2i(0, 0), d, 8)
	for f in own:
		assert_almost_eq(f, 12.0, EPS)
	# The transposed direction runs along +x.
	var south := Region.new({Vector2i(-1, 0): 12.0, Vector2i(0, 0): 12.0, Vector2i(1, 0): 12.0,
		Vector2i(-1, 1): 0.0, Vector2i(0, 1): 0.0, Vector2i(1, 1): 4.0}, 0.0)
	var along_x := Tile.edge_profile(south, Vector2i(0, 0), Vector2i(0, 1), 8)
	assert_almost_eq(along_x[0], 0.0, EPS)
	assert_gt(along_x[8], along_x[0] + 0.5)


func test_height_bounds_on_side_is_one_sided() -> void:
	var region = Region.tile(12.0, 0.0, 0.0, 12.0)
	assert_eq(Tile.height_bounds_on_side(region, Rect2(2.0, 1.0, 4.0, 4.0), Vector2i(0, 0)), Vector2(12.0, 12.0))
	assert_eq(Tile.height_bounds_on_side(region, Rect2(6.0, 1.0, 4.0, 4.0), Vector2i(1, 0)), Vector2(0.0, 0.0))
	assert_eq(Tile.height_bounds(region, Rect2(4.0, 1.0, 4.0, 4.0)), Vector2(0.0, 12.0))
