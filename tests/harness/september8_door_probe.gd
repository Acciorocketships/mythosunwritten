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
	var report:Dictionary={"placements":[],"shapes":[],"entries":record.outskirts.entries,"streets":record.outskirts.street_paths}
	for placement:VillageMassingPlacement in record.outskirts.placements:
		var values:Dictionary={}
		for property:Dictionary in placement.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:values[property.name]=placement.get(property.name)
		report.placements.append(values)
	for shape:FeatureGroundShape in record.surface_shapes:
		var values:Dictionary={}
		for property:Dictionary in shape.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:values[property.name]=shape.get(property.name)
		report.shapes.append(values)
	FileAccess.open("/tmp/september8-door-source.txt",FileAccess.WRITE).store_string(var_to_str(report))
	FileAccess.open("/tmp/september8-door-source.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
