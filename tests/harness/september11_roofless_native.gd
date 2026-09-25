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
	for before: bool in [true,false]:
		var town := Node3D.new()
		stage.add_child(town)
		town.transform = Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(-409.5,13.08,-263.5))
		var path := "res://docs/qa/2026-09-11-manual/05-floating/baseline-payload.bin" if before else "res://docs/qa/2026-09-11-manual/06-variety/candidate-payload.bin"
		var data: Dictionary = FileAccess.open(path, FileAccess.READ).get_var()
		var payload := frozen.payload(data, before)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count() > 0:
			queue.drain(100000,100000,100000)
			await process_frame
		town.visible = false
		towns.append(town)
	var output := "res://docs/qa/2026-09-11-manual/07-roofless/native-pairs"
	var player := Vector3(-409,25.1,-262.7)
	var poses: Array[Dictionary] = []
	for spot: Array in [["03_block",Vector3(-409.4,26.3,-262.7)],["04_village",Vector3(-409,26.3,-262.4)]]:
		var eye := ReviewCam.solve_cam(player,spot[1],26,16,1)
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
