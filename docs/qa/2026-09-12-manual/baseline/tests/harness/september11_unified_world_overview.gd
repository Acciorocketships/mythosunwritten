extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1920, 1080)
	var args := OS.get_cmdline_user_args()
	var after := "--after" in args
	var directory := "10-unified-city" if after else "09-prefabs"
	var snapshot := "res://docs/qa/2026-09-11-manual/%s/live-after/village.scn" % directory
	if "--snapshot" in args: snapshot = args[args.find("--snapshot") + 1]
	var world := (load(snapshot) as PackedScene).instantiate()
	for key: StringName in world.get_meta("shader_globals"):
		RenderingServer.global_shader_parameter_set(key, world.get_meta("shader_globals")[key])
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 50
	var target := Vector3(-409, 23, -264)
	var output := "res://docs/qa/2026-09-11-manual/10-unified-city/world-overviews/" + ("after" if after else "before")
	if "--output" in args: output = args[args.find("--output") + 1]
	DirAccess.make_dir_recursive_absolute(output)
	var poses: Array[Dictionary] = []
	for height: float in [65, 30]:
		for angle: float in [0, 45, 90, 135, 180, 225, 270, 315]:
			camera.position = target + Vector3(0, height, 95).rotated(Vector3.UP, deg_to_rad(angle))
			camera.look_at(target)
			var id := "%d_%d" % [height, angle]
			poses.append({"id": id, "camera": str(camera.transform)})
			for frame in 10: await process_frame
			_draw.call_deferred()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(id + ".png"))
	FileAccess.open(output.path_join("poses.json"), FileAccess.WRITE).store_string(JSON.stringify(poses, "  "))
	quit()

func _draw() -> void:
	RenderingServer.force_draw(true)
