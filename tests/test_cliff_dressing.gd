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
			assert_true(Field.is_flat_cell(region, ccx, ccz),
				"seed %d lip at %s must sit on a flat cell (cliff top / inner-corner top)" % [seed, str(xf.origin)])
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

func test_cliff_top_walls_every_drop_off_its_edge() -> void:
	# Vertical cliffs: a cliff top is a flat plateau, so EVERY storey drop off it is a wall — even a
	# 1-storey drop to an otherwise-flat shelf (nothing ramps the shelf up to meet the top anymore).
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == -1 and cz == -1: return 8.0   # diagonal pit (not adjacent to (1,0)) → (0,0) cliff top
		if cx == 1 and cz == 0: return 12.0    # +x neighbour one storey down — a flat shelf
		return 16.0)
	var r = plan.compute_region(0, 0, 8)
	assert_true(Field._is_wall_edge(r, 0, 0, Vector2i(1, 0)), "cliff top walls its 1-storey drop (a vertical cliff)")

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
func test_lip_and_wall_share_the_kaykit_place_offset() -> void:
	# Owner/KayKit: every wall AND lip node origin sits at PLACE (10.5) — 1.5 inside the ±12 boundary,
	# exactly like the old tiles. The piece's own baked GLTF offset carries the rock face out to the
	# boundary; placing the origin at 12 double-counts it (pieces too far out — the owner's spacing bug).
	var data = Dress.compute(_region_side(2), 0, 0, 1)   # cell (0,0): one +x cliff edge
	for t in (data["lip"] as Array):
		assert_almost_eq(absf((t as Transform3D).origin.x), Dress.PLACE, 0.01, "each lip sits at PLACE (10.5)")
	for t in (data["wall"] as Array):
		assert_almost_eq(absf((t as Transform3D).origin.x), Dress.PLACE, 0.01, "each wall sits at PLACE (10.5)")

func test_inner_corner_lip_is_rotated_180_from_its_wall() -> void:
	# Owner: the inner-corner LIP rendered rotated 180°. The KayKit inner lip is authored facing the
	# OPPOSITE diagonal from the inner wall, so the lip yaw must be the wall yaw + 180°.
	var plan := Plan.new(0, 32.0, 8, "mean", 3)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 1: return 8.0
		if cx == 2 and cz == 1: return 0.0
		if cx == 1 and cz == 2: return 0.0
		if cx == 2 and cz == 2: return 0.0
		return 12.0)
	var data = Dress.compute(plan.compute_region(0, 0, 8), 0, 0, 1)
	assert_gt((data["inner_wall"] as Array).size(), 0, "the test region has an inner corner")
	var wf: Vector3 = ((data["inner_wall"][0] as Transform3D).basis) * Vector3(0, 0, 1)
	var lf: Vector3 = ((data["inner_lip"][0] as Transform3D).basis) * Vector3(0, 0, 1)
	assert_lt(wf.dot(lf), -0.9, "inner lip faces opposite the inner wall (180° apart)")

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

# --- owner screenshots (2026-07-01): corner pieces fill the dropped end slot EXACTLY --------
# Ground truth = the old hand-built tiles (git 0bcc47ea CliffCorner.tscn): EVERY piece sits on
# the 10.5 line and the corner piece occupies (±10.5, ±10.5) — the end slot the edges drop. The
# KayKit pieces are 3-unit modules with recessed faces; only the 10.5 grid tiles them. At 11.0
# the corner lip overshot the ±12 cell boundary (protruding planes at cliff-top corners) and
# every corner left a 0.5 slit back to the last straight piece (the owner's lip gaps).
func test_corner_piece_sits_in_the_dropped_end_slot() -> void:
	var outer = Dress.compute(_region_outer(2), 0, 0, 1)   # cell (0,0): +x & +z edges + 1 corner
	assert_eq((outer["outer_lip"] as Array).size(), 1, "one outer corner lip")
	var lip := (outer["outer_lip"][0] as Transform3D).origin
	assert_almost_eq(lip.x, 10.5, 0.01, "corner lip x sits in the end slot (old-tile spacing)")
	assert_almost_eq(lip.z, 10.5, 0.01, "corner lip z sits in the end slot (old-tile spacing)")
	for t in (outer["outer_wall"] as Array):
		assert_almost_eq((t as Transform3D).origin.x, 10.5, 0.01, "corner wall x in the end slot")
		assert_almost_eq((t as Transform3D).origin.z, 10.5, 0.01, "corner wall z in the end slot")

