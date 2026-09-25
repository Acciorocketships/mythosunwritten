extends "res://tests/harness/warren_maze_mode_sweep.gd"

func _run() -> void:
	var prefix := "seed11-" if "--seed11" in OS.get_cmdline_user_args() else ""
	var args := OS.get_cmdline_user_args()
	var before_name := args[args.find("--before") + 1] if "--before" in args else prefix + "before"
	var after_name := args[args.find("--after") + 1] if "--after" in args else prefix + "proposal1"
	var frozen := preload("res://tests/fixtures/september11/floating_payload.gd")
	var before_data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/39-door-panels/before-payload.bin",FileAccess.READ).get_var()
	var after_data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/39-door-panels/after-payload.bin",FileAccess.READ).get_var()
	var original := frozen.payload(before_data,false)
	var payload := frozen.payload(after_data,false)
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	cache.prepare(original.asset_ids())
	cache.prepare(payload.asset_ids())
	var reports := {}
	for after: bool in [false,true]:
		cache = EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
		if not after:
			var frozen_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/39-door-panels/before-assets.json"))
			for asset: String in frozen_assets: cache._visuals[StringName(asset)] = load(frozen_assets[asset])
		cache.prepare(original.asset_ids())
		cache.prepare(payload.asset_ids())
		var stage := Node3D.new()
		root.add_child(stage)
		EnvironmentCollisionBuilder.commit(stage,payload if after else original,cache,&"FloatingClearance")
		await physics_frame
		await physics_frame
		var space := root.world_3d.direct_space_state
		var capsule := CapsuleShape3D.new()
		capsule.radius = PLAYER_CAPSULE_RADIUS
		capsule.height = PLAYER_CAPSULE_HEIGHT
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.margin = CLEARANCE_MARGIN
		var walked: Dictionary = after_data.walked if after else before_data.walked
		var report := {"cells":{},"gates":{}}
		for cell: Vector3i in walked:
			report.cells[str(cell)] = _clearance_of_cell(space,query,cell)
			for direction: Vector3i in [Vector3i.RIGHT,Vector3i.BACK]:
				if walked.has(cell+direction):
					report.gates[_clearance_edge_key(cell,cell+direction)] = _clearance_of_gate(space,query,cell,direction)
		reports["after" if after else "before"] = report
		stage.free()
		await physics_frame
	var output := "res://docs/qa/2026-09-13-manual/39-door-panels/clearance.json"
	if "--output" in args: output = args[args.find("--output") + 1]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	assert(reports.before == reports.after,"The native housing must preserve every actual public clearance result")
	print("DOOR_CLEARANCE cells=",reports.after.cells.size()," gates=",reports.after.gates.size()," identical=",reports.before == reports.after)
	quit()
