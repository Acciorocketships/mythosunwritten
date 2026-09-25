extends "res://tests/harness/warren_maze_mode_sweep.gd"

func _run() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var seed_value:=VillagePlan.warren_seed_for_cell(2697992464,Vector2i(51,22))
	var spatial:=WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.select(seed_value))
	assert(spatial!=null,WarrenVolumetricSolver.last_failure)
	var fabric:=spatial.compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,
		SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	payload.append_from(SettlementFabricAssembler.low_retaining_payload(fabric))
	payload.append_from(SettlementFabricAssembler.terrace_retaining_payload(fabric,false))
	var stage:=Node3D.new()
	root.add_child(stage)
	var cache:=EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	EnvironmentCollisionBuilder.commit(stage,payload,cache,&"NativeOnlyClearance")
	await physics_frame
	await physics_frame
	var capsule:=CapsuleShape3D.new()
	capsule.radius=PLAYER_CAPSULE_RADIUS
	capsule.height=PLAYER_CAPSULE_HEIGHT
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.margin=CLEARANCE_MARGIN
	var space:=root.world_3d.direct_space_state
	var walked:=SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)
	var report:={"cells":{},"gates":{}}
	for cell:Vector3i in walked:
		report.cells[str(cell)]=_clearance_of_cell(space,query,cell)
		for direction:Vector3i in CLEARANCE_ROUTE_STEPS:
			if walked.has(cell+direction):
				report.gates[_clearance_edge_key(cell,cell+direction)]=_clearance_of_gate(space,query,cell,direction)
	FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/native-only-clearance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for kind:String in report:
		for key:String in report[kind]: assert(report[kind][key]==0,"Blocked public position: "+key)
	print("NATIVE_ONLY_CLEARANCE cells=",report.cells.size()," crossings=",report.gates.size())
	quit()
