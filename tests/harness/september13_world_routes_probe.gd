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
	var root_path := "res://docs/qa/2026-09-13-manual/36-world-paths"
	var pairs := [[Vector2i(-1,-2),Vector2i(0,-2)],
		[Vector2i(-1,-2),Vector2i(-1,-1)],
		[Vector2i(0,-2),Vector2i(0,-1)],
		[Vector2i(-1,-1),Vector2i(0,-1)]]
	for index in pairs.size():
		var pair: Array = pairs[index]
		print("WORLD_ROUTE_START ",pair)
		var a := paths.node_for(pair[0])
		var b := paths.node_for(pair[1])
		if a.is_empty() or b.is_empty(): continue
		var record := paths._route_record(a.cell,b.cell,paths._pair_key(a,b))
		FileAccess.open(root_path.path_join("route-%d.bin" % index),FileAccess.WRITE).store_var(record)
		var solved := paths._SOLVER.solve(record)
		var row := {"pair":str(pair),"a":a,"b":b,"solved":not solved.is_empty(),
			"cells":record.heights.size(),"edge_cells":record.edges.size()}
		if not solved.is_empty():
			row["variation"] = solved.variation
			row["exact"] = paths._validate_route_exact(solved.edges)
		record.vertical_budget = 128
		var relaxed := paths._SOLVER.solve(record)
		row["range_budget_solved"] = not relaxed.is_empty()
		if not relaxed.is_empty():
			row["range_variation"] = relaxed.variation
			row["range_exact"] = paths._validate_route_exact(relaxed.edges)
		rows.append(row)
		FileAccess.open(root_path.path_join("routes.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
		print("WORLD_ROUTE ",JSON.stringify(row))
	quit()
