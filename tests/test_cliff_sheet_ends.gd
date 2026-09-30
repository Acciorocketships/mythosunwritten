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
