extends SceneTree

func _init() -> void:
	var start := Time.get_ticks_msec()
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	print("ROOF_PROFILE compile_ms=", Time.get_ticks_msec()-start)
	var water := TerrainWorldTuning.make_water(2697992464)
	var heightfield := TerrainWorldTuning.make_heightfield(2697992464, water)
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(2697992464, water, fields, program,
		SettlementPlan.new(2697992464, water))
	start = Time.get_ticks_msec()
	var frame := world.frame_for(Vector2i(1,-3))
	print("ROOF_PROFILE frame_ms=", Time.get_ticks_msec()-start)
	start = Time.get_ticks_msec()
	var record := world.village_plan().record_for(frame)
	print("ROOF_PROFILE record_ms=", Time.get_ticks_msec()-start)
	print("ROOF_PROFILE stages=", world.village_plan().stats())
	assert(record != null and not record.is_empty())
	var urban := record.urban_fabric
	var report := {"frame_cell":str(frame.cell),"transform":str(urban.world_transform), "units":[], "entries":[],
		"rooms":[], "entrances":urban.fabric_plan.surface_plan.entrance_records}
	for building: WarrenBuildingVolume in urban.volumetric_spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			report.rooms.append({"building":str(building.stable_id),"id":str(room.stable_id),
				"origin":str(room.lattice_origin),"kind":str(room.kind),"yaw":room.yaw_quarters,"addressed":room.addressed,
				"bearing":room.terrain_bearing,"support_parent":str(room.support_parent_parcel_id),"support_storey":room.support_parent_storey_index,"private_cells":str(room.private_cells),
				"threshold":str(room.threshold_cell),"frontage":str(room.frontage_direction),"audit":room.audit})
	for unit: FabricUnit in urban.fabric_plan.units:
		report.units.append({"id":str(unit.stable_id),"recipe":str(unit.recipe_id),
			"world":str(urban.world_transform * unit.transform()),"suppressed":unit.suppressed_placement_ids})
	for entry: Dictionary in urban.entries:
		var box: AABB = entry.transform * catalog.descriptor(entry.asset_id).measured_aabb
		report.entries.append({"id":str(entry.stable_id),"asset":str(entry.asset_id),
			"bounds":[box.position.x,box.position.y,box.position.z,box.end.x,box.end.y,box.end.z],
			"transform":str(entry.transform)})
	var source := urban.volumetric_spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var source_fields: Dictionary = {}
	for key in ["passage_kinds","market_zone","market_square_cells","feature_stamps","summit_cell","block_thickness","plots","audit"]: source_fields[key] = source.get(key)
	var excavation: Dictionary = {}
	for key in ["route","lanes","loop_edges","bridge_spans","bridge_span_audit","frontage_reservations","carved","covered","transitions","portals"]: excavation[key] = source.excavation.get(key)
	var frozen := {"world_seed":source.world_seed,"profile":source.scale_profile.scale_id,"massif_columns":source.massif.columns,"massif_core":source.massif.core_top_bands,"massif_form":source.massif.form_id,"massif_open_court":source.massif.open_court,"excavation":excavation,"source":source_fields}
	FileAccess.open("res://docs/qa/2026-09-13-manual/11-roof-joins/P31-current-source.txt",FileAccess.WRITE).store_string(var_to_str(frozen))
	FileAccess.open("res://docs/qa/2026-09-13-manual/11-roof-joins/P31-current-skin.txt",FileAccess.WRITE).store_string(var_to_str(SettlementFabricAssembler.maze_ground_skin_transaction(urban.fabric_plan)))
	var file := FileAccess.open("res://docs/qa/2026-09-13-manual/11-roof-joins/P31-probe-before.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	var payload := SettlementFabricAssembler.payload(urban.fabric_plan)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(urban.fabric_plan))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(urban.fabric_plan.surface_plan,
		SettlementFabricAssembler.maze_module_footprints(urban.fabric_plan),
		SettlementFabricAssembler.maze_skin_panel_boxes_for(urban.fabric_plan),urban.fabric_plan.planned_plaza_cells))
	FileAccess.open("res://docs/qa/2026-09-13-manual/11-roof-joins/P31-before-payload.bin",FileAccess.WRITE).store_var({"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":urban.world_transform,"walked":SettlementFabricAssembler.walked_floor_cells(urban.fabric_plan.surface_plan)})
	quit()
