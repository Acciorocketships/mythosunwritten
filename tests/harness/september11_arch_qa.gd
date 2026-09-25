extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1920,1080)
	var output := "res://docs/qa/2026-09-11-manual/12-landforms/arches/"
	var args := OS.get_cmdline_user_args()
	if args.has("--output"): output=args[args.find("--output")+1].trim_suffix("/")+"/"
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
	var plan := TerrainWorldTuning.make_heightfield(2697992464)
	var chunk := Vector2i(-4,0)
	var region := plan.compute_region(-28,4,16)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(2697992464)
	mesher.prepare_resources()
	var data := mesher.compute_chunk(chunk,region)
	assert(data.natural_arches.placements.size()>0)
	var record: Dictionary = data.natural_arches.placements[0]
	var target := Vector3(record.center.x,record.low+4,record.center.y)
	var poses: Array[Dictionary] = []
	for phase: String in ["before","after"]:
		var copy := data.duplicate()
		if phase=="before": copy.erase("natural_arches")
		var stage := mesher.commit_chunk(copy)
		root.add_child(stage)
		var folder := output+phase
		DirAccess.make_dir_recursive_absolute(folder)
		for height: float in [2,12,24]:
			for angle: float in [-30,0,30,90]:
				camera.position = target+Vector3(25,height,25).rotated(Vector3.UP,deg_to_rad(angle))
				camera.look_at(target)
				var id := "%d_%d" % [height,angle]
				if phase=="before": poses.append({"id":id,"camera":str(camera.transform)})
				for frame in 10: await process_frame
				_draw.call_deferred()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder.path_join(id+".png"))
		FileAccess.open(folder.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
		stage.queue_free()
		await process_frame
	quit()

func _draw() -> void: RenderingServer.force_draw(true)
