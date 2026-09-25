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
	var args := OS.get_cmdline_user_args()
	var before := "--before" in args
	var label := "before" if before else "after"
	var program := SettlementFabricProgram.compile(catalog)
	var output_root := "res://docs/qa/2026-09-13-manual/07-platform/shared-plaza-native"
	for seed_value in [3,7]:
		var spatial := WarrenVolumetricSolver.solve(seed_value,{},program,WarrenVillageScaleProfile.for_id(&"standard"))
		assert(spatial!=null,WarrenVolumetricSolver.last_failure)
		var fabric := spatial.compiled_fabric_cache()
		var payload := SettlementFabricAssembler.payload(fabric)
		payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
		payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,
			SettlementFabricAssembler.maze_module_footprints(fabric),
			SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
		var town := Node3D.new()
		stage.add_child(town)
		town.scale = Vector3.ONE*2
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count()>0:
			queue.drain(100000,100000,100000)
			await process_frame
		var source := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
		var target := Vector3.ZERO
		for plot: Dictionary in source.plots:
			if plot.id != WarrenPlotReservations.PLAZA_PLOT_ID: continue
			for column: Vector2i in plot.cells:
				target += Vector3(column.x*6+1.5,float(plot.floor)*3,column.y*6+1.5)
			target /= float(plot.cells.size())
		var poses := []
		for angle in [0,90,180,270]:
			camera.position = target+Vector3(0,24,28).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(target)
			poses.append({"angle":angle,"camera":str(camera.transform),"target":str(target)})
			for frame in 5: await process_frame
			RenderingServer.force_draw(false)
			var directory := output_root.path_join(label)
			DirAccess.make_dir_recursive_absolute(directory)
			root.get_texture().get_image().save_png(directory.path_join("seed%d_%d.png"%[seed_value,angle]))
		FileAccess.open(output_root.path_join("%s_seed%d_poses.json"%[label,seed_value]),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
		town.free()
	quit()
