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
	var towns: Array[Node3D] = []
	for name: String in ["before","after"]:
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-18-manual/84-cliff-curved-masses/town-soffits/%s-payload.bin" % name,FileAccess.READ).get_var()
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

	var output := "res://docs/qa/2026-09-18-manual/84-cliff-curved-masses/town-soffits/native"
	DirAccess.make_dir_recursive_absolute(output)
	var feet:=Vector3(-1050.8,9,1055.9)
	var shots:Array=[
	 ["reported",ReviewCam.solve_cam(feet,Vector3(-1048.7,9,1060.8)),feet,65.0],
	 ["front",Vector3(-1057,17,1043),Vector3(-1048,12,1065),65.0],
	 ["overhead",Vector3(-1048,45,1050),Vector3(-1048,8,1065),50.0],
	 ["side",Vector3(-1028,16,1057),Vector3(-1048,11,1065),65.0]]
	for version:int in towns.size():
		towns[version].visible=true
		var name:String=["before","after"][version]
		for shot:Array in shots:
			camera.position=shot[1];camera.look_at(shot[2]);camera.fov=shot[3]
			for frame in 10:await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(output.path_join(name+"-"+shot[0]+".png"))
			print("P02_NATIVE ",shot[0])
		towns[version].visible=false
	quit()
