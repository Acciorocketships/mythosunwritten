extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1000,900)
	Engine.max_fps = 30
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("738080")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = .8
	environment.environment.ambient_light_color = Color.WHITE
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees = Vector3(-45,-30,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 50
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var old_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/39-door-panels/before-assets.json"))
	for side: String in ["before","after"]:
		var plan := SettlementFabricPlan.new(&"housing-control")
		plan.set_asset_visual_bounds(program.asset_visual_bounds)
		var recipe := program.recipe(&"room.tower.base.orange")
		plan.register_recipe(recipe)
		plan.append_constructed_unit(FabricUnit.new(&"room",recipe.recipe_id,Vector3i.ZERO,0))
		assert(plan.finish_construction())
		var cache := EnvironmentRenderCache.new(catalog)
		if side == "before":
			for asset: String in old_assets: cache._visuals[StringName(asset)] = load(old_assets[asset])
		var house := Node3D.new()
		stage.add_child(house)
		for placement: Dictionary in plan.expanded_placements():
			for piece: EnvironmentVisualPiece in cache.visual(placement.asset_id).pieces:
				var mesh := MeshInstance3D.new()
				mesh.mesh = piece.mesh
				mesh.transform = placement.transform*piece.local_transform
				mesh.material_override = piece.material_override
				house.add_child(mesh)
		var directory := "res://docs/qa/2026-09-13-manual/39-door-panels/controls/"+side
		DirAccess.make_dir_recursive_absolute(directory)
		for angle: int in [0,45,-45,135,-135]:
			var target := Vector3(0,1.5,0)
			camera.position = target+Vector3(0,.8,8).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(target)
			for tick in 8: await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(directory.path_join("%d.png"%angle))
		house.free()
	quit()
