# tests/test_slope_profile_stacked.gd
extends GutTest

const EPS := 0.001
const TOL := 0.02

var _sp := SlopeProfile.new()  # instance only so .call() can dispatch to the static fns

func _dz(fn: String, x: float, z: float) -> float:
	var hi: float = _sp.call(fn, x, z + EPS)
	var lo: float = _sp.call(fn, x, z - EPS)
	return (hi - lo) / (2.0 * EPS)

func test_outer_stacked_endpoints() -> void:
	assert_almost_eq(SlopeProfile.outer_corner_stacked_height(6.0, 6.0), 0.0, 1e-4)
	assert_almost_eq(SlopeProfile.outer_corner_stacked_height(-6.0, -6.0), -4.0, 1e-4)

func test_inner_stacked_endpoints() -> void:
	assert_almost_eq(SlopeProfile.inner_corner_stacked_height(6.0, 6.0), 0.0, 1e-4)
	assert_almost_eq(SlopeProfile.inner_corner_stacked_height(-6.0, -6.0), -4.0, 1e-4)

func test_outer_stacked_edge_seam_matches_edge() -> void:
	for z in [-6.0, -2.0, 2.0, 6.0]:
		assert_almost_eq(SlopeProfile.outer_corner_stacked_height(6.0, z), SlopeProfile.edge_height(0.0, z), TOL)

func test_inner_stacked_edge_seam_is_flat() -> void:
	for z in [-6.0, 0.0, 6.0]:
		assert_almost_eq(SlopeProfile.inner_corner_stacked_height(6.0, z), 0.0, TOL)

func test_seam_tangents_mate() -> void:
	var t_outer := _dz("outer_corner_stacked_height", -5.5, -5.5)
	var t_inner := _dz("inner_corner_stacked_height", 5.5, 5.5)
	assert_gt(absf(t_outer), 1.0, "upper outer must be steep at the seam")
	assert_gt(absf(t_inner), 1.0, "lower inner must be steep at the seam")
	assert_almost_eq(absf(t_outer), absf(t_inner), 0.3, "upper-bottom and lower-top tangents must mate")

func test_outer_stacked_soft_at_plateau() -> void:
	var t_top := _dz("outer_corner_stacked_height", 5.5, 5.5)
	var t_seam := _dz("outer_corner_stacked_height", -5.5, -5.5)
	assert_lt(absf(t_top), absf(t_seam), "outer stacked must be flatter at plateau than at seam")
