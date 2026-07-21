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

class BorderPathPlan extends PathPlan:
	func _biome_at(point: Vector2) -> StringName:
		return &"meadow" if point.x < 12.0 else &"deep_forest"

class StripedPathPlan extends PathPlan:
	func _biome_at(point: Vector2) -> StringName:
		return &"meadow" if floori(point.x / TerrainSurfaceField.TILE) % 2 == 0 \
			else &"deep_forest"

func _plan(seed_value := 4242) -> PathPlan:
	var water := DryPlanningWater.new(seed_value)
	var heights := HeightfieldPlan.new(seed_value, 1.0, 1, "mean", 1)
	heights.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	var program := PathProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.FIELD_CACHE_CAP)
	var settlements := SettlementPlan.new(seed_value, water)
	return PathPlan.new(seed_value, water, fields, program,
		program.query_margin, settlements)

func _route(key: String, cells: Array[Vector2i]) -> Dictionary:
	var connections: Array[Dictionary] = []
	for index in cells.size() - 1:
		connections.append({"a": cells[index], "b": cells[index + 1]})
	return {"key": key,
		"node_a": {"id": StringName(key + ".a"), "cell": cells[0]},
		"node_b": {"id": StringName(key + ".b"), "cell": cells[-1]},
		"connections": connections, "bridges": [], "cost": 1.0, "pair_hash": 7}

func _straight_cells(node: Vector2i, direction: Vector2i,
		steps := 12) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for step in steps + 1:
		cells.append(node + direction * step)
	return cells

func _masks_for(routes: Array[Dictionary]) -> Dictionary:
	var masks: Dictionary = {}
	for route: Dictionary in routes:
		for connection: Dictionary in route.connections:
			PathPlan._add_connection(masks, connection.a, connection.b)
	return masks

func test_lamps_have_hard_spacing_and_alternate_observed_sides() -> void:
	var plan := _plan()
	var a := {"id": &"a", "cell": Vector2i(0, 0)}
	var b := {"id": &"b", "cell": Vector2i(24, 0)}
	var connections: Array[Dictionary] = []
	var masks: Dictionary = {}
	var cell_routes: Dictionary = {}
	for x in range(24):
		connections.append({"a": Vector2i(x, 0), "b": Vector2i(x + 1, 0)})
	for x in range(25):
		masks[Vector2i(x, 0)] = 3
		cell_routes[Vector2i(x, 0)] = {"a|b": true}
	var route := {"key": "a|b", "node_a": a, "node_b": b,
		"connections": connections, "bridges": [], "cost": 1.0, "pair_hash": 7}
	var occupied: Array[Rect2] = []
	var payload := EnvironmentInstancePayload.new()
	plan._place_lamps(Rect2(Vector2.ZERO, Vector2(25.0 * 24.0, 192.0)), [route],
		masks, {a.cell: true, b.cell: true}, {}, cell_routes, [], occupied,
		payload)
	var centres: Array[Vector2] = []
	for rect: Rect2 in occupied:
		centres.append(rect.get_center())
	centres.sort_custom(func(left: Vector2, right: Vector2) -> bool:
		return left.x < right.x)
	assert_gt(centres.size(), 3)
	for i in range(1, centres.size()):
		assert_gte(centres[i].x - centres[i - 1].x, 48.0 - 0.001)
		assert_lt(centres[i].y * centres[i - 1].y, 0.0,
			"accepted lamp sides strictly alternate along the canonical route")
	var lamps: Dictionary = payload.batches.get(&"sfv.light_pole.001", {})
	assert_false(lamps.is_empty())
	for transform: Transform3D in lamps.transforms:
		var arm := transform.basis * Vector3(0.0, 0.0, 1.0)
		var toward_path := Vector3(0.0, 0.0, -transform.origin.z).normalized()
		assert_gt(arm.dot(toward_path), 0.99,
			"the authored hanging arm faces inward over the path")

func test_large_gates_follow_each_real_village_approach() -> void:
	var plan := _plan(991177)
	var node := Vector2i(4, 4)
	var routes: Array[Dictionary] = []
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
			Vector2i.DOWN, Vector2i.UP]:
		routes.append(_route("route.%d.%d" % [direction.x, direction.y],
			_straight_cells(node, direction)))
	var masks := _masks_for(routes)
	var occupied: Array[Rect2] = []
	var payload := EnvironmentInstancePayload.new()
	plan._place_arches(Rect2(Vector2.ZERO, Vector2.ONE * 192.0), routes, masks,
		{node: true}, {}, [], occupied, payload)
	var gate_count := 0
	for asset_id: StringName in [&"sfv.arch.001", &"sfv.arch.002"]:
		var batch: Dictionary = payload.batches.get(asset_id, {})
		if batch.is_empty():
			continue
		gate_count += batch.transforms.size()
		for transform: Transform3D in batch.transforms:
			var distance := Vector2(transform.origin.x, transform.origin.z).distance_to(
				Vector2(node) * TerrainSurfaceField.TILE)
			assert_almost_eq(distance, (PathProgram.VILLAGE_GATE_MIN_STEPS - 0.5) \
				* TerrainSurfaceField.TILE, 0.001)
	assert_eq(gate_count, 4, "every accepted route out of the village receives a gate")

