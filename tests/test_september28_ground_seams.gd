extends GutTest
## September 28 owner review (seed 2697992464): visible seams on the ground,
## generally between flat ground and slopes. The terrain sheet's lighting
## normals were facet averages over each chunk's own 2 m triangles, so a
## chunk border shaded differently on either side and the sheet disagreed
## with the slope solid's exact gradient normals wherever the two meet.
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")


## Point 16 (on the x = 192 chunk border) is the east edge of a plateau that
## ramps down one storey to point 17: the border runs along the top of that
## slope, where each chunk alone sees only one side of the curve.
func _border_plan():
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, _cz):
		return 12.0 if cx <= 16 else 8.0)
	return p


func _surface(plan, chunk: Vector2i) -> Array:
	var node := Mesher.new().build_chunk(plan, chunk)
	var mesh := (node.find_child("Surface", true, false) as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	node.free()
	return arrays


func test_sheet_normals_agree_across_a_chunk_border() -> void:
	var plan = _border_plan()
	var west := _surface(plan, Vector2i(0, 0))
	var east := _surface(plan, Vector2i(1, 0))
	var normals := {}
	for i in (west[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var v: Vector3 = west[Mesh.ARRAY_VERTEX][i]
		if is_equal_approx(v.x, 192.0):
			normals[v] = west[Mesh.ARRAY_NORMAL][i]
	var compared := 0
	var worst := 0.0
	for i in (east[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var v: Vector3 = east[Mesh.ARRAY_VERTEX][i]
		if normals.has(v):
			compared += 1
			worst = maxf(worst, (normals[v] as Vector3).distance_to(east[Mesh.ARRAY_NORMAL][i]))
	assert_gt(compared, 50)
	assert_lt(worst, 0.001, "both chunks light a shared border vertex identically")


func test_sheet_normals_are_the_field_gradient() -> void:
	var plan = _border_plan()
	var region: HeightfieldRegion = plan.compute_region(24, 8, Mesher.POINTS_PER_CHUNK)
	var arrays := _surface(plan, Vector2i(1, 0))
	var worst := 0.0
	var h := 0.01
	for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
		if v.x < 193.0 or v.x > 227.0:
			continue
		var gx := (TerrainTileField.surface_y(region, v.x + h, v.z) - TerrainTileField.surface_y(region, v.x - h, v.z)) / (2.0 * h)
		var gz := (TerrainTileField.surface_y(region, v.x, v.z + h) - TerrainTileField.surface_y(region, v.x, v.z - h)) / (2.0 * h)
		var exact := Vector3(-gx, 1.0, -gz).normalized()
		worst = maxf(worst, exact.distance_to(arrays[Mesh.ARRAY_NORMAL][i]))
	assert_lt(worst, 0.01, "the sheet lights the slope with its exact gradient")


const ENV := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const SLOPE := preload("res://scripts/terrain/field/CliffSlopeField.gd")
const STYLE := preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SEED := 2697992464

func after_each() -> void:
	STYLE.apply("sheet_bedrock")


## A 12 m wall whose high side ends at the dual-cell border y = 18.
static func _wall_ground(q: Vector2) -> float:
	return 12.0 if q.y < 18.0 else 0.0


## The terrain's flat top runs to its wall line; the rounded shoulder
## started half a grid step early, a slope kink along every crest line where
## the terrain sheet hands over to the slope solid.
func test_the_rounded_shoulder_starts_at_the_wall_line() -> void:
	STYLE.apply("sheet")
	var env = ENV.build(Rect2(-12, -8, 24, 40), _wall_ground, Callable(), SEED)
	assert_almost_eq(env.at(Vector2(0, 18)), 12.0, 0.002,
		"the envelope is still level with the crest at the wall line")
	assert_lt(12.0 - env.at(Vector2(0, 18.5)), 0.05,
		"and leaves it tangentially just past it")


## Where the slope's lift over the terrain is nil the solid lies on the
## terrain sheet's own chords (a hair above), not under them: it met the
## terrain along a crease where it emerged at RAISED.
func test_the_slope_solid_meets_the_terrain_sheet_flush() -> void:
	STYLE.apply("sheet_bedrock")
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	# Plateau points z <= 0: the wall stands on z = 6.
	plan.set_raw_height_override(func(_cx, cz): return 16.0 if cz <= 0 else 4.0)
	var region: HeightfieldRegion = plan.compute_region(0, 4, 16)
	var field = SLOPE.new([], SEED, region, Rect2(-24, -24, 48, 96))
	var env = field.envelope()
	var tested := 0
	for k in range(0, 80):
		var q := Vector2(3.0, 6.0 + k * 0.5)
		var lift: float = env.at(q) - env.ground_node(q)
		var solid: float = field._solid_top(env, q)
		var mesh: float = field._mesh_height(q)
		assert_gte(solid, mesh - 0.001, "the solid never dips under the terrain sheet at %s" % q)
		if lift < 0.01:
			tested += 1
			assert_almost_eq(solid - mesh, SLOPE.COVER, 0.02,
				"on unraised ground it lies on the terrain chords at %s" % q)
	assert_gt(tested, 10, "exercise the flat ground beyond the slope's foot")


class PocketPool extends WaterFieldContext:
	func has_sources() -> bool: return true
	func coverage() -> Rect2: return Rect2(-200, -200, 400, 400)
	func covers(_q: Vector2) -> bool: return true
	func level_at(q: Vector2) -> float:
		return 6.0 if absf(q.x + 6.0) < 12.0 and q.y > 18.0 and q.y < 42.0 else NAN


## A 24 m pocket (two by two lattice points, walled on dual-cell borders) sunk
## 12 m among its neighbours and holding a 6 m deep pool, like the owner's
## water photo.
static func _pocket_ground(q: Vector2) -> float:
	return 0.0 if absf(q.x + 6.0) < 12.0 and q.y > 18.0 and q.y < 42.0 else 12.0


## Rounded walls standing in a pool: the water cut the banks with planar
## 54-degree faces and a steep receiver slot from a 2 m block mask, leaving
## prisms, fins and pits. The banks now round down to the bed and the water
## covers them: from every wall the bank only descends, without a crease
## above the water, and the pool stays open in the middle.
func test_banks_rise_out_of_a_pocket_pool_without_cut_creases() -> void:
	STYLE.apply("sheet")
	var pool := PocketPool.new()
	var env = ENV.build(Rect2(-36, 0, 60, 60), _pocket_ground, Callable(), SEED,
		func(q: Vector2) -> float: return pool.level_at(q))
	var worst := 0.0
	for line: Array in [[Vector2(-6, 18), Vector2(0, 1)], [Vector2(-18, 30), Vector2(1, 0)],
			[Vector2(-2, 18), Vector2(0, 1)], [Vector2(-18, 22), Vector2(1, 0)]]:
		var start: Vector2 = line[0]
		var step: Vector2 = line[1]
		var previous: float = env.sample(start)
		for k in range(1, 40):
			var q: Vector2 = start + step * (k * 0.25)
			var y: float = env.sample(q)
			assert_lte(y, previous + 0.001, "the bank only descends into the pool (%s)" % q)
			previous = y
			var ahead: float = env.sample(q + step * 0.5)
			if minf(y, ahead) < 6.05:
				continue
			worst = maxf(worst, absf(ahead - 2.0 * y + env.sample(q - step * 0.5)))
	assert_lt(worst, 0.2, "no crease in the banks above the water")
	assert_lt(env.sample(Vector2(-6, 30)), 6.0, "the pool stays open in the middle")
