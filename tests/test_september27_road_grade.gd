extends GutTest
## September 27 dead-end road (owner, seed 2697992464): a country road routed
## on natural terrain must stay walkable after the town at its end grades
## the ground. The town's perimeter street lowered cells (49,21)/(49,22) a
## storey below natural, so road cell (48,22) stood two storeys above them:
## a cliff top whose 8 m wall ended the road.
##
## Dual-grid re-freeze (September 30): the fixture is the same town (super
## cell (1, 0)) re-frozen by tests/harness/road_grade_freeze.gd on 12 m points.
## The resampled geography no longer exhibits the defect: its bare grade (no
## road grading) breaks none of its 11 naturally walkable road edges, and the
## radius-2 corpus probe (tests/harness/road_grade_walkability_probe.gd, 23
## towns) found no town whose bare grade breaks a road edge, so no equivalent
## current site exists to re-pin. The reported town keeps the invariant; the
## mechanism (a road graded one storey per point into a sunken pad, through a
## route edge's middle point) is pinned by the synthetic tests below.

const FIXTURE := "res://tests/fixtures/september27-dead-end-grade.var.gz"
const Frozen := preload("res://tests/fixtures/frozen_road_grade.gd")
const NativeGrade := preload("res://scripts/terrain/field/NativeTerrainGrade.gd")

static func _road_edges(masks: Dictionary) -> Array:
	var edges := []
	var cells: Array = masks.keys()
	cells.sort()
	for cell: Vector2i in cells:
		for arm: Array in [[1, Vector2i.RIGHT], [4, Vector2i(0, 1)]]:
			if (int(masks[cell]) & int(arm[0])) != 0:
				edges.append([cell, arm[1]])
	return edges

static func _broken_edges(natural: HeightfieldRegion, graded: HeightfieldRegion,
		masks: Dictionary) -> Array:
	var broken := []
	for edge: Array in _road_edges(masks):
		var far: Vector2i = (edge[0] + edge[1]) * PathProgram.POINTS_PER_ROUTE_CELL
		if not natural.has_surface_point(far.x, far.y):
			continue
		if PathProgram.is_route_edge_walkable(natural, edge[0], edge[1]) \
				and not PathProgram.is_route_edge_walkable(graded, edge[0], edge[1]):
			broken.append("%s->%s" % [edge[0], edge[0] + edge[1]])
	return broken

func test_reported_town_grade_keeps_its_country_road_walkable() -> void:
	var d := Frozen.load_fixture(FIXTURE)
	var natural: HeightfieldRegion = d.region
	var grade: TerrainGradePatch = d.grade_patch
	grade.road_masks = d.road_masks
	var graded := natural.with_terrain_grades([grade] as Array[TerrainGradePatch])
	var walkable := 0
	for edge: Array in _road_edges(d.road_masks):
		if PathProgram.is_route_edge_walkable(natural, edge[0], edge[1]): walkable += 1
	assert_gte(walkable, 10, "The town's country roads were accepted on natural ground")
	assert_eq(_broken_edges(natural, graded, d.road_masks), [],
		"Every accepted road edge stays walkable on the final graded field")
	# Only road points move: the ground beside the road keeps its grade.
	var bare := natural.with_terrain_grades([Frozen.grade(d.grade)] as Array[TerrainGradePatch])
	var roads := NativeGrade.road_points(grade)
	var points: Rect2i = d.points
	for z in range(points.position.y, points.end.y + 1):
		for x in range(points.position.x, points.end.x + 1):
			if roads.has(Vector2i(x, z)): continue
			assert_eq(graded.surface_height(x, z), bare.surface_height(x, z),
				"Non-road point (%d,%d) is not regraded by the road" % [x, z])

func test_a_grade_without_roads_is_unchanged() -> void:
	# The sunken pad below without its road: nothing regrades the approach, so
	# the road point beside the pad keeps its natural 20 m (a cliff remains).
	var pad := _sunken_pad()
	var graded := (pad[0] as HeightfieldRegion).with_terrain_grades([pad[1]] as Array[TerrainGradePatch])
	assert_eq(graded.surface_height(5, 0), 20.0, "Roads are an explicit construction input")

