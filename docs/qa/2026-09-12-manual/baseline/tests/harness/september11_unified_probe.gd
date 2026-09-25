extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var args := OS.get_cmdline_user_args()
	var original := frozen.read("res://tests/fixtures/september11-floating-source.txt")
	var profile := WarrenVillageScaleProfile.for_id(original.scale_profile.scale_id)
	if "--extra" in OS.get_cmdline_user_args(): profile.landmark_range += Vector2i.ONE
	var seed_value := int(args[args.find("--seed")+1]) if "--seed" in args else original.world_seed
	profile.landmark_range = Vector2i(5,6)
	profile.lane_budget = 5
	profile.lane_cell_budget = 20
	var massif := preload("res://tests/harness/september11_unified_source_experiment.gd").SourceField.experiment(seed_value,{},profile)
	var source := WarrenMazeCarver.carve(seed_value,massif,profile,false)
	WarrenPlotPlanner.reserve(source,profile)
	WarrenPlotPlanner.partition(source,profile)
	source.finish_construction()
	assert(source != null,WarrenMazeSitePlanner.last_failure)
	var spatial := frozen.spatial(source,program)
	var plan := spatial.compiled_fabric_cache()
	var rooms: Array[Dictionary] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			rooms.append({"id": room.stable_id, "kind": room.kind,
				"origin": str(room.lattice_origin), "storey": room.source_storey_index,
				"roof_feature": room.roof_feature, "audit": room.audit})
	var features: Array[Dictionary] = []
	for feature: WarrenFeatureReservation in spatial.features:
		features.append({"id": feature.stable_id, "kind": feature.kind, "audit": feature.audit})
	var units: Array[Dictionary] = []
	for unit: FabricUnit in plan.units:
		units.append({"id": unit.stable_id, "recipe": unit.recipe_id})
	var report := {"rooms": rooms, "features": features, "units": units,
		"spatial_audit": spatial.audit, "fabric_audit": plan.audit,
		"source_outcomes": source.audit.get("plot_outcomes",{}),
		"feature_audit": WarrenSpatialFeatureSolver.last_audit,
		"balcony_diagnostic": WarrenSpatialFeatureSolver.last_skywalk_diagnostic,
		"corner_room_conflicts": WarrenSpatialFeatureSolver.last_corner_room_conflicts}
	var output := args[args.find("--output") + 1]
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	if "--payload" in args:
		var payload := SettlementFabricAssembler.payload(plan)
		payload.append_from(SettlementFabricAssembler.structural_support_payload(plan))
		payload.append_from(SettlementFabricAssembler.production_surface_bundle(plan.surface_plan,
			SettlementFabricAssembler.maze_module_footprints(plan),
			SettlementFabricAssembler.maze_skin_panel_boxes_for(plan),plan.planned_plaza_cells))
		var data := {"batches":payload.batches,"collision_boxes":payload.collision_boxes,
			"surface_meshes":payload.surface_meshes,"rooms":rooms,
			"walked":SettlementFabricAssembler.walked_floor_cells(plan.surface_plan),
			"skin":SettlementFabricAssembler.maze_ground_skin_transaction(plan)}
		FileAccess.open(args[args.find("--payload")+1],FileAccess.WRITE).store_var(data)
	print("UNIFIED_PROBE ", output)
	quit()
