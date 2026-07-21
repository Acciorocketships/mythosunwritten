extends GutTest

class DryPlanningWater extends WaterPlan:
	func _init(seed_value: int) -> void:
		super(seed_value, 1.0, 1)
	func bodies_near(_center_cell: Vector2i, _radius_cells: int) -> Dictionary:
		return {"ponds": [], "rivers": []}
	func planning_signed_distance(_point: Vector2) -> float:
		return PATH_QUERY_MAX
	func planning_intervals(_a: Vector2, _b: Vector2) -> Array[Vector2]:
		return []

func test_centred_corridor_uses_rectangle_union() -> void:
	var payload := EnvironmentInstancePayload.new()
	var corridors: Array[Rect2] = [
		Rect2(Vector2(0.0, -2.0), Vector2(12.0, 4.0)),
	]
	var context := PathContext.new(Rect2(-Vector2.ONE * 96.0, Vector2.ONE * 192.0),
		corridors, corridors, payload, 2.0)
	assert_true(context.corridor_at(Vector2(1.0, -1.0)))
	assert_true(context.corridor_at(Vector2(1.0, 1.0)),
		"the 4m strip covers the two 2m quad-centre columns")
	assert_false(context.corridor_at(Vector2(7.0, 3.0)))

func test_village_node_paints_a_large_circle_instead_of_a_square() -> void:
	var masks := {Vector2i.ZERO: 3}
	var context := PathContext.new(Rect2(-Vector2.ONE * 24.0, Vector2.ONE * 48.0),
		[], [], EnvironmentInstancePayload.new(), 2.0, masks,
		{Vector2i.ZERO: true})
	assert_true(context.corridor_at(Vector2(7.9, 0.0)),
		"the circular plaza is wider than the old twelve-metre square")
	assert_true(context.corridor_at(Vector2(5.0, 5.0)),
		"the large circle fills its interior beyond the old road strip")
	assert_false(context.corridor_at(Vector2(7.0, 7.0)),
		"the village plaza has a circular boundary, not a larger square")

func test_clearance_is_signed_saturated_and_includes_props() -> void:
	var corridor := Rect2(Vector2(-2.0, -12.0), Vector2(4.0, 24.0))
	var prop := Rect2(Vector2(10.0, -1.0), Vector2(2.0, 2.0))
	var context := PathContext.new(Rect2(-Vector2.ONE * 20.0, Vector2.ONE * 40.0),
		[corridor], [corridor, prop], EnvironmentInstancePayload.new(), 3.0)
	assert_lt(context.clearance_at(Vector2.ZERO), 0.0)
	assert_almost_eq(context.clearance_at(Vector2(2.0, 0.0)), 0.0, 0.0001)
	assert_lt(context.clearance_at(Vector2(11.0, 0.0)), 0.0,
		"prop footprints join the reservation union")
	assert_almost_eq(context.clearance_at(Vector2(100.0, 100.0)), 3.0, 0.0001)
	assert_false(context.corridor_at(Vector2(11.0, 0.0)),
		"a prop reservation does not paint path terrain")

func test_turn_rounds_both_edges_without_a_centre_circle_blob() -> void:
	var masks := {Vector2i.ZERO: 5}
	var context := PathContext.new(Rect2(-Vector2.ONE * 24.0, Vector2.ONE * 48.0),
		[], [], EnvironmentInstancePayload.new(), 2.0, masks)
	assert_true(context.corridor_at(Vector2(2.5, 2.5)),
		"the inner edge follows the two-metre-radius fillet")
	assert_false(context.corridor_at(Vector2(3.0, 3.0)),
		"space inside the rounded inner edge stays grass")
	assert_true(context.corridor_at(Vector2(-0.2, -0.2)),
		"the outer edge follows the six-metre-radius fillet")
	assert_false(context.corridor_at(Vector2(-0.5, -0.5)),
		"space beyond the rounded outer edge stays grass")
	assert_false(context.corridor_at(Vector2(0.0, -1.9)),
		"the incoming strip stops at the tangent instead of squaring off the outer edge")
	assert_false(context.corridor_at(Vector2(-3.0, 0.0)),
		"there is no circle superimposed over the centre of the bend")
	assert_eq(context.corridor_at_cell(Vector2(2.5, 2.5), Vector2i.ZERO),
		context.corridor_at(Vector2(2.5, 2.5)),
		"lattice consumers reuse their known cell without changing classification")

func test_branch_fillets_each_concave_corner() -> void:
	var context := PathContext.new(Rect2(-Vector2.ONE * 24.0, Vector2.ONE * 48.0),
		[], [], EnvironmentInstancePayload.new(), 2.0, {Vector2i.ZERO: 7})
	assert_true(context.corridor_at(Vector2(2.5, 2.5)),
		"the right side of a T receives the same inner curve as a bend")
	assert_true(context.corridor_at(Vector2(-2.5, 2.5)),
		"the left side of a T receives the matching inner curve")
	assert_false(context.corridor_at(Vector2(3.0, 3.0)))
	assert_false(context.corridor_at(Vector2(-3.0, 3.0)))

func test_canonical_context_is_memoized_and_resource_free_on_flat_dry_fields() -> void:
	var seed_value := 4242
	var water := DryPlanningWater.new(seed_value)
	var heights := HeightfieldPlan.new(seed_value, 1.0, 1, "mean", 1)
	heights.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.FIELD_CACHE_CAP)
	var settlements := SettlementPlan.new(seed_value, water)
	var plan := PathPlan.new(seed_value, water, fields, program,
		program.query_margin, settlements)
	var first := plan.context_for(Vector2i.ZERO)
	assert_same(plan.context_for(Vector2i.ZERO), first)
	assert_true(first.placements().validate())
	var visible_cells := first.connection_masks.size()
	var node_count := 0
	var feasible_count := 0
	var node_map: Dictionary = {}
	for z in range(-3, 4):
		for x in range(-3, 4):
			var node := plan.node_for(Vector2i(x, z))
			node_map[Vector2i(x, z)] = node
			if not node.is_empty():
				node_count += 1
	for sc: Vector2i in node_map:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if not node_map[sc].is_empty() and node_map.has(sc + direction) \
				and not node_map[sc + direction].is_empty():
				var route := plan.route_for(node_map[sc], node_map[sc + direction])
				if not route.is_empty():
					feasible_count += 1
					var middle: Dictionary = route.connections[route.connections.size() / 2]
					var point := Vector2(middle.a + middle.b) \
						* TerrainSurfaceField.TILE * 0.5
					visible_cells += plan.context_for(
						WorldFieldBlockCache.key_of(point)).connection_masks.size()
	assert_gt(node_count, 0, "pinned flat field has provisional nodes")
	assert_gt(feasible_count, 0, "neighbouring flat-field nodes have feasible routes")
	assert_gt(visible_cells, 0,
		"flat dry fields produce a visible canonical network in the pinned corpus window")
	assert_eq(first.coverage(), Rect2(-Vector2.ONE * program.query_margin,
		Vector2.ONE * (TerrainChunkMesher.CHUNK_WORLD + 2.0 * program.query_margin)))
	assert_gte(int(plan.stats().context_builds), 1)
