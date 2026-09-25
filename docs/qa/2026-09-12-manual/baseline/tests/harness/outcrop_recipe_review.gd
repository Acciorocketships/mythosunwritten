extends SceneTree

## Isolated visual falsification for the two outcropping constructions. Town
## cameras are necessarily crowded; this harness proves the authored shell is
## closed and its roof reads from every exposed side before contextual review.
const RECIPE_IDS: Array[StringName] = [
	&"outcrop.corner.wrap.left.blue",
	&"outcrop.corner.wrap.right.orange",
	&"outcrop.embedded.blue",
	&"outcrop.embedded.orange",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1400, 1000)
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
	assert(program != null)
	for recipe_id: StringName in RECIPE_IDS:
		var recipe := program.recipe(recipe_id)
		assert(recipe != null)
		print("[outcrop_recipe_review] recipe=%s bounds=%s" % [
			String(recipe_id), recipe.local_bounds])
		var construction := Node3D.new()
		world.add_child(construction)
		for placement: Dictionary in recipe.placements:
			var descriptor := catalog.descriptor(StringName(placement.asset_id))
			assert(descriptor != null)
			print("[outcrop_recipe_review] placement=%s asset=%s bounds=%s" % [
				String(placement.id), String(placement.asset_id),
				(placement.transform as Transform3D) * descriptor.measured_aabb])
			var visual := load(descriptor.visual_path) as EnvironmentVisual
			assert(visual != null)
			for piece: EnvironmentVisualPiece in visual.pieces:
				var instance := MeshInstance3D.new()
				instance.mesh = piece.mesh
				instance.transform = (placement.transform as Transform3D) \
					* piece.local_transform
				instance.material_override = piece.material_override
				construction.add_child(instance)
		if DisplayServer.get_name() == "headless":
			construction.queue_free()
			await process_frame
			continue
		for view: Dictionary in [
			{"id": "northwest", "position": Vector3(-7.5, 5.4, -8.0)},
			{"id": "northeast", "position": Vector3(7.5, 5.4, -8.0)},
			{"id": "southwest", "position": Vector3(-7.5, 5.4, 7.0)},
			{"id": "top", "position": Vector3(-4.0, 11.0, 5.0)},
		]:
			camera.position = view.position as Vector3
			camera.look_at(Vector3(0.0, 1.6, -1.2))
			for unused in 4:
				await process_frame
			RenderingServer.force_draw()
			await process_frame
			var path := "/tmp/warren-%s-%s.png" % [
				String(recipe_id).replace(".", "-"), String(view.id)]
			var image := root.get_texture().get_image()
			assert(image != null and image.save_png(path) == OK)
			print("[outcrop_recipe_review] captured %s" % path)
		construction.queue_free()
		await process_frame
	quit()
