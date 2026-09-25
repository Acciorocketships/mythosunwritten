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
	var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/september10-skywalk-source.txt"),program).compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.terrace_retaining_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan, SettlementFabricAssembler.maze_module_footprints(fabric), SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric), fabric.planned_plaza_cells))
	var town:=Node3D.new()
	stage.add_child(town)
	town.transform=Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE*2),Vector3(481.5,12.08,-2066.5))
	var cache:=EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	if "--before" in OS.get_cmdline_user_args():
		var original: Dictionary = FileAccess.open("res://docs/qa/2026-09-10-manual/09-roofs/native-before.bin",FileAccess.READ).get_var()
		for id: String in original:
			var visual := cache.visual(StringName(id)).duplicate(true) as EnvironmentVisual
			assert(visual.pieces.size()==1)
			var mesh := ArrayMesh.new()
			for arrays: Array in original[id]:
				var index := mesh.get_surface_count()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				mesh.surface_set_material(index,visual.pieces[0].mesh.surface_get_material(index))
			visual.pieces[0].mesh=mesh
			cache._visuals[StringName(id)]=visual
	var queue:=FeatureCommitQueue.new(cache)
	queue.enqueue(Vector2i.ZERO,1,town,payload)
	while queue.pending_count() > 0:
		queue.drain(100000,100000,100000)
		await process_frame
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=75.0
	var player:=Vector3(490.6,16.6,-2090.7)
	var crosshair:=Vector3(490.3,16.9,-2091)
	camera.position=ReviewCam.solve_cam(player,crosshair)
	camera.look_at(player)
	camera.force_update_transform()
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var output := args[args.find("--output")+1] if "--output" in args else "/tmp/september10-roof.png"
	root.get_texture().get_image().save_png(output)
	if "--nearby" in args:
		var original_cam := camera.position
		var views := [
			["left",player+(original_cam-player).rotated(Vector3.UP,deg_to_rad(-8)),player],
			["right",player+(original_cam-player).rotated(Vector3.UP,deg_to_rad(8)),player],
			["rear",Vector3(506,23,-2091),Vector3(498,19,-2086)],
			["overhead",Vector3(498,30,-2086),Vector3(498,18,-2085.9)]]
		for view: Array in views:
			camera.position=view[1]
			camera.look_at(view[2])
			for frame in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.get_basename()+"_"+view[0]+".png")
	quit()
