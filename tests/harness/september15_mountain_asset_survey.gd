extends SceneTree

var OUT = "res://docs/qa/2026-09-13-manual/27-mountain-art-direction/"
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			OUT = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	run.call_deferred()

func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(640, 480)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("596978")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-45, -30, 0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var paths: Array = JSON.parse_string(FileAccess.get_file_as_string(OUT + "assets.json"))
	var records: Array = []
	for i in paths.size():
		var path: String = paths[i]
		var item: Node3D
		if path.ends_with(".gltf") or path.ends_with(".glb"):
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(path, state) != OK:
				push_error("Cannot load " + path)
				continue
			item = doc.generate_scene(state)
		else:
			var packed = load(path)
			if not packed is PackedScene:
				push_error("No imported scene " + path)
				continue
			item = packed.instantiate()
		stage.add_child(item)
		var bounds := AABB()
		var first := true
		for node in item.find_children("*", "MeshInstance3D", true, false):
			if node.mesh == null: continue
			var b: AABB = node.global_transform * node.mesh.get_aabb()
			bounds = b if first else bounds.merge(b)
			first = false
		if first:
			item.free()
			continue
		var extent: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var center := bounds.get_center()
		camera.size = extent * 1.65
		camera.near = maxf(extent * 0.001, 0.001)
		camera.far = maxf(extent * 20.0, 1000.0)
		for angle in [0, 65]:
			camera.position = center + Vector3(0.15, 0.38, 1.0).rotated(Vector3.UP, deg_to_rad(float(angle))) * extent * 3.0
			camera.look_at(center)
			for frame in 4: await process_frame
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png(OUT + "%02d_%d.png" % [i, angle])
		records.append({"index": i, "path": path, "bounds": str(bounds)})
		print("ASSET_SURVEY ", records.back())
		item.free()
	FileAccess.open(OUT + "survey.json", FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	quit()
