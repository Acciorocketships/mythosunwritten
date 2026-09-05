extends SceneTree
## Isolated deterministic screenshot reproduction; no village/streaming queue.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 800)
	var world := Node3D.new()
	root.add_child(world)
	var mountain := OS.get_cmdline_user_args().has("--mountain")
	var env := WorldEnvironment.new()
	var template: Node = load("res://scenes/world.tscn").instantiate()
	env.environment = (template.get_node("WorldEnvironment") as WorldEnvironment).environment
	template.free()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.background_color = Color(0.68, 0.83, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	world.add_child(sun)
	var seed_v := 991177 if mountain else 2697992464
	var water: WaterPlan = WaterPlan.new(seed_v, 22.0, 8) if mountain else preload("res://tests/fixtures/ReportedWaterPlan.gd").new(seed_v)
	var plan := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
	plan.set_water_plan(water)
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	mesher.set_seed(seed_v)
	var builder := WaterSurfaceBuilder.new()
	var chunks: Array[Vector2i] = [Vector2i(-2, -4), Vector2i(-1, -4)]
	var player := Vector3(-225.6, 4.0, -752.7)
	if mountain:
		var trace := water.river_for(Vector2i(-3, -4), 0)
		var centre := trace.points[20]
		player = Vector3(centre.x, water.smooth_h(centre), centre.y)
		var cc := Vector2i((centre / 192.0).floor())
		chunks.clear()
		for z in range(-1, 2):
			for x in range(-1, 2):
				chunks.append(cc + Vector2i(x, z))
	for chunk in chunks:
		var region := plan.compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
		world.add_child(mesher.commit_chunk(mesher.compute_chunk(chunk, region)))
		var wet := builder.build_chunk(water, chunk, region)
		if wet != null:
			world.add_child(wet)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = ReviewCam.solve_cam(player, Vector3(-225.6, 4.2, -753.0))
	if mountain:
		camera.position = player + Vector3(150, 140, 180)
	camera.look_at(player)
	camera.current = true
	for i in 3:
		if i == 2:
			camera.position += Vector3(1.2, 0.8, 0)
			camera.look_at(player)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/river-%s-%d.png" % ["mountain" if mountain else "corner", i])
	quit()
