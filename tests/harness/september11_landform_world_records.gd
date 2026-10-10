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
	for super_cell: Vector2i in [Vector2i(-1,-1),Vector2i(-3,-2),Vector2i(0,-1),Vector2i(0,0),Vector2i(1,0)]:
		var frame := world.frame_for(super_cell)
		if frame == null:
			rows.append({"super_cell":str(super_cell),"absent":true})
			continue
		var started := Time.get_ticks_msec()
		var record := world.village_plan().record_for(frame)
		var row := {"super_cell":str(super_cell),"cell":str(frame.cell),"tier":record.tier,
			"accepted":record.urban_fabric.accepted,"valid":record.validate(program.villages),
			"reason":record.urban_fabric.reason,
			"building_count":record.urban_fabric.buildings.size(),"world_transform":str(record.urban_fabric.world_transform),"instances":record.payload.instance_count,
			"ms":Time.get_ticks_msec()-started,"audit":record.urban_fabric.fabric_audit}
		rows.append(row)
		FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/world-records.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
		print("WORLD_TOWN ", row.cell, " ",row.tier," accepted=",row.accepted," valid=",row.valid)
	FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/world-records.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
