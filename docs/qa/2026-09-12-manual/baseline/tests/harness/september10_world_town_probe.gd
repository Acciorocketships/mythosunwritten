extends SceneTree
func _init() -> void:
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program, settlements)
	var rows: Array = []
	for super_cell: Vector2i in [Vector2i(0,-1),Vector2i(0,0),Vector2i(1,0)]:
		var frame := world.frame_for(super_cell)
		if frame == null: continue
		var started := Time.get_ticks_msec()
		var record := world.village_plan().record_for(frame)
		var row := {"super_cell":str(super_cell),"cell":str(frame.cell),"tier":record.tier,
			"accepted":record.urban_fabric.accepted,"valid":record.validate(program.villages),
			"reason":record.urban_fabric.reason,"instances":record.payload.instance_count,
			"ms":Time.get_ticks_msec()-started,"audit":record.urban_fabric.fabric_audit}
		rows.append(row)
		print("WORLD_TOWN ",JSON.stringify(row))
	FileAccess.open("res://docs/qa/2026-09-10-manual/15-city-form/world-records.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
