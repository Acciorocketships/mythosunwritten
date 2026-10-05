extends GutTest
## September 27 judging pass (owner, seed 2697992464, photo 12 and photo 9):
## slope versus cliff is decided per EDGE. A side one storey from its
## neighbour is the ordinary smootherstep slope with no slope dressing, even
## beside a cliff. Only cliff edges are vertical and only they take the
## rounded envelope; an ordinary slope beside a path stays the plain slope.
## Dual-grid terrain tiles (September 30): heights live on 12 m points and
## walls on the dual-cell borders (x or z = 12 i + 6). The per-tile shape
## rules themselves (E2 cliff ends, seams, saddles) are pinned by
## test_terrain_tile_field; the September 27 cell-kernel checks and the
## photo-12 cell geography were retired with that kernel.

const Envelope := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")

static func _points(storey: Callable) -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 41):
		for x in range(-24, 41):
			storeys[Vector2i(x, z)] = int(storey.call(x, z))
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)

## Points z <= 3: x <= 2 at storey 3, x >= 3 at storey 4 (a one-storey slope
## in the tile x 24..36). Points z >= 4 at storey 1: a cliff wall on z = 42.
static func _cliff_and_slope(with_cliff := true) -> HeightfieldRegion:
	return _points(func(x: int, z: int) -> int:
		if with_cliff and z >= 4:
			return 1
		return 3 if x <= 2 else 4)

func test_only_cliff_edges_are_double_valued_across_varied_fields() -> void:
	for world_seed in [17, 4242, 918273, 2697992464]:
		var plan := HeightfieldPlan.new(world_seed, 40.0, 8, "mean", 3)
		var region := plan.compute_region(0, 0, 14)
		for pz in range(-10, 10):
			for px in range(-10, 10):
				var p := Vector2i(px, pz)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					if TerrainTileField.is_cliff_edge(region, p, d):
						continue
					var bx := float(px) * 12.0 + float(d.x) * 6.0
					var bz := float(pz) * 12.0 + float(d.y) * 6.0
					for i in 5:
						var t := (float(i) / 4.0) * 2.0 - 1.0
						var x := bx + float(d.y) * 6.0 * t
						var z := bz + float(d.x) * 6.0 * t
						assert_almost_eq(TerrainTileField.surface_y_on_side(region, x, z, p),
							TerrainTileField.surface_y_on_side(region, x, z, p + d), 0.0001,
							"seed %d slope seam %s->%s sample %d" % [world_seed, p, d, i])

func test_rock_skirts_stand_only_on_cliff_edges_and_follow_the_top() -> void:
	var region := _cliff_and_slope()
	var mesher := Mesher.new()
	mesher.prepare_resources()
	var data: Dictionary = mesher.compute_chunk(Vector2i.ZERO, region)
	var walls: Array = data.wall_collision_arrays
	assert_false(walls.is_empty(), "the cliff has a wall")
	var off_cliff := 0
	var on_cliff := 0
	var off_top := 0.0
	var vertices: PackedVector3Array = walls[Mesh.ARRAY_VERTEX]
	for v: Vector3 in vertices:
		if v.z != 42.0:
			off_cliff += 1
			continue
		on_cliff += 1
		# A wall's top vertices lie on the high point's own surface.
		var owner := Vector2i(TerrainTileField.point_of(v.x), 3)
		off_top = maxf(off_top, v.y - TerrainTileField.surface_y_on_side(region, v.x, 42.0, owner))
	assert_eq(off_cliff, 0, "no rock skirt on the one-storey side")
	assert_gt(on_cliff, 0, "the cliff side keeps its skirt")
	assert_lt(off_top, 0.01, "skirt tops never rise over the ground they back")

func test_envelope_dresses_the_cliff_but_not_the_one_storey_side() -> void:
	var region := _cliff_and_slope()
	var ground := func(q: Vector2) -> float: return TerrainTileField.surface_y(region, q.x, q.y)
	var env = Envelope.build(Rect2(-10.0, -40.0, 80.0, 130.0), ground, Callable(), 11)
	# Beyond the cliff's rounding reach the slope side keeps its own surface.
	var worst := 0.0
	for iz in range(-20, 25, 2):
		for ix in range(14, 47, 2):
			var q := Vector2(ix, iz)
			worst = maxf(worst, absf(env.at(q) - env.ground_node(q)))
	assert_lt(worst, 0.001, "no slope dressing along the one-storey side (worst %.3f m)" % worst)
	var foot := 0.0
	for ix in range(-10, 70, 2):
		foot = maxf(foot, env.at(Vector2(ix, 44.0)) - env.ground_node(Vector2(ix, 44.0)))
	assert_gt(foot, 1.0, "the cliff itself is rounded by the envelope")

