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
	var grass_program := GrassProgram.compile(load("res://terrain/grass/settings.tres") as GrassSettings,catalog,cache)
	var grass_renderer := GrassStreamer.new(grass_program,cache)
	grass_renderer.begin_frame(Vector2(216,480))
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(2697992464)
	mesher.prepare_resources()
	var heights: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-8,40):
		for x in range(-8,40):
			heights[Vector2i(x,z)]=3
			levels[Vector2i(x,z)]=0
	var region := HeightfieldRegion.new(heights,levels)
	var towns: Array[Node3D] = []
	var campfire := "--campfire" in OS.get_cmdline_user_args()
	var payload_dir := "res://docs/qa/2026-09-13-manual/20-civic/"+("campfire/" if campfire else "well/")
	var baseline:="before"
	var output := payload_dir+"native"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="): baseline=arg.trim_prefix("--baseline=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	for name: String in ([baseline] if "--current" in OS.get_cmdline_user_args() else [baseline,"after"]):
		var data: Dictionary = FileAccess.open(payload_dir+"%s-payload.bin" % name,FileAccess.READ).get_var()
		var town := Node3D.new()
		stage.add_child(town)
		town.transform = data.transform
		region = HeightfieldRegion.new(heights,levels)
		region.terrain_grades.append(TerrainGradePatch.new(&"civic.qa",data.grade_claims,Vector2(216,480),VillageOutskirtsConstruction.PITCH))
		var surfaces: Array[FeatureGroundShape] = []
		for value: Array in data.surfaces:
			surfaces.append(FeatureGroundShape.new(value[0],value[1],value[2],value[3],value[4],value[5],value[6],value[7],value[8]))
		var clearances: Array[FeatureGroundShape] = []
		for value: Array in data.get("clearances",[]):
			clearances.append(FeatureGroundShape.new(value[0],value[1],value[2],value[3],value[4],value[5],value[6],value[7],value[8]))
		var features := FeatureContext.new(Rect2(0,384,384,192), FeatureGroundField.new(surfaces,clearances,GrassProgram.FEATURE_CLEARANCE),EnvironmentInstancePayload.new())
		for chunk: Vector2i in [Vector2i(0,2),Vector2i(1,2)]:
			town.add_child(mesher.commit_chunk(mesher.compute_chunk(chunk,region,null,features)))
		var payload := preload("res://tests/fixtures/september11/floating_payload.gd").payload(data,false)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count()>0:
			queue.drain(100000,100000,100000)
			await process_frame
		if "--grass" in OS.get_cmdline_user_args():
			var water := WaterFieldContext.new()
			water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":region}
			water._region = region
			water._coverage = Rect2(0,0,960,960)
			water._shore_limit = .3
			water._shore_curves_ready = true
			for z in range(18,22):
				for x in range(7,11):
					var grass := GrassField.compute(grass_program,2697992464,Vector2i(x,z),region,water,features)
					for asset_id: StringName in grass.batches:
						grass_renderer._add_batch(town,asset_id,grass.batches[asset_id])
		town.visible = false
		towns.append(town)
	await physics_frame
	await physics_frame
	var feet := Vector3(241,12,493.4)
	var target := feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var crosshair := Vector3(229.7,12,487.5)
	var backward := (target-crosshair).normalized()
	var eye := ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.fov = 75
	var wide:="--wide" in OS.get_cmdline_user_args()
	if wide:
		# Orbit the reported bed's construction centre using the F3-derived
		# viewing direction; the default captures retain the exact photo pivot.
		target=Vector3(216,13,480)
		eye=target+ReviewCam.solve_cam(feet,crosshair,38,20,1)-(feet+Vector3.UP)
		camera.fov=50
	var poses := []
	for angle: int in ([0,-30,30,90,180,-90] if wide else [0,-8,8]):
		var desired:=target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle))
		camera.position = desired if wide else CameraObstructionSolver.new().resolve_boom(stage.get_world_3d().direct_space_state,target,desired,[])
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
