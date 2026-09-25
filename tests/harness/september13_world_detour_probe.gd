extends SceneTree

func _init() -> void:
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var paths := preload("res://tests/fixtures/september13/DetourPathProbe.gd").new(seed_value, water, fields, program.paths,
		program.query_margin, settlements, program.surface_priorities)
	var rows: Array = []
	var root_path := "res://docs/qa/2026-09-13-manual/36-world-paths"
	var pairs := [[Vector2i(-1,-1),Vector2i(0,-1)]]
	for index in pairs.size():
		var pair: Array = pairs[index]
		print("WORLD_ROUTE_START ",pair)
		var a := paths.node_for(pair[0])
		var b := paths.node_for(pair[1])
		if a.is_empty() or b.is_empty(): continue
		var record := paths._route_record(a.cell,b.cell,paths._pair_key(a,b))
		FileAccess.open(root_path.path_join("detour-%d.bin" % index),FileAccess.WRITE).store_var(record)
		var pending: Array[int] = [int(record.start)]
		var previous := {int(record.start):-1}
		while not pending.is_empty():
			var cell: int = pending.pop_front()
			if cell == int(record.goal): break
			for edge: Dictionary in record.edges.get(cell,[]):
				if previous.has(int(edge.to)): continue
				previous[int(edge.to)] = cell
				pending.append(int(edge.to))
		var points := []
		var cursor := int(record.goal)
		if previous.has(cursor):
			while cursor >= 0:
				points.push_front(record.cells[cursor])
				cursor = int(previous[cursor])
		var row := {"pair":str(pair),"reachable":previous.size(),"found":previous.has(int(record.goal)),"points":points}
		FileAccess.open(root_path.path_join("detour.json"),FileAccess.WRITE).store_string(JSON.stringify(row,"  "))
		print("DETOUR ",JSON.stringify(row))
	quit()
