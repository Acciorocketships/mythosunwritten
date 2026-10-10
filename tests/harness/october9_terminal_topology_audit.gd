extends SceneTree
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var failed := 0
	for seed_value: int in [2697992464,99]:
		var plan := TerrainWorldTuning.make_water(seed_value)
		var checked := 0
		var corrected := 0
		var roots := 0
		var start := Time.get_ticks_msec()
		for z in range(-2,3):
			for x in range(-2,3):
				var cell := Vector2i(x,z)
				var first := plan._priority_river_for(cell,WaterPlan.JOIN_DEPTH)
				var final := plan.river_for(cell)
				if first == null:
					if final != null: failed += 1
					continue
				checked += 1
				if not first.joined:
					roots += 1
					if not is_same(first,final): failed += 1
				if not is_same(first,final):
					corrected += 1
					if final.points.size() > first.points.size() or final.points.size() < 2: failed += 1
					var receivers := plan._terminal_receivers(first,WaterPlan.JOIN_DEPTH)
					if final.points.size() != first.points.size() and plan._join_target(final.points[-1],first.beds[final.points.size()-1],plan._index_neighbour_rivers(receivers)) == null:
						failed += 1
						print("BAD_ENDPOINT ",cell)
					for i in range(1,final.beds.size()):
						if final.beds[i]>final.beds[i-1]+0.0001: failed += 1
		print("TOPOLOGY_AUDIT seed=%d checked=%d roots=%d corrected=%d failures=%d elapsed_ms=%d" % [seed_value,checked,roots,corrected,failed,Time.get_ticks_msec()-start])
	quit(1 if failed else 0)
