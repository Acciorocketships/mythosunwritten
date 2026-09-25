extends SceneTree

func _init() -> void:
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var paths := PathPlan.new(seed_value, water, fields, program.paths,
		program.query_margin, settlements, program.surface_priorities)
	var rows: Array = []
	var output := "res://docs/qa/2026-09-13-manual/36-world-paths/nodes.json"
	for z in range(-2, 2):
		for x in range(-2, 2):
			var sc := Vector2i(x,z)
			var site := settlements.site_for(sc)
			var row := {"super":str(sc),"site":site}
			if not site.is_empty():
				var low := INF
				var high := -INF
				for point: Vector2 in paths._node_support_samples(site.cell):
					var h := paths._ground(point)
					low = minf(low,h)
					high = maxf(high,h)
				row["support_span"] = high-low
				row["node"] = paths.node_for(sc)
			rows.append(row)
			FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
			print("WORLD_PATH_NODE ",JSON.stringify(row))
	quit()
