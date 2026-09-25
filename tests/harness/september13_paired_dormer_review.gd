extends SceneTree

## Visual QA for the exact roof+dormer recipes production selects. Source-pack
## scenes are never loaded here: every mesh and transform comes through the
## compiled environment catalogue and SettlementFabricProgram contract.
const RECIPE_IDS: Array[StringName] = [
 &"roof.long.blue.dormer.pair.left", &"roof.long.blue.dormer.pair.right",
 &"roof.long.orange.dormer.pair.left", &"roof.long.orange.dormer.pair.right",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a6b4bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 44.0
	world.add_child(camera)
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var phase := "after"
	if "--before" in OS.get_cmdline_user_args():
		phase = "before"
		var original := GDScript.new()
		original.source_code = FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/41-dormers/program-before.gd.txt").replace("class_name SettlementFabricProgram\n", "")
		assert(original.reload() == OK)
		program = original.compile(catalog)
	var directory := "res://docs/qa/2026-09-13-manual/41-dormers/paired-control/" + phase
	DirAccess.make_dir_recursive_absolute(directory)
	assert(program != null)
	for recipe_id: StringName in RECIPE_IDS:
		var recipe := program.recipe(recipe_id)
		assert(recipe != null)
		var construction := Node3D.new()
		world.add_child(construction)
		var dormer_pose := Transform3D.IDENTITY
		for placement: Dictionary in recipe.placements:
			var descriptor := catalog.descriptor(StringName(placement.asset_id))
			assert(descriptor != null)
			var visual := load(descriptor.visual_path) as EnvironmentVisual
			assert(visual != null)
			for piece: EnvironmentVisualPiece in visual.pieces:
				var instance := MeshInstance3D.new()
				instance.mesh = piece.mesh
				instance.transform = (placement.transform as Transform3D) \
					* piece.local_transform
				instance.material_override = piece.material_override
				construction.add_child(instance)
			if String(placement.id).contains("dormer"):
				dormer_pose = placement.transform as Transform3D
		var target := Vector3(0, 2.0, 0)
		var outward := dormer_pose.basis * Vector3.BACK
		outward.y = 0.0
		outward = outward.normalized()
		for view: Dictionary in [
			{"id": "front", "direction": outward},
			{"id": "back", "direction": -outward},
			{"id": "oblique", "direction": (outward \
				+ Vector3(outward.z, 0.0, -outward.x)).normalized()},
		]:
			camera.position = target + (view.direction as Vector3) * 16.0 \
				+ Vector3.UP * 2.1
			camera.look_at(target)
			for unused in 5:
				await process_frame
			RenderingServer.force_draw()
			await process_frame
			var path := directory.path_join("%s-%s.png") % [
				String(recipe_id).replace(".", "-"), String(view.id)]
			var image := root.get_texture().get_image()
			assert(image != null and image.save_png(path) == OK)
			print("[dormer_recipe_review] captured %s" % path)
		construction.queue_free()
		await process_frame
	quit()
