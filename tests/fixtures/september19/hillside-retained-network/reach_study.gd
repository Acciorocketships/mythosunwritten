extends RefCounted
## Detached experiment: flow joins a downstream reach, not another source's
## retained prefix. Nothing in production loads this class.
var water: WaterPlan
var indexes: Dictionary = {}

func _init(plan: WaterPlan) -> void:
	water = plan

func route(source: Vector2i) -> Dictionary:
	var raw := water.river_for(source, 0)
	if raw == null: return {}
	var owner := source
	var station := 0
	var visited: Dictionary = {}
	var nodes: Array[Dictionary] = []
	var jumps: Array[Dictionary] = []
	var distance := 0.0
	var previous := raw.points[0]
	var reason := "station_budget"
	# Same finite station budget as a source trace; report exhaustion instead
	# of pretending an arbitrary cutoff is a valid terminal pond.
	for step in water.MAX_STEPS:
		var key := Vector3i(owner.x, owner.y, station)
		assert(not visited.has(key), "A descending reach path cannot cycle")
		visited[key] = true
		var current := water.river_for(owner, 0)
		var point: Vector2 = current.points[station]
		var bed: float = current.beds[station]
		# A composed route can turn beyond the raw trace's source-centred
		# radius. Keep the existing maximum river arc budget instead. Any
		# production adapter would need this larger bound in source discovery.
		var segment := previous.distance_to(point)
		if distance + segment > water.MAX_STEPS * water.TRACE_STEP:
			reason = "arc_budget"
			break
		distance += segment
		previous = point
		nodes.append({"owner": str(owner), "station": station, "point": [point.x, point.y], "bed": bed})
		var next := _target(current, station)
		if not next.is_empty():
			jumps.append({"from_owner": str(owner), "from_station": station,
				"to_owner": str(next.owner), "to_station": next.station,
				"from_bed": bed, "to_bed": next.bed})
			owner = next.owner
			station = next.station
		elif station + 1 < current.points.size():
			station += 1
		else:
			reason = "native_terminal"
			break
	return {"source": str(source), "nodes": nodes, "jumps": jumps,
		"termination": reason, "arc": distance,
		"terminal_owner": str(owner), "terminal_station": station}

func _target(current: RiverTrace, station: int) -> Dictionary:
	var index := _index(current)
	var p: Vector2 = current.points[station]
	var bed: float = current.beds[station]
	var result: Dictionary = {}
	var selected_bed := INF
	var selected_distance := INF
	for entry: Vector3i in water._nearby_neighbour_points(index, p, water.ALLUVIAL_HALF_WIDTH):
		var other: RiverTrace = index.rivers[entry.x]
		var other_bed: float = other.beds[entry.y]
		# Strict descent, with one stable precedence for exactly equal levels.
		if other_bed > bed: continue
		if other_bed == bed and other.priority <= current.priority: continue
		var d := p.distance_squared_to(other.points[entry.y])
		if d > float(other.widths[entry.y]) * float(other.widths[entry.y]): continue
		if other_bed > selected_bed or (other_bed == selected_bed and d >= selected_distance): continue
		selected_bed = other_bed
		selected_distance = d
		result = {"owner": other.source_cell, "station": entry.y, "bed": other_bed}
	return result

func _index(current: RiverTrace) -> Dictionary:
	if indexes.has(current.source_cell): return indexes[current.source_cell]
	var others: Array = []
	var bounds := water._bounds_for(current).grow(water.SENSE_RADIUS + water.W_MAX)
	for z in range(-water.REACH_SUPERS * 2, water.REACH_SUPERS * 2 + 1):
		for x in range(-water.REACH_SUPERS * 2, water.REACH_SUPERS * 2 + 1):
			var cell := current.source_cell + Vector2i(x, z)
			if cell == current.source_cell: continue
			var raw := water.river_for(cell, 0)
			if raw != null and water._bounds_for(raw).intersects(bounds): others.append(raw)
	var index := water._index_neighbour_rivers(others)
	indexes[current.source_cell] = index
	return index
