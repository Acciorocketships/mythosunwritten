extends "res://tests/harness/warren_maze_mode_sweep.gd"

func _run() -> void:
	var prefix := "seed11-" if "--seed11" in OS.get_cmdline_user_args() else ""
	var args := OS.get_cmdline_user_args()
	var before_name := args[args.find("--before") + 1] if "--before" in args else prefix + "before"
	var after_name := args[args.find("--after") + 1] if "--after" in args else prefix + "proposal1"
	var frozen := preload("res://tests/fixtures/september11/floating_payload.gd")
	var before_data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/40-rail-ends/before-payload.bin",FileAccess.READ).get_var()
	var after_data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/40-rail-ends/after-payload.bin",FileAccess.READ).get_var()
	var original := frozen.payload(before_data,false)
	var payload := frozen.payload(after_data,false)
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	cache.prepare(original.asset_ids())
	cache.prepare(payload.asset_ids())
	var reports := {}
	for after: bool in [false,true]:
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
	var output := "res://docs/qa/2026-09-13-manual/40-rail-ends/clearance.json"
	if "--output" in args: output = args[args.find("--output") + 1]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	assert(reports.before.cells == reports.after.cells,"Every public stance stays clear")
	var changed := []
	for gate: String in reports.before.gates:
		if reports.before.gates[gate] != reports.after.gates[gate]: changed.append(gate)
	# This is the photographed exposed side of a descending flight, now guarded.
	# The ordinary upper landing remains the garden entrance (live walking audit).
	assert(changed == ["3,2,6|4,2,6"],"Only the unsafe lateral stair exit may close")
	assert(reports.before.gates[changed[0]] == 0 and reports.after.gates[changed[0]] == -1)
	print("RAIL_CLEARANCE cells=",reports.after.cells.size()," gates=",reports.after.gates.size()," deliberate_side_closures=",changed)
	quit()
