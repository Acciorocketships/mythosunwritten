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

func _context(coverage: Rect2, surface_rects: Array[Rect2],
		clearance_rects: Array[Rect2], clearance_limit: float,
		masks: Dictionary = {}, nodes: Dictionary = {}) -> FeatureContext:
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	for rect: Rect2 in surface_rects:
		surfaces.append(FeatureGroundShape.axis_rect(rect,
			FeatureGroundField.WORN_PATH))
	for rect: Rect2 in clearance_rects:
		clearances.append(FeatureGroundShape.axis_rect(rect))
	var ground := FeatureGroundField.new(surfaces, clearances,
		clearance_limit, masks, nodes)
	return FeatureContext.new(coverage, ground,
		EnvironmentInstancePayload.new(), masks, nodes)

func test_centred_surface_uses_geometric_union() -> void:
	var coverage := Rect2(-Vector2.ONE * 96.0, Vector2.ONE * 192.0)
	var corridor := Rect2(Vector2(0.0, -2.0), Vector2(12.0, 4.0))
	var context := _context(coverage, [corridor], [corridor], 2.0)
	assert_eq(context.surface_at(Vector2(1.0, -1.0)),
		FeatureGroundField.WORN_PATH)
	assert_eq(context.surface_at(Vector2(1.0, 1.0)),
		FeatureGroundField.WORN_PATH,
		"the 4m strip covers the two 2m quad-centre columns")
	assert_eq(context.surface_at(Vector2(7.0, 3.0)), FeatureGroundField.NATURAL)

func test_village_node_paints_a_large_circle_instead_of_a_square() -> void:
	var masks := {Vector2i.ZERO: 3}
	var context := _context(Rect2(-Vector2.ONE * 24.0, Vector2.ONE * 48.0),
		[], [], 2.0, masks, {Vector2i.ZERO: true})
	assert_eq(context.surface_at(Vector2(7.9, 0.0)),
		FeatureGroundField.WORN_PATH,
		"the circular plaza is wider than the old twelve-metre square")
	assert_eq(context.surface_at(Vector2(5.0, 5.0)),
		FeatureGroundField.WORN_PATH,
		"the large circle fills its interior beyond the old road strip")
	assert_eq(context.surface_at(Vector2(7.0, 7.0)), FeatureGroundField.NATURAL,
		"the village plaza has a circular boundary, not a larger square")

func test_geometric_surfaces_remain_visible_when_path_masks_exist() -> void:
	var supplement := Rect2(Vector2(-2.0, 8.0), Vector2(4.0, 4.0))
	var context := _context(Rect2(-Vector2.ONE * 24.0, Vector2.ONE * 48.0),
		[supplement], [], 2.0, {Vector2i.ZERO: 1})
	assert_eq(context.surface_at(Vector2(0.0, 10.0)),
		FeatureGroundField.WORN_PATH,
		"the geometric layer is unioned with the lattice instead of disabled by it")

func test_compiled_priority_resolves_path_and_shape_layers() -> void:
	var shapes: Array[FeatureGroundShape] = [
		FeatureGroundShape.circle(Vector2.ZERO, 3.0, 7, 6),
	]
	var clearances: Array[FeatureGroundShape] = []
	var ground := FeatureGroundField.new(shapes, clearances, 0.0,
		{Vector2i.ZERO: 1}, {}, {FeatureGroundField.WORN_PATH: 5})
	assert_eq(ground.surface_at(Vector2.ZERO), 7,
		"the compiled table, rather than a hidden path constant, controls precedence")

func test_shape_distances_cover_every_supported_primitive() -> void:
	var circle := FeatureGroundShape.circle(Vector2.ZERO, 2.0)
	assert_almost_eq(circle.signed_distance(Vector2(3.0, 0.0)), 1.0, 0.0001)
	var capsule := FeatureGroundShape.capsule(Vector2(-2.0, 0.0),
		Vector2(2.0, 0.0), 1.0)
	assert_lt(capsule.signed_distance(Vector2.ZERO), 0.0)
	assert_almost_eq(capsule.signed_distance(Vector2(0.0, 2.0)), 1.0, 0.0001)
	var box := FeatureGroundShape.oriented_rect(Vector2.ZERO,
		Vector2(2.0, 1.0), PI * 0.5)
	assert_true(box.contains(Vector2(0.0, 1.5)))
	assert_false(box.contains(Vector2(1.5, 0.0)))
	assert_true(box.bounds().encloses(Rect2(Vector2(-1.0, -2.0),
		Vector2(2.0, 4.0))))

func test_shape_intersection_is_exact_across_the_closed_vocabulary() -> void:
	var circle := FeatureGroundShape.circle(Vector2.ZERO, 1.0)
	var capsule := FeatureGroundShape.capsule(Vector2(2.0, -2.0),
		Vector2(2.0, 2.0), 0.5)
	var rotated := FeatureGroundShape.oriented_rect(Vector2(4.0, 0.0),
		Vector2(1.0, 2.0), PI * 0.25)
	assert_false(circle.intersects(capsule))
	assert_true(circle.intersects(capsule, 0.5),
		"an explicit planner margin closes the exact one-half-metre gap")
	assert_true(capsule.intersects(rotated))
	assert_true(rotated.intersects(capsule), "intersection is symmetric")
	assert_false(circle.intersects(rotated))
	var crossing := FeatureGroundShape.capsule(Vector2(2.2, -4.0),
		Vector2(2.2, 4.0), 0.1)
	assert_true(crossing.intersects(rotated),
		"segment-to-rectangle distance catches an edge crossing with both endpoints outside")
	var disjoint_box := FeatureGroundShape.oriented_rect(Vector2(8.0, 0.0),
		Vector2(1.0, 1.0), PI * 0.25)
	assert_false(rotated.intersects(disjoint_box))

