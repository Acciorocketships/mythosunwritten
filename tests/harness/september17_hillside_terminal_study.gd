extends SceneTree
## Investigation only. Compare terminal hydraulic targets on the actual retained
## receiver. Neither candidate is admitted to the production water plan.
func _initialize() -> void:
	var water := preload("res://tests/fixtures/september17/hillside-order/terrace_order.gd").new(2697992464, TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE, TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var incoming: RiverTrace = water.river_for(Vector2i(-2, -1))
	var receiver: RiverTrace = water._join_target(incoming.points[-1], incoming.beds[-1], water._index_neighbour_rivers(water._neighbour_rivers(incoming.source_cell, water.JOIN_DEPTH)))
	assert(receiver != null)
	var nearest := 0
	for i in receiver.points.size():
		if receiver.points[i].distance_to(incoming.points[-1]) < receiver.points[nearest].distance_to(incoming.points[-1]): nearest = i
	var cell := Vector2i((incoming.points[-1] / 24).floor())
	var region := plan.compute_rect_region(Rect2i(cell - Vector2i.ONE * 4, Vector2i.ONE * 9))
	# Resolve the receiving profile before evaluating any incoming candidate;
	# never perform cross-river lookup under WaterField's profile mutex.
	var receiving_head: float = WaterField.profile(receiver, region).levels[nearest]
	var receiving_point: Vector2 = receiver.points[nearest]
	for mode: String in ["original", "endpoint_target", "connected_target"]:
		var candidate := _copy(incoming)
		if mode == "endpoint_target":
			candidate.beds[-1] = receiving_head - WaterField.SURFACE_RIDE
		elif mode == "connected_target":
			var start: Vector2 = incoming.points[-1]
			var steps := ceili(start.distance_to(receiving_point) / 3.0)
			for step in range(1, steps + 1):
				var t := float(step) / steps
				candidate.points.append(start.lerp(receiving_point, t))
				candidate.beds.append(lerpf(incoming.beds[-1], receiving_head - WaterField.SURFACE_RIDE, t))
				candidate.widths.append(incoming.widths[-1])
		var profile := WaterField.profile(candidate, region)
		var maximum_rise := 0.0
		for i in range(1, candidate.points.size()): maximum_rise = maxf(maximum_rise, profile.levels[i] - profile.levels[i - 1])
		print("TERMINAL_STUDY mode=", mode, " receiver=", receiver.source_cell, " station=", nearest, " extra_stations=", candidate.points.size() - incoming.points.size(), " head_gap=", profile.levels[-1] - receiving_head, " center_gap=", candidate.points[-1].distance_to(receiving_point), " maximum_rise=", maximum_rise)
		for i in range(maxi(0, incoming.points.size() - 3), candidate.points.size()):
			print("TERMINAL_SAMPLE mode=", mode, " point=", candidate.points[i], " head=", profile.levels[i], " ground=", TerrainSurfaceField.surface_y(region, candidate.points[i].x, candidate.points[i].y))
	quit()

func _copy(source: RiverTrace) -> RiverTrace:
	var result := RiverTrace.new()
	result.source_cell = source.source_cell
	result.priority = source.priority
	result.points = source.points.duplicate()
	result.beds = source.beds.duplicate()
	result.widths = source.widths.duplicate()
	result.source_pool = source.source_pool
	result.joined = source.joined
	result.land_bars = source.land_bars.duplicate(true)
	return result
