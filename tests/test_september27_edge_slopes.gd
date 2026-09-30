extends GutTest
## September 27 judging pass (owner, seed 2697992464, photo 12 and photo 9):
## slope versus cliff is decided per EDGE, not per tile. A side one storey
## from its neighbour is the ordinary smootherstep slope with no slope
## dressing, even when the same cell walls down two or more storeys on
## another side. Only cliff edges are vertical and only they take the
## rounded envelope; an ordinary slope beside a path stays the plain slope.

const Envelope := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")

## Rows z <= 3: x <= 2 at storey 3, x >= 3 at storey 4 (a one-storey slope
## along x = 60). Rows z >= 4 at storey 1: a cliff under row 3. Cell (3,3)
## therefore has a one-storey west side and a three-storey south side.
static func _cliff_and_slope(with_cliff := true) -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 24):
		for x in range(-12, 24):
			var s := 3 if x <= 2 else 4
			if with_cliff and z >= 4:
				s = 1
			storeys[Vector2i(x, z)] = s
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)

func test_one_storey_side_of_a_cliff_cell_is_the_standard_slope() -> void:
	var region := _cliff_and_slope()
	var plain := _cliff_and_slope(false)
	var cell := Vector2i(3, 3)
	assert_true(TerrainSurfaceField.is_wall_edge(region, cell.x, cell.y, Vector2i(0, 1)),
		"the three-storey south side is a cliff")
	assert_false(TerrainSurfaceField.is_cliff_edge(region, cell.x, cell.y, Vector2i(-1, 0)),
		"the one-storey west side is not")
	assert_true(TerrainSurfaceField.is_walkable_edge(region, cell, Vector2i(-1, 0)),
		"the one-storey side is walkable")
	# Every point of the cell equals the same cell on a hillside with no cliff:
	# its west side is exactly the ordinary one-storey slope tile.
	for iz in 13:
		for ix in 13:
			var x := float(cell.x) * 24.0 - 12.0 + 2.0 * ix
			var z := float(cell.y) * 24.0 - 12.0 + 2.0 * iz
			assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region, x, z, cell.x, cell.y),
				TerrainSurfaceField.surface_y_in_cell(plain, x, z, cell.x, cell.y), 0.0001,
				"cell (3,3) at (%.0f,%.0f) is the standard slope" % [x, z])
	# The shared seam is single-valued for both owners along its whole length.
	for i in 13:
		var z := float(cell.y) * 24.0 - 12.0 + 2.0 * i
		assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region, 60.0, z, 3, 3),
			TerrainSurfaceField.surface_y_in_cell(region, 60.0, z, 2, 3), 0.0001,
			"one boundary curve at z=%.0f" % z)

func test_only_cliff_edges_are_double_valued_across_varied_fields() -> void:
	for world_seed in [17, 4242, 918273, 2697992464]:
		var plan := HeightfieldPlan.new(world_seed, 40.0, 8, "mean", 3)
		var region := plan.compute_region(0, 0, 7)
		for cz in range(-5, 5):
			for cx in range(-5, 5):
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					if TerrainSurfaceField.is_cliff_edge(region, cx, cz, d):
						continue
					var bx := float(cx) * 24.0 + float(d.x) * 12.0
					var bz := float(cz) * 24.0 + float(d.y) * 12.0
					for i in 5:
						var t := (float(i) / 4.0) * 2.0 - 1.0
						var x := bx + float(d.y) * 12.0 * t
						var z := bz + float(d.x) * 12.0 * t
						assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region, x, z, cx, cz),
							TerrainSurfaceField.surface_y_in_cell(region, x, z, cx + d.x, cz + d.y), 0.0001,
							"seed %d slope seam (%d,%d)->%s sample %d" % [world_seed, cx, cz, d, i])

func test_rock_skirts_stand_only_on_cliff_edges_and_follow_the_top() -> void:
	var region := _cliff_and_slope()
	var mesher := Mesher.new()
	mesher.prepare_resources()
	var data: Dictionary = mesher.compute_chunk(Vector2i.ZERO, region)
	var walls: Array = data.wall_collision_arrays
	assert_false(walls.is_empty(), "the cliff has a wall")
	var on_slope_seam := 0
	var on_cliff := 0
	var off_top := 0.0
	var vertices: PackedVector3Array = walls[Mesh.ARRAY_VERTEX]
	for v: Vector3 in vertices:
		if absf(v.x - 60.0) < 0.001 and v.z < 83.9:
			on_slope_seam += 1
		if absf(v.z - 84.0) < 0.001:
			on_cliff += 1
			# A wall's top vertices lie on the high cell's own boundary.
			var owner := Vector2i(roundi(v.x / 24.0), 3)
			var top := TerrainSurfaceField.surface_y_in_cell(region, v.x, 84.0, owner.x, owner.y)
			if v.y > 4.0 + 0.01:
				off_top = maxf(off_top, v.y - top)
	assert_eq(on_slope_seam, 0, "no rock skirt on the one-storey side")
	assert_gt(on_cliff, 0, "the cliff side keeps its skirt")
	assert_lt(off_top, 0.01, "skirt tops never rise over the ground they back")