func test_whole_shape_reservation_query_cannot_miss_a_crossing() -> void:
	var reservation := FeatureGroundShape.axis_rect(
		Rect2(Vector2(-2.0, -12.0), Vector2(4.0, 24.0)))
	var ground := FeatureGroundField.new([], [reservation], 3.0)
	var crossing_lot := FeatureGroundShape.oriented_rect(Vector2.ZERO,
		Vector2(8.0, 1.0), PI * 0.25)
	var clear_lot := FeatureGroundShape.oriented_rect(Vector2(12.0, 0.0),
		Vector2(2.0, 1.0), PI * 0.25)
	assert_true(ground.overlaps_clearance(crossing_lot))
	assert_false(ground.overlaps_clearance(clear_lot))

func test_clearance_is_signed_saturated_and_includes_props() -> void:
	var corridor := Rect2(Vector2(-2.0, -12.0), Vector2(4.0, 24.0))
	var prop := Rect2(Vector2(10.0, -1.0), Vector2(2.0, 2.0))
	var context := _context(Rect2(-Vector2.ONE * 20.0, Vector2.ONE * 40.0),
		[corridor], [corridor, prop], 3.0)
	assert_lt(context.clearance_at(Vector2.ZERO), 0.0)
	assert_almost_eq(context.clearance_at(Vector2(2.0, 0.0)), 0.0, 0.0001)
	assert_lt(context.clearance_at(Vector2(11.0, 0.0)), 0.0,
		"prop footprints join the reservation union")
	assert_almost_eq(context.clearance_at(Vector2(100.0, 100.0)), 3.0, 0.0001)
	assert_eq(context.surface_at(Vector2(11.0, 0.0)),
		FeatureGroundField.NATURAL,
		"a prop reservation does not paint terrain")

func test_turn_rounds_both_edges_without_a_centre_circle_blob() -> void:
	var masks := {Vector2i.ZERO: 5}
	var context := _context(Rect2(-Vector2.ONE * 24.0, Vector2.ONE * 48.0),
		[], [], 2.0, masks)
	assert_eq(context.surface_at(Vector2(2.5, 2.5)),
		FeatureGroundField.WORN_PATH,
		"the inner edge follows the two-metre-radius fillet")
	assert_eq(context.surface_at(Vector2(3.0, 3.0)), FeatureGroundField.NATURAL,
		"space inside the rounded inner edge stays grass")
	assert_eq(context.surface_at(Vector2(-0.2, -0.2)),
		FeatureGroundField.WORN_PATH,
		"the outer edge follows the six-metre-radius fillet")
	assert_eq(context.surface_at(Vector2(-0.5, -0.5)), FeatureGroundField.NATURAL,
		"space beyond the rounded outer edge stays grass")
	assert_eq(context.surface_at(Vector2(0.0, -1.9)), FeatureGroundField.NATURAL,
		"the incoming strip stops at the tangent instead of squaring off the outer edge")
	assert_eq(context.surface_at(Vector2(-3.0, 0.0)), FeatureGroundField.NATURAL,
		"there is no circle superimposed over the centre of the bend")
	assert_eq(context.surface_at_cell(Vector2(2.5, 2.5), Vector2i.ZERO),
		context.surface_at(Vector2(2.5, 2.5)),
		"lattice consumers reuse their known cell without changing classification")

func test_branch_fillets_each_concave_corner() -> void:
	var context := _context(Rect2(-Vector2.ONE * 24.0, Vector2.ONE * 48.0),
		[], [], 2.0, {Vector2i.ZERO: 7})
	assert_eq(context.surface_at(Vector2(2.5, 2.5)),
		FeatureGroundField.WORN_PATH,
		"the right side of a T receives the same inner curve as a bend")
	assert_eq(context.surface_at(Vector2(-2.5, 2.5)),
		FeatureGroundField.WORN_PATH,
		"the left side of a T receives the matching inner curve")
	assert_eq(context.surface_at(Vector2(3.0, 3.0)), FeatureGroundField.NATURAL)
	assert_eq(context.surface_at(Vector2(-3.0, 3.0)), FeatureGroundField.NATURAL)

func test_canonical_context_is_memoized_and_resource_free_on_flat_dry_fields() -> void:
	var seed_value := 4242
	var water := DryPlanningWater.new(seed_value)
	var heights := HeightfieldPlan.new(seed_value, 1.0, 1, "mean", 1)
	heights.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var reservation_context_margin := program.query_margin + 10.0
	var world := WorldFeaturePlan.new(seed_value, water, fields, program,
		settlements, reservation_context_margin)
	var plan := world.path_plan()
	var first := world.context_for(Vector2i.ZERO)
	assert_same(world.context_for(Vector2i.ZERO), first)
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
	assert_eq(first.coverage(), Rect2(-Vector2.ONE * reservation_context_margin,
		Vector2.ONE * (TerrainChunkMesher.CHUNK_WORLD \
			+ 2.0 * reservation_context_margin)),
		"reservation coverage can grow independently of finite field sampling")
	assert_gte(int(plan.stats().context_builds), 1)
