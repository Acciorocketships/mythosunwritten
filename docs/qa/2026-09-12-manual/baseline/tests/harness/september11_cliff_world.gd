extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1920,1080)
	var directory := "res://docs/qa/2026-09-11-manual/11-cliffs/"
	var world := (load(directory+"final-live/village.scn") as PackedScene).instantiate()
	for key: StringName in world.get_meta("shader_globals"):
		RenderingServer.global_shader_parameter_set(key,world.get_meta("shader_globals")[key])
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var candidates: Array[Vector3] = []
	var natives: Array[GeometryInstance3D] = []
	for node: Node in world.get_children():
		if node is MultiMeshInstance3D and (String(node.name).begins_with("kaykit_terrace_") or String(node.name)=="kaykit_rock_05"):
			natives.append(node)
			print("NATIVE_BATCH ",node.name," ",node.multimesh.instance_count)
			if not String(node.name).begins_with("kaykit_terrace_"): continue
			for index in node.multimesh.instance_count:
				candidates.append(node.global_transform*node.multimesh.get_instance_transform(index).origin+Vector3.UP*2)
	var reference := Vector3(-409,25,-262)
	candidates.sort_custom(func(a: Vector3,b: Vector3) -> bool: return a.distance_squared_to(reference)<b.distance_squared_to(reference))
	var targets: Array[Vector3] = []
	for candidate: Vector3 in candidates:
		var separate := true
		for existing: Vector3 in targets:
			if candidate.distance_to(existing)<45: separate=false
		if separate: targets.append(candidate)
		if targets.size() == 3: break
	assert(targets.size()==3)
	if OS.get_cmdline_user_args().has("--audit-only"):
		print("CLIFF_WORLD instances=",candidates.size()," batches=",natives.size())
		world.free()
		quit()
		return
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 50
	var poses: Array[Dictionary] = []
	for phase: String in ["before","after"]:
		for native: GeometryInstance3D in natives: native.visible = phase == "after"
		var output := directory+"world-"+phase
		DirAccess.make_dir_recursive_absolute(output)
		for index in targets.size():
			for height: float in [10,18]:
				for angle: float in [-35,0,35]:
					camera.position = targets[index]+Vector3(25,height,25).rotated(Vector3.UP,deg_to_rad(angle))
					camera.look_at(targets[index])
					var id := "%d_%d_%d" % [index,height,angle]
					if phase=="before": poses.append({"id":id,"target":str(targets[index]),"camera":str(camera.transform)})
					for frame in 10: await process_frame
					_draw.call_deferred()
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(id+".png"))
		FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	print("CLIFF_WORLD instances=",candidates.size()," batches=",natives.size()," targets=",targets)
	quit()

func _draw() -> void: RenderingServer.force_draw(true)
