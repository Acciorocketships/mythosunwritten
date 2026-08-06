class_name WarrenPlotVoidPlan
extends RefCounted

## Immutable, resource-free coarse grammar decision. Occupied plots and public
## route episodes are chosen together; neither is inferred as decoration around
## an already-frozen counterpart. A later compiler expands these records into
## ordinary FabricRecipe units and the common transaction remains authoritative.
var stable_id: StringName
var world_seed: int
var route_steps: Array[Dictionary] = []
var occupied_plots: Array[Dictionary] = []
var market_node_ids: Array[StringName] = []
var covered_node_ids: Array[StringName] = []
var _sealed := false


func _init(p_stable_id: StringName, p_world_seed: int) -> void:
	stable_id = p_stable_id
	world_seed = p_world_seed


func seal(p_route_steps: Array[Dictionary],
		p_occupied_plots: Array[Dictionary], p_market_node_ids: Array[StringName],
		p_covered_node_ids: Array[StringName]) -> bool:
	if _sealed or stable_id.is_empty() or p_route_steps.size() < 2:
		return false
	var known_ids: Dictionary = {}
	var landing_count := 0
	for index in p_route_steps.size():
		var step := p_route_steps[index]
		var step_id := StringName(step.get("stable_id", ""))
		var recipe_id := StringName(step.get("recipe_id", ""))
		var parent_id := StringName(step.get("parent_id", ""))
		if step_id.is_empty() or recipe_id.is_empty() or known_ids.has(step_id) \
				or int(step.get("yaw_quarters", -1)) < 0 \
				or int(step.get("yaw_quarters", -1)) > 3:
			return false
		if index == 0:
			if parent_id != &"" or recipe_id != &"route.landing" \
					or not step.has("origin"):
				return false
			landing_count += 1
		elif step.has("origin"):
			var parents := step.get("parents", []) as Array
			var bonds := step.get("bonds", []) as Array
			if parents.is_empty() or bonds.is_empty():
				return false
			for parent_value: Variant in parents:
				if not known_ids.has(StringName(parent_value)):
					return false
			for bond: Dictionary in bonds:
				if StringName(bond.get("own_socket", "")).is_empty() \
						or not known_ids.has(StringName(
							bond.get("target_unit", ""))) \
						or StringName(bond.get("target_socket", "")).is_empty():
					return false
		elif parent_id.is_empty() or not known_ids.has(parent_id) \
				or StringName(step.get("own_socket", "")).is_empty() \
				or StringName(step.get("parent_socket", "")).is_empty():
			return false
		known_ids[step_id] = true
	var plot_ids: Dictionary = {}
	for plot: Dictionary in p_occupied_plots:
		var plot_id := StringName(plot.get("stable_id", ""))
		var kind := StringName(plot.get("kind", ""))
		var origin := plot.get("origin", Vector3i()) as Vector3i
		if plot_id.is_empty() or plot_ids.has(plot_id) or not plot.has("origin") \
				or (kind != &"building" and kind != &"tower" \
					and kind != &"market") \
				or (kind == &"market" and (int(plot.get("market_family", -1)) < 0 \
					or int(plot.get("market_family", -1)) \
						>= SettlementFabricProgram.MARKET_STALLS.size())) \
				or (kind != &"market" and (int(plot.get("storeys", 0)) < 1 \
					or int(plot.get("storeys", 0)) > 4)) \
				or (plot.has("theme") and StringName(plot.theme) != &"blue" \
					and StringName(plot.theme) != &"orange") \
				or (origin.y != 0 and origin.y != 1):
			return false
		plot_ids[plot_id] = true
	for node_id: StringName in p_market_node_ids:
		if not known_ids.has(node_id):
			return false
	for node_id: StringName in p_covered_node_ids:
		if not known_ids.has(node_id):
			return false
	if landing_count != 1:
		return false
	route_steps.assign(p_route_steps)
	occupied_plots.assign(p_occupied_plots)
	market_node_ids.assign(p_market_node_ids)
	covered_node_ids.assign(p_covered_node_ids)
	_sealed = true
	return true


func validate() -> bool:
	return _sealed and not stable_id.is_empty() and route_steps.size() >= 2


func deterministic_signature() -> String:
	return "seed:%d|%s" % [world_seed, geometry_signature()]


func geometry_signature() -> String:
	## Seed is deliberately excluded: corpus tests compare this value to prove
	## that two seeds changed construction rather than merely their identity.
	var parts := PackedStringArray()
	for step: Dictionary in route_steps:
		parts.append("R:%s:%s:%s:%s:%s:%d" % [step.stable_id, step.recipe_id,
			step.get("parent_id", &""), step.get("own_socket", &""),
			step.get("parent_socket", &""), int(step.yaw_quarters)])
	for plot: Dictionary in occupied_plots:
		var origin := plot.origin as Vector3i
		parts.append("P:%s:%s:%d,%d,%d:%d:%d:%s:%d" % [plot.stable_id, plot.kind,
			origin.x, origin.y, origin.z, int(plot.storeys),
			int(plot.yaw_quarters), StringName(plot.get("theme", "")),
			int(plot.get("market_family", -1))])
	return "|".join(parts)