func test_envelope_dresses_the_cliff_but_not_the_one_storey_side() -> void:
	var region := _cliff_and_slope()
	var ground := func(q: Vector2) -> float: return TerrainSurfaceField.surface_y(region, q.x, q.y)
	var env = Envelope.build(Rect2(20.0, -40.0, 80.0, 150.0), ground, Callable(), 11)
	# Beyond the cliff's rounding reach the slope side keeps its own surface.
	var worst := 0.0
	for iz in range(0, 57, 2):
		for ix in range(44, 77, 2):
			var q := Vector2(ix, iz)
			worst = maxf(worst, absf(env.at(q) - env.ground_node(q)))
	assert_lt(worst, 0.001, "no slope dressing along the one-storey side (worst %.3f m)" % worst)
	var foot := 0.0
	for ix in range(0, 120, 2):
		foot = maxf(foot, env.at(Vector2(ix, 86.0)) - env.ground_node(Vector2(ix, 86.0)))
	assert_gt(foot, 1.0, "the cliff itself is rounded by the envelope")

func test_an_ordinary_slope_beside_a_road_keeps_its_surface() -> void:
	# Photo 9: a one-storey slope with a path along its top. The envelope
	# lifted the plain slope by up to 0.6 m and cut that lift back at the
	# road, leaving a jagged ridge and a dark strip beside the path.
	var region := _cliff_and_slope(false)
	var ground := func(q: Vector2) -> float: return TerrainSurfaceField.surface_y(region, q.x, q.y)
	var road := func(q: Vector2) -> int: return 1 if absf(q.x - 46.0) < 2.0 else 0
	var env = Envelope.build(Rect2(20.0, -30.0, 80.0, 60.0), ground, road, 11)
	var worst := 0.0
	for iz in range(-24, 25, 1):
		for ix in range(30, 90, 1):
			var q := Vector2(ix, iz)
			worst = maxf(worst, absf(env.at(q) - env.ground_node(q)))
	assert_lt(worst, 0.001, "the plain slope and the road edge keep the ground (worst %.3f m)" % worst)

func test_reported_site_one_storey_sides_are_slopes() -> void:
	# Photo 12, Opal Highlands: storeys 17 17 18 / 16 [17] 17 / 14 14 14
	# around cell (17,39). (17,39) walls three storeys down to (17,40), so it
	# was a flat cliff tile whose one-storey west side to (16,39) was a wall.
	var water := TerrainWorldTuning.make_water(2697992464)
	var heightfield := TerrainWorldTuning.make_heightfield(2697992464, water)
	var region := heightfield.compute_region(17, 39, 5)
	assert_eq([region.storey_at(16, 39), region.storey_at(17, 39), region.storey_at(17, 40)], [16, 17, 14],
		"the reported storeys")
	assert_true(TerrainSurfaceField.is_wall_edge(region, 17, 39, Vector2i(0, 1)), "the south side is a cliff")
	assert_true(TerrainSurfaceField.is_walkable_edge(region, Vector2i(17, 39), Vector2i(-1, 0)),
		"the one-storey west side is a walkable slope")
	for i in 13:
		var z := 39.0 * 24.0 - 12.0 + 2.0 * i
		assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region, 396.0, z, 17, 39),
			TerrainSurfaceField.surface_y_in_cell(region, 396.0, z, 16, 39), 0.0001,
			"single-valued west seam at z=%.0f" % z)
	# The corner (396, 924) where the owner saw the groove: every owner meets it.
	var heights := []
	for cell: Vector2i in [Vector2i(16, 38), Vector2i(17, 38), Vector2i(16, 39), Vector2i(17, 39)]:
		heights.append(snappedf(TerrainSurfaceField.surface_y_in_cell(region, 396.0, 924.0, cell.x, cell.y), 0.001))
	assert_eq(heights, [64.0, 64.0, 64.0, 64.0], "one corner height for all four owners")

## September 29 (owner): no special "dying cliff" profile. A cliff edge keeps
## its full height; where its corner ring is slope-connected (the cliff ends
## in a hillside) the top meets that corner through the same smootherstep
## blend as every other quadrant, and the plateau beside it stays flat. The
## former rule lowered the edge midpoint halfway toward that corner, which
## dented the plateau beside the edge (owner photos 6/7, "deformed").
## Rows z <= 0 at storey 5; row z >= 1 at storey 3 for x <= 0 and 4 for
## x >= 1. The south cliff of (0,0) (two storeys) ends at the corner x = 12,
## where the ring (0,0)-(1,0)-(1,1)-(0,1) is slope-connected.
static func _dying_cliff() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			storeys[Vector2i(x, z)] = 5 if z <= 0 else (3 if x <= 0 else 4)
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)

