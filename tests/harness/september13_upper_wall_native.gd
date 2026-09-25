extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,800)
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
	var towns: Array[Node3D] = []
	for name: String in ["before","after"]:
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/09-upper-wall/%s-payload.bin" % name,FileAccess.READ).get_var()
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
	var feet := Vector3(916.1,16,-410.1)
	var target := feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var crosshair := Vector3(945.6,16.5,-401.2)
	var backward := (target-crosshair).normalized()
	var eye := ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.fov = 75
	var output := "res://docs/qa/2026-09-13-manual/09-upper-wall/native-reproduction"
	var poses := []
	for angle: int in [0,-8,8]:
		camera.position = target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle))
		camera.look_at(target)
		poses.append({"angle":angle,"camera":str(camera.transform),"target":str(target)})
		for index in 2:
			towns[index].visible = true
			for frame in 10: await process_frame
			RenderingServer.force_draw(false)
			var directory := output.path_join("before" if index==0 else "after")
			DirAccess.make_dir_recursive_absolute(directory)
			root.get_texture().get_image().save_png(directory.path_join("detail_%d.png"%angle))
			towns[index].visible = false
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()