func _world_boxes(data: Dictionary, keys: Array) -> Array:
	var out: Array = []
	for key in keys:
		var piece: Array = Dress._piece(Dress.SCENES[key])
		var local_aabb: AABB = (piece[1] as Transform3D) * (piece[0] as Mesh).get_aabb()
		for t in (data[key] as Array):
			out.append((t as Transform3D) * local_aabb)
	return out

func test_pieces_tile_the_edge_with_no_gap_and_no_boundary_overshoot() -> void:
	# Sweep along the +x cliff edge of the outer-corner cell: the lip line (straight lips + the
	# corner lip) must cover the edge with NO gap, and no piece may protrude past the ±12 cell
	# boundary planes (the owner's "planes sticking out of the cliff top / walls").
	var data = Dress.compute(_region_outer(2), 0, 0, 1)
	var lips := _world_boxes(data, ["lip", "outer_lip"])
	var walls := _world_boxes(data, ["wall", "outer_wall"])
	for b in lips + walls:
		assert_lte((b as AABB).end.x, 12.01, "no piece crosses the +x cell boundary")
		assert_lte((b as AABB).end.z, 12.01, "no piece crosses the +z cell boundary")
	# lip coverage along the +x edge (pieces reaching into the x-edge band), z from the far end
	# up to the corner bevel margin (the module's rounded corner ends 0.25 inside the boundary)
	for z in range(-119, 117):   # -11.9 .. 11.6 in 0.1 steps
		var zz := float(z) * 0.1
		var covered := false
		for b in lips:
			var bb := b as AABB
			if bb.end.x > 10.6 and bb.position.z <= zz and bb.end.z >= zz:
				covered = true
				break
		assert_true(covered, "lip line covers the +x edge at z=%.1f (no slit next to the corner)" % zz)
	# wall coverage just below the top: the rock face may not have a vertical slit either
	for z in range(-119, 114):   # -11.9 .. 11.3
		var zz := float(z) * 0.1
		var covered := false
		for b in walls:
			var bb := b as AABB
			if bb.end.x > 10.6 and bb.position.z <= zz and bb.end.z >= zz:
				covered = true
				break
		assert_true(covered, "wall face covers the +x edge at z=%.1f (no slit next to the corner)" % zz)

# --- owner screenshot (2827641023 cell (2,4)): wall follows a DIPPING slope neighbour --------
# C=(1,1) storey 3 is a cliff top over a storey-1 SLOPE neighbour (2,1) that ramps further down
# to storey 0 at (2,0). Along C's east edge the neighbour's surface descends 4 → 0 toward the
# north corner, but the wall rows only spanned the cell-centre storey drop (12→4) — leaving a
# see-through void under the wall. The wall must extend down to the neighbour's actual surface.
func _region_dipping_slope():
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 2 and cz == 1: return 4.0    # C's east neighbour: a slope cell
		if cx == 2 and cz == 0: return 0.0    # ...ramping down to storey 0 on its north side
		return 12.0)
	return plan.compute_region(1, 1, 8)

func test_wall_rows_follow_a_dipping_neighbour_slope() -> void:
	var data = Dress.compute(_region_dipping_slope(), 1, 1, 1)   # dress only C=(1,1)
	# the north-end slot of C's east edge (x=34.5, z=13.5) faces neighbour ground that falls to
	# y=0 at the corner — the wall there must reach y=0 (3 rows), not stop at the storey drop (y=4)
	var deepest := 1e9
	for t in (data["wall"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 34.5) < 0.1 and o.z < 16.0:
			deepest = minf(deepest, o.y)
	assert_almost_eq(deepest, 0.0, 0.1, "east-edge wall extends down to the dipped neighbour surface (y=0)")

# --- owner screenshot (2827641023 cell (4,12)): cliff wraps around to the slope-facing side --
# C=(1,1) storey 3 cliff top (cliff via its storey-1 east neighbour) walls north over a 1-storey
# drop. Its WEST neighbour W=(0,1) is at the SAME storey but is a slope ramping down to storey 2
# on its north side — so along the C|W boundary W's surface descends 12 → 8 toward the north
# corner while C stays flat at 12. That exposed face must be dressed: lip + wall on C's west
# edge (where the slope has dipped) and an outer corner piece at C's NW corner.
func _region_slope_beside_cliff():
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 2 and cz == 1: return 4.0    # C's cliff drop (east)
		if cx == 1 and cz == 0: return 8.0    # C's north: storey 2 → C walls north
		if cx == 0 and cz == 0: return 8.0    # W's north: storey 2 → W is a slope descending north
		return 12.0)
	return plan.compute_region(1, 1, 8)

