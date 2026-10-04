extends GutTest
## September 29 owner review (seed 2697992464): "yellow" deformed ground far
## from any town, ground seams, and large divots along country roads.

const NativeGrade := preload("res://scripts/terrain/field/NativeTerrainGrade.gd")


static func _sunken_pad() -> Array:
	# Natural ground level at storey 5 (20 m); a town pad at 12 m.
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-6, 7):
		for x in range(-8, 9):
			storeys[Vector2i(x, z)] = 5
			levels[Vector2i(x, z)] = 0
	var natural := HeightfieldRegion.new(storeys, levels)
	var claims: Dictionary = {}
	for z in range(-6, 7):
		for x in range(-6, 7):
			claims[Vector2i(x, z)] = 12.0
	return [natural, TerrainGradePatch.new(&"sunken.pad", claims, Vector2(96, 0), 4.0)]


## F9 painted "town / road grade" from TerrainGradePatch bounds, but a graded
## region carries its grade as native controls only: the flag was always 0 and
## the yellow the owner saw was orange (dying cliff) blended with green (slope).
func test_category_snapshot_flags_exactly_the_graded_cells() -> void:
	var pad := _sunken_pad()
	var graded: HeightfieldRegion = (pad[0] as HeightfieldRegion).with_terrain_grades(
		[pad[1]] as Array[TerrainGradePatch])
	var values := FieldTerrainStreamer._point_snapshot(Vector2i.ZERO, graded)
	for z in 16:
		for x in 16:
			var expected := 1.0 if graded.native_control_heights.has(Vector2i(x, z)) else 0.0
			assert_eq(values[(z * 16 + x) * 2 + 1], expected, "point (%d, %d) graded flag" % [x, z])
	# The pad (world x 70..122) owns every corner it touches: points 5..11.
	assert_eq(values[(0 * 16 + 6) * 2 + 1], 1.0, "the pad point is graded")
	assert_eq(values[(6 * 16 + 0) * 2 + 1], 0.0, "untouched natural ground is not graded")


const Frozen := preload("res://tests/fixtures/frozen_road_grade.gd")
## Three real towns near the reported road (photos 8/9, player 310.8,16.9,477.8)
## frozen by tests/harness/road_grade_freeze.gd with their natural terrain and
## the accepted country-road lattice around them. Dual-grid re-freeze: the
## town at super cell (1, -1) no longer seals any country road on 12 m points,
## so its fixture (september29-road-divot-1-m1) was vacuous and is replaced by
## the town at (-1, 0) (23 sealed road cells in the radius-2 probe), frozen
## the same way. Every fixture must exercise at least one road edge.
const DIVOT_FIXTURES := ["res://tests/fixtures/september29-road-divot-0-0.var.gz",
	"res://tests/fixtures/september29-road-divot-0-m2.var.gz",
	"res://tests/fixtures/september29-road-divot-m1-0.var.gz"]


static func _broken_road_edges(natural: HeightfieldRegion, graded: HeightfieldRegion,
		masks: Dictionary) -> Array:
	var broken := []
	var cells: Array = masks.keys()
	cells.sort()
	for cell: Vector2i in cells:
		for arm: Array in [[1, Vector2i.RIGHT], [4, Vector2i(0, 1)]]:
			if (int(masks[cell]) & int(arm[0])) == 0: continue
			var d: Vector2i = arm[1]
			var far: Vector2i = (cell + d) * PathProgram.POINTS_PER_ROUTE_CELL
			if not natural.has_surface_point(far.x, far.y): continue
			if PathProgram.is_route_edge_walkable(natural, cell, d) \
					and not PathProgram.is_route_edge_walkable(graded, cell, d):
				var heights := []
				for k in 3:
					var p: Vector2i = cell * PathProgram.POINTS_PER_ROUTE_CELL + d * k
					heights.append("%.0f" % graded.surface_height(p.x, p.y))
				broken.append("%s->%s %s" % [cell, cell + d, "/".join(heights)])
	return broken


func _graded(path: String) -> Array:
	var d := Frozen.load_fixture(path)
	var grade: TerrainGradePatch = d.grade_patch
	grade.road_masks = d.road_masks
	return [d, d.region, d.region.with_terrain_grades([grade] as Array[TerrainGradePatch])]


