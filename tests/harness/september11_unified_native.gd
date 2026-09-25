extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920,1080)
	Engine.max_fps = 30
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("738080")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-45,-30,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 50
	var frozen := preload("res://tests/fixtures/september11/floating_payload.gd")
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var towns: Array[Node3D] = []
	var world_bounds := AABB()
	var has_bounds := false
	var catalog := EnvironmentCatalog.load_default()
	var args := OS.get_cmdline_user_args()
	var seed11 := "--overview" in args
	for before: bool in [true,false]:
		var town := Node3D.new()
		stage.add_child(town)
		town.transform = Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(-409.5,13.08,-263.5))
		var argument := "--before" if before else "--after"
		var name := ("before" if before else "proposal1")
		if argument in args: name = args[args.find(argument) + 1]
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-11-manual/10-unified-city/%s%s-payload.bin" % ["",name], FileAccess.READ).get_var()
		for asset: StringName in data.batches:
			var batch: Dictionary = data.batches[asset]
			for pose: Transform3D in batch.transforms:
				var box := town.transform*(pose*catalog.descriptor(asset).measured_aabb)
				world_bounds = world_bounds.merge(box) if has_bounds else box
				has_bounds = true
		var payload := frozen.payload(data, false)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count() > 0:
			queue.drain(100000,100000,100000)
			await process_frame
		town.visible = false
		towns.append(town)
	var output := "res://docs/qa/2026-09-11-manual/10-unified-city/"+("proposal1-overviews" if seed11 else "proposal1-photo")
	if "--output" in args: output = args[args.find("--output") + 1]
	var player := world_bounds.get_center()-Vector3.UP if seed11 else Vector3(-409,25.1,-262.7)
	var poses: Array[Dictionary] = []
	var spots: Array = [["03_block",Vector3(-409.4,26.3,-262.7)],["04_village",Vector3(-409,26.3,-262.4)]]
	if seed11:
		var distance := maxf(world_bounds.size.x,world_bounds.size.z)*1.35
		spots = [["overview",Vector3(0,distance*.55,distance)],["lower",Vector3(0,distance*.22,distance)]]
	for spot: Array in spots:
		var eye := player+(spot[1] as Vector3) if seed11 else ReviewCam.solve_cam(player,spot[1],26,16,1)
		for angle: float in [0,-8,8,-30,30,90,180,-90]:
			camera.position = player+(eye-player).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(player+Vector3.UP)
			poses.append({"spot":spot[0],"angle":angle,"camera":str(camera.transform)})
			for index in 2:
				towns[index].visible = true
				for frame in 10: await process_frame
				_force_draw.call_deferred()
				await RenderingServer.frame_post_draw
				var directory := output.path_join("before" if index == 0 else "after")
				DirAccess.make_dir_recursive_absolute(directory)
				root.get_texture().get_image().save_png(directory.path_join("%s_%d.png" % [spot[0],int(angle)]))
				towns[index].visible = false
	var pose_file := "poses-reverse.json" if "--reverse" in OS.get_cmdline_user_args() else "poses.json"
	FileAccess.open(output.path_join(pose_file),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()

func _force_draw() -> void:
	RenderingServer.force_draw(true)