static func _sunken_pad() -> Array:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-6, 7):
		for x in range(-16, 18):
			storeys[Vector2i(x, z)] = 5
			levels[Vector2i(x, z)] = 0
	var claims: Dictionary = {}
	for z in range(-6, 7):
		for x in range(-6, 7):
			claims[Vector2i(x, z)] = 12.0
	return [HeightfieldRegion.new(storeys, levels),
		TerrainGradePatch.new(&"sunken.pad", claims, Vector2(108, 0), 4.0)]

func test_road_ramp_steps_down_one_storey_per_point_into_a_sunken_pad() -> void:
	# A pad two storeys below a straight road that ran level on natural
	# ground: the road grades down 20 -> 16 -> 12 into the pad, no cliff.
	# Terrain is on 12 m points; the road on 24 m route cells (cell c = point
	# 2c). The pad (world x 82..134) owns points 6..12, so the road point next
	# to it is point 5: the MIDDLE point of route edge 2 -> 3, which no route
	# cell centre touches. It is regraded like any other road point.
	var pad := _sunken_pad()
	var natural: HeightfieldRegion = pad[0]
	var grade: TerrainGradePatch = pad[1]
	var masks: Dictionary = {}
	for x in range(-8, 6):
		PathPlan._add_connection(masks, Vector2i(x, 0), Vector2i(x + 1, 0))
	grade.road_masks = masks
	var graded := natural.with_terrain_grades([grade] as Array[TerrainGradePatch])
	assert_eq(graded.surface_height(6, 0), 12.0, "The pad keeps its datum")
	assert_eq(graded.surface_height(5, 0), 16.0, "The road's middle point steps one storey above the pad")
	assert_eq(graded.surface_height(4, 0), 20.0, "and the route cell before it keeps its natural ground")
	assert_eq(graded.surface_height(5, 1), 20.0, "Ground beside the road is not regraded")
	assert_eq(_broken_edges(natural, graded, masks), [], "The road meets the pad walkably")
	var previous := graded.surface_height(-16, 0)
	for x in range(-15, 13):
		var height := graded.surface_height(x, 0)
		assert_lte(absf(height - previous), HeightfieldRegion.STOREY_HEIGHT,
			"Road point %d changes at most one storey" % x)
		previous = height
	assert_eq(graded.surface_height(-16, 0), 20.0, "Far along, the road keeps its natural ground")

func test_road_masks_survive_every_grade_extension() -> void:
	var grade := TerrainGradePatch.new(&"town", {Vector2i.ZERO: 8.0}, Vector2.ZERO, 4.0)
	grade.road_masks = {Vector2i(3, 0): 3}
	var street := grade.with_continuous_extension({Vector2i.ZERO: 8.0, Vector2i(1, 0): 8.0}, 8.0)
	var fixed := street.with_fixed_extension({Vector2i.ZERO: 8.0, Vector2i(2, 0): 8.0})
	var pads := fixed.with_foundation_pads([{"area": Rect2(8, 0, 4, 4), "height": 8.0}] as Array[Dictionary])
	for patch: TerrainGradePatch in [street, fixed, pads]:
		assert_eq(patch.road_masks, grade.road_masks, "Road constraints are sealed with the town")

func test_native_road_ramp_is_independent_of_query_order() -> void:
	var d := Frozen.load_fixture(FIXTURE)
	var natural: HeightfieldRegion = d.region
	var first: TerrainGradePatch = d.grade_patch
	first.road_masks = d.road_masks
	var second := Frozen.grade(d.grade)
	second.road_masks = d.road_masks
	var a := NativeGrade.controls(first, natural)
	# Different dictionary insertion order must not change the result.
	var reversed := {}
	var keys: Array = d.road_masks.keys()
	keys.reverse()
	for key: Vector2i in keys: reversed[key] = d.road_masks[key]
	second.road_masks = reversed
	var b := NativeGrade.controls(second, natural)
	assert_eq_deep(a, b)
