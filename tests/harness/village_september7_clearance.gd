extends "res://tests/harness/warren_maze_mode_sweep.gd"

# Paired baseline/candidate survey of the frozen photographed construction.
# Uses the existing conservative corpus capsule, including buildings this time.
func _run() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fixture := "res://tests/fixtures/september8-west-source.txt" \
		if OS.get_cmdline_user_args().has("--west") else "res://tests/fixtures/september7-manual-source.txt"
	var source := frozen.read(fixture)
	if OS.get_cmdline_user_args().has("--current-source"):
		source = WarrenMazeCarver.carve(source.world_seed,source.massif,source.scale_profile,false,false)
		WarrenPlotPlanner.reserve(source,source.scale_profile)
		WarrenPlotPlanner.partition(source,source.scale_profile)
		source.finish_construction(false)
	var spatial := frozen.spatial(source,program)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.terrace_retaining_payload(fabric))
	var cache := EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var stage := Node3D.new()
	root.add_child(stage)
	EnvironmentCollisionBuilder.commit(stage,payload,cache,&"ManualClearance")
	await physics_frame
	await physics_frame
	var space := root.world_3d.direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_CAPSULE_RADIUS
	capsule.height = PLAYER_CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.margin = CLEARANCE_MARGIN
	var walked := SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)
	var report := {"cells":{},"gates":{}}
	for cell: Vector3i in walked:
		report.cells[str(cell)] = _clearance_of_cell(space,query,cell)
		for direction: Vector3i in [Vector3i.RIGHT,Vector3i.BACK]:
			if walked.has(cell+direction): report.gates[_clearance_edge_key(cell,cell+direction)] = _clearance_of_gate(space,query,cell,direction)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if args.size()>0 else "/tmp/september7-clearance.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MANUAL_CLEARANCE cells=",report.cells.size()," gates=",report.gates.size()," output=",output)
	stage.queue_free()
	await process_frame
	quit()
