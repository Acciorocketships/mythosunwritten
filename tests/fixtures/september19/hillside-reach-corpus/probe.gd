extends SceneTree
## Broader falsification of the detached reach proposal. No production mutation.
const STUDY = preload("res://tests/fixtures/september19/hillside-retained-network/reach_study.gd")
const TERMINAL_STUDY = preload("res://tests/fixtures/september19/hillside-reach-corpus/terminal_reach_study.gd")
const OUTPUT = "res://docs/qa/2026-09-19-manual/111-hillside-reach-corpus/"

func _initialize() -> void:
	var seed_value := 2697992464
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
	var water := TerrainWorldTuning.make_water(seed_value)
	var terminal := "--terminal" in OS.get_cmdline_user_args()
	var reverse := "--reverse" in OS.get_cmdline_user_args()
	var study = TERMINAL_STUDY.new(water) if terminal else STUDY.new(water)
	var summaries: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	var counts: Dictionary = {}
	var started := Time.get_ticks_msec()
	var axes := range(-6,1)
	if reverse: axes.reverse()
	for z in axes:
		for x in axes:
			var route: Dictionary = study.route(Vector2i(x,z))
			if route.is_empty(): continue
			counts[route.termination] = int(counts.get(route.termination,0)) + 1
			var rises := 0
			var repeated_owners := 0
			var max_drop := 0.0
			var max_radius := 0.0
			var origin := Vector2(route.nodes[0].point[0],route.nodes[0].point[1])
			var seen_owners: Dictionary = {route.source:true}
			for i in route.nodes.size():
				var node: Dictionary = route.nodes[i]
				max_radius = maxf(max_radius, origin.distance_to(Vector2(node.point[0],node.point[1])))
				if i > 0 and float(node.bed) > float(route.nodes[i-1].bed): rises += 1
			for jump: Dictionary in route.jumps:
				max_drop = maxf(max_drop,float(jump.from_bed)-float(jump.to_bed))
				if seen_owners.has(jump.to_owner): repeated_owners += 1
				seen_owners[jump.to_owner] = true
			var summary: Dictionary = route.duplicate()
			summary.erase("nodes")
			summary["nodes"] = route.nodes.size()
			summary["station_hash"] = JSON.stringify(route.nodes).sha256_text()
			summary["rises"] = rises
			summary["repeated_owners"] = repeated_owners
			summary["max_drop"] = max_drop
			summary["max_radius"] = max_radius
			summaries.append(summary)
			if route.termination != "native_terminal" or rises > 0: failures.append(route)
			print("CORPUS ",seed_value," ",route.source," ",route.termination," nodes=",route.nodes.size()," jumps=",route.jumps.size())
	summaries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.source < b.source)
	var result := {"seed":seed_value,"candidate_cells":49,"counts":counts,"routes":summaries,"failures":failures,"elapsed_ms":Time.get_ticks_msec()-started}
	var suffix := ("-terminal" if terminal else "") + ("-reverse" if reverse else "")
	FileAccess.open(OUTPUT+str(seed_value)+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CORPUS_DONE ",seed_value," ",counts," elapsed_ms=",result.elapsed_ms)
	quit()
