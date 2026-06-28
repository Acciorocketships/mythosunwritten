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
const Field := preload("res://scripts/terrain/field/TerrainSurfaceField.gd")

# A grass lip must sit ON the terrain — never float above it (midair) or below it (buried).
# Cliff edges may now run along a SLOPING cell, so the lip FOLLOWS the surface height rather
# than a flat cliff-top height. Invariant: every lip's y matches surface_y just behind it (into
# the cell). Checked over several real seeds for every lip compute() emits.
func test_every_lip_sits_on_the_terrain() -> void:
	for seed in [1, 7, 13, 42, 99, 123]:
		var plan := Plan.new(seed, 22.0, 8, "mean", 3)
		var region = plan.compute_region(0, 0, 16)
		var data = Dress.compute(region, -6, -6, 13)
		for t in (data["lip"] as Array):
			var xf := t as Transform3D
			var drop_dir := (xf.basis * Vector3(0, 0, 1)).normalized()   # toward the drop
			var back := xf.origin - drop_dir * 1.0      # 1u behind the edge, into the cell
			var yb := Field.surface_y(region, back.x, back.z)
			# lip is lifted a hair (LIP_LIFT/CORNER_LIP_LIFT ≤ 0.1) above the terrain it follows
			assert_almost_eq(xf.origin.y, yb, 0.35,
				"seed %d lip at %s must sit on the terrain behind it (%.2f)" % [seed, str(xf.origin), yb])

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

# --- the wall spans the drop and STOPS at the neighbour (no jutting slab) ------
func test_wall_spans_exactly_to_neighbour() -> void:
	# Cliff top storey 2 (y=8) over a storey-0 neighbour (y=0). The wall must cover the whole
	# face (8→0) and bottom out AT the neighbour — never hang far below it, which would stick
	# out under the neighbour's thin surface as a visible slab (the owner's blue rectangle).
	var ys := []
	for t in (Dress.compute(_region_side(2), -2, -2, 5)["wall"] as Array):
		ys.append((t as Transform3D).origin.y)
	assert_gt(ys.size(), 0, "a 2-storey cliff produces wall pieces")
	assert_almost_eq((ys as Array).min(), 0.0, 0.6, "wall bottom sits at the neighbour ground (y≈0)")
	assert_gte((ys as Array).max(), 4.0, "wall covers up the cliff face")

func test_one_storey_taper_collinear_with_cliff_is_a_wall() -> void:
	# Owner: a cliff's ≥2 face that tapers to a 1-storey drop should CONTINUE as one cliff edge
	# down its tapering end (collinear), while a LONE 1-storey drop stays a slope.
	# Row of +z drops along x: (-1,0)→3 storeys, (0,0)→1 storey (the taper), (1,0)→0 (flat).
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cz >= 1: return 0.0                         # everything south is low
		if cx == -1: return 12.0                       # the ≥2 cliff (storey3 → 0 south)
		if cx == 0: return 4.0                          # the 1-storey taper (storey1 → 0 south)
		return 4.0)                                     # cx≥1: storey1 but south is also storey1 → no drop
	var r = plan.compute_region(0, 0, 8)
	# (0,0)'s +z is a 1-storey drop COLLINEAR with (-1,0)'s ≥2 +z cliff → a wall edge.
	assert_true(Field._is_wall_edge(r, 0, 0, Vector2i(0, 1)), "1-storey taper collinear with a cliff continues the edge")
	# A lone 1-storey drop with no cliff in line stays a slope.
	var plan2 := Plan.new(0, 64.0, 12, "mean", 4)
	plan2.set_raw_height_override(func(cx, cz): return 4.0 if cz <= 0 else 0.0)   # uniform 1-storey step
	assert_false(Field._is_wall_edge(plan2.compute_region(0, 0, 8), 0, 0, Vector2i(0, 1)), "lone 1-storey drop is a slope")

# --- issue 4 (gap): the low ground tucks flat to the cliff wall base ----------
func test_low_ground_reaches_the_cliff_wall_base() -> void:
	# The boundary-straddling quad is tucked flat at the LOW height (not skipped, not a
	# climbing ramp), so low grass reaches the cliff boundary and meets the wall base — no
	# gap. Cliff at cell 3|4 → boundary world x = 84; low ground sits at y≈0.
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 3 else 0.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var reaches := false
	for v in verts:
		if absf(v.x - 84.0) < 2.1 and v.y < 1.0:
			reaches = true
			break
	assert_true(reaches, "low ground grass reaches the cliff boundary (no base gap)")
	node.free()

# --- issue 3: outer (convex) corner piece ------------------------------------
func test_outer_corner_piece_present() -> void:
	var data = Dress.compute(_region_outer(2), -2, -2, 5)
	assert_gt((data["outer_wall"] as Array).size(), 0, "convex corner produces an outer-corner wall")
	assert_gt((data["outer_lip"] as Array).size(), 0, "convex corner produces an outer-corner lip")

# --- owner pic 1: a 1-storey edge + a ≥2 DIAGONAL drop must not see through -----
func test_step_corner_covers_diagonal_cliff() -> void:
	# (0,0) is a cliff top (its +x+z diagonal is 2 storeys below). +x drops 1 (a wall edge), +z
	# is level. That corner is neither convex (both edges) nor concave (both level), so the
	# diagonal cliff face used to get NO piece → see-through. It must now get an outer (step) corner.
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 12.0    # diagonal pit, 2 storeys down
		if cx == 1 and cz == 0: return 12.0    # +x neighbour, 2 storeys down → a real wall edge
		return 20.0)
	var data = Dress.compute(plan.compute_region(0, 0, 8), 0, 0, 1)
	assert_gt((data["outer_wall"] as Array).size(), 0, "step corner covers the diagonal cliff face")
	assert_eq((data["inner_wall"] as Array).size(), 0, "it is an outer/step corner, not an inner one")

# --- issue 2: inner (concave) corner piece -----------------------------------
func test_inner_corner_piece_present() -> void:
	var data = Dress.compute(_region_inner(2), -2, -2, 5)
	assert_gt((data["inner_wall"] as Array).size(), 0, "concave corner produces an inner-corner wall")

# --- issue 1: edges keep full coverage; the corner overlaps (no gap) ----------
func test_edges_keep_full_width_and_corner_present() -> void:
	# Each cliff edge is dressed across its FULL width (8 pieces) so nothing is dropped at the
	# corner (which previously left a gap). A convex-corner cell has two full edges plus a
	# dedicated corner piece that overlaps their ends.
	var side = Dress.compute(_region_side(2), 0, 0, 1)    # just cell (0,0): one edge
	var outer = Dress.compute(_region_outer(2), 0, 0, 1)  # cell (0,0): two edges + a corner
	assert_eq((side["lip"] as Array).size(), 8, "a lone straight edge has 8 lip pieces")
	assert_eq((outer["lip"] as Array).size(), 16, "both edges keep full width (no dropped ends)")
	assert_gt((outer["outer_lip"] as Array).size(), 0, "the corner has a dedicated corner piece")