## The collar's rounded blend put road cell (12,20) at 13 m next to (13,20)
## at 20 m: a two-storey wall across the road. Regrading lowered (13,20) to
## 17 m and pushed the wall one cell out (17 m against 24 m): the divot.
## Dual-grid re-freeze (September 30): the same three towns re-frozen on 12 m
## points by tests/harness/road_grade_freeze.gd. The resampled geography no
## longer exhibits the divot (the bare town grade breaks no road edge, here or
## in any of the 23 towns of the radius-2 road_grade_walkability_probe), so
## the cell pins are retired; the reported town keeps the invariant over all
## of its naturally walkable road edges, and road edges step at most one
## storey per 12 m point.
func test_reported_road_keeps_its_natural_climb_out_of_the_town() -> void:
	var r := _graded(DIVOT_FIXTURES[0])
	var natural: HeightfieldRegion = r[1]
	var graded: HeightfieldRegion = r[2]
	assert_eq(_broken_road_edges(natural, graded, r[0].road_masks), [], "no wall across the road")
	var walkable := 0
	for cell: Vector2i in r[0].road_masks:
		for arm: Array in [[1, Vector2i.RIGHT], [4, Vector2i(0, 1)]]:
			if (int(r[0].road_masks[cell]) & int(arm[0])) == 0: continue
			if not PathProgram.is_route_edge_walkable(natural, cell, arm[1]): continue
			walkable += 1
			for half: Array in PathProgram.route_point_edges(cell, arm[1]):
				var a: Vector2i = half[0]
				var b: Vector2i = a + (arm[1] as Vector2i)
				assert_lte(absi(graded.storey_at(b.x, b.y) - graded.storey_at(a.x, a.y)), 1,
					"road point %s -> %s stays a slope" % [a, b])
	assert_gt(walkable, 10, "the fixture exercises the town's country roads")


func test_town_grades_leave_every_natural_road_edge_walkable() -> void:
	for path: String in DIVOT_FIXTURES:
		var r := _graded(path)
		var walkable := 0
		for cell: Vector2i in r[0].road_masks:
			for arm: Array in [[1, Vector2i.RIGHT], [4, Vector2i(0, 1)]]:
				if (int(r[0].road_masks[cell]) & int(arm[0])) != 0 \
						and PathProgram.is_route_edge_walkable(r[1], cell, arm[1]):
					walkable += 1
		assert_gt(walkable, 0, "%s exercises at least one naturally walkable road edge" % path)
		assert_eq(_broken_road_edges(r[1], r[2], r[0].road_masks), [], path)


func test_road_grading_moves_only_road_cells() -> void:
	for path: String in DIVOT_FIXTURES:
		var d := Frozen.load_fixture(path)
		var natural: HeightfieldRegion = d.region
		var bare := natural.with_terrain_grades([Frozen.grade(d.grade)] as Array[TerrainGradePatch])
		var r := _graded(path)
		var graded: HeightfieldRegion = r[2]
		var roads := NativeGrade.road_points(r[0].grade_patch)
		var points: Rect2i = d.points
		for z in range(points.position.y, points.end.y + 1):
			for x in range(points.position.x, points.end.x + 1):
				if roads.has(Vector2i(x, z)): continue
				assert_eq(graded.surface_height(x, z), bare.surface_height(x, z),
					"%s: non-road point (%d,%d) keeps the town's grade" % [path, x, z])


const _STYLE := preload("res://scripts/terrain/field/CliffRockStyle.gd")
const _ROCKS := preload("res://scripts/terrain/field/CliffRockDressing.gd")

