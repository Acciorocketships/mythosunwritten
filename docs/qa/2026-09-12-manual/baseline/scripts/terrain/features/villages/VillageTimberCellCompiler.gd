class_name VillageTimberCellCompiler
extends RefCounted

## Projects semantic skirts, shared platforms, and curved aerial links onto
## one fixed-cell vocabulary. The materializer downstream is intentionally
## unaware of which planner requested a cell.


static func compile(settlement_id: StringName,
		circulation: VillageCirculationPlan,
		skirts: Array[VillageSkirtDeckPlan],
		placements: Array[VillageMassingPlacement],
		route_stairs: VillageRouteStairFabricPlan = null
		) -> Array[VillageTimberCell]:
	assert(not settlement_id.is_empty() and circulation != null)
	var selected: Dictionary = {}
	var placement_table: Dictionary = {}
	for placement: VillageMassingPlacement in placements:
		placement_table[placement.stable_key] = placement
	for skirt: VillageSkirtDeckPlan in skirts:
		assert(skirt.accepted)
		for cell: VillageTimberCell in skirt.cells:
			_add(selected, cell)
	for platform: VillagePlatformRegion in circulation.platforms:
		var owner := StringName("%s.%s" % [settlement_id,
			platform.stable_key])
		for index in platform.cell_centres.size():
			_add(selected, VillageTimberCell.new(
				StringName("%s.%s.floor.%03d" % [settlement_id,
					platform.stable_key, index]),
				owner,
				VillageTimberCell.Kind.PLATFORM,
				platform.cell_centres[index],
				platform.surface_y, platform.yaw))
	for link: VillageCirculationLink in circulation.links:
		if not link.is_aerial():
			continue
		var samples := _uniform_samples(link.samples, VillageProgram.MODULE)
		var route_length := _horizontal_length(link.samples)
		var stair_runs: Array[VillageRouteStairRun] = [] if route_stairs == null \
			else route_stairs.runs_for(link.stable_key)
		for index in samples.size():
			var point := samples[index]
			var distance := route_length * float(index) \
				/ float(maxi(1, samples.size() - 1))
			if route_stairs != null and route_stairs.interval_is_stair(
					link.stable_key,
					distance - VillageProgram.MODULE * 0.5,
					distance + VillageProgram.MODULE * 0.5):
				continue
			if not stair_runs.is_empty():
				var run := stair_runs[0]
				point.y = run.from_y if distance < run.start_distance \
					else run.to_y
			var tangent := _tangent(samples, index)
			if _cell_on_platform(point, tangent.angle(),
					circulation.platforms):
				continue
			var owner := StringName("%s.%s" % [settlement_id,
				link.stable_key])
			var from_key := _owner_key(link.from_key)
			var to_key := _owner_key(link.to_key)
			var from_placement := placement_table.get(from_key) \
				as VillageMassingPlacement
			var to_placement := placement_table.get(to_key) \
				as VillageMassingPlacement
			if _cell_uses_access(point, from_placement):
				owner = _building_owner(settlement_id, link.from_key)
			elif _cell_uses_access(point, to_placement):
				owner = _building_owner(settlement_id, link.to_key)
			_add(selected, VillageTimberCell.new(
				StringName("%s.%s.floor.%03d" % [settlement_id,
					link.stable_key, index]),
				owner,
				VillageTimberCell.Kind.WALKWAY, Vector2(point.x, point.z),
				point.y, tangent.angle()))
	var keys: Array = selected.keys()
	keys.sort()
	var out: Array[VillageTimberCell] = []
	for key: String in keys:
		out.append(selected[key])
	return out


static func _add(selected: Dictionary, cell: VillageTimberCell) -> void:
	var key := _key(cell.centre, cell.floor_y)
	if not selected.has(key) \
			or _kind_priority(cell.kind) \
				< _kind_priority((selected[key] as VillageTimberCell).kind):
		selected[key] = cell


static func _uniform_samples(points: Array[Vector3],
		step: float) -> Array[Vector3]:
	assert(points.size() >= 2 and step > 0.0)
	var cumulative: PackedFloat32Array = [0.0]
	for index in range(1, points.size()):
		cumulative.append(cumulative[-1] \
			+ Vector2(points[index].x, points[index].z).distance_to(
				Vector2(points[index - 1].x, points[index - 1].z)))
	var total := cumulative[-1]
	var count := maxi(1, ceili(total / step))
	var out: Array[Vector3] = []
	var segment := 1
	for index in count + 1:
		var distance := minf(total, float(index) * total / float(count))
		while segment < cumulative.size() - 1 \
				and cumulative[segment] < distance:
			segment += 1
		var start_distance := cumulative[segment - 1]
		var span := cumulative[segment] - start_distance
		var t := 0.0 if span <= 0.0001 \
			else (distance - start_distance) / span
		out.append(points[segment - 1].lerp(points[segment], t))
	return out


static func _tangent(points: Array[Vector3], index: int) -> Vector2:
	var prior := points[maxi(0, index - 1)]
	var next := points[mini(points.size() - 1, index + 1)]
	var tangent := Vector2(next.x - prior.x, next.z - prior.z)
	return Vector2.RIGHT if tangent.length_squared() <= 0.0001 \
		else tangent.normalized()


static func _kind_priority(kind: VillageTimberCell.Kind) -> int:
	# Building skirts own their exact facade seam; public platforms own the
	# broader shared patch; a route cell fills only remaining positions.
	return kind


static func _building_owner(settlement_id: StringName,
		node_key: StringName) -> StringName:
	var owner_key := String(_owner_key(node_key))
	return StringName("%s.urban.%s" % [settlement_id, owner_key])


static func _owner_key(node_key: StringName) -> StringName:
	var text := String(node_key)
	return StringName(text.trim_suffix(".door").trim_suffix(".terrain"))


static func _cell_uses_access(point: Vector3,
		placement: VillageMassingPlacement) -> bool:
	return placement != null and placement.route_access_shape().signed_distance(
		Vector2(point.x, point.z)) <= 0.001


static func _key(point: Vector2, floor_y: float) -> String:
	return "%d:%d:%d" % [roundi(point.x * 1000.0),
		roundi(point.y * 1000.0), roundi(floor_y * 1000.0)]


static func _horizontal_length(points: Array[Vector3]) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += Vector2(points[index].x, points[index].z).distance_to(
			Vector2(points[index - 1].x, points[index - 1].z))
	return total


static func _cell_on_platform(point: Vector3, yaw: float,
		platforms: Array[VillagePlatformRegion]) -> bool:
	for platform: VillagePlatformRegion in platforms:
		if absf(point.y - platform.surface_y) \
				<= TraversalEnvelope.MAX_PLANNED_STEP + 0.001 \
				and platform.contains_cell(Vector2(point.x, point.z), yaw):
			return true
	return false