func test_cliff_wraps_around_to_the_slope_facing_side() -> void:
	var data = Dress.compute(_region_slope_beside_cliff(), 1, 1, 1)   # dress only C=(1,1)
	# (a) WEST-FACING lips appear on C's west edge where the slope has dipped (northern half)...
	# (facing matters: the north edge's end pieces also sit at x=13.5 but face north)
	var north_lips := 0
	var south_lips := 0
	for t in (data["lip"] as Array):
		var xf := t as Transform3D
		if (xf.basis * Vector3(0, 0, 1)).x > -0.9:
			continue   # not west-facing
		if xf.origin.z < 22.0: north_lips += 1
		if xf.origin.z > 30.0: south_lips += 1
	assert_gt(north_lips, 0, "west edge gets lip pieces where the neighbouring slope descends")
	# (b) ...but NOT on the flush south half (same height, no exposed face — no lip spam)
	assert_eq(south_lips, 0, "no lips where the same-storey neighbour is flush with the cliff top")
	# (c) a west-facing wall row covers the exposed face (profile dips to 8 → one row at y=8)
	var wall_found := false
	for t in (data["wall"] as Array):
		var xf := t as Transform3D
		if (xf.basis * Vector3(0, 0, 1)).x < -0.9 and absf(xf.origin.y - 8.0) < 0.1 and xf.origin.z < 22.0:
			wall_found = true
	assert_true(wall_found, "west edge gets wall rows under the lip (down past the slope's dip)")
	# (d) the NW corner (wall edge meets the wrapped edge) gets an outer corner piece
	var corner_found := false
	for t in (data["outer_lip"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 13.5) < 0.1 and absf(o.z - 13.5) < 0.1:
			corner_found = true
	assert_true(corner_found, "an outer corner piece caps the turn from the north wall to the west edge")

# --- owner (2026-07-01 round 2): extend tiles at the current level UNDER higher tiles -------
# C=(1,1) storey 2 (h=8) walls south (low ground at cz>=2). Its WEST neighbour W=(0,1) is
# storey 3 — higher and flat. W's own south wall is recessed 1.5 into W, so C's south wall
# line stopping at C's cell edge left a vertical slit at the junction. C's wall+lip line must
# continue one module INTO W (behind W's wall face) — "extend the tile at the current level
# underneath the higher tile so there aren't any gaps".
func _region_terrace():
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 1: return 12.0
		if cz >= 2: return 0.0
		return 8.0)
	return plan.compute_region(1, 1, 8)