## Summed visible grass area (squared clump scale) per 1 m band of z.
static func _grass_bands(z0: float, bands: int) -> PackedFloat64Array:
	_STYLE.apply("sheet_bedrock")
	_ROCKS.prepare()
	var plan := HeightfieldPlan.new(17, 64, 12, "mean", 4)
	# A 16 m cliff whose plateau (points z <= 1) ends at the wall line z = 18.
	plan.set_raw_height_override(func(_x: int, z: int) -> float: return 16.0 if z <= 1 else 0.0)
	var region := plan.compute_region(8, 8, 24)
	var water := WaterFieldContext.new()
	water._region = region; water._coverage = Rect2(-48, -48, 288, 288)
	water._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	water._shore_curves_ready = true; water._shore_limit = .3
	var data: Dictionary = _ROCKS.compute(region, Vector2i.ZERO, 99, null, null)
	var catalog := EnvironmentCatalog.load_default()
	var program := GrassProgram.compile(load("res://terrain/grass/settings.tres"), catalog,
		EnvironmentRenderCache.new(catalog))
	var result := PackedFloat64Array(); result.resize(bands)
	for seed_value in [99, 100]:
		for x in range(2, 6):
			var payload := GrassField.compute(program, seed_value, Vector2i(x, 0), region, water,
				null, data.grass_supports)
			for asset_id in payload.batches:
				var batch: Dictionary = payload.batches[asset_id]
				var buffer: PackedFloat32Array = batch.buffer
				for i in batch.count:
					var k: int = i * GrassPayload.FLOATS_PER_INSTANCE
					var band := floori(buffer[k + 11] - z0)
					if band >= 0 and band < bands:
						result[band] += Vector3(buffer[k], buffer[k + 4], buffer[k + 8]).length_squared()
	_STYLE.apply("sheet_bedrock")
	return result


## Terrain grass ran dense to the wall line and the slope sheet's rounded
## crest carried quarter-size clumps: a line in the grass (photos 1, 3, 10).
func test_grass_carries_over_a_rounded_crest_without_a_line() -> void:
	var bands := _grass_bands(10.0, 12)   # z 10..22: plateau 10..14, crest 18..21
	var plateau := (bands[0] + bands[1] + bands[2] + bands[3]) / 4.0
	var crest := (bands[8] + bands[9] + bands[10]) / 3.0
	gut.p("crest/plateau grass area %.3f" % (crest / plateau))
	assert_gt(plateau, 0.0, "the plateau grows grass")
	assert_gt(crest / plateau, 0.25,
		"the first metres of the rounded crest keep most of the plateau's grass (%.2f)" % (crest / plateau))


const _SLOPE := preload("res://scripts/terrain/field/CliffSlopeField.gd")
const _CRAGS := preload("res://scripts/terrain/field/CliffRockCrags.gd")

## Photo 3 (owner, after the first pass): the slope sheet grew moss only where
## it stood above the terrain, and that lift jumps where a cliff ends, so the
## steep end ramp stayed lawn beside the mossy face: a colour seam. The sheet's
## colour is now a function of its steepness alone; ordinary slopes (at most
## one storey and three levels) stay exactly the terrain's lawn.
func test_sheet_moss_depends_on_steepness_alone() -> void:
	_STYLE.apply("sheet_bedrock")
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			# A three-storey cliff that ends in a hillside at x = 12.
			storeys[Vector2i(x, z)] = 6 if z <= 0 else (3 if x <= 0 else 5)
			levels[Vector2i(x, z)] = 0
	var region := HeightfieldRegion.new(storeys, levels)
	var field = _SLOPE.new([], 2697992464, region, Rect2(-48, -48, 96, 96))
	var sheets: Array = field.solid(Rect2(-24, -24, 48, 48))
	assert_false(sheets.is_empty(), "the cliff is dressed by the slope sheet")
	var arrays: Array = _CRAGS.mesh_arrays(sheets[0], region, 0)[0]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var rise: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var roots: Dictionary = sheets[0].native_roots
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lawn := 0
	var mossy := 0
	var worst := 0.0
	for i in points.size():
		var steep := 1.0 - normals[i].y
		var expected := 0.0
		if steep > _CRAGS.SHEET_LAWN_STEEPNESS:
			expected = lerpf(.05, .24, clampf((steep - _CRAGS.SHEET_LAWN_STEEPNESS)
				/ (_CRAGS.SHEET_MOSS_STEEPNESS - _CRAGS.SHEET_LAWN_STEEPNESS), 0.0, 1.0))
		var root: Array = roots[points[i]]
		var bedrock := float(root[2]) if root.size() > 2 else 0.0
		worst = maxf(worst, absf(rise[i].x / _CRAGS.SHEET_MOSS_RISE - maxf(expected, bedrock)))
		if steep <= _CRAGS.SHEET_LAWN_STEEPNESS and bedrock == 0.0: lawn += 1
		if steep >= _CRAGS.SHEET_MOSS_STEEPNESS: mossy += 1
	assert_lt(worst, 0.0001, "moss grade = f(steepness), max'ed with bedrock's own grade; no lift term")
	assert_gt(lawn, 100, "the fixture covers ordinary ground")
	assert_gt(mossy, 100, "and cliff-steep faces")


