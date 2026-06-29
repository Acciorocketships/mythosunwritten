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

# Owner round 4: a grass lip must never overhang into midair or be undercut by a slope behind
# it. Invariant that guarantees this: a cell that carries a lip is a CLIFF TOP, and a cliff top
# is FLAT across its whole surface — so the terrain directly behind every lip is flat at the
# lip's height. Checked over several real seeds AND every lip piece compute() emits.
func test_every_lip_is_backed_by_flat_terrain() -> void:
	for seed in [1, 7, 13, 42, 99, 123]:
		var plan := Plan.new(seed, 22.0, 8, "mean", 3)
		var region = plan.compute_region(0, 0, 16)
		# 1. Every cliff-top cell is flat across its whole top (so any lip on it is backed).
		for cz in range(-7, 8):
			for cx in range(-7, 8):
				if not Field._is_cliff_top(region, cx, cz):
					continue
				var h: float = region.surface_height(cx, cz)
				for oz in [-11.0, -6.0, 0.0, 6.0, 11.0]:
					for ox in [-11.0, -6.0, 0.0, 6.0, 11.0]:
						var y := Field.surface_y(region, cx * 24.0 + ox, cz * 24.0 + oz)
						assert_almost_eq(y, h, 0.05,
							"seed %d cliff-top (%d,%d) must be flat behind its lip" % [seed, cx, cz])
		# 2. Every straight lip is anchored on a cliff top, and the terrain right behind it (into
		#    the cell) is flat at the cliff height — no gap, no dip, no overhang into midair.
		var data = Dress.compute(region, -6, -6, 13)
		for t in (data["lip"] as Array):
			var xf := t as Transform3D
			var drop_dir := (xf.basis * Vector3(0, 0, 1)).normalized()   # toward the drop
			var ccx := int(round((xf.origin.x - drop_dir.x * 12.0) / 24.0))
			var ccz := int(round((xf.origin.z - drop_dir.z * 12.0) / 24.0))
			assert_true(Field._is_cliff_top(region, ccx, ccz),
				"seed %d lip at %s must sit on a cliff top" % [seed, str(xf.origin)])
			var back := xf.origin - drop_dir * 2.0      # 2u behind the edge, into the cell
			var yb := Field.surface_y(region, back.x, back.z)
			assert_almost_eq(yb, region.surface_height(ccx, ccz), 0.05,
				"seed %d terrain behind lip at %s must be flat at cliff height" % [seed, str(xf.origin)])

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

func test_one_storey_drop_to_a_pure_shelf_is_not_walled() -> void:
	# A cliff top's 1-storey drop to a NON-cliff cell that is itself a flat SHELF (no further drop)
	# is a walkable slope, not a wall — no spurious corner there. (0,0) is a cliff top via its ≥2
	# DIAGONAL drop to (-1,-1); its +x neighbour (1,0) is one storey down and otherwise level.
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == -1 and cz == -1: return 8.0   # diagonal pit (not adjacent to (1,0)) → (0,0) cliff top
		if cx == 1 and cz == 0: return 12.0    # +x neighbour one storey down — a PURE shelf (level around it)
		return 16.0)
	var r = plan.compute_region(0, 0, 8)
	assert_false(Field._is_wall_edge(r, 0, 0, Vector2i(1, 0)), "1-storey drop to a pure flat shelf is a slope, not a wall")

func test_one_storey_drop_to_a_funnel_cell_is_walled() -> void:
	# Owner: inner corners must be clean vertical cliffs. The +x neighbour here is a FUNNEL — one
	# storey below the cliff top AND dropping further to the diagonal pit (1,1). Ramping it up would
	# pinch a thin spike at the corner, so instead the cliff WALLS down to it (a terraced step).
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 8.0     # diagonal pit, 2 storeys down → (0,0) is a cliff top
		if cx == 1 and cz == 0: return 12.0    # +x neighbour one storey down AND above the (1,1) pit → a funnel
		return 16.0)
	var r = plan.compute_region(0, 0, 8)
	assert_true(Field._is_wall_edge(r, 0, 0, Vector2i(1, 0)), "1-storey drop to a funnel cell is a wall (terraced inner corner)")

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

