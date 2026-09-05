extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1200, 900)
	var scene := Node3D.new()
	root.add_child(scene)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	scene.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.25, 0.3, 0.35)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)
	var catalog := EnvironmentCatalog.load_default()
	var asset_id := &"sfv.fabric.wall.wood.corner.s.001"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		asset_id = StringName(args[0])
	var asset := load(catalog.descriptor(asset_id).visual_path) as EnvironmentVisual
	for piece: EnvironmentVisualPiece in asset.pieces:
		print("bounds ", piece.local_transform * piece.mesh.get_aabb())
		var depths: Dictionary = {}
		for surface_index in piece.mesh.get_surface_count():
			var arrays := piece.mesh.surface_get_arrays(surface_index)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var point := piece.local_transform * vertex
				if point.y > 0.5 and point.y < 2.5:
					var key := snappedf(point.z, 0.01)
					depths[key] = int(depths.get(key, 0)) + 1
		print("depths ", depths)
		var instance := MeshInstance3D.new()
		instance.mesh = piece.mesh
		instance.transform = piece.local_transform
		scene.add_child(instance)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	for index in 4:
		camera.position = Vector3(3.0, 2.2, 3.0).rotated(Vector3.UP, index * PI / 2.0)
		camera.look_at(Vector3(0, 1.5, 0))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/%s-%d.png" % [asset_id, index])
	quit()
