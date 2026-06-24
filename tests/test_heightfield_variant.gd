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

# Convenience: a flat neighbourhood at height h (all 8 neighbours == h).
func _flat(h: float) -> Array:
	var cards: Dictionary = {"front": h, "right": h, "back": h, "left": h}
	var diag: Dictionary = {"frontright": h, "backright": h, "backleft": h, "frontleft": h}
	return [cards, diag]

func test_descriptor_flat_ground() -> void:
	var nb: Array = _flat(0.0)
	var d: Dictionary = HeightfieldVariant.cell_descriptor(0.0, 0, 0, nb[0], nb[1])
	assert_eq(d["family"], "ground", "storey 0 level 0 flat => ground")
	assert_eq(d["variant_tag"], "ground-plain", "ground tile tag")
	assert_almost_eq(d["origin_y"], 0.0, 0.0001, "ground at y=0")

func test_descriptor_cliff_edge() -> void:
	# Storey 1 (origin 4m), front drops a full storey to ground.
	var cards: Dictionary = {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 4.0}
	var d: Dictionary = HeightfieldVariant.cell_descriptor(4.0, 1, 0, cards, diag)
	assert_eq(d["family"], "cliff", "a 4m drop => cliff family")
	assert_eq(d["variant_tag"], "cliff-side", "one cliff wall => cliff-side")
	assert_almost_eq(d["origin_y"], 4.0, 0.0001, "cliff plateau top at storey*4")

func test_descriptor_level_edge() -> void:
	# Storey 0 level 1 (origin 0.5m), front drops one level to 0.
	var cards: Dictionary = {"front": 0.0, "right": 0.5, "back": 0.5, "left": 0.5}
	var diag: Dictionary = {"frontright": 0.5, "backright": 0.5, "backleft": 0.5, "frontleft": 0.5}
	var d: Dictionary = HeightfieldVariant.cell_descriptor(0.5, 0, 1, cards, diag)
	assert_eq(d["family"], "level", "a 0.5m drop => level family")
	assert_eq(d["variant_tag"], "level-side", "one level wall => level-side")
	assert_almost_eq(d["origin_y"], 0.5, 0.0001, "level top at storey*4 + level*0.5")

func test_descriptor_cliff_plateau_interior() -> void:
	var nb: Array = _flat(4.0)
	var d: Dictionary = HeightfieldVariant.cell_descriptor(4.0, 1, 0, nb[0], nb[1])
	assert_eq(d["family"], "cliff", "elevated flat cell is cliff family")
	assert_eq(d["variant_tag"], "cliff-interior", "flat cliff top => cliff-interior")

func test_descriptor_level_center() -> void:
	var nb: Array = _flat(0.5)
	var d: Dictionary = HeightfieldVariant.cell_descriptor(0.5, 0, 1, nb[0], nb[1])
	assert_eq(d["family"], "level", "raised-but-flat level cell")
	assert_eq(d["variant_tag"], "level-center", "flat level => level-center")

func test_descriptor_cliff_corner_with_rotation() -> void:
	# Drops on right and back (a corner) at storey 1.
	var cards: Dictionary = {"front": 4.0, "right": 0.0, "back": 0.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 0.0, "backright": 0.0, "backleft": 4.0, "frontleft": 4.0}
	var d: Dictionary = HeightfieldVariant.cell_descriptor(4.0, 1, 0, cards, diag)
	assert_eq(d["family"], "cliff", "two cliff walls")
	assert_eq(d["variant_tag"], "cliff-corner", "adjacent cliff walls => cliff-corner")
	assert_eq(d["rotation_steps"], 2, "corner canonical [front,left] rotates twice to [back,right]")

func test_descriptor_terrace_edge_on_a_cliff_plateau() -> void:
	# A level-2 terrace sitting on a storey-1 plateau (origin 5.0m), front drops
	# one level (0.5m) to level 1. It is a level-side, NOT a cliff tile.
	var cards: Dictionary = {"front": 4.5, "right": 5.0, "back": 5.0, "left": 5.0}
	var diag: Dictionary = {"frontright": 5.0, "backright": 5.0, "backleft": 5.0, "frontleft": 5.0}
	var d: Dictionary = HeightfieldVariant.cell_descriptor(5.0, 1, 2, cards, diag)
	assert_eq(d["family"], "level", "a 0.5m drop is a level edge even up on a plateau")
	assert_eq(d["variant_tag"], "level-side", "terrace edge on a plateau => level-side")
	assert_almost_eq(d["origin_y"], 5.0, 0.0001, "origin = 1*4 + 2*0.5")

func test_descriptor_flat_terrace_interior_on_plateau_is_level_center() -> void:
	# Flat level-2 terrace interior on a storey-1 plateau: must be level-center
	# (matching its level-* edges), NOT cliff-interior, even though storey > 0.
	var nb: Array = _flat(5.0)
	var d: Dictionary = HeightfieldVariant.cell_descriptor(5.0, 1, 2, nb[0], nb[1])
	assert_eq(d["family"], "level", "level>0 takes priority over storey>0 for flat cells")
	assert_eq(d["variant_tag"], "level-center", "flat terrace interior => level-center")

func test_variant_peninsula_three_walls() -> void:
	# Three walls (open on the fourth side) => peninsula. Canonical is open-back.
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front", "left", "right"])
	assert_eq(v["tag"], "peninsula", "three walls => peninsula")
	assert_eq(v["rotation_steps"], 0, "canonical peninsula is open on the back")

func test_variant_two_opposite_diagonals_is_inner_corner_diag() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["frontleft", "backright"])
	assert_eq(v["tag"], "inner-corner-diag", "two opposite diagonal notches => inner-corner-diag")

func test_descriptor_cliff_peninsula() -> void:
	# Storey 1 plateau finger: front, left, right all drop a full storey; back connected.
	var cards: Dictionary = {"front": 0.0, "right": 0.0, "back": 4.0, "left": 0.0}
	var diag: Dictionary = {"frontright": 0.0, "backright": 0.0, "backleft": 0.0, "frontleft": 0.0}
	var d: Dictionary = HeightfieldVariant.cell_descriptor(4.0, 1, 0, cards, diag)
	assert_eq(d["family"], "cliff", "three cliff drops")
	assert_eq(d["variant_tag"], "cliff-peninsula", "three cliff walls => cliff-peninsula")
