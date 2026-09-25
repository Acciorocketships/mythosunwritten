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
	var grade := record.urban_fabric.terrain_grade
	var data := {"claims":grade._claims,"origin":grade._origin,"pitch":grade._targets.pitch}
	FileAccess.open("res://tests/fixtures/september7-grade-source.txt",FileAccess.WRITE).store_string(var_to_str(data))
	for z in range(5,14):
		var row := []
		for x in range(1,14): row.append(grade._claims.get(Vector2i(x,z),null))
		print("FINAL_CLAIMS z=",z," worldz=",-365.5+z*3," x=241.5..277.5 ",row)
	quit()