func test_junction_into_a_continuing_higher_wall_is_owned_by_its_corner() -> void:
	# Round 3: when the HIGHER cell walls the same direction, its own outer corner covers the
	# junction — a straight extension module from the lower cell would z-fight it (the owner's
	# bright slab). The lower cell must emit NOTHING there; the higher cell's corner reaches down.
	var data = Dress.compute(_region_terrace(), 0, 1, 2)   # dress W=(0,1) AND C=(1,1)
	for t in (data["lip"] as Array):
		var o := (t as Transform3D).origin
		assert_false(absf(o.x - 10.5) < 0.1 and absf(o.z - 34.5) < 0.1 and o.y < 10.0,
			"no straight C-level lip inside W (the corner owns the junction)")
	for t in (data["wall"] as Array):
		var o := (t as Transform3D).origin
		assert_false(absf(o.x - 10.5) < 0.1 and absf(o.z - 34.5) < 0.1,
			"no straight C-level wall inside W (would z-fight W's corner walls)")
	var deepest := 1e9
	for t in (data["outer_wall"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 10.5) < 0.1 and absf(o.z - 34.5) < 0.1:
			deepest = minf(deepest, o.y)
	assert_almost_eq(deepest, 0.0, 0.1, "W's SE corner walls reach the low ground, covering the junction")

func test_step_junction_caps_the_lower_run_with_an_inner_turn() -> void:
	# Owner (round 5, seed 1751195249): where a lower cliff's wall line runs into a HIGHER cliff
	# that walls the SAME direction (a step), the lower run just stopped at the cell edge: the
	# ledge-level notch ("edge doesn't extend all the way to the cliff... it should extend to
	# the wall and end in a corner") plus a tall recess slit next to the higher cell's corner
	# stack showing the bare skirt ("grey plane sticking out of wall"). The junction is CONCAVE
	# from the lower run: it must end with an INNER turn into the higher wall's face — the
	# recessed arc tucks inside the higher corner's convex stack (no z-fight, unlike a straight
	# or outer module) and its wall rows fill the recess slit at each storey.
	var data = Dress.compute(_region_terrace(), 0, 1, 2)   # dress W=(0,1) AND C=(1,1)
	var cap := false
	var rows := 0
	for t in (data["inner_lip"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 10.5) < 0.1 and absf(o.z - 34.5) < 0.1 and absf(o.y - (8.0 + Dress.CORNER_LIP_LIFT)) < 0.05:
			cap = true
	for t in (data["inner_wall"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 10.5) < 0.1 and absf(o.z - 34.5) < 0.1 and o.y < 8.0:
			rows += 1
	assert_true(cap, "C's south run ends with an inner lip turning into W's wall face")
	assert_eq(rows, 2, "inner wall rows fill the recess slit down to the low ground (8m = 2 rows)")

func test_corner_caps_sit_nearly_flush_with_straight_lips() -> void:
	# Owner (round 5): corner caps floated CORNER_LIP_LIFT−LIP_LIFT = 5cm above the straight lip
	# modules they butt against — every butt joint showed a shadowed step that reads as a slit
	# ("gap next to corner still there"). The old tiles set both at y=0; we keep just enough
	# difference to win incidental overlaps without a visible step.
	assert_lt(Dress.CORNER_LIP_LIFT - Dress.LIP_LIFT, 0.015,
		"corner caps butt flush against straight lip runs (a taller step reads as a slit)")

func test_lip_run_into_a_higher_cliff_ends_in_an_outer_corner() -> void:
	# Owner (round 3): "cliff edge lips extending into higher cliffs should end in a corner."
	# C=(1,1) storey 2 walls south; W=(0,1) is storey 3 flat but does NOT wall south (its south
	# neighbour is at its own level) — C's lip line runs INTO W's east wall face and must be
	# capped with an outer corner piece turning into that wall, not a bare butt-cut.
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx <= -1: return 4.0               # W's cliff-maker (west drop 2)
		if cx == 0: return 12.0               # W's column: storey 3, flush to its south
		if cz >= 2: return 0.0                # low ground south of C
		return 8.0)                            # C=(1,1) and backdrop
	var r = plan.compute_region(1, 1, 8)
	var data = Dress.compute(r, 1, 1, 1)      # dress only C
	var corner_found := false
	for t in (data["outer_lip"] as Array):
		var xf := t as Transform3D
		if absf(xf.origin.x - 10.5) < 0.1 and absf(xf.origin.z - 34.5) < 0.1 and absf(xf.origin.y - 8.1) < 0.1:
			corner_found = true
			# the corner's two arms: native +z faces west (into the higher wall), native +x
			# faces south (continuing the lip line's drop side)
			assert_lt((xf.basis * Vector3(0, 0, 1)).x, -0.5, "one arm faces west (into the higher wall)")
			assert_gt((xf.basis * Vector3(1, 0, 0)).z, 0.5, "the other continues the south-facing lip line")
	assert_true(corner_found, "the lip run is capped with an outer corner at the higher wall")
	for t in (data["lip"] as Array):
		var o := (t as Transform3D).origin
		assert_false(absf(o.x - 10.5) < 0.1 and absf(o.z - 34.5) < 0.1,
			"no straight lip in the cap slot (the corner replaces it)")

func test_ghost_inner_corner_joins_walls_over_a_terraced_pocket() -> void:
	# Owner screenshot: C storey 2 with N and W both storey 3 (flat) and NW storey 4 — a
	# TERRACED pocket. The classic inner-corner rule needs the arms level with the diagonal,
	# so nothing joined N's and W's walls where they meet over C — a vertical slit. An inner
	# corner piece must join them, spanning the [h(C), min(h(N),h(W))] band.
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 0: return 16.0   # NW, storey 4
		if cx == 1 and cz == 0: return 12.0   # N, storey 3 (cliff via (2,0))
		if cx == 0 and cz == 1: return 12.0   # W, storey 3 (cliff via (0,2))
		if cx == 2 and cz == 0: return 0.0
		if cx == 0 and cz == 2: return 0.0
		return 8.0)                            # C=(1,1) and backdrop
	var r = plan.compute_region(1, 1, 8)
	assert_false(Field._is_inner_corner(r, 0, 0, Vector2i(1, 1)),
		"terraced pocket is NOT a classic inner corner (arms below the diagonal cell)")
	var data = Dress.compute(r, 1, 1, 1)   # dress only C — it owns the ghost corner
	var found := false
	for t in (data["inner_wall"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 10.5) < 0.1 and absf(o.z - 10.5) < 0.1 and absf(o.y - 8.0) < 0.1:
			found = true
	assert_true(found, "an inner corner joins N's and W's walls over the terraced pocket (span 8..12)")

# --- owner (round 4, seed 1450085760 cell (3,-2)): SLOPE pockets get inner corners too ------
# In a diagonal terrace the pocket cell is usually a SLOPE (all its drops are 1-storey), but
# its two cardinal arms are higher FLAT cells whose walls meet concavely over its corner. The
# ghost-inner-corner rule only ran for flat pocket cells, so these junctions showed a bare
# notch ("no inner corner tile as there should be"). It must run for EVERY cell.
# Diagonal-descent config mirroring the owner's screenshot (storeys 3/2/1 stepping SW):
# D=(2,0)=12 flat; arms N=(1,0)=8 and E=(2,1)=8 flat; pocket P=(1,1)=4 is a SLOPE.
func _region_diagonal_descent():
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 0: return 8.0
		if cx == 2 and cz == 1: return 8.0
		if cx == 1 and cz == 1: return 4.0
		if (cx == 0 and cz == 1) or (cx == 1 and cz == 2) or (cx == 0 and cz == 2): return 0.0
		return 12.0)
	return plan.compute_region(1, 1, 8)

func test_slope_pocket_gets_a_ghost_inner_corner() -> void:
	var r = _region_diagonal_descent()
	assert_false(Field.is_flat_cell(r, 1, 1), "the pocket is a slope cell")
	assert_true(Field.is_flat_cell(r, 1, 0), "the north arm is flat")
	assert_true(Field.is_flat_cell(r, 2, 1), "the east arm is flat")
	var data = Dress.compute(r, 1, 1, 1)   # dress only the pocket cell — it owns the ghost
	var wall_found := false
	var lip_found := false
	for t in (data["inner_wall"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 37.5) < 0.1 and absf(o.z - 10.5) < 0.1 and absf(o.y - 4.0) < 0.1:
			wall_found = true
	for t in (data["inner_lip"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 37.5) < 0.1 and absf(o.z - 10.5) < 0.1:
			lip_found = true
	assert_true(wall_found, "an inner corner wall joins the two arms' walls over the slope pocket")
	assert_true(lip_found, "with its inner lip on top")

func test_outer_corner_does_not_dive_below_its_arms() -> void:
	# Round 4 counterpart: D=(2,0)=12's SW outer corner used to take its depth from the diagonal
	# pocket sample, diving (convex-shaped, z-fighting the new inner piece) into the band that
	# belongs to the pocket's concave junction. Its depth must come from its own arms' walls.
	var r = _region_diagonal_descent()
	var data = Dress.compute(r, 2, 0, 1)
	var any := false
	for t in (data["outer_wall"] as Array):
		var o := (t as Transform3D).origin
		if absf(o.x - 37.5) < 0.1 and absf(o.z - 10.5) < 0.1:
			any = true
			assert_gt(o.y, 7.9, "D's outer corner stops with its arms (8..12); the pocket's inner piece owns the band below")
	assert_true(any, "D still gets its outer corner")

# --- issue 1: edges keep full coverage; the corner overlaps (no gap) ----------
func test_edges_keep_full_width_and_corner_present() -> void:
	# Each cliff edge is dressed across its FULL width (8 pieces) so nothing is dropped at the
	# corner (which previously left a gap). A convex-corner cell has two full edges plus a
	# dedicated corner piece that overlaps their ends.
	var side = Dress.compute(_region_side(2), 0, 0, 1)    # just cell (0,0): one edge, no corners
	var outer = Dress.compute(_region_outer(2), 0, 0, 1)  # cell (0,0): two edges + ONE outer corner
	assert_eq((side["lip"] as Array).size(), 8, "a lone straight edge with no corners keeps all 8 lip pieces")
	# Each of the two edges DROPS its one end slot that abuts the outer corner, so 7+7 = 14 straight
	# lips PLUS the corner piece — they butt together with NO overlap (owner: corner edges overlap).
	assert_eq((outer["lip"] as Array).size(), 14, "edges drop the end slot where the corner sits (no overlap)")
	assert_eq((outer["outer_lip"] as Array).size(), 1, "plus exactly one outer corner piece")
