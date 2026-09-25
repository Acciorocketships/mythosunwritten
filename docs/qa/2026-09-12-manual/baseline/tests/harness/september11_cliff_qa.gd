extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920,1080)
	Engine.max_fps = 30
	var args := OS.get_cmdline_user_args()
	var phase := args[args.find("--phase")+1]
	var seed_value := int(args[args.find("--seed")+1]) if args.has("--seed") else 0
	var output := "res://docs/qa/2026-09-11-manual/11-cliffs/"+phase
	DirAccess.make_dir_recursive_absolute(output)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("91adbb")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-45,-30,0)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 50
	var poses: Array[Dictionary] = []
	for shape: String in ["face", "outer", "inner"]:
		var plan := HeightfieldPlan.new(17,64,12,"mean",4)
		plan.set_raw_height_override(func(cx: int, cz: int) -> float:
			if shape == "face": return 16.0 if cx <= 3 else 0.0
			if shape == "outer": return 16.0 if cx <= 3 and cz <= 3 else 0.0
			return 0.0 if cx > 3 and cz > 3 else 16.0)
		var mesher := TerrainChunkMesher.new()
		mesher.prepare_resources()
		mesher.set_seed(seed_value)
		var data := mesher.compute_chunk(Vector2i.ZERO,plan.compute_region(4,4,8))
		if args.has("--bare"): data.erase("cliff_terraces")
		FileAccess.open(output.path_join(shape+"-data.bin"),FileAccess.WRITE).store_var(data)
		var terrain := mesher.commit_chunk(data)
		root.add_child(terrain)
		var detail: Dictionary = {}
		if args.has("--details"):
			for placement: Dictionary in data.get("cliff_terraces",{}).get("placements",[]):
				if placement.kind == "rock":
					detail = placement
					break
			if detail.is_empty(): detail = data.cliff_terraces.placements[0]
		for height: float in [14,28]:
			for angle: float in [-20,0,20]:
				var target := Vector3(84,7,84)
				camera.position = target+Vector3(40,height,32).rotated(Vector3.UP,deg_to_rad(angle))
				if not detail.is_empty():
					target = (detail.bounds as AABB).get_center()
					camera.position = target+Vector3(9,height*.25,7).rotated(Vector3.UP,deg_to_rad(angle))
				camera.look_at(target)
				var id := "%s_%d_%d" % [shape,height,angle]
				poses.append({"id":id,"camera":str(camera.transform)})
				for frame in 10: await process_frame
				_draw.call_deferred()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join(id+".png"))
		terrain.queue_free()
		await process_frame
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()

func _draw() -> void:
	RenderingServer.force_draw(true)
