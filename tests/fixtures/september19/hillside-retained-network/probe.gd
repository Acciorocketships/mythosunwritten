extends SceneTree
## Read-only survey of the shipped network. No alternate routing or carving.
const OUTPUT := "res://docs/qa/2026-09-19-manual/110-hillside-retained-network"

func _initialize() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var cells: Array[Vector2i] = []
	for z in range(-3, 0):
		for x in range(-4, -1): cells.append(Vector2i(x, z))
	cells.append(Vector2i(-3, -4))
	if "--reverse" in OS.get_cmdline_user_args(): cells.reverse()
	var rows: Array[Dictionary] = []
	for cell: Vector2i in cells:
		var incoming := water.river_for(cell)
		if incoming == null: continue
		var bounds := water._bounds_for(incoming).grow(water.SENSE_RADIUS + water.W_MAX)
		var others: Array = []
		for z in range(-water.REACH_SUPERS * 2, water.REACH_SUPERS * 2 + 1):
			for x in range(-water.REACH_SUPERS * 2, water.REACH_SUPERS * 2 + 1):
				var other_cell := cell + Vector2i(x, z)
				if other_cell == cell: continue
				var raw := water.river_for(other_cell, 0)
				if raw == null or not water._bounds_for(raw).intersects(bounds): continue
				others.append(water.river_for(other_cell))
		var index := water._index_neighbour_rivers(others)
		var first := -1
		var target: RiverTrace
		for station in incoming.points.size():
			target = water._join_target(incoming.points[station], incoming.beds[station], index)
			if target != null:
				first = station
				break
		var old_index := water._index_neighbour_rivers(water._neighbour_rivers(cell, water.JOIN_DEPTH))
		var old_receiver := water._join_target(incoming.points[-1], incoming.beds[-1], old_index) if incoming.joined else null
		var retained_receiver: RiverTrace
		var old_contact_retained := false
		if old_receiver != null:
			retained_receiver = water.river_for(old_receiver.source_cell)
			old_contact_retained = water._join_target(incoming.points[-1], incoming.beds[-1], water._index_neighbour_rivers([retained_receiver])) != null
		var row := {"source": str(cell), "count": incoming.points.size(), "joined": incoming.joined,
			"first_retained_contact": first, "receiver": str(target.source_cell) if target != null else "none",
			"receiver_count": target.points.size() if target != null else 0,
			"excluded_by_priority": target != null and target.priority <= incoming.priority,
			"old_receiver": str(old_receiver.source_cell) if old_receiver != null else "none",
			"old_receiver_count_at_depth_one": old_receiver.points.size() if old_receiver != null else 0,
			"old_receiver_count_at_depth_two": retained_receiver.points.size() if retained_receiver != null else 0,
			"old_contact_retained": old_contact_retained}
		if target != null:
			var nearest := -1
			var distance := INF
			for j in target.points.size():
				var d := incoming.points[first].distance_to(target.points[j])
				if d < distance:
					distance = d
					nearest = j
			row.merge({"position": str(incoming.points[first]), "incoming_bed": incoming.beds[first],
				"receiver_station": nearest, "receiver_bed": target.beds[nearest],
				"distance": distance, "receiver_half_width": target.widths[nearest]})
		rows.append(row)
		print("RETAINED_CONTACT ", JSON.stringify(row))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.source < b.source)
	var suffix := "reverse" if "--reverse" in OS.get_cmdline_user_args() else "forward"
	FileAccess.open(OUTPUT.path_join(suffix + ".json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit()
