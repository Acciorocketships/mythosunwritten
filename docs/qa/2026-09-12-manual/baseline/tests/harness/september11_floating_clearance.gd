extends "res://tests/harness/warren_maze_mode_sweep.gd"

func _run() -> void:
	var frozen := preload("res://tests/fixtures/september11/floating_payload.gd")
	var before_data := frozen.read(true)
	var after_data := frozen.read(false)
	assert(before_data.walked == after_data.walked, "The composition repair retains the canonical walking field")
	var original := frozen.payload(before_data,true)
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
		var walked: Dictionary = after_data.walked
		var report := {"cells":{},"gates":{}}
		for cell: Vector3i in walked:
			report.cells[str(cell)] = _clearance_of_cell(space,query,cell)
			for direction: Vector3i in [Vector3i.RIGHT,Vector3i.BACK]:
				if walked.has(cell+direction):
					report.gates[_clearance_edge_key(cell,cell+direction)] = _clearance_of_gate(space,query,cell,direction)
		reports["after" if after else "before"] = report
		stage.free()
		await physics_frame
	var output := "res://docs/qa/2026-09-11-manual/05-floating/composition-clearance.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	assert(reports.before == reports.after,"Native supports must retain every public stance and crossing")
	print("FLOATING_CLEARANCE cells=",reports.after.cells.size()," gates=",reports.after.gates.size()," identical=true")
	quit()
