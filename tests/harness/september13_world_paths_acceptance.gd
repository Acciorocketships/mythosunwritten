extends SceneTree
func _init() -> void:
	var root_path := "res://docs/qa/2026-09-13-manual/36-world-paths/after"
	var args := OS.get_cmdline_user_args()
	if args.has("--output"):
		root_path = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(root_path)
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value,water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
	var paths := PathPlan.new(seed_value,water,fields,program.paths,program.query_margin,SettlementPlan.new(seed_value,water),program.surface_priorities)
	var rows: Array = []
	var pairs := [[Vector2i(-1,-2),Vector2i(-1,-1)],[Vector2i(-1,-1),Vector2i(0,-1)],
		[Vector2i(-1,-2),Vector2i(0,-2)],[Vector2i(0,-2),Vector2i(0,-1)]]
	for index in pairs.size():
		var pair: Array = pairs[index]
		var started := Time.get_ticks_msec()
		print("ACCEPT_ROUTE_START ",pair)
		var a := paths.node_for(pair[0])
		var b := paths.node_for(pair[1])
		var route := paths.route_for(a,b)
		FileAccess.open(root_path.path_join("route-%d.bin"%index),FileAccess.WRITE).store_var(route)
		var row := {"pair":str(pair),"route":route,"elapsed_ms":Time.get_ticks_msec()-started}
		rows.append(row)
		FileAccess.open(root_path.path_join("routes.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
		print("ACCEPT_ROUTE ",index," count=",route.get("connections",[]).size()," ms=",row.elapsed_ms)
	for sc:Vector2i in [Vector2i(-1,-2),Vector2i(-1,-1),Vector2i(0,-1)]:
		print("ACCEPT_GATE_START ",sc)
		var node := paths.node_for(sc)
		var mask := paths.accepted_mask_for_node(sc)
		var context := paths.context_for(WorldFieldBlockCache.key_of(Vector2(node.cell)*HeightfieldPlan.CELL))
		var row := {"gate":str(sc),"node":node,"accepted":mask,"projected":context.connection_masks.get(node.cell,0),"stats":paths.stats()}
		rows.append(row)
		FileAccess.open(root_path.path_join("routes.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
		print("ACCEPT_GATE ",JSON.stringify(row))
	quit()
