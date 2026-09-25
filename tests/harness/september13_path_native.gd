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
	var args := OS.get_cmdline_user_args()
	var support := "--support" in args
	var path := "res://docs/qa/2026-09-13-manual/04-path/"
	var towns: Array[Node3D] = []
	for name: String in (["support-before","support-after"] if support else ["before","after"]):
		var data: Dictionary = FileAccess.open(path+name+"-payload.bin",FileAccess.READ).get_var()
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
	var target := Vector3(-222.4,17.5,-955)
	if support:
		var data: Dictionary = str_to_var(FileAccess.get_file_as_string(path+"support-before-support.txt"))
		target = Vector3.ZERO
		for cell: Vector3i in data.unsupported: target += Vector3(cell)*FabricRecipe.CELL_SIZE
		target /= float(data.unsupported.size())
	var output := path+("support-native" if support else "closure-native")
	var poses := []
	for angle: int in [0,90,180,270]:
		camera.position = target+Vector3(0,3,13).rotated(Vector3.UP,deg_to_rad(angle))
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
