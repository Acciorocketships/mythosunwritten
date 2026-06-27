extends GutTest
# Tests for the cliff composition issues the owner flagged. They assert on
# CliffDressing.compute() — the placement DATA — because MultiMesh transforms don't read
# back in headless mode.
#  1. walls extend below the neighbour (so a sloping base never exposes a gap)
#  2. concave (inner) corners get an inner-corner piece
#  3. convex (outer) corners get an outer-corner piece (walls don't run through each other)
#  4. the low-side slope renders right up to the wall (not skipped → no gap)
#  5. an edge wall stops where the cliff-top behind it stops being flat (doesn't overhang)
const Dress := preload("res://scripts/terrain/field/CliffDressing.gd")
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

# cell (0,0) is a cliff top `drop` storeys above its +x neighbour (one straight cliff edge).
func _region_side(drop: int):
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		return float(drop) * 4.0 if cx <= 0 else 0.0)
	return plan.compute_region(0, 0, 8)

# cell (0,0) high; both +x and +z neighbours lower → a convex (outer) corner at +x+z.
func _region_outer(drop: int):
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		return float(drop) * 4.0 if (cx <= 0 and cz <= 0) else 0.0)
	return plan.compute_region(0, 0, 8)

# Only the +x+z DIAGONAL neighbour is lower; the cardinals are level → concave (inner) corner.
func _region_inner(drop: int):
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		return 0.0 if (cx >= 1 and cz >= 1) else float(drop) * 4.0)
	return plan.compute_region(0, 0, 8)

func _min_y(transforms: Array) -> float:
	var out := 1e9
	for t in transforms:
		out = minf(out, (t as Transform3D).origin.y)
	return out

# --- issue 1: wall extends all the way down ----------------------------------
func test_wall_extends_below_neighbour() -> void:
	var data = Dress.compute(_region_side(2), -2, -2, 5)
	assert_gt((data["wall"] as Array).size(), 0, "a 2-storey cliff produces wall pieces")
	assert_lt(_min_y(data["wall"]), 0.0, "wall over-extends below the neighbour ground (y=0)")

# --- issue 4: low-side slope renders up to the wall --------------------------
func test_low_side_slope_quad_not_skipped() -> void:
	var r = _region_side(2)
	var m = Mesher.new()
	assert_false(m._spans_cliff(r, 21.0, 24.0, -3.0, 0.0), "low-side slope quad renders")
	assert_true(m._spans_cliff(r, 9.5, 12.0, -3.0, 0.0), "cliff-top lip strip is omitted")

# --- issue 3: outer (convex) corner piece ------------------------------------
func test_outer_corner_piece_present() -> void:
	var data = Dress.compute(_region_outer(2), -2, -2, 5)
	assert_gt((data["outer_wall"] as Array).size(), 0, "convex corner produces an outer-corner wall")
	assert_gt((data["outer_lip"] as Array).size(), 0, "convex corner produces an outer-corner lip")

# --- issue 2: inner (concave) corner piece -----------------------------------
func test_inner_corner_piece_present() -> void:
	var data = Dress.compute(_region_inner(2), -2, -2, 5)
	assert_gt((data["inner_wall"] as Array).size(), 0, "concave corner produces an inner-corner wall")

# --- issue 5: outer corner replaces the shared edge ends ---------------------
func test_outer_corner_replaces_edge_ends() -> void:
	# A single straight cliff edge keeps all 8 lip pieces; the convex-corner cell drops the
	# shared end pieces in favour of the corner piece, so it has FEWER straight edge lips
	# per edge than the straight side.
	var side = Dress.compute(_region_side(2), 0, 0, 1)    # just cell (0,0): one edge
	var outer = Dress.compute(_region_outer(2), 0, 0, 1)  # cell (0,0): two edges + a corner
	assert_eq((side["lip"] as Array).size(), 8, "a lone straight edge has 8 lip pieces")
	assert_gt((outer["outer_lip"] as Array).size(), 0, "the corner is a dedicated corner piece")
	# Each of the outer cell's two edges loses its shared corner end (8 -> 7 each = 14).
	assert_eq((outer["lip"] as Array).size(), 14, "edges drop their shared corner end piece")
