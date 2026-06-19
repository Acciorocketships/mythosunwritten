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

func test_missing_is_empty_when_all_neighbours_level() -> void:
	var flat: Dictionary = {"front": 4.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 4.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, flat, diag)
	assert_eq(missing.size(), 0, "no drops => no walls")

func test_missing_includes_a_lower_cardinal() -> void:
	var cards: Dictionary = {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 4.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing, ["front"], "a lower front neighbour is a wall")

func test_missing_ignores_higher_neighbours() -> void:
	# A higher neighbour means THIS cell is at the foot of that wall — no wall here.
	var cards: Dictionary = {"front": 8.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 4.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing.size(), 0, "higher neighbours are not walls")

func test_missing_diagonal_only_when_both_cardinals_connected() -> void:
	# frontleft lower, but front and left are level => inner-corner notch.
	var cards: Dictionary = {"front": 4.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 0.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing, ["frontleft"], "diagonal drop with connected cardinals => inner corner")

func test_missing_diagonal_suppressed_when_a_cardinal_is_a_wall() -> void:
	# Both front and frontleft are lower: the diagonal is absorbed by the front
	# wall (the canonical 'side'/'corner' shapes already cover it), so only the
	# cardinal is reported.
	var cards: Dictionary = {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 0.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing, ["front"], "diagonal not reported when an adjoining cardinal is a wall")

func test_missing_diagonal_suppressed_when_other_cardinal_is_a_wall() -> void:
	# Mirror of the front-wall case: here `left` is the wall (front is level), so
	# frontleft is suppressed because the SECOND adjoining cardinal is a wall.
	var cards: Dictionary = {"front": 4.0, "right": 4.0, "back": 4.0, "left": 0.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 0.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing, ["left"], "diagonal suppressed when only the second adjoining cardinal is a wall")

func test_missing_defaults_absent_neighbours_to_h0() -> void:
	# Absent dict entries default to h0 (connected) => no walls.
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, {}, {})
	assert_eq(missing.size(), 0, "absent neighbours default to h0 => no walls")
