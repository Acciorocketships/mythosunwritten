extends GutTest
## Performance shortcuts in the cliff sheet are exact (dual-grid performance
## pass, September 30): CliffSlopeEnvelope skips closings that cannot lift the
## ground (a grid without crests, lines without stamps or lift, corner
## roundings away from their reach, a bedrock cut zone without a cut);
## CliffSlopeField._columns filters with a linear-time window maximum; and
## TerrainTileField.wall_segments skips tiles without a cliff edge. Each is
## compared bit for bit with the full computation.

const Envelope := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const Field := preload("res://scripts/terrain/field/CliffSlopeField.gd")
const Style := preload("res://scripts/terrain/field/CliffRockStyle.gd")

func before_each() -> void:
	Style.apply("sheet_bedrock")

func after_each() -> void:
	Envelope.always_transform = false

## A plateau (storey 5) over a low plain, a one-storey slope across the plain,
## a taller block with a convex corner on the plateau, and a cliff that ends
## in a slope.
static func _cliffs() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 14):
		for x in range(-12, 14):
			var s := 5 if z <= 0 else (2 if x <= 2 else 3)
			if x >= 3 and z <= -2:
				s = 8
			if x <= -4 and z == 1:
				s = 4
			storeys[Vector2i(x, z)] = s
			levels[Vector2i(x, z)] = (x * 7 + z * 3) % 4 if z > 1 else 0
	return HeightfieldRegion.new(storeys, levels)

## Rolling ground: neighbouring points at most one storey apart (no walls).
static func _rolling() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 14):
		for x in range(-12, 14):
			storeys[Vector2i(x, z)] = 3 + int(floor(sin(x * 0.7) + cos(z * 0.5)))
			levels[Vector2i(x, z)] = (x + 2 * z) % 3 if (x + z) % 2 == 0 else 0
	return HeightfieldRegion.new(storeys, levels)

static func _build(region: HeightfieldRegion, full: bool, roads: bool, wet: bool):
	Envelope.always_transform = full
	var ground := func(q: Vector2) -> float: return TerrainTileField.surface_y(region, q.x, q.y)
	var excluded := Callable()
	if roads:
		excluded = func(q: Vector2) -> int: return 1 if q.x > 20.0 and q.x < 26.0 and q.y > -30.0 else 0
	var water := Callable()
	if wet:
		water = func(q: Vector2) -> float: return 9.5 if q.y > 40.0 else NAN
	var env = Envelope.build(Rect2(-40.0, -40.0, 100.0, 100.0), ground, excluded, 11, water)
	Envelope.always_transform = false
	return env

static func _bits(env) -> Array:
	return [var_to_bytes(env.surface), var_to_bytes(env.rock), var_to_bytes(env.moss_grade),
		var_to_bytes(env.ground), var_to_bytes(env.excluded)]

func test_cliffs_match_the_full_closing() -> void:
	for case: Array in [[false, false], [true, true]]:
		var fast = _build(_cliffs(), false, case[0], case[1])
		var full = _build(_cliffs(), true, case[0], case[1])
		var a := _bits(fast)
		var b := _bits(full)
		for k in a.size():
			assert_true(a[k] == b[k], "envelope array %d matches (roads %s, water %s)" % [k, case[0], case[1]])

func test_ground_without_walls_matches_the_full_closing() -> void:
	var fast = _build(_rolling(), false, true, false)
	var full = _build(_rolling(), true, true, false)
	var a := _bits(fast)
	var b := _bits(full)
	for k in a.size():
		assert_true(a[k] == b[k], "envelope array %d matches without walls" % k)
	assert_false(fast.moss_grade.is_empty(), "the shortcut still grades the moss")

func test_window_max_is_the_clipped_window_maximum() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n in [1, 3, 8, 17, 18, 40, 101]:
		for r in [1, 3, 8]:
			var f := PackedFloat64Array()
			for i in n:
				f.append(-INF if rng.randf() < 0.6 else rng.randf_range(-5.0, 5.0))
			var got := Field._window_max(f, r)
			var want := PackedFloat64Array()
			for i in n:
				var m := -INF
				for d in range(maxi(0, i - r), mini(n, i + r + 1)):
					m = maxf(m, f[d])
				want.append(m)
			assert_eq(got, want, "n %d r %d" % [n, r])

## The former wall_segments: every half-segment sampled, no tile test.
static func _all_segments(region, rect: Rect2) -> Array[Dictionary]:
	var s := TerrainTileField.SPACING
	var out: Array[Dictionary] = []
	for j in range(floori(rect.position.y / s) - 1, ceili(rect.end.y / s) + 2):
		for i in range(floori(rect.position.x / s) - 1, ceili(rect.end.x / s) + 2):
			var p := Vector2i(i, j)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var q := p + d
				var mid := (Vector2(p) + Vector2(d) * 0.5) * s
				var along := Vector2(-d.y, d.x) * s * 0.5
				for pair: Array in [[mid - along, mid], [mid, mid + along]]:
					var a: Vector2 = pair[0]
					var b: Vector2 = pair[1]
					if not Rect2(a, Vector2.ZERO).expand(b).intersects(rect, true):
						continue
					var inset := (b - a) * 0.001
					var pa := TerrainTileField.surface_y_on_side(region, a.x + inset.x, a.y + inset.y, p)
					var pb := TerrainTileField.surface_y_on_side(region, b.x - inset.x, b.y - inset.y, p)
					var qa := TerrainTileField.surface_y_on_side(region, a.x + inset.x, a.y + inset.y, q)
					var qb := TerrainTileField.surface_y_on_side(region, b.x - inset.x, b.y - inset.y, q)
					var mp := TerrainTileField.surface_y_on_side(region, (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, p)
					var mq := TerrainTileField.surface_y_on_side(region, (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, q)
					if maxf(maxf(absf(pa - qa), absf(pb - qb)), absf(mp - mq)) <= 0.001:
						continue
					var p_high := (pa + pb + mp) >= (qa + qb + mq)
					out.append({"a": a, "b": b, "high": p if p_high else q, "low": q if p_high else p,
						"top": Vector2(pa, pb) if p_high else Vector2(qa, qb),
						"bottom": Vector2(qa, qb) if p_high else Vector2(pa, pb),
						"normal": Vector2(d) if p_high else -Vector2(d)})
	return out

func test_wall_segments_skip_only_wall_free_tiles() -> void:
	var saved := TerrainTileField.cliff_end
	for end in [TerrainTileField.CliffEnd.E1, TerrainTileField.CliffEnd.E2]:
		TerrainTileField.cliff_end = end
		for region in [_cliffs(), _rolling()]:
			var rect := Rect2(-60.0, -60.0, 130.0, 130.0)
			assert_eq(var_to_str(TerrainTileField.wall_segments(region, rect)),
				var_to_str(_all_segments(region, rect)))
	TerrainTileField.cliff_end = saved
