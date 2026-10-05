extends GutTest
## Cliff ends on the dual-grid tiles (tile gallery review, September 30:
## mixed_e2_end / mixed_e1_end / terrace_hill). A cliff that ends in a slope
## hands over from a wall to ground that is continuous but, for its first
## metres, far steeper than any ordinary slope: under E2 the wall runs to the
## tile centre and a ramp then fans out to the slope profile; under E1 the wall
## shortens across the tile over a sloping low side. The sheet's rounding
## stopped with a steep cut across the fall line (E2: the FOOT fillet that
## carries the rounding on over the ramp was gated by the lift at each node, so
## it stopped where the lift ran out; E1: the widened shoulder of a
## centimetre-high wall stood metres over the falling low side, then ended at
## the tile edge). The fillet now also reaches along each wall as far as a
## fillet can from its rounding, and a crest's rounding never stands higher
## over the ground than the crest's own drop, so the rounding tapers out along
## the end instead of stopping.

const Envelope := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const Field := preload("res://scripts/terrain/field/CliffSlopeField.gd")
const Style := preload("res://scripts/terrain/field/CliffRockStyle.gd")
const H := 0.5

## Points z <= 0 at storey 5 (20 m); z >= 1 at storey 3 for x <= 0 and 4 for
## x >= 1. The south wall (z = 6) of point (0, 0) is a two-storey cliff over
## x <= 6 that ends in tile (0, 0), whose east edge (x = 12) is a one-storey
## slope.
static func _ending_cliff() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 41):
		for x in range(-24, 41):
			storeys[Vector2i(x, z)] = 5 if z <= 0 else (3 if x <= 0 else 4)
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)

var _saved_end: int

func before_each() -> void:
	_saved_end = TerrainTileField.cliff_end
	Style.apply("sheet_bedrock")

func after_each() -> void:
	TerrainTileField.cliff_end = _saved_end

static func _envelope(region: HeightfieldRegion):
	var ground := func(q: Vector2) -> float: return TerrainTileField.surface_y(region, q.x, q.y)
	return Envelope.build(Rect2(-30.0, -16.0, 80.0, 40.0), ground, Callable(), 11)

static func _lift(env, q: Vector2) -> float:
	return env.at(q) - env.ground_node(q)

## Largest step of the sheet between neighbouring nodes along the wall (x),
## beyond the step the ground itself takes there, over the low side and the
## end tile: a cut across the fall line where the rounding stops.
static func _worst_end_step(env) -> Dictionary:
	var worst := {"step": 0.0, "at": Vector2.ZERO}
	for zi in range(12, 44):         # z 6 .. 21.5 (the low side and the foot)
		for xi in range(0, 36):      # x 0 .. 17.5 (wall end, the end tile, beyond)
			var a := Vector2(xi * H, zi * H)
			var b := a + Vector2(H, 0.0)
			var step := absf(env.at(b) - env.at(a)) - absf(env.ground_node(b) - env.ground_node(a))
			if step > worst.step:
				worst = {"step": step, "at": a}
	return worst

func test_e2_cliff_end_rounding_tapers_instead_of_stopping() -> void:
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E2
	var env = _envelope(_ending_cliff())
	var worst := _worst_end_step(env)
	assert_lt(worst.step, 0.6, "the sheet steps %.2f m between neighbouring nodes at %s (a cut across the end)" \
		% [worst.step, worst.at])
	# The rounding carries past the tile centre (x = 6) over the steep ramp.
	var past := 0.0
	for zi in range(12, 40):
		past = maxf(past, _lift(env, Vector2(8.0, zi * H)))
	assert_gt(past, 0.5, "the ramp just past the wall's end keeps some rounding (%.2f m)" % past)
	# ...and it is gone over the ordinary slope tile beyond the end (x >= 12).
	var beyond := 0.0
	for zi in range(0, 48):
		for xi in range(24, 32):
			beyond = maxf(beyond, _lift(env, Vector2(xi * H, zi * H)))
	assert_lt(beyond, 0.05, "no rounding over the ordinary slope beyond the end (%.2f m)" % beyond)

func test_e1_cliff_end_rounding_tapers_instead_of_stopping() -> void:
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E1
	var env = _envelope(_ending_cliff())
	var worst := _worst_end_step(env)
	assert_lt(worst.step, 0.6, "the sheet steps %.2f m between neighbouring nodes at %s (a cut across the end)" \
		% [worst.step, worst.at])

