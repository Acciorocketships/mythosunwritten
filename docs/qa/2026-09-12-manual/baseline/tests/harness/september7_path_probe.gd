extends SceneTree

func _init() -> void:
	var start := Time.get_ticks_msec()
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	print("EVENING_PROFILE compile_ms=", Time.get_ticks_msec()-start)
	var water := TerrainWorldTuning.make_water(2697992464)
	var heightfield := TerrainWorldTuning.make_heightfield(2697992464, water)
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(2697992464, water, fields, program,
		SettlementPlan.new(2697992464, water))
	start = Time.get_ticks_msec()
	var frame := world.frame_for(Vector2i(0,-1))
	print("EVENING_PROFILE frame_ms=", Time.get_ticks_msec()-start)
	start = Time.get_ticks_msec()
	var record := world.village_plan().record_for(frame)
	print("EVENING_PROFILE record_ms=", Time.get_ticks_msec()-start)
	print("EVENING_PROFILE stages=", world.village_plan().stats())
	assert(record != null and not record.is_empty())
	var shapes: Array = []
	for shape: FeatureGroundShape in record.surface_shapes:
		shapes.append({"id":str(shape.stable_id),"kind":shape.kind,"bounds":str(shape.bounds()),"a":str(shape._a),"b":str(shape._b)})
	var paths: Array = []
	for path: Dictionary in record.outskirts.street_paths:
		paths.append({"id":str(path.owner),"points":str(path.points)})
	var data := {"shapes":shapes,"paths":paths,"axis":str(record.street_axis),"centre":str(frame.centre),"canonical_masks":str(frame.path_ground._connection_masks)}
	FileAccess.open(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else "/tmp/september7-paths.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	quit()
