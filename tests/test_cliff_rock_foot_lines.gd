extends GutTest

# Historical step-ground fixtures exercise the E3 envelope/fillet. The shared
# production profile supplies continuous ground and is covered separately.
var _fixture_saved_mode: int
func before_each() -> void:
	_fixture_saved_mode = TerrainTileField.cliff_end
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E3
func after_each() -> void:
	TerrainTileField.cliff_end = _fixture_saved_mode
	STYLE.apply("sheet_bedrock")
## Rock foot lines of the whole-wall slope come from the terrain's own walls
## (TerrainTileField.wall_segments, dual-grid terrain tiles, September 30), not
## from native KayKit piece formations: each wall segment is split where its
## top or bottom changes, outer corners add a zero-radius arc, and a chunk's
## rocks and reservations follow its walls.

const FIELD := preload("res://scripts/terrain/field/CliffSlopeField.gd")
const ROCKS := preload("res://scripts/terrain/field/CliffRockDressing.gd")
const STYLE := preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SEED := 2697992464


func before_all() -> void:
	STYLE.apply("sheet_bedrock")


static func _points(heights: Callable) -> HeightfieldRegion:
	var storeys := {}
	var levels := {}
	for j in range(-24, 41):
		for i in range(-24, 41):
			var h: float = heights.call(i, j)
			storeys[Vector2i(i, j)] = floori(h / 4.0)
			levels[Vector2i(i, j)] = floori(fposmod(h, 4.0))
	return HeightfieldRegion.new(storeys, levels)


## A 12 m plateau west of x = 90 (points i <= 7), the full window long.
static func _straight() -> HeightfieldRegion:
	return _points(func(i: int, _j: int) -> float: return 12.0 if i <= 7 else 0.0)


## The plateau i <= 7, j <= 9: walls x = 90 and z = 114 meet at an outer corner.
static func _corner() -> HeightfieldRegion:
	return _points(func(i: int, j: int) -> float: return 12.0 if i <= 7 and j <= 9 else 0.0)


const AREA := Rect2(-6, -6, 192, 192)


func test_a_straight_wall_is_one_foot_line_on_its_wall_line() -> void:
	var region := _straight()
	var walls := TerrainTileField.wall_segments(region, AREA)
	assert_gt(walls.size(), 20)
	var field = FIELD.new(walls, SEED, region, AREA)
	for s: Dictionary in field._primitives:
		assert_false(s.arc, "a straight wall has no corner")
		assert_almost_eq((s.a as Vector2).x, 90.0, 0.0001, "the foot line is the wall line itself")
		assert_eq(s.n, Vector2(1, 0), "facing the low side")
		assert_almost_eq(float(s.base), 0.0, 0.0001)
		assert_almost_eq(float(s.height), 12.0, 0.0001)
	assert_eq(field._groups.size(), 1, "collinear segments merge into one foot line")
	assert_gt(field.rock_list.size(), 0, "a long wall carries rock clusters")
	for rock: Dictionary in field.rock_list:
		assert_almost_eq((rock.foot as Vector2).x, 90.0, 0.0001, "rocks stand on the wall's foot line")
		assert_gt((rock.point as Vector3).x, 90.0, "on the low side, in front of the wall")


func test_an_outer_corner_turns_the_foot_line_with_an_arc() -> void:
	var region := _corner()
	var walls := TerrainTileField.wall_segments(region, AREA)
	var field = FIELD.new(walls, SEED, region, AREA)
	var arcs: Array = field._primitives.filter(func(s: Dictionary) -> bool: return s.arc)
	assert_eq(arcs.size(), 1, "exactly one outer corner")
	var arc: Dictionary = arcs[0]
	assert_eq(arc.c, Vector2(90, 114), "at the corner of the two wall lines")
	var normals := [arc.n1, arc.n2]
	assert_true(normals.has(Vector2(1, 0)) and normals.has(Vector2(0, 1)), "facing both low sides")
	assert_almost_eq(float(arc.height), 12.0, 0.0001)
	# The runs ending at the corner continue into the arc: no free taper there.
	for s: Dictionary in field._primitives:
		if s.arc:
			continue
		for end: int in 2:
			var p: Vector2 = (s.a as Vector2) + (s.t as Vector2) * (0.0 if end == 0 else float(s.length))
			if p == Vector2(90, 114):
				assert_false(s["free_a" if end == 0 else "free_b"], "the run continues round the corner")


func test_wall_segments_split_where_their_heights_change() -> void:
	# The x = 90 cliff stands over low ground that dips a storey along it (the
	# low point (8, 5) is a storey below its neighbours): the wall's bottom
	# follows the slope, so its segments split into pieces.
	var region := _points(func(i: int, j: int) -> float:
		if i <= 7: return 12.0
		return 0.0 if i == 8 and j == 5 else 4.0)
	var checked := 0
	var split := 0
	for wall: Dictionary in TerrainTileField.wall_segments(region, AREA):
		var field = FIELD.new([wall], SEED, region)
		split += maxi(0, field._primitives.size() - 1)
		for s: Dictionary in field._primitives:
			if s.arc:
				continue
			# Its sample stations (0.5 m apart): all but the one where the next
			# piece starts hold the piece's heights within the split tolerance.
			var off := 0
			var stations := roundi(float(s.length) / FIELD.WALL_SAMPLE)
			for k in stations + 1:
				var p: Vector2 = (s.a as Vector2) + (s.t as Vector2) * FIELD.WALL_SAMPLE * k
				var top := TerrainTileField.surface_y_on_side(region, p.x, p.y, wall.high)
				var bottom := TerrainTileField.surface_y_on_side(region, p.x, p.y, wall.low)
				if absf(bottom - float(s.base)) > FIELD.WALL_SPLIT + 0.0001 \
						or absf(top - float(s.base) - float(s.height)) > FIELD.WALL_SPLIT + 0.0001:
					off += 1
				checked += 1
			assert_lte(off, 1, "a piece holds its heights up to where the next begins")
	assert_gt(split, 0, "the cliff end splits its wall into pieces")
	assert_gt(checked, 100)


func test_a_chunk_reserves_its_wall_feet_and_owns_its_rocks() -> void:
	ROCKS.prepare()
	var region := _straight()
	var data: Dictionary = ROCKS.compute(region, Vector2i.ZERO, SEED)
	var reservations: Array = data.ground_reservations
	for z in range(0, 192, 6):
		var foot := Vector2(92.0, float(z) + 0.5)
		assert_true(reservations.any(func(r: Rect2) -> bool: return r.has_point(foot)),
			"the ground in front of the wall is reserved at z=%d" % z)
	var owned := ROCKS.owned_rect(Vector2i.ZERO)
	assert_eq(owned, Rect2(-6, -6, 192, 192), "a chunk owns its points' dual cells")
	var count := 0
	for piece: String in data.slope_rocks:
		for rock: Dictionary in data.slope_rocks[piece]:
			assert_true(owned.has_point(rock.bunch), "only this chunk's rock clusters")
			count += 1
	assert_gt(count, 0, "the chunk's wall carries rocks")
	assert_false((data.placements as Array).is_empty(), "the slope solid dresses the wall")
