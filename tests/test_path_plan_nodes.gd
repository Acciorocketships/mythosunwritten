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

func _plan(seed_value := 4242, cache_cap := 256) -> PathPlan:
	var water := DryPlanningWater.new(seed_value)
	var heights := HeightfieldPlan.new(seed_value, 1.0, 1, "mean", 1)
	heights.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	var fields := WorldFieldBlockCache.new(heights, water, 28.0, 0.0, cache_cap)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var settlements := SettlementPlan.new(seed_value, water)
	return PathPlan.new(seed_value, water, fields, program,
		program.query_margin, settlements)

func test_nodes_are_deterministic_order_independent_and_minimal() -> void:
	var a := _plan()
	var b := _plan()
	var keys := [Vector2i(-2, -1), Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 2)]
	var expected: Dictionary = {}
	for key: Vector2i in keys:
		expected[key] = a.node_for(key)
	keys.reverse()
	for key: Vector2i in keys:
		assert_eq(b.node_for(key), expected[key])
		var node: Dictionary = expected[key]
		if not node.is_empty():
			assert_eq(node.keys().size(), 2)
			assert_true(node.has("id") and node.has("cell"))

func test_node_cache_eviction_changes_work_not_answers() -> void:
	var plan := _plan(4242)
	var first := plan.node_for(Vector2i(-1, 0))
	# The production cap is fixed, so cross it without changing any fields.
	for x in range(PathProgram.NODE_CACHE_CAP + 2):
		plan.node_for(Vector2i(x, 7))
	assert_eq(plan.node_for(Vector2i(-1, 0)), first)
	assert_gt(int(plan.stats().evictions), 0)

func test_only_a_provisional_winner_materializes_exact_water() -> void:
	var plan := _plan()
	# Find a deterministic present node; existence/biome rejection may make any
	# individual super-cell absent, but exact water is never built per candidate.
	for x in range(-4, 5):
		plan.node_for(Vector2i(x, 0))
	var fields: WorldFieldBlockCache = plan._fields
	assert_lte(fields.water_build_count, 9,
		"at most one winning support footprint per queried super-cell asks exact water")
	assert_gt(fields.region_build_count, 0,
		"all candidate scoring is allowed to read canonical terrain")

func test_hillside_route_uses_only_rendered_walkable_slopes() -> void:
	var seed_value := 7319
	var water := DryPlanningWater.new(seed_value)
	var heights := HeightfieldPlan.new(seed_value, 12.0, 4, "mean", 3)
	heights.set_raw_height_override(func(cx: int, _cz: int) -> float:
		return clampf(float(cx), 0.0, 32.0) * 0.25)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.FIELD_CACHE_CAP)
	var plan := PathPlan.new(seed_value, water, fields, program,
		program.query_margin, SettlementPlan.new(seed_value, water))
	var route := plan.route_for(
		{"id": &"hill-low", "cell": Vector2i.ZERO},
		{"id": &"hill-high", "cell": Vector2i(32, 0)})
	assert_false(route.is_empty(), "a gradual multi-storey hill remains routable")
	assert_eq(route.connections.size(), 32)
	var low := plan._ground(Vector2.ZERO)
	var high := plan._ground(Vector2(32, 0) * TerrainSurfaceField.TILE)
	assert_gt(high, low + HeightfieldPlan.STOREY_HEIGHT)
	for connection: Dictionary in route.connections:
		var a: Vector2i = connection.a
		var b: Vector2i = connection.b
		var midpoint := (Vector2(a) + Vector2(b)) \
			* TerrainSurfaceField.TILE * 0.5
		assert_true(TerrainSurfaceField.is_walkable_edge(
			fields.region_at(midpoint), a, b - a),
			"a path can climb rendered slopes but never crosses an exposed cliff face")

func test_route_never_cuts_through_an_exposed_cliff_face() -> void:
	var seed_value := 7320
	var water := DryPlanningWater.new(seed_value)
	var heights := HeightfieldPlan.new(seed_value, 12.0, 4, "mean", 3)
	heights.set_raw_height_override(func(cx: int, _cz: int) -> float:
		return 0.0 if cx < 16 else 12.0)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.FIELD_CACHE_CAP)
	var plan := PathPlan.new(seed_value, water, fields, program,
		program.query_margin, SettlementPlan.new(seed_value, water))
	var route := plan.route_for(
		{"id": &"cliff-low", "cell": Vector2i.ZERO},
		{"id": &"cliff-high", "cell": Vector2i(32, 0)})
	assert_true(route.is_empty(),
		"an exposed 12 m face is rejected rather than hidden under a path")
