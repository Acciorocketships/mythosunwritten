extends SceneTree
func _init()->void:call_deferred("_run")
func _run()->void:
	var seed_value := 2697992464
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value,water)
	var fields := WorldFieldBlockCache.new(heights,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
	var features := WorldFeaturePlan.new(seed_value,water,fields,program,SettlementPlan.new(seed_value,water))
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(seed_value)
	mesher.profile_enabled=true
	var cache := EnvironmentRenderCache.new(catalog)
	var assets: Array[StringName]=[]
	assets.assign(CliffDressing.ASSETS.values())
	cache.prepare(assets)
	CliffDressing.prepare(cache)
	mesher.prepare_resources()
	var results: Array=[]
	for chunk in [Vector2i(5,2),Vector2i(6,2),Vector2i(9,2),Vector2i(10,2)]:
		print("STREAM_PROFILE begin=",chunk)
		var start := Time.get_ticks_usec()
		var context := features.context_for(chunk)
		var context_ms := (Time.get_ticks_usec()-start)/1000.0
		var region := context.graded_region(fields.region(chunk))
		var wet := fields.water(chunk)
		start=Time.get_ticks_usec()
		var payload := mesher.compute_chunk(chunk,region,wet,context)
		var mesh_ms := (Time.get_ticks_usec()-start)/1000.0
		var sum_profile := 0.0
		for key in ["surface","normals","aprons_and_walls"]:sum_profile+=float(payload.profile[key])/1000
		var hashes: Dictionary={}
		for key in ["surface_arrays","collision_faces","apron_arrays","wall_arrays","wall_collision_arrays","cliffs","graded_cliff_arrays"]:
			hashes[key]=var_to_bytes(payload[key]).hex_encode().sha256_text()
		var row := {"chunk":str(chunk),"context_ms":context_ms,"mesh_ms":mesh_ms,"unprofiled_ms":mesh_ms-sum_profile,"profile_usec":payload.profile,"counts":payload.profile_counts,"hashes":hashes}
		results.append(row)
		print("STREAM_PROFILE ",JSON.stringify(row))
		FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit()
