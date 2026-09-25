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
	var junction_bounds:=AABB()
	var baseline:="before"
	var output := "res://docs/qa/2026-09-13-manual/12-bay-spacing/native-integration"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="): baseline=arg.trim_prefix("--baseline=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	for name: String in [baseline,"after"]:
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/12-bay-spacing/%s-payload.bin" % name,FileAccess.READ).get_var()
		if name=="after":
			for asset: StringName in data.batches:
				if "window.s.002" not in String(asset): continue
				for index in data.batches[asset].transforms.size():
					if "facade-bay.01" not in str(data.batches[asset].ids[index]): continue
					var pose: Transform3D=data.batches[asset].transforms[index]
					var bounds: AABB=data.transform*pose*catalog.descriptor(asset).measured_aabb
					junction_bounds=bounds if not junction_bounds.has_volume() else junction_bounds.merge(bounds)
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
	await physics_frame
	await physics_frame
	var feet := Vector3(-178.3,8,-904.7)
	var target := feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var crosshair := Vector3(-188.9,11.4,-919.4)
	var backward := (target-crosshair).normalized()
	var eye := ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.fov = 75
	var wide:="--wide" in OS.get_cmdline_user_args()
	if wide:
		target=feet+Vector3.UP
		eye=ReviewCam.solve_cam(feet,crosshair,26,16,1)
		camera.fov=50
	var orbit:="--junction-orbit" in OS.get_cmdline_user_args()
	if orbit:
		assert(junction_bounds.has_volume())
		target=junction_bounds.get_center()
		camera.fov=50
	var poses := []
	for angle: int in ([0,-30,30,90,180,-90] if wide or orbit else [0,-8,8]):
		var desired:=target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle))
		camera.position = desired if wide or orbit else CameraObstructionSolver.new().resolve_boom(stage.get_world_3d().direct_space_state,target,desired,[])
		camera.look_at(target)
		poses.append({"angle":angle,"camera":str(camera.transform),"target":str(target)})
		for index in towns.size():
			towns[index].visible = true
			for frame in 10: await process_frame
			RenderingServer.force_draw(false)
			var directory := output.path_join("before" if index==0 else "after")
			DirAccess.make_dir_recursive_absolute(directory)
			root.get_texture().get_image().save_png(directory.path_join("detail_%d.png"%angle))
			towns[index].visible = false
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()
