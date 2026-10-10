extends SceneTree
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var failures := 0
	for seed_value: int in [2697992464,99]:
		var plan := TerrainWorldTuning.make_water(seed_value)
		var checked := 0
		for z in range(-3,4):
			for x in range(-3,4):
				var river := plan.river_for(Vector2i(x,z))
				if river == null or not river.joined: continue
				var others: Array = plan._neighbour_rivers(river.source_cell,WaterPlan.JOIN_DEPTH)
				others.append_array(plan._terminal_receivers(river,WaterPlan.JOIN_DEPTH))
				var final: Array = []
				for other: RiverTrace in others:
					var realized := plan.river_for(other.source_cell)
					if realized != null: final.append(realized)
				checked += 1
				if plan._join_target(river.points[-1],river.beds[-1],plan._index_neighbour_rivers(final)) == null:
					failures += 1
					print("STRANDED_JOIN seed=",seed_value," source=",river.source_cell," tail=",river.points[-1]," bed=",river.beds[-1])
		print("DEPENDENCY_AUDIT seed=",seed_value," checked=",checked," failures=",failures)
	quit(1 if failures else 0)
