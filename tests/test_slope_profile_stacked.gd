# tests/test_slope_profile_stacked.gd
extends GutTest

const TOL := 0.02

# outer_corner_stacked is now the 2-STOREY diagonal-ramp corner: BOTTOM*(rampz+rampx).
func test_outer_stacked_is_2storey_diagonal_ramp() -> void:
	# plateau corner: flat; each cardinal-edge corner: one storey; open diagonal: two storeys.
	assert_almost_eq(SlopeProfile.outer_corner_stacked_height(6.0, 6.0), 0.0, 1e-4)
	assert_almost_eq(SlopeProfile.outer_corner_stacked_height(-6.0, 6.0), -4.0, 1e-4)
	assert_almost_eq(SlopeProfile.outer_corner_stacked_height(6.0, -6.0), -4.0, 1e-4)
	assert_almost_eq(SlopeProfile.outer_corner_stacked_height(-6.0, -6.0), -8.0, 1e-4)

func test_outer_stacked_cardinal_seams_match_plain_edge() -> void:
	# Each cardinal edge-seam must equal the 1-storey edge profile so the 2-storey
	# corner mates continuously with its sloping (s-1) cardinal neighbours.
	for c in [-6.0, -2.0, 2.0, 6.0]:
		# +x seam (x=+HALF): ramps only in z -> edge profile in z
		assert_almost_eq(SlopeProfile.outer_corner_stacked_height(6.0, c), SlopeProfile.edge_height(0.0, c), TOL)
		# +z seam (z=+HALF): ramps only in x -> edge profile in x
		assert_almost_eq(SlopeProfile.outer_corner_stacked_height(c, 6.0), SlopeProfile.edge_height(0.0, c), TOL)

func test_outer_stacked_monotone_into_pit() -> void:
	# Descends monotonically from plateau (0) to pit floor (-8) along the diagonal.
	var prev := 1.0
	for t in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		var h: float = SlopeProfile.outer_corner_stacked_height(-t, -t)  # t=-6 -> (6,6) plateau
		assert_lte(h, prev + 1e-4, "must not rise toward the pit")
		prev = h

# inner_corner_stacked is no longer used by the instantiator (the 2-storey corner
# replaces the convex-top + concave-bottom pair). The component/scene are still
# baked so they load; sanity-check the profile endpoints are unchanged.
func test_inner_stacked_deprecated_endpoints() -> void:
	assert_almost_eq(SlopeProfile.inner_corner_stacked_height(6.0, 6.0), 0.0, 1e-4)
	assert_almost_eq(SlopeProfile.inner_corner_stacked_height(-6.0, -6.0), -4.0, 1e-4)
