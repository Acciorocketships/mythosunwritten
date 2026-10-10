extends SceneTree

const OUTPUT := "res://docs/qa/2026-09-11-manual/10-unified-city/roof-native"
const OWNERS: Array[String] = ["spatial.maze_back.01.room00", "spatial.residual.01.room00"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	Engine.max_fps = 30
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var source := preload("res://tests/fixtures/frozen_maze_source.gd").read(
		"res://tests/fixtures/september11-unified-roof-source.txt")
	var spatial := WarrenVolumetricSolver.from_volume(
		WarrenMazeVolumeAdapter.to_volume_plan(source), -1, program, true)
	var fabric := WarrenSpatialFabricCompiler.generate(spatial, program, true)
	assert(fabric != null, WarrenSpatialFabricCompiler.last_failure)
	var selected: Array[Dictionary] = []
	var selected_units: Array[FabricUnit] = []
	for unit: FabricUnit in fabric.units:
		if String(unit.stable_id).begins_with("spatial.roof.") and _target(unit.stable_id):
			selected_units.append(unit)
			selected.append({"id":unit.stable_id,"recipe":unit.recipe_id,
				"transform":str(unit.transform()),
				"bounds":str(unit.transform()*program.recipe(unit.recipe_id).local_clearance_bounds)})
	print("SELECTED_ROOFS ", selected)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("738080")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-45, -30, 0)
	var cache := EnvironmentRenderCache.new(catalog)
	var variants: Array[Node3D] = []
	var whole := "--whole" in OS.get_cmdline_user_args()
	for before: bool in ([false] if whole else [true, false]):
		var payload := EnvironmentInstancePayload.new()
		for placement: Dictionary in fabric.expanded_placements():
			if not whole and not _target(placement.stable_id): continue
			if not whole and String(placement.stable_id).begins_with("spatial.roof."): continue
			payload.add(placement.asset_id,placement.transform,Color.WHITE,placement.stable_id)
		# Compare each complete native recipe before continuous-roof merging;
		# a merged asset may also cover rooms outside this two-room diagnostic.
		var roof_units: Array[FabricUnit] = []
		roof_units.assign([
				FabricUnit.new(&"rejected.row",&"roof.row.orange.dormer.left",Vector3i(10,2,-14),3),
				FabricUnit.new(&"rejected.slim",&"roof.slim.orange.dormer.right",Vector3i(9,2,-16),0)] if before else selected_units)
		if whole:
			roof_units.clear()
			payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
			payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,
				SettlementFabricAssembler.maze_module_footprints(fabric),
				SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
		for unit: FabricUnit in roof_units:
			for placement: Dictionary in program.recipe(unit.recipe_id).placements:
				payload.add(placement.asset_id,unit.transform()*placement.transform,
					Color.WHITE,StringName("%s/%s" % [unit.stable_id,placement.id]))
		var node := Node3D.new()
		root.add_child(node)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,node,payload)
		while queue.pending_count() > 0:
			queue.drain(100000,100000,100000)
			await process_frame
		node.visible = false
		variants.append(node)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 50
	var target := Vector3(14.25,3.4,-23.25)
	var poses: Array[Dictionary] = []
	for height: float in [7.0,2.0]:
		for angle: float in [0,60,120,180,240,300]:
			camera.position = target+Vector3(0,height,18).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(target)
			var label := "%d_%d" % [height,angle]
			poses.append({"id":label,"camera":str(camera.transform)})
			for index in variants.size():
				variants[index].visible = true
				for frame in 10: await process_frame
				_draw.call_deferred()
				await RenderingServer.frame_post_draw
				var directory := OUTPUT.path_join("whole" if whole else "before" if index == 0 else "after")
				DirAccess.make_dir_recursive_absolute(directory)
				root.get_texture().get_image().save_png(directory.path_join(label+".png"))
				variants[index].visible = false
	FileAccess.open(OUTPUT.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	FileAccess.open(OUTPUT.path_join("selected.json"),FileAccess.WRITE).store_string(JSON.stringify(selected,"  "))
	quit()

func _target(id: StringName) -> bool:
	for owner: String in OWNERS:
		if String(id).contains(owner): return true
	return false

func _draw() -> void:
	RenderingServer.force_draw(true)