## Owner review October 2 (rings round the slope rocks): a rock's ground
## skirt joined to the sheet stored its raw steepness (1 - normal.y) where the
## sheet keeps only bedrock's own moss grade, so mesh_arrays read a 15 degree
## mound as grade .03-.3 and painted it full moss: a dark grass-free disc round
## every rock. A skirt vertex takes the grade the sheet would have there.
func test_rock_skirts_on_the_sheet_follow_the_sheet_moss_rule() -> void:
	_STYLE.apply("sheet_bedrock")
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			storeys[Vector2i(x, z)] = 6 if z <= 0 else (3 if x <= 0 else 5)
			levels[Vector2i(x, z)] = 0
	var region := HeightfieldRegion.new(storeys, levels)
	var owned := Rect2(-48, -48, 96, 96)
	var field = _SLOPE.new(TerrainTileField.wall_segments(region, owned.grow(48.0)), 2697992464, region, owned)
	var sheets: Array = field.solid(owned)
	field.add_skirts(sheets[0], owned)
	var env = field.envelope()
	var roots: Dictionary = sheets[0].native_roots
	var checked := 0
	var worst := 0.0
	for rock: Dictionary in field.skirts():
		if not owned.has_point(rock.bunch):
			continue
		var sk: Dictionary = field.skirts()[rock]
		for i: int in sk.sheet_indices:
			var v: Vector3 = sk.vertices[i]
			var q := Vector2(v.x, v.z)
			var exposure: float = env.rock_at(q) if sk.on_sheet[i] == 1 else 0.0
			var bedrock: float = env.moss_grade_at(q) * smoothstep(.1, .5, exposure) \
				if sk.on_sheet[i] == 1 and not env.moss_grade.is_empty() else 0.0
			var root: Array = roots[v]
			if root.size() > 2:
				worst = maxf(worst, absf(float(root[2]) - bedrock))
			checked += 1
	assert_gt(checked, 50, "the fixture's rocks have skirts on the sheet")
	assert_lt(worst, 0.0001, "a skirt vertex keeps only bedrock's own moss grade (the band adds steepness)")

## Off the road, a town's grade still made cliffs between cells no pad owns:
## the collar's rounded blend put a cell a storey down beside natural ground
## (e.g. 4 -> 10 m beside 0 m), and pad support lifted one 8 m beside a 12 m
## neighbour. The envelope rounded each into a stray mound. A natural slope
## between two free points stays a slope after grading; pad owners (every
## corner a pad touches) and regraded road points are construction and may
## keep retaining edges.
func test_town_grades_make_no_new_cliffs_between_free_cells() -> void:
	for path: String in DIVOT_FIXTURES:
		var r := _graded(path)
		var natural: HeightfieldRegion = r[1]
		var graded: HeightfieldRegion = r[2]
		var owners := NativeGrade.construction_cells(r[0].grade_patch, natural)
		assert_false(owners.is_empty(), "the grade reports its construction cells")
		var points: Rect2i = r[0].points
		var broken := []
		for z in range(points.position.y, points.end.y):
			for x in range(points.position.x, points.end.x):
				for d: Vector2i in [Vector2i.RIGHT, Vector2i(0, 1)]:
					var a := Vector2i(x, z)
					var b := a + d
					var grade: TerrainGradePatch = r[0].grade_patch
					if not (NativeGrade.is_free(grade, owners, a) and NativeGrade.is_free(grade, owners, b)): continue
					if TerrainTileField.is_cliff_edge(natural, a, d): continue
					if TerrainTileField.is_cliff_edge(graded, a, d):
						broken.append("%s-%s %.0f/%.0f" % [a, b, graded.surface_height(a.x, a.y),
							graded.surface_height(b.x, b.y)])
		assert_eq(broken, [], path)
