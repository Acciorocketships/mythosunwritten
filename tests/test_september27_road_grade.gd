extends GutTest
## September 27 dead-end road (owner, seed 2697992464): a country road routed
## on natural terrain must stay walkable after the town at its end grades
## the ground. The town's perimeter street lowered cells (49,21)/(49,22) a
## storey below natural, so road cell (48,22) stood two storeys above them:
## a cliff top whose 8 m wall ended the road.

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
		if not natural.has_surface_point(edge[0].x + edge[1].x, edge[0].y + edge[1].y):
			continue
		if TerrainSurfaceField.is_walkable_edge(natural, edge[0], edge[1],
				PathProgram.PATH_HALF_WIDTH) and not TerrainSurfaceField.is_walkable_edge(
				graded, edge[0], edge[1], PathProgram.PATH_HALF_WIDTH):
			broken.append("%s->%s" % [edge[0], edge[0] + edge[1]])
	return broken

func test_reported_town_grade_keeps_its_country_road_walkable() -> void:
	var d := Frozen.load_fixture(FIXTURE)
	var natural: HeightfieldRegion = d.region
	var grade: TerrainGradePatch = d.grade_patch
	grade.road_masks = d.road_masks
	var graded := natural.with_terrain_grades([grade] as Array[TerrainGradePatch])
	assert_true(TerrainSurfaceField.is_walkable_edge(natural, Vector2i(48, 22),
		Vector2i.RIGHT, PathProgram.PATH_HALF_WIDTH), "The route was accepted on natural ground")
	assert_eq(_broken_edges(natural, graded, d.road_masks), [],
		"Every accepted road edge stays walkable on the final graded field")
	# The road is graded down into the sunken town, one storey per cell.
	assert_eq(graded.surface_height(49, 22), 24.0, "The town's own street keeps its datum")
	assert_eq(graded.surface_height(48, 22), 28.0, "The road cell steps one storey above it")
	assert_eq(graded.surface_height(47, 22), 32.0, "Beyond, the road keeps its natural ground")
	# Only road cells move: the ground beside the road keeps its grade.
	for cell: Vector2i in [Vector2i(48, 21), Vector2i(48, 23), Vector2i(49, 21)]:
		assert_eq(graded.surface_height(cell.x, cell.y),
			natural.with_terrain_grades([Frozen.grade(d.grade)] as Array[TerrainGradePatch]).surface_height(cell.x, cell.y),
			"Non-road cell %s is not regraded by the road" % cell)

func test_a_grade_without_roads_is_unchanged() -> void:
	var d := Frozen.load_fixture(FIXTURE)
	var natural: HeightfieldRegion = d.region
	var graded := natural.with_terrain_grades([d.grade_patch] as Array[TerrainGradePatch])
	assert_eq(graded.surface_height(48, 22), 32.0, "Roads are an explicit construction input")

func test_road_ramp_steps_down_one_storey_per_cell_into_a_sunken_pad() -> void:
	# A pad two storeys below a straight road that ran level on natural
	# ground: the road grades down 20 -> 16 -> 12 into the pad, no cliff.
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
	var grade := TerrainGradePatch.new(&"sunken.pad", claims, Vector2(96, 0), 4.0)
	var masks: Dictionary = {}
	for x in range(-8, 6):
		PathPlan._add_connection(masks, Vector2i(x, 0), Vector2i(x + 1, 0))
	grade.road_masks = masks
	var graded := natural.with_terrain_grades([grade] as Array[TerrainGradePatch])
	assert_eq(graded.surface_height(4, 0), 12.0, "The pad keeps its datum")
	assert_eq(graded.surface_height(2, 0), 16.0, "The road steps one storey above the pad")
	assert_eq(graded.surface_height(2, 1), 20.0, "Ground beside the road is not regraded")
	assert_eq(_broken_edges(natural, graded, masks), [], "The road meets the pad walkably")
	var previous := graded.surface_height(-8, 0)
	for x in range(-7, 5):
		var height := graded.surface_height(x, 0)
		assert_lte(absf(height - previous), HeightfieldRegion.STOREY_HEIGHT,
			"Road cell %d changes at most one storey" % x)
		previous = height
	assert_eq(graded.surface_height(-8, 0), 20.0, "Far along, the road keeps its natural ground")

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
