extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := preload("res://tests/fixtures/frozen_maze_source.gd").read("res://tests/fixtures/september11-unified-roof-source.txt") if "--frozen" in OS.get_cmdline_user_args() else WarrenMazeSitePlanner.plan(8, {}, WarrenVillageScaleProfile.for_id(&"grand"))
	if "--freeze-only" in OS.get_cmdline_user_args():
		var source_fields: Dictionary = {}
		for key in ["passage_kinds","market_zone","market_square_cells","feature_stamps","summit_cell","block_thickness","plots","audit"]: source_fields[key] = source.get(key)
		var excavation: Dictionary = {}
		for key in ["route","lanes","loop_edges","bridge_spans","bridge_span_audit","frontage_reservations","carved","covered","transitions","portals"]: excavation[key] = source.excavation.get(key)
		var frozen := {"world_seed":source.world_seed,"profile":source.scale_profile.scale_id,"massif_columns":source.massif.columns,"massif_core":source.massif.core_top_bands,"excavation":excavation,"source":source_fields}
		FileAccess.open("res://tests/fixtures/september11-unified-roof-source.txt",FileAccess.WRITE).store_string(var_to_str(frozen))
		quit()
		return
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	var spatial := WarrenVolumetricSolver.from_volume(volume, -1, program, false, true)
	FileAccess.open("res://docs/qa/2026-09-11-manual/10-unified-city/roof-case-source.txt", FileAccess.WRITE).store_string(var_to_str(source.plots))
	print("ROOF_SPATIAL ", spatial != null, " ", WarrenVolumetricSolver.last_failure)
	if spatial != null and "--domains" in OS.get_cmdline_user_args():
		var rooms: Array[WarrenRoomStamp] = []
		var owners: Dictionary = {}
		for building: WarrenBuildingVolume in spatial.buildings:
			for room: WarrenRoomStamp in building.room_records:
				rooms.append(room)
				for cell: Vector3i in room.private_cells: owners[cell] = room.stable_id
		var domains := WarrenSpatialFabricCompiler._required_roof_clearance(spatial,program,rooms,owners)
		for domain: Dictionary in domains:
			if domain.owner_room_id in [&"spatial.residual.01.room00",&"spatial.maze_back.01.room00"]: print("DOMAIN ",domain)
		var candidate := FabricUnit.new(&"spatial.roof.spatial.maze_back.01.room00",&"roof.row.orange.dormer.left",Vector3i(10,2,-14),3)
		print("DIRECT_DOMAIN_CONFLICT ",WarrenSpatialFabricCompiler._roof_candidate_required_closure_conflict(candidate,program.recipe(candidate.recipe_id),&"spatial.maze_back.01.room00",domains,{&"spatial.residual.01.room00":true},program))
	WarrenSpatialFabricCompiler.diagnostic_trace_timing = "--domains" in OS.get_cmdline_user_args()
	var fabric := WarrenSpatialFabricCompiler.generate(spatial, program, true) if spatial != null else null
	print("ROOF_FABRIC ", fabric != null, " ", WarrenSpatialFabricCompiler.last_failure)
	FileAccess.open("res://docs/qa/2026-09-11-manual/10-unified-city/roof-case-audit.json", FileAccess.WRITE).store_string(JSON.stringify(WarrenSpatialFabricCompiler.last_audit, "  "))
	quit()
