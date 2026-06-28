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

func test_one_storey_edge_wall_does_not_overhang() -> void:
	# The owner's "blue rectangle": a cliff top (made so by a ≥2 DIAGONAL drop) with a 1-storey
	# CARDINAL drop. That edge's wall must span only the one storey (16→12) and bottom out at the
	# neighbour — not hang storeys below it (which juts out under the neighbour's thin surface).
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 8.0     # diagonal pit, 2 storeys down → (0,0) is a cliff top
		if cx >= 1 or cz >= 1: return 12.0      # +x / +z neighbours one storey down
		return 16.0)
	var data = Dress.compute(plan.compute_region(0, 0, 8), 0, 0, 1)   # just cell (0,0)
	var ys := []
	for t in (data["wall"] as Array):
		ys.append((t as Transform3D).origin.y)
	assert_gt(ys.size(), 0, "the 1-storey edge is walled")
	assert_gte((ys as Array).min(), 11.0, "wall bottoms at the neighbour (~12), not storeys below")

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
