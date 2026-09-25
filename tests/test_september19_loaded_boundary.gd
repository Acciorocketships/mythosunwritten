extends GutTest
const Boundary = preload("res://scripts/terrain/diagnostics/LoadedTerrainBoundary.gd")

func test_reported_west_frontier_is_not_the_desired_stream_radius() -> void:
	var loaded := {Vector2i(-3, 0): true, Vector2i(-2, 0): true}
	assert_almost_eq(Boundary.exit_distance(loaded, Vector2(-566.9, 127.4), Vector2.LEFT), 9.1, .001)
	assert_almost_eq(Boundary.exit_distance(loaded, Vector2(-566.9, 127.4), Vector2.RIGHT), 374.9, .001)

func test_holes_and_disconnected_islands_do_not_extend_visibility() -> void:
	var loaded := {Vector2i.ZERO: true, Vector2i(2, 0): true}
	assert_almost_eq(Boundary.exit_distance(loaded, Vector2(100, 100), Vector2.RIGHT), 92.0, .001)
	loaded[Vector2i(1, 0)] = true
	assert_almost_eq(Boundary.exit_distance(loaded, Vector2(100, 100), Vector2.RIGHT), 476.0, .001)
	loaded.erase(Vector2i(1, 0))
	assert_almost_eq(Boundary.exit_distance(loaded, Vector2(100, 100), Vector2.RIGHT), 92.0, .001)

func test_diagonal_and_axis_aligned_rays_are_finite_at_unloaded_ground() -> void:
	var loaded := {Vector2i.ZERO: true}
	assert_almost_eq(Boundary.exit_distance(loaded, Vector2(96, 96), Vector2.ONE), 96.0 * sqrt(2.0), .001)
	assert_eq(Boundary.exit_distance(loaded, Vector2(-1, 96), Vector2.RIGHT), 0.0)
	assert_eq(Boundary.exit_distance(loaded, Vector2(96, 96), Vector2.ZERO), INF)
	assert_almost_eq(Boundary.exit_distance(loaded, Vector2(0, 96), Vector2.LEFT), 0.0, .001)
