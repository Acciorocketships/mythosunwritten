extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[args.find("--phase")+1]
	var rows: Array[Dictionary] = []
	for seed_value: int in [991177,2697992464,314159]:
		var water := TerrainWorldTuning.make_water(seed_value)
		var count := 0
		var minimum := INF
		for z in range(-4,5):
			for x in range(-4,5):
				if water.has_source(Vector2i(x,z)):
					count += 1
					minimum = minf(minimum,water.smooth_h(water.source_pos(Vector2i(x,z))))
		rows.append({"seed":seed_value,"sources":count,"minimum_height":minimum})
	print(JSON.stringify(rows,"  "))
	FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/"+phase+"-sources.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
