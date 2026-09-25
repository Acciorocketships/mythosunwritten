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
	payload.append_from(SettlementFabricAssembler.terrace_retaining_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan, SettlementFabricAssembler.maze_module_footprints(fabric), SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric), fabric.planned_plaza_cells))
	var town:=Node3D.new()
	stage.add_child(town)
	town.transform=Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(1822.5,12.08,-269.5))
	var cache:=EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var queue:=FeatureCommitQueue.new(cache)
	queue.enqueue(Vector2i.ZERO,1,town,payload)
	while queue.pending_count() > 0:
		queue.drain(100000,100000,100000)
		await process_frame
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=75.0
	var player:=Vector3(1828,18.1,-248.1)
	var crosshair:=Vector3(1827.7,18.4,-248.3)
	camera.position=ReviewCam.solve_cam(player,crosshair)
	camera.look_at(player)
	camera.force_update_transform()
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/september10-turf-isolated.png")
	for view in [["garden_under",Vector3(1.5,3.9,-4.5),Vector3(1.5,6,-4.3)],["garden_side",Vector3(0,3.9,-3.7),Vector3(2,4.5,-4.5)]]:
		camera.position=town.transform*view[1]
		camera.look_at(town.transform*view[2])
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/september10-"+view[0]+".png")
	quit()
