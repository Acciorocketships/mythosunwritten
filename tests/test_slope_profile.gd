# tests/test_slope_profile.gd
extends GutTest

func test_smootherstep_endpoints() -> void:
	assert_almost_eq(SlopeProfile.smootherstep(0.0), 0.0, 1e-6)
	assert_almost_eq(SlopeProfile.smootherstep(1.0), 1.0, 1e-6)
	assert_almost_eq(SlopeProfile.smootherstep(0.5), 0.5, 1e-6)

func test_smootherstep_flat_tangents() -> void:
	# derivative ~0 at both ends -> C1 continuity with flat plateau/ground
	var d0 := (SlopeProfile.smootherstep(0.01) - SlopeProfile.smootherstep(0.0)) / 0.01
	var d1 := (SlopeProfile.smootherstep(1.0) - SlopeProfile.smootherstep(0.99)) / 0.01
	assert_lt(absf(d0), 0.05)
	assert_lt(absf(d1), 0.05)

func test_smootherstep_clamps() -> void:
	assert_almost_eq(SlopeProfile.smootherstep(-1.0), 0.0, 1e-6)
	assert_almost_eq(SlopeProfile.smootherstep(2.0), 1.0, 1e-6)

func test_edge_height_endpoints() -> void:
	# Edge ramps toward front (-z). Inner side z=+6 -> top (0); outer z=-6 -> -4.
	assert_almost_eq(SlopeProfile.edge_height(0.0, 6.0), 0.0, 1e-6)
	assert_almost_eq(SlopeProfile.edge_height(0.0, -6.0), -4.0, 1e-6)
	# independent of x
	assert_almost_eq(SlopeProfile.edge_height(-6.0, 0.0), SlopeProfile.edge_height(6.0, 0.0), 1e-6)
	# z=3 is inside the 12u band and clearly sloping (would be flat at 0 in a 6u band) -
	# discriminates the band width so this test guards the 50% change.
	assert_lt(SlopeProfile.edge_height(0.0, 3.0), -0.2)

func test_outer_corner_seam_matches_edge() -> void:
	# Along x=+6 the outer corner must equal the front-edge profile (continuity).
	for z in [-6.0, -2.0, 2.0, 6.0]:
		assert_almost_eq(SlopeProfile.outer_corner_height(6.0, z), SlopeProfile.edge_height(0.0, z), 1e-6)
	# Far outer corner fully drops.
	assert_almost_eq(SlopeProfile.outer_corner_height(-6.0, -6.0), -4.0, 1e-6)

func test_inner_corner_seams_flat() -> void:
	# Inner corner: plateau wraps; both inner seams stay at top (0).
	for z in [-6.0, 0.0, 6.0]:
		assert_almost_eq(SlopeProfile.inner_corner_height(6.0, z), 0.0, 1e-6)
	for x in [-6.0, 0.0, 6.0]:
		assert_almost_eq(SlopeProfile.inner_corner_height(x, 6.0), 0.0, 1e-6)
	# Only the far corner dips.
	assert_almost_eq(SlopeProfile.inner_corner_height(-6.0, -6.0), -4.0, 1e-6)