# --- owner: NO spurious corner lip mid-edge where a straight cliff continues ------
func test_straight_cliff_has_no_midedge_corner() -> void:
	# A straight E-facing cliff spanning two cells (0,0) and (0,1), with the ground below dropping
	# 2 storeys. Each cell's SE/NE corner has one wall edge (E) + a ≥2 diagonal — the OLD code put a
	# step (outer) corner there, but the E wall CONTINUES straight from (0,0) to (0,1), so that
	# corner sits mid-edge: a stray corner lip in the middle of the run (owner). It must be suppressed.
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and (cz == 0 or cz == 1): return 12.0   # the low ground east of the straight cliff
		return 20.0)                                        # the storey-5 plateau (cells x<=0)
	var r = plan.compute_region(0, 0, 8)
	# both cells wall E (the cliff is continuous), so the shared corner is covered by the collinear walls
	assert_true(Field._is_wall_edge(r, 0, 0, Vector2i(1, 0)) and Field._is_wall_edge(r, 0, 1, Vector2i(1, 0)),
		"the E cliff is continuous across (0,0) and (0,1)")
	var data = Dress.compute(r, 0, 0, 1)   # dress only (0,0)
	assert_eq((data["outer_wall"] as Array).size(), 0, "no spurious step/outer corner mid straight cliff")
	assert_eq((data["inner_wall"] as Array).size(), 0, "and certainly no inner corner here")

# --- owner: a real convex turn STILL gets a corner (we didn't suppress everything) ----
func test_lip_is_inset_from_the_wall_to_meet_the_flat_top() -> void:
	# Owner: the lip must not leave a gap with the flat surface behind it. The grass LIP sits 1 unit
	# INSIDE the cell boundary (LIP_EDGE) so its flat top ends at the edge and meets the field's flat
	# top seam-free; the rock WALL stays on the boundary (EDGE) in front of the field's own rock face
	# (so the modeled wall isn't occluded). So every lip is inset from its wall.
	var data = Dress.compute(_region_side(2), 0, 0, 1)   # cell (0,0): one +x cliff edge
	assert_lt(Dress.LIP_EDGE, Dress.EDGE, "lip offset is inside the wall offset")
	for t in (data["lip"] as Array):
		assert_almost_eq(absf((t as Transform3D).origin.x), Dress.LIP_EDGE, 0.01, "each lip sits at LIP_EDGE")
	for t in (data["wall"] as Array):
		assert_almost_eq(absf((t as Transform3D).origin.x), Dress.EDGE, 0.01, "each wall sits on the boundary (EDGE)")

func test_real_convex_turn_still_gets_corner() -> void:
	var data = Dress.compute(_region_outer(2), 0, 0, 1)
	assert_gt((data["outer_wall"] as Array).size(), 0, "a genuine convex corner is still dressed")

# --- owner: a concave NOTCH is an inner-corner cliff, not a dipping slope -------------
func test_inner_corner_notch_gets_inner_piece() -> void:
	# Mirrors the owner's (-4,-3) spot: a cell whose four cardinals are LEVEL and whose diagonal
	# neighbour is one storey lower AND a cliff top (its arms wall it). It is the high corner of a
	# clean pocket, so it gets the modeled inner-corner piece — even though the drop is only 1 storey.
	var plan := Plan.new(0, 32.0, 8, "mean", 3)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 8.0     # the notch, one storey below (0,0)
		if cx == 2 and cz == 1: return 0.0     # E arm (1,0) drops ≥2 here → arm is a cliff top
		if cx == 1 and cz == 2: return 0.0     # S arm (0,1) drops ≥2 here → arm is a cliff top
		if cx == 2 and cz == 2: return 0.0     # notch (1,1) drops ≥2 here → notch is a cliff top
		return 12.0)                            # (0,0) and its level arms
	var r = plan.compute_region(0, 0, 8)
	assert_true(Field._is_inner_corner(r, 0, 0, Vector2i(1, 1)), "the level-armed 1-storey pocket is an inner corner")
	var data = Dress.compute(r, 0, 0, 1)
	assert_gt((data["inner_wall"] as Array).size(), 0, "the inner-corner cell gets a modeled inner piece")
	assert_eq((data["outer_wall"] as Array).size(), 0, "and not an outer/step corner")

func test_open_one_storey_diagonal_is_not_an_inner_corner() -> void:
	# Guard: a lone 1-storey diagonal dip whose arms do NOT wall it (an open slope, not a pocket)
	# must stay a slope — NOT become a spurious inner corner.
	var plan := Plan.new(0, 32.0, 8, "mean", 3)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 8.0   # diagonal one storey down, but arms (1,0)/(0,1) only 0 drop
		return 12.0)
	var r = plan.compute_region(0, 0, 8)
	assert_false(Field._is_inner_corner(r, 0, 0, Vector2i(1, 1)), "an open 1-storey diagonal dip is not an inner corner")

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
