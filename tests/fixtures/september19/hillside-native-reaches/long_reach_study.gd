extends "res://tests/fixtures/september19/hillside-reach-corpus/terminal_reach_study.gd"
## Diagnostic wider network budget; not a proof for all source chains.
const ROUTE_STATIONS := WaterPlan.MAX_STEPS*2

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
	# A composed network may include two raw river arcs. Exhaustion stays
	# an explicit study rejection, never a fabricated pond.
	for step in ROUTE_STATIONS:
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
		if distance + segment > ROUTE_STATIONS * water.TRACE_STEP:
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