func test_e2_ramp_top_is_drawn_without_a_notch() -> void:
	# mixed_e2_end: a thin dark notch in the plateau lip beside the wall's end.
	# Just past the tile centre the ramp drops metres within less than one of
	# the terrain sheet's 2 m quads, so the quad on the high side slants down
	# to the ramp's middle on the wall line, up to 1.5 m under the ground; the
	# sheet's solid, lying on those chords where it does not raise the ground,
	# drew the same notch.
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E2
	var region := _ending_cliff()
	var owned := Rect2(-6.0, -6.0, 36.0, 36.0)
	var field = Field.new(TerrainTileField.wall_segments(region, owned.grow(24.0)), 11, region, owned)
	var env = field.envelope()
	var columns: Dictionary = field._columns(owned)
	var worst := {"sag": 0.0, "at": Vector2.ZERO}
	for zi in range(6, 12):          # z 3 .. 5.5: the high side of the ramp's top
		for xi in range(12, 22):     # x 6 .. 10.5
			var key := Vector2i(xi, zi)
			var q := Vector2(key) * H
			var drawn: float = field._mesh_height(q)
			if columns.has(key):
				drawn = maxf(drawn, field._solid_top(env, q))
			var sag := TerrainTileField.surface_y(region, q.x, q.y) - drawn
			if sag > worst.sag:
				worst = {"sag": sag, "at": q}
	assert_lt(worst.sag, 0.3, "the ramp top is drawn %.2f m under the ground at %s" % [worst.sag, worst.at])

func test_e1_rounding_shrinks_toward_the_end_without_a_blob() -> void:
	# The shortening wall of E1 is centimetres high near the slope edge, over a
	# low side that keeps falling: its shoulder, widened to keep the face's
	# plan width, stood two metres over that slope as a blob near the end.
	# The wall only shrinks toward the end (+x), so its rounding may too.
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E1
	var env = _envelope(_ending_cliff())
	var worst := {"rise": 0.0, "at": Vector2.ZERO}
	for zi in range(12, 44):         # z 6 .. 21.5
		for xi in range(12, 32):     # x 6 .. 15.5: past the tile centre to beyond the end
			var a := Vector2(xi * H, zi * H)
			var rise := _lift(env, a + Vector2(H, 0.0)) - _lift(env, a)
			if rise > worst.rise:
				worst = {"rise": rise, "at": a}
	assert_lt(worst.rise, 0.05, "the rounding grows %.2f m toward the end at %s" % [worst.rise, worst.at])

## Points z <= 0 at storey 5; for "stacked" z <= -1 at storey 7 (a 12 m
## terrace behind the lower wall); z >= 1 at storey 3.
static func _straight(stacked: bool) -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 41):
		for x in range(-24, 41):
			storeys[Vector2i(x, z)] = (7 if stacked and z <= -1 else 5) if z <= 0 else 3
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)

func test_walls_without_an_end_keep_their_rounding() -> void:
	# Review of the cliff-end fillet: carried along a wall, the fillet's reach
	# must follow the rounding the surface actually has (narrow valleys, wide
	# ridges), or it opened at feet and terraces the rounding never raised.
	# Frozen from the envelope before the cliff-end change: a straight wall and
	# a stacked terrace have no end, so their rounding is unchanged.
	var frozen := {false: [16811.506183, 104621.807001], true: [35260.266472, 220539.313697]}
	for stacked: bool in [false, true]:
		var env = _envelope(_straight(stacked))
		var total := 0.0
		var squares := 0.0
		for zi in range(-32, 80):
			for xi in range(-60, 100):
				var lift := _lift(env, Vector2(xi * H, zi * H))
				total += lift
				squares += lift * lift
		assert_almost_eq(total, float(frozen[stacked][0]), 0.01, "stacked=%s: summed rounding" % stacked)
		assert_almost_eq(squares, float(frozen[stacked][1]), 0.01, "stacked=%s: summed squared rounding" % stacked)