func test_an_ordinary_slope_beside_a_road_keeps_its_surface() -> void:
	# Photo 9: a one-storey slope with a path along its top. The envelope
	# lifted the plain slope by up to 0.6 m and cut that lift back at the
	# road, leaving a jagged ridge and a dark strip beside the path.
	var region := _cliff_and_slope(false)
	var ground := func(q: Vector2) -> float: return TerrainTileField.surface_y(region, q.x, q.y)
	var road := func(q: Vector2) -> int: return 1 if absf(q.x - 22.0) < 2.0 else 0
	var env = Envelope.build(Rect2(-10.0, -30.0, 80.0, 60.0), ground, road, 11)
	var worst := 0.0
	for iz in range(-24, 25, 1):
		for ix in range(0, 60, 1):
			var q := Vector2(ix, iz)
			worst = maxf(worst, absf(env.at(q) - env.ground_node(q)))
	assert_lt(worst, 0.001, "the plain slope and the road edge keep the ground (worst %.3f m)" % worst)

## Points z <= 0 at storey 5; z >= 1 at storey 3 for x <= 0 and 4 for
## x >= 1. The south wall (z = 6) of point (0,0) is a two-storey cliff that
## ends (E2) where its low side becomes a one-storey slope beside (1,0).
static func _dying_cliff() -> HeightfieldRegion:
	return _points(func(x: int, z: int) -> int: return 5 if z <= 0 else (3 if x <= 0 else 4))

func _top_lift(region: HeightfieldRegion, top_rows: Callable, rect: Rect2) -> float:
	var ground := func(q: Vector2) -> float: return TerrainTileField.surface_y(region, q.x, q.y)
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
	# wall (20 -> 16 m). The dilated crest spilled over the sloping top as a
	# raised, darker nose.
	var region := _points(func(x: int, z: int) -> int: return (5 if x <= 0 else 4) if z <= 0 else 2)
	var worst := _top_lift(region, func(q: Vector2) -> bool: return q.y < 5.5,
		Rect2(-30.0, -16.0, 80.0, 40.0))
	assert_lt(worst, 0.05, "the rounding does not stand on the stepping crest (%.3f m)" % worst)

func test_no_raised_nose_where_a_cliff_ends() -> void:
	# The closing must not spill a crest ALONG its wall over the sloping top
	# beside a wall that dies away (E2). Under E3 (the default since October 4)
	# a lone cliff ends in an end face, a real wall whose own rounding may
	# stand on the slope beside the plateau: that is not a spilled nose.
	var saved_end := TerrainTileField.cliff_end
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E2
	var worst := _top_lift(_dying_cliff(), func(q: Vector2) -> bool: return q.y < 5.5,
		Rect2(-30.0, -16.0, 80.0, 40.0))
	TerrainTileField.cliff_end = saved_end
	assert_lt(worst, 0.05, "the ending cliff's top keeps its ground (%.3f m)" % worst)

func test_an_ending_cliff_ends_in_a_rounded_blob_not_a_spike() -> void:
	# Coordinator review: the rounded face of a dying cliff ran out as a thin
	# spike with a dark rock tail. The terrain's own wall (its two owners at
	# the dual-cell border) is rounded right to its end, so the face keeps its
	# plan width to the end instead of pinching to a point. Under the E2 cliff
	# end the wall keeps its full drop up to the tile centre (x = 6 here) and
	# the tile ramps beyond it: the last metres before the centre are the end.
	var region := _dying_cliff()
	var ground := func(q: Vector2) -> float: return TerrainTileField.surface_y(region, q.x, q.y)
	var env = Envelope.build(Rect2(-30.0, -16.0, 80.0, 40.0), ground, Callable(), 11)
	var checked := 0
	for xi in range(6, 12):
		var x := xi * 0.5
		var drop := TerrainTileField.surface_y_on_side(region, x, 6.0, Vector2i(TerrainTileField.point_of(x), 0)) \
			- TerrainTileField.surface_y_on_side(region, x, 6.0, Vector2i(TerrainTileField.point_of(x), 1))
		if drop < 0.3:
			continue
		var width := 0.0
		for zi in range(0, 40):
			var q := Vector2(x, 6.0 + zi * 0.5)
			if env.at(q) - env.ground_node(q) > 0.15:
				width = zi * 0.5
		assert_gte(width, 2.0, "the face still stands %.1f m wide at x=%.1f (drop %.2f m)" % [width, x, drop])
		checked += 1
	assert_gt(checked, 0, "the fixture reaches the cliff's dying end")