func coarse_route_trace() -> Array[Vector3i]:
	## Ordered, resource-free route centres including elevation. This is useful to
	## prove that seed variation changes the maze itself instead of only its ids,
	## asset themes, or final building choices. Explicit post-stair landings do not
	## advance twice: they occupy the destination already reached by the flight.
	var out: Array[Vector3i] = []
	if route_steps.is_empty():
		return out
	var current := route_steps[0].get("origin", Vector3i()) as Vector3i
	out.append(current)
	for index in range(1, route_steps.size()):
		var step := route_steps[index]
		var parent_socket := StringName(step.get("parent_socket", ""))
		var direction := _socket_direction(parent_socket)
		if direction == Vector2i.ZERO:
			continue
		var recipe_id := StringName(step.recipe_id)
		var distance := 5 if _is_full_stair(recipe_id) \
			else 4 if recipe_id == &"stair.half" else 2
		current.x += direction.x * distance
		current.z += direction.y * distance
		if String(recipe_id).begins_with("stair."):
			var rise := 2 if _is_full_stair(recipe_id) else 1
			current.y += rise if StringName(step.own_socket) == &"walk.low" \
				else -rise
		out.append(current)
	return out


func canonical_coarse_route_signature() -> String:
	## Remove translation and cardinal rotation before comparing seed geometry.
	## A changed value therefore represents a different ordered 3D maze, not the
	## same route spun around its settlement landing.
	var trace := coarse_route_trace()
	if trace.is_empty():
		return ""
	var best := ""
	for quarter in 4:
		var parts := PackedStringArray()
		var origin := _rotate_y(trace[0], quarter)
		for point: Vector3i in trace:
			var rotated := _rotate_y(point, quarter) - origin
			parts.append("%d,%d,%d" % [rotated.x, rotated.y, rotated.z])
		var candidate := ";".join(parts)
		if best.is_empty() or candidate < best:
			best = candidate
	return best


func coarse_route_bounds() -> Rect2i:
	## Reconstruct the grammar's centreline without compiling meshes or recipes.
	## This is an admissible cheap screen for obviously linear candidates; exact
	## room, roof, clearance, and support bounds remain the final authority.
	if route_steps.is_empty():
		return Rect2i()
	var current := route_steps[0].get("origin", Vector3i()) as Vector3i
	var minimum := Vector2i(current.x, current.z)
	var maximum := minimum
	for index in range(1, route_steps.size()):
		var step := route_steps[index]
		var parent_socket := StringName(step.get("parent_socket", ""))
		var direction := _socket_direction(parent_socket)
		if direction == Vector2i.ZERO:
			# The explicit square landing after a stair occupies its destination;
			# it does not advance the centreline a second time.
			continue
		var recipe_id := StringName(step.recipe_id)
		var distance := 5 if _is_full_stair(recipe_id) \
			else 4 if recipe_id == &"stair.half" else 2
		current.x += direction.x * distance
		current.z += direction.y * distance
		if String(recipe_id).begins_with("stair."):
			var rise := 2 if _is_full_stair(recipe_id) else 1
			current.y += rise if StringName(step.own_socket) == &"walk.low" \
				else -rise
		minimum = minimum.min(Vector2i(current.x, current.z))
		maximum = maximum.max(Vector2i(current.x, current.z))
	# Rect2i.end is exclusive. Include both extrema and one lattice cell of
	# centreline thickness on either side.
	return Rect2i(minimum - Vector2i.ONE,
		maximum - minimum + Vector2i(3, 3))


static func _rotate_y(point: Vector3i, quarter: int) -> Vector3i:
	match posmod(quarter, 4):
		0:
			return point
		1:
			return Vector3i(-point.z, point.y, point.x)
		2:
			return Vector3i(-point.x, point.y, -point.z)
		_:
			return Vector3i(point.z, point.y, -point.x)


static func _is_full_stair(recipe_id: StringName) -> bool:
	return recipe_id == &"stair.full" \
		or String(recipe_id).begins_with("stair.facade.full.")


static func _socket_direction(socket_id: StringName) -> Vector2i:
	if socket_id == &"walk.east":
		return Vector2i.RIGHT
	if socket_id == &"walk.west":
		return Vector2i.LEFT
	if socket_id == &"walk.north":
		return Vector2i.UP
	if socket_id == &"walk.south":
		return Vector2i.DOWN
	return Vector2i.ZERO
