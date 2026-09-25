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
	for before: bool in [true,false]:
		var town := Node3D.new()
		stage.add_child(town)
		town.transform = Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(-409.5,13.08,-263.5))
		var name := "before" if before else "candidate"
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-11-manual/08-skywalk/%s-payload.bin" % name, FileAccess.READ).get_var()
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
	var output := "res://docs/qa/2026-09-11-manual/08-skywalk/details"
	var catalogue := EnvironmentCatalog.load_default()
	var poses: Array[Dictionary] = []
	for porch in [0,1]:
		var centre := Vector3.ZERO
		var count := 0
		for asset: StringName in final_data.batches:
			var batch: Dictionary = final_data.batches[asset]
			for index in batch.ids.size():
				var id := String(batch.ids[index])
				if id.contains("spatial.maze_bridge_end.00.%02d.room00/ground-masonry/" % porch):
					centre += (batch.transforms[index] as Transform3D)*catalogue.descriptor(asset).measured_aabb.get_center()
					count += 1
		assert(count > 0)
		centre = towns[1].transform*(centre/float(count))+Vector3.UP*.5
		var outward := centre-towns[1].position
		outward.y = 0.0
		outward = Vector3.LEFT if "--close" in OS.get_cmdline_user_args() else outward.normalized()
		var views: Array[Dictionary] = [{"id":"front","yaw":0.0,"height":5.0},{"id":"left","yaw":-45.0,"height":5.0},{"id":"right","yaw":45.0,"height":5.0},{"id":"underside","yaw":0.0,"height":-4.0}]
		if "--close" in OS.get_cmdline_user_args():
			views = [{"id":"close_front","yaw":-15.0,"height":2.0},{"id":"close_underside","yaw":15.0,"height":-2.0}]
		for view: Dictionary in views:
			camera.fov = 70.0 if "--close" in OS.get_cmdline_user_args() else 50.0
			var distance := 8.0 if "--close" in OS.get_cmdline_user_args() else 18.0
			camera.position = centre+outward.rotated(Vector3.UP,deg_to_rad(view.yaw))*distance+Vector3.UP*view.height
			camera.look_at(centre)
			var label := "course%d_%s" % [porch,view.id]
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
