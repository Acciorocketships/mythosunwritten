extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1920,1080)
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var seed_value:=VillagePlan.warren_seed_for_cell(2697992464,Vector2i(51,22))
	var spatial:=WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.select(seed_value))
	assert(spatial!=null,WarrenVolumetricSolver.last_failure)
	var fabric:=spatial.compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,
		SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	payload.append_from(SettlementFabricAssembler.low_retaining_payload(fabric))
	payload.append_from(SettlementFabricAssembler.terrace_retaining_payload(fabric,false))
	var stage:=Node3D.new()
	root.add_child(stage)
	var cache:=EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var queue:=FeatureCommitQueue.new(cache)
	queue.enqueue(Vector2i.ZERO,1,stage,payload)
	while queue.pending_count()>0:
		queue.drain(100000,100000,100000)
		await process_frame
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("91adbb")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.65
	root.add_child(environment)
	var light:=DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees=Vector3(-45,-30,0)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	camera.fov=50
	var output:="res://docs/qa/2026-09-11-manual/12-landforms/prefab-only-views"
	DirAccess.make_dir_recursive_absolute(output)
	for height:float in [12,30]:
		for angle:float in [0,90,180,270]:
			camera.position=Vector3(0,4,0)+Vector3(0,height,50).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(Vector3(0,4,0))
			for frame in 10: await process_frame
			_draw.call_deferred()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("%d_%d.png"%[height,angle]))
	FileAccess.open(output.path_join("audit.json"),FileAccess.WRITE).store_string(JSON.stringify(fabric.audit,"  "))
	quit()

func _draw() -> void: RenderingServer.force_draw(true)
