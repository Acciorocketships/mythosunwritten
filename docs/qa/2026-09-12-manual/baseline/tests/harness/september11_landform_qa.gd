extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1920,1080)
	var args := OS.get_cmdline_user_args()
	var broad := args.has("--broad")
	var phase := args[args.find("--phase")+1]
	var directory := "res://docs/qa/2026-09-11-manual/12-landforms/"
	var output := directory+phase
	DirAccess.make_dir_recursive_absolute(output)
	var site_file := args[args.find("--sites")+1] if args.has("--sites") else "before-survey.json"
	var sites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+site_file))
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
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(2697992464)
	mesher.prepare_resources()
	var poses: Array[Dictionary] = []
	for biome: String in sites:
		if args.has("--biome") and biome!=args[args.find("--biome")+1]: continue
		var point := Vector2(sites[biome].core.x,sites[biome].core.z)
		var chunk := Vector2i((point/192).floor())
		var plan := preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd").make_heightfield(2697992464) \
			if args.has("--legacy") else TerrainWorldTuning.make_heightfield(2697992464)
		var region := plan.compute_region(chunk.x*8+4,chunk.y*8+4,40 if broad else 32)
		var stage := Node3D.new()
		root.add_child(stage)
		var start := Time.get_ticks_msec()
		var extent := 3 if broad else 2
		for z in range(-extent,extent+1):
			for x in range(-extent,extent+1):
				stage.add_child(mesher.commit_chunk(mesher.compute_chunk(chunk+Vector2i(x,z),region)))
			await process_frame
		print("LANDFORM_SITE ",biome," mesh_ms=",Time.get_ticks_msec()-start)
		var target := Vector3(point.x,20,point.y)
		for angle: float in [-35,0,35]:
			var offset := Vector3(600,550,600) if broad else Vector3(300,250,300)
			if args.has("--low"): offset=Vector3(350,95,350)
			camera.position = target+offset.rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(target)
			var id := "%s_%d" % [biome,angle]
			poses.append({"id":id,"camera":str(camera.transform)})
			for frame in 10: await process_frame
			_draw.call_deferred()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(id+".png"))
		stage.queue_free()
		await process_frame
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()

func _draw() -> void: RenderingServer.force_draw(true)
