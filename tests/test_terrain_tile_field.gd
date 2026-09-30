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
	# 6 m quadrant is flat at its own corner's height.
	for h: Array in [[8.0, 0.0, 0.0, 0.0], [8.0, 0.0, 0.0, 8.0], [8.0, 8.0, 0.0, 8.0],
			[16.0, 8.0, 0.0, 8.0]]:
		var region = Region.tile(h[0], h[1], h[2], h[3])
		for q in [[0.2, 0.3, 0], [0.8, 0.1, 1], [0.7, 0.9, 2], [0.1, 0.6, 3]]:
			assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, q[0], q[1]), float(h[q[2]]), EPS,
				"%s quadrant %s" % [h, q[2]])


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


func test_e2_cliff_end_walls_to_the_tile_centre_then_ramps() -> void:
	# Bottom edge a-b is a cliff (0 vs 8), top edge d-c a slope (8 vs 4).
	var region = Region.tile(8.0, 0.0, 4.0, 8.0)
	# Wall on the lower half of the midline, high side level.
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.49, 0.2), 8.0, EPS)
	assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, 0.2, 0.45), 8.0, EPS)
	var low := Tile.tile_y(region, Vector2i.ZERO, 0.51, 0.2)
	assert_lt(low, 1.0, "the low side of the wall")
	# The top edge is exactly the neighbour's slope profile.
	for i in 9:
		var t := float(i) / 8.0
		assert_almost_eq(Tile.tile_y(region, Vector2i.ZERO, t, 1.0), lerpf(8.0, 4.0, _s(t)), EPS)
	# Continuous above the centre (no wall there).
	var above_l := Tile.tile_y(region, Vector2i.ZERO, 0.499, 0.8)
	var above_r := Tile.tile_y(region, Vector2i.ZERO, 0.501, 0.8)
	assert_almost_eq(above_l, above_r, 0.2)
	# The high side stays level beside the wall (no E1-style dip).
	for iv in 6:
		var y := Tile.tile_y(region, Vector2i.ZERO, 0.2, float(iv) / 10.0)
		assert_almost_eq(y, 8.0, EPS)


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
				assert_between(y, bounds.x - EPS, bounds.y + EPS, "%s at %s,%s" % [rect, x, z])


func test_height_bounds_are_exact_on_a_flat_or_single_slope_footprint() -> void:
	var flat = Region.new({}, 4.0)
	assert_eq(Tile.height_bounds(flat, Rect2(-4.0, -3.0, 8.0, 6.0)), Vector2(4.0, 4.0))
	var slope = Region.tile(4.0, 0.0, 0.0, 4.0)
	var bounds := Tile.height_bounds(slope, Rect2(0.0, 1.0, 6.0, 4.0))
	assert_almost_eq(bounds.x, 2.0, EPS)
	assert_almost_eq(bounds.y, 4.0, EPS)