func test_wall_end_lip_is_lit_level() -> void:
	# The sliver at every E2 wall end: the plateau vertex on the wall's last
	# corner (6, 20, 6) took its +x gradient sample on the neighbour's
	# surface, which agrees with it at the vertex but 0.25 m on stands on the
	# ramp's middle, 3 m lower: its normal leaned 10 degrees into the ramp.
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E2
	var region := _ending_cliff()
	var vertices := PackedVector3Array([Vector3(6.0, 20.0, 6.0), Vector3(4.0, 20.0, 6.0), Vector3(6.0, 20.0, 4.0)])
	var normals := TerrainChunkMesher.field_normals(vertices, region, {})
	for i in vertices.size():
		assert_gt(normals[i].y, 0.999, "the plateau at %s is lit level (normal %s)" % [vertices[i], normals[i]])

## Owner photo 1 (October 4 judging pass, seed 2697992464, crosshair
## (491.4, 18.6, 881.0)): a cliff that dies into a slope while its top climbs
## along it. Points z <= 0 at storey 5 for x <= 0 and 6 for x >= 1; z >= 1 at
## storey 4 for x <= 0 and 3 for x >= 1. The south wall (z = 6) of tile (0, 0)
## is 4 m tall at x = 0 and 12 m at x = 12, its crest rising 4 m along it.
static func _climbing_end() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 41):
		for x in range(-24, 41):
			storeys[Vector2i(x, z)] = (5 if x <= 0 else 6) if z <= 0 else (4 if x <= 0 else 3)
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)

## Largest height of the sheet within 3 m on the low side of the wall line
## z = 6 over the sheet just across it (z = 5.5), over x -12 .. 24: a trough
## along the lip, at the wall and on past its end.
static func _worst_trough(env) -> Dictionary:
	var worst := {"rise": 0.0, "at": Vector2.ZERO}
	for xi in range(-24, 49):
		var lip := Vector2(xi * H, 5.5)
		for j in range(1, 7):
			var rise: float = env.at(lip + Vector2(0.0, j * H)) - env.at(lip)
			if rise > worst.rise:
				worst = {"rise": rise, "at": lip}
	return worst

func test_the_rounding_never_stands_over_its_own_lip() -> void:
	# The dark streak in owner photo 1 was a trough along the wall line: the
	# foot fillet, an isotropic closing, carried the higher crest a metre or
	# two along the wall onto the low side, so the sheet there stood up to
	# 0.9 m over the plateau's edge across the line, which keeps its ground.
	# The rounding of a wall falls away from its lip, also past its end.
	for end in [TerrainTileField.CliffEnd.E2, TerrainTileField.CliffEnd.E1]:
		TerrainTileField.cliff_end = end
		for fixture: String in ["climbing_end", "ending_cliff"]:
			var region := _climbing_end() if fixture == "climbing_end" else _ending_cliff()
			var worst := _worst_trough(_envelope(region))
			assert_lt(worst.rise, 0.05, "%s E%d: the sheet stands %.2f m over the lip at %s" \
				% [fixture, end + 1, worst.rise, worst.at])


## E3 (clean cliff ends): the bare ground at an end face's foot can lie under
## a slope that rises back toward the plateau beyond it (a cliff 8 m over 0
## for x <= 0, ending where the ground beside it is a 4 -> 8 slope). The
## sheet's foot fillet fills it: along the wall, the rendered surface over the
## end tile never dips.
func test_e3_cliff_end_renders_without_a_dip() -> void:
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E3
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 25):
		for x in range(-24, 25):
			storeys[Vector2i(x, z)] = 2 if z >= 1 else (0 if x <= 0 else 1)
			levels[Vector2i(x, z)] = 0
	var env = _envelope(HeightfieldRegion.new(storeys, levels))
	var worst := {"dip": 0.0, "at": Vector2.ZERO}
	for zi in range(13, 25):          # z 6.5 .. 12: the end tile beyond the wall line
		var row: Array[float] = []
		for xi in 49:                 # x -6 .. 18
			row.append(env.at(Vector2(-6.0 + xi * H, zi * H)))
		for i in row.size():
			var before := -INF
			var after := -INF
			for k in i: before = maxf(before, row[k])
			for k in range(i + 1, row.size()): after = maxf(after, row[k])
			var dip := minf(before, after) - row[i]
			if dip > worst.dip:
				worst = {"dip": dip, "at": Vector2(-6.0 + i * H, zi * H)}
	assert_lt(worst.dip, 0.05, "the sheet dips %.2f m at %s beside the end face" % [worst.dip, worst.at])