func test_village_gate_follows_a_route_through_an_early_turn() -> void:
	var plan := _plan(991177)
	var node := Vector2i(4, 4)
	var cells: Array[Vector2i] = [node, node + Vector2i.RIGHT]
	for step in range(1, 12):
		cells.append(node + Vector2i(1, step))
	var routes: Array[Dictionary] = [_route("turn", cells)]
	var masks := _masks_for(routes)
	var payload := EnvironmentInstancePayload.new()
	plan._place_arches(Rect2(Vector2.ZERO, Vector2.ONE * 192.0), routes, masks,
		{node: true}, {}, [], [], payload)
	var transforms: Array[Transform3D] = []
	for asset_id: StringName in [&"sfv.arch.001", &"sfv.arch.002"]:
		var batch: Dictionary = payload.batches.get(asset_id, {})
		if not batch.is_empty():
			transforms.append_array(batch.transforms)
	assert_eq(transforms.size(), 1)
	var transform := transforms[0]
	var expected := (Vector2(cells[PathProgram.VILLAGE_GATE_MIN_STEPS - 1]) \
		+ Vector2(cells[PathProgram.VILLAGE_GATE_MIN_STEPS])) \
		* TerrainSurfaceField.TILE * 0.5
	assert_eq(Vector2(transform.origin.x, transform.origin.z),
		expected)
	var across_opening := transform.basis * Vector3.RIGHT
	assert_gt(absf(across_opening.x), 0.99,
		"the arch aligns to the local vertical road segment after the turn")

func test_routes_that_split_near_a_village_each_receive_a_gate() -> void:
	var plan := _plan(991177)
	var node := Vector2i(4, 4)
	var routes: Array[Dictionary] = [
		_route("left", _straight_cells(node, Vector2i.LEFT)),
		_route("right", _straight_cells(node, Vector2i.RIGHT)),
	]
	var fork: Array[Vector2i] = [node, node + Vector2i.RIGHT]
	for step in range(1, 12):
		fork.append(node + Vector2i(1, -step))
	routes.append(_route("fork", fork))
	var payload := EnvironmentInstancePayload.new()
	plan._place_arches(Rect2(Vector2.ZERO, Vector2.ONE * 192.0), routes,
		_masks_for(routes), {node: true}, {}, [], [], payload)
	var gate_count := 0
	for asset_id: StringName in [&"sfv.arch.001", &"sfv.arch.002"]:
		gate_count += payload.batches.get(asset_id, {}).get("transforms", []).size()
	assert_eq(gate_count, 3,
		"a branch before the gate distance creates one gate on each physical exit")

func test_small_arch_is_owned_by_the_exact_biome_crossing() -> void:
	var base := _plan()
	var plan := BorderPathPlan.new(base._world_seed, base._water_plan, base._fields,
		base._program, base._context_margin, base._settlements)
	var masks := {Vector2i.ZERO: 1, Vector2i.RIGHT: 2}
	var payload := EnvironmentInstancePayload.new()
	plan._place_arches(Rect2(Vector2.ZERO, Vector2.ONE * 192.0),
		[], masks, {}, {}, [], [], payload)
	var batch: Dictionary = payload.batches.get(&"sfv.entrance_arch.001", {})
	assert_eq(batch.transforms.size(), 1)
	assert_almost_eq((batch.transforms[0] as Transform3D).origin.x, 12.0,
		TerrainSurfaceField.TILE / 256.0,
		"fixed bisection places the arch at the dominant-biome boundary")

func test_biome_gates_stay_clear_of_villages_and_each_other() -> void:
	var base := _plan()
	var border := BorderPathPlan.new(base._world_seed, base._water_plan, base._fields,
		base._program, base._context_margin, base._settlements)
	var one_edge := {Vector2i.ZERO: 1, Vector2i.RIGHT: 2}
	var near_payload := EnvironmentInstancePayload.new()
	border._place_arches(Rect2(Vector2.ZERO, Vector2.ONE * 192.0), [], one_edge,
		{Vector2i.ZERO: true}, {}, [], [], near_payload)
	assert_false(near_payload.batches.has(&"sfv.entrance_arch.001"),
		"a biome marker cannot stack inside a village approach")

	var striped := StripedPathPlan.new(base._world_seed, base._water_plan, base._fields,
		base._program, base._context_margin, base._settlements)
	var masks := {
		Vector2i.ZERO: 1,
		Vector2i.RIGHT: 3,
		Vector2i(2, 0): 2,
	}
	var spaced_payload := EnvironmentInstancePayload.new()
	striped._place_arches(Rect2(Vector2.ZERO, Vector2.ONE * 192.0), [], masks,
		{}, {}, [], [], spaced_payload)
	var batch: Dictionary = spaced_payload.batches.get(&"sfv.entrance_arch.001", {})
	assert_eq(batch.get("transforms", []).size(), 1,
		"nearby ecotone oscillations collapse to one readable biome gate")
