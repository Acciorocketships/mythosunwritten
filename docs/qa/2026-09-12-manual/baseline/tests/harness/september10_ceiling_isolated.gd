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
	var base := "--base" in OS.get_cmdline_user_args()
	var stone := "--stone" in OS.get_cmdline_user_args()
	var skywalk := "--skywalk" in OS.get_cmdline_user_args()
	var fixture := "september10-prefab-base-source.txt" if base else "september10-ceiling-source.txt"
	if stone: fixture="september10-stone-source.txt"
	if skywalk: fixture="september10-skywalk-source.txt"
	var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/"+fixture),program).compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.terrace_retaining_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan, SettlementFabricAssembler.maze_module_footprints(fabric), SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric), fabric.planned_plaza_cells))
	var town:=Node3D.new()
	stage.add_child(town)
	town.transform=Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE*2),Vector3(985.5,5.08,-2066.5))
	if base:
		town.transform=Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(1924.5,16.08,-1001.5))
	if stone: town.transform=Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(1822.5,12.08,-269.5))
	if skywalk: town.transform=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*2),Vector3(481.5,12.08,-2066.5))
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
	var views := [
		["09",Vector3(991.4,9.2,-2055.4),Vector3(991.7,9.4,-2055.5)],
		["08",Vector3(982.2,9.3,-2079.8),Vector3(982.4,9.6,-2080.1)]]
	if base: views = [
		["04",Vector3(1923.3,18.7,-1040.1),Vector3(1923.1,19.1,-1040.5)],
		["02",Vector3(1957.3,19.2,-987.5),Vector3(1957.6,19.6,-987.8)]]
	if stone: views = [
		["17",Vector3(1825.6,24.1,-274.8),Vector3(1826,24.4,-274.7)],
		["07",Vector3(1794,24.1,-279),Vector3(1793.8,24.3,-279.3)],
		["12",Vector3(1828,18.1,-248.1),Vector3(1827.7,18.4,-248.3)],
		["05",Vector3(1820.8,27.1,-259),Vector3(1821.1,27.4,-259.1)]]
	if skywalk: views = [
		["03",Vector3(482.7,31.3,-2069.3),Vector3(483,31.6,-2069.2)],
		["01",Vector3(475,21.1,-2077.8),Vector3(474.6,21.4,-2077.9)]]
	var args := OS.get_cmdline_user_args()
	var output := "/tmp"
	if "--output" in args: output = args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	for view: Array in views:
		camera.position=ReviewCam.solve_cam(view[1],view[2])
		camera.look_at(view[1])
		camera.force_update_transform()
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("ceiling%s.png"%view[0]))
	quit()
