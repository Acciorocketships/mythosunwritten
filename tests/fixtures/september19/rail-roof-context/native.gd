extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1920,1080)
	Engine.max_fps = 30
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("738080")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .8
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees = Vector3(-45,-30,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 50
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var source := "res://docs/qa/2026-09-19-manual/108-rail-roof-context"
	if "--after" in OS.get_cmdline_user_args(): source = source.path_join("after")
	var towns: Array[Node3D] = []
	for name: String in ["current"]:
		var data: Dictionary = FileAccess.open(source.path_join("payload.bin"),FileAccess.READ).get_var()
		var town := Node3D.new()
		stage.add_child(town)
		town.transform = data.transform
		var payload := preload("res://tests/fixtures/september11/floating_payload.gd").payload(data,false)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count()>0:
			queue.drain(100000,100000,100000)
			await process_frame
		town.visible = false
		towns.append(town)

	var output := source.path_join("native")
	for site in ["P04", "P15"]:
		var poses: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-16-manual/05-town-rails/baseline/%s/poses.json" % site))
		for pose: Dictionary in poses:
			var pattern := RegEx.new()
			pattern.compile("-?[0-9]+(?:\\.[0-9]+)?")
			var v: Array[float] = []
			for match in pattern.search_all(pose.camera): v.append(float(match.get_string()))
			camera.transform=Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
			camera.fov=pose.fov
			for index in 1:
				towns[index].visible = true
				for frame in 10: await process_frame
				RenderingServer.force_draw(false)
				var directory := output
				DirAccess.make_dir_recursive_absolute(directory)
				root.get_texture().get_image().save_png(directory.path_join("%s_%d.png"%[site,int(pose.angle)]))
				if int(pose.angle)==0:
					var pixel := Vector2(1150,650) if site=="P15" else Vector2(1630,400)
					var target := camera.project_position(pixel,10.0)
					camera.look_at(target)
					camera.fov = 25
					for frame in 10: await process_frame
					RenderingServer.force_draw(false)
					root.get_texture().get_image().save_png(directory.path_join("%s_termination.png" % site))
				towns[index].visible = false
	quit()
