extends GutTest

# ------------------------------------------------------------
# HeightfieldVariant — plan heights -> tile descriptor (Phase 3a)
# ------------------------------------------------------------

func test_variant_empty_missing_is_center_no_rotation() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing([])
	assert_eq(v["tag"], "center", "no walls => center")
	assert_eq(v["rotation_steps"], 0, "center needs no rotation")

func test_variant_single_wall_is_side() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front"])
	assert_eq(v["tag"], "side", "one wall => side")
	assert_eq(v["rotation_steps"], 0, "canonical side wall is on front")

func test_variant_rotates_canonical_to_match() -> void:
	# A wall on the right is the side variant rotated one 90deg step (front->right).
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["right"])
	assert_eq(v["tag"], "side", "one wall (any direction) => side")
	assert_eq(v["rotation_steps"], 1, "front rotates to right in one step")

func test_variant_adjacent_walls_is_corner() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front", "left"])
	assert_eq(v["tag"], "corner", "two adjacent walls => corner")

func test_variant_opposite_walls_is_line() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front", "back"])
	assert_eq(v["tag"], "line", "two opposite walls => line")

func test_variant_all_four_walls_is_island() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front", "right", "back", "left"])
	assert_eq(v["tag"], "island", "four walls => island")

func test_variant_diagonal_is_inner_corner() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["frontleft"])
	assert_eq(v["tag"], "inner-corner", "a single diagonal notch => inner-corner")

func test_variant_rotated_inner_corner() -> void:
	# Canonical inner-corner notch is on frontleft; a frontright notch is the same
	# variant rotated one 90deg step (frontleft -> frontright). Exercises rotation
	# of a diagonal (period-4) variant, complementing the cardinal rotation test.
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["frontright"])
	assert_eq(v["tag"], "inner-corner", "a diagonal notch is still inner-corner")
	assert_eq(v["rotation_steps"], 1, "frontleft rotates to frontright in one step")
