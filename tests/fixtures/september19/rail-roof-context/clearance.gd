extends "res://tests/harness/warren_maze_mode_sweep.gd"

func _run() -> void:
	var prefix := "seed11-" if "--seed11" in OS.get_cmdline_user_args() else ""
	var args := OS.get_cmdline_user_args()
	var before_name := args[args.find("--before") + 1] if "--before" in args else prefix + "before"
	var after_name := args[args.find("--after") + 1] if "--after" in args else prefix + "proposal1"
	var frozen := preload("res://tests/fixtures/september11/floating_payload.gd")
	var before_data: Dictionary = FileAccess.open("res://docs/qa/2026-09-19-manual/108-rail-roof-context/payload.bin",FileAccess.READ).get_var()
	var after_data: Dictionary = FileAccess.open("res://docs/qa/2026-09-19-manual/108-rail-roof-context/after/payload.bin",FileAccess.READ).get_var()
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
		# EnvironmentCollisionBuilder owns native stock and boxes. Production's
		# feature queue also commits the generated stair/rail triangle surfaces.
		var surfaces := StaticBody3D.new()
		stage.add_child(surfaces)
		var active_payload := payload if after else original
		for mesh: Dictionary in active_payload.surface_meshes:
			if bool(mesh.get("visual_only", false)): continue
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(mesh.collision_faces as PackedVector3Array)
			var shape_node := CollisionShape3D.new()
			shape_node.name = String(mesh.stable_id).replace("/", "_").replace(".", "_")
			shape_node.shape = shape
			surfaces.add_child(shape_node)
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
		report["mouths"] = {}
		for cell: Vector3i in [Vector3i(-4,4,8),Vector3i(-3,4,8)]:
			report.mouths[str(cell)] = _clearance_of_gate(space,query,cell,Vector3i.FORWARD)
			query.transform = Transform3D(Basis.IDENTITY,_clearance_stance(cell)+Vector3.FORWARD*.75)
			for hit: Dictionary in space.intersect_shape(query,16):
				var body := hit.collider as CollisionObject3D
				var owner := body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) as CollisionShape3D
				print("MOUTH_HIT ",after," ",cell," ",owner.name," ",owner.transform)
		report["door_sweeps"] = []
		for offset: float in [-.18,0.0,.18]:
			for direction: float in [-1.0,1.0]:
				var origin := _clearance_stance(Vector3i(-4,4,8)) + Vector3(offset,0,-.75-direction*.75)
				query.transform = Transform3D(Basis.IDENTITY,origin)
				query.motion = Vector3(0,0,direction*1.5)
				var fraction := space.cast_motion(query)
				report.door_sweeps.append({"offset":offset,"direction":direction,"fraction":fraction[0]})
		query.motion=Vector3.ZERO
		report["bridge_sweeps"] = []
		# Exercise the complete retained crossing, including both terminal joins.
		for start: Vector3i in [Vector3i(-9,4,2),Vector3i(-4,4,5),Vector3i(0,5,5),Vector3i(1,5,5)]:
			var step := Vector3.RIGHT if start.x == -9 else Vector3.BACK
			for direction: float in [-1.0,1.0]:
				query.transform = Transform3D(Basis.IDENTITY,_clearance_stance(start)+step*(4.5 if direction<0 else 0.0))
				query.motion = step*4.5*direction
				var fraction := space.cast_motion(query)
				report.bridge_sweeps.append({"start":str(start),"direction":direction,"fraction":fraction[0]})
		query.motion=Vector3.ZERO
		report["roof_side_rails"] = []
		for z: float in [9.9, 10.2, 10.5, 10.8, 11.1]:
			var floor_y := 9.0 - (z - 8.25) * .5
			for height: float in [.52, 1.0]:
				var point := Vector3(5.25, floor_y + WarrenTransitionSurfaceBuilder.GUARD_HEIGHT * height, z)
				var ray := PhysicsRayQueryParameters3D.create(point-Vector3(.2,0,0),point+Vector3(.2,0,0))
				report.roof_side_rails.append(not space.intersect_ray(ray).is_empty())
		var post_ray := PhysicsRayQueryParameters3D.create(Vector3(5.05,8,11.25),Vector3(5.45,8,11.25))
		report.roof_side_rails.append(not space.intersect_ray(post_ray).is_empty())
		reports["after" if after else "before"] = report
		stage.free()
		await physics_frame
	var output := "res://docs/qa/2026-09-19-manual/108-rail-roof-context/complete-collision.json"
	if "--output" in args: output = args[args.find("--output") + 1]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	assert(reports.before.cells == reports.after.cells)
	assert(reports.before.gates == reports.after.gates)
	print("PUBLIC_CLEARANCE cells=",reports.after.cells.size()," gates=",reports.after.gates.size()," unchanged=true")
	print("MOUTHS before=",reports.before.mouths," after=",reports.after.mouths)
	print("DOOR_SWEEPS before=",reports.before.door_sweeps," after=",reports.after.door_sweeps)
	# The complete surface set exposes an existing floor contact at this old
	# lattice stance. Preserve it as a regression control, not a clear passage.
	assert(reports.before.mouths["(-4, 4, 8)"] == -1 and reports.after.mouths["(-4, 4, 8)"] == -1)
	assert(reports.before.mouths["(-3, 4, 8)"] == -1 and reports.after.mouths["(-3, 4, 8)"] == -1)
	for sweep: Dictionary in reports.after.door_sweeps: assert(sweep.fraction == 1.0)
	print("BRIDGE_SWEEPS before=",reports.before.bridge_sweeps," after=",reports.after.bridge_sweeps)
	# A long flat cast encounters existing endpoint trim; it is recorded as a
	# regression control, not proof of character step traversal.
	assert(reports.before.bridge_sweeps == reports.after.bridge_sweeps)
	assert(reports.before.roof_side_rails.count(false) == 11)
	assert(reports.after.roof_side_rails.count(true) == 11)
	print("ROOF_SIDE_RAILS before=", reports.before.roof_side_rails, " after=", reports.after.roof_side_rails)
	quit()
