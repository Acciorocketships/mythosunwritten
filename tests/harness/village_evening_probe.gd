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
	var frame := world.frame_for(Vector2i.ZERO)
	print("EVENING_PROFILE frame_ms=", Time.get_ticks_msec()-start)
	start = Time.get_ticks_msec()
	var record := world.village_plan().record_for(frame)
	print("EVENING_PROFILE record_ms=", Time.get_ticks_msec()-start)
	print("EVENING_PROFILE stages=", world.village_plan().stats())
	assert(record != null and not record.is_empty())
	var urban := record.urban_fabric
	var report := {"transform":str(urban.world_transform), "units":[], "entries":[],
		"rooms":[], "entrances":urban.fabric_plan.surface_plan.entrance_records}
	for building: WarrenBuildingVolume in urban.volumetric_spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			report.rooms.append({"building":str(building.stable_id),"id":str(room.stable_id),
				"origin":str(room.lattice_origin),"yaw":room.yaw_quarters,"addressed":room.addressed,
				"threshold":str(room.threshold_cell),"frontage":str(room.frontage_direction)})
	for unit: FabricUnit in urban.fabric_plan.units:
		report.units.append({"id":str(unit.stable_id),"recipe":str(unit.recipe_id),
			"world":str(urban.world_transform * unit.transform()),"suppressed":unit.suppressed_placement_ids})
	for entry: Dictionary in urban.entries:
		var box: AABB = entry.transform * catalog.descriptor(entry.asset_id).measured_aabb
		report.entries.append({"id":str(entry.stable_id),"asset":str(entry.asset_id),
			"bounds":[box.position.x,box.position.y,box.position.z,box.end.x,box.end.y,box.end.z],
			"transform":str(entry.transform)})
	var file := FileAccess.open("/tmp/village-evening-probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	quit()
