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
	var final_data: Dictionary = {}
	var seed11 := "--seed11" in OS.get_cmdline_user_args()
	for before: bool in [true,false]:
		var town := Node3D.new()
		stage.add_child(town)
		town.transform = Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(-409.5,13.08,-263.5))
		var name := "before" if before else "candidate"
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-11-manual/09-prefabs/%s%s-payload.bin" % ["seed11-" if seed11 else "",name], FileAccess.READ).get_var()
		if not before: final_data = data
		var payload := frozen.payload(data, false)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count() > 0:
			queue.drain(100000,100000,100000)
			await process_frame
		town.visible = false
		towns.append(town)
	var output := "res://docs/qa/2026-09-11-manual/09-prefabs/"+("seed11-details" if seed11 else "photo-details")
	var catalogue := EnvironmentCatalog.load_default()
	var poses: Array[Dictionary] = []
	for prefab in [0,1]:
		var centre := Vector3.ZERO
		var outward := Vector3.ZERO
		var count := 0
		var extent := 0.0
		for asset: StringName in final_data.batches:
			var batch: Dictionary = final_data.batches[asset]
			for index in batch.ids.size():
				var id := String(batch.ids[index])
				if id.contains("spatial.feature.landmark.%02d.component.00/building" % prefab):
					var pose: Transform3D = batch.transforms[index]
					var box := catalogue.descriptor(asset).measured_aabb
					centre = towns[1].transform*(pose*box.get_center())
					outward = (towns[1].basis*pose.basis*Vector3.FORWARD).normalized()
					extent = maxf(box.size.x,box.size.z)*2.0
					count += 1
		assert(count == 1, "Exactly one complete native prefab owns each landmark")
		var views: Array[Dictionary] = [{"id":"front","yaw":0.0,"height":2.0},{"id":"left","yaw":-45.0,"height":2.0},{"id":"right","yaw":45.0,"height":2.0},{"id":"rear","yaw":180.0,"height":2.0},{"id":"base","yaw":0.0,"height":-3.0}]
		for view: Dictionary in views:
			camera.fov = 50.0
			var distance := maxf(12.0,extent*1.7)
			camera.position = centre+outward.rotated(Vector3.UP,deg_to_rad(view.yaw))*distance+Vector3.UP*view.height
			camera.look_at(centre)
			var label := "prefab%d_%s" % [prefab,view.id]
			poses.append({"id":label,"camera":str(camera.transform),"fov":camera.fov})
			for index in 2:
				towns[index].visible = true
				for frame in 10: await process_frame
				_force_draw.call_deferred()
				await RenderingServer.frame_post_draw
				var directory := output.path_join("before" if index == 0 else "after")
				DirAccess.make_dir_recursive_absolute(directory)
				root.get_texture().get_image().save_png(directory.path_join(label+".png"))
				towns[index].visible = false
	FileAccess.open(output.path_join("poses-close.json" if "--close" in OS.get_cmdline_user_args() else "poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()

func _force_draw() -> void:
	RenderingServer.force_draw(true)