func test_a_cliff_keeps_its_height_and_ends_through_the_standard_corner() -> void:
	var region := _dying_cliff()
	assert_true(TerrainSurfaceField.is_wall_edge(region, 0, 0, Vector2i(0, 1)), "a two-storey cliff")
	for x: float in [-12.0, -6.0, 0.0]:
		assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region, x, 12.0, 0, 0), 20.0, 0.0001,
			"the wall keeps its full height at x=%.0f" % x)
	for i in 13:
		var x := float(i)
		var expected := lerpf(20.0, 12.0, TerrainSurfaceField.transition_weight(x))
		assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region, x, 12.0, 0, 0), expected, 0.0001,
			"the end quadrant is the standard smootherstep blend at x=%.0f" % x)
	# The plateau beside the cliff is flat: nothing dents it.
	for p: Vector2 in [Vector2(-10, 0), Vector2(-4, 6), Vector2(-1, 11), Vector2(0, 11.9)]:
		assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region, p.x, p.y, 0, 0), 20.0, 0.0001,
			"the plateau stays level at %s" % p)
	# Every owner of the end corner still meets it at one height.
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		assert_almost_eq(TerrainSurfaceField.surface_y_in_cell(region, 12.0, 12.0, cell.x, cell.y), 12.0, 0.0001,
			"owner %s meets the end corner" % cell)

func _top_lift(region: HeightfieldRegion, top_rows: Callable, rect: Rect2) -> float:
	var ground := func(q: Vector2) -> float: return TerrainSurfaceField.surface_y(region, q.x, q.y)
	var env = Envelope.build(rect, ground, Callable(), 11)
	var worst := 0.0
	for iz in range(int(rect.position.y), int(rect.end.y) + 1):
		for ix in range(int(rect.position.x), int(rect.end.x) + 1):
			var q := Vector2(ix, iz)
			if top_rows.call(q):
				worst = maxf(worst, env.at(q) - env.ground_node(q))
	return worst

func test_no_raised_nose_on_a_crest_that_steps_down() -> void:
	# HookA view, photo 12: the crest of a wall steps down a storey along the
	# wall (68 -> 64 m). The dilated crest spilled over the sloping top as a
	# raised, darker nose.
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			storeys[Vector2i(x, z)] = (5 if x <= 0 else 4) if z <= 0 else 2
			levels[Vector2i(x, z)] = 0
	var region := HeightfieldRegion.new(storeys, levels)
	var worst := _top_lift(region, func(q: Vector2) -> bool: return q.y < 11.5,
		Rect2(-30.0, -10.0, 80.0, 40.0))
	assert_lt(worst, 0.05, "the rounding does not stand on the stepping crest (%.3f m)" % worst)

func test_no_raised_nose_where_a_cliff_ends() -> void:
	var worst := _top_lift(_dying_cliff(), func(q: Vector2) -> bool: return q.y < 11.5,
		Rect2(-30.0, -10.0, 80.0, 40.0))
	assert_lt(worst, 0.05, "the ending cliff's top keeps its ground (%.3f m)" % worst)

func test_an_ending_cliff_ends_in_a_rounded_blob_not_a_spike() -> void:
	# Coordinator review: the rounded face of a dying cliff ran out as a thin
	# spike with a dark rock tail. The terrain's own wall (its two owners at
	# the cell boundary) is rounded right to its end, with a shoulder that
	# widens as the drop falls, so the face keeps its plan width almost to
	# the end instead of pinching to a point.
	var region := _dying_cliff()
	var ground := func(q: Vector2) -> float: return TerrainSurfaceField.surface_y(region, q.x, q.y)
	var env = Envelope.build(Rect2(-30.0, -10.0, 80.0, 40.0), ground, Callable(), 11)
	var checked := 0
	for xi in range(-8, 30):
		var x := xi * 0.5
		var drop := TerrainSurfaceField.surface_y_in_cell(region, x, 12.0, 0, 0) \
			- TerrainSurfaceField.surface_y_in_cell(region, x, 12.0, 0, 1)
		if drop < 0.3 or drop > 1.0:
			continue
		var width := 0.0
		for zi in range(0, 40):
			var q := Vector2(x, 12.0 + zi * 0.5)
			if env.at(q) - env.ground_node(q) > 0.15:
				width = zi * 0.5
		assert_gte(width, 2.0, "the face still stands %.1f m wide at x=%.1f (drop %.2f m)" % [width, x, drop])
		checked += 1
	assert_gt(checked, 0, "the fixture reaches the cliff's dying end")
