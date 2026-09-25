extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1718,1035)
	var stage:=Node3D.new()
	root.add_child(stage)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("738080")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=0.8
	stage.add_child(env)
	var light:=DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees=Vector3(-45,-30,0)
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/september10-stone-source.txt"),program).compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	var town:=Node3D.new()
	stage.add_child(town)
	town.transform=Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(1822.5,12.08,-269.5))
	var cache:=EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var queue:=EnvironmentCommitQueue.new(cache,&"FrozenExterior")
	queue.register_chunk(Vector2i.ZERO,1)
	queue.enqueue(Vector2i.ZERO,1,town,payload)
	queue.drain(100000)
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=75.0
	var player:=Vector3(1825.6,24.1,-274.8)
	var crosshair:=Vector3(1826,24.4,-274.7)
	camera.position=ReviewCam.solve_cam(player,crosshair)
	camera.look_at(player)
	camera.force_update_transform()
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/september10-prefab-isolated.png")
	quit()
