extends SceneTree

## Isolated visual falsification for the wraparound balcony contract.  Each
## balcony is attached to the real addressed tower facade at first-floor height;
## the support feet and switchback terminate on a lower platform made from the
## same authored walk-surface assets used by production.
const CASES: Array[Dictionary] = [
	{
		"id": &"left-blue",
		"base": &"room.tower.base.blue.closed",
		"upper": &"room.tower.upper.address.blue",
		"roof": &"roof.tower.blue",
		"balcony": &"balcony.wrap.left.blue.planted",
	},
	{
		"id": &"right-orange",
		"base": &"room.tower.base.orange.closed",
		"upper": &"room.tower.upper.address.orange",
		"roof": &"roof.tower.orange",
		"balcony": &"balcony.wrap.right.orange.planted",
	},
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
	camera.fov = 50.0
	world.add_child(camera)
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	for case_value: Dictionary in CASES:
		var construction := Node3D.new()
		world.add_child(construction)
		_commit_recipe(construction, program.recipe(case_value.base), catalog,
			Transform3D.IDENTITY)
		_commit_recipe(construction, program.recipe(case_value.upper), catalog,
			_transform(Vector3.UP * 3.0))
		_commit_recipe(construction, program.recipe(case_value.roof), catalog,
			_transform(Vector3.UP * 6.0))
		var balcony_pose := _transform(Vector3(0.0, 3.0, 1.5))
		_commit_recipe(construction, program.recipe(case_value.balcony), catalog,
			balcony_pose)
		# The complete lower public platform makes every support foot and the exact
		# low stair tread falsifiable.  It uses production plank modules, never a
		# debug plane.
		for x in range(-6, 7):
			for z in range(-2, 6):
				_commit_asset(construction, SettlementFabricProgram.GALLERY_FLOOR,
					catalog, program.module_program.walk_aligned_transform(
						SettlementFabricProgram.GALLERY_FLOOR,
						_transform(Vector3(float(x) * FabricRecipe.CELL_SIZE,
							0.0, float(z) * FabricRecipe.CELL_SIZE)), 0.0))
		for view: Dictionary in [
			{"id": "door-axis", "position": Vector3(0.0, 5.2, 12.0),
				"target": Vector3(0.0, 4.1, 2.6)},
			# Stand inside the perimeter so the outer guard cannot occlude the
			# threshold. This is the adversarial view for a redundant facade-side
			# rail or a terminal post left in the authored doorway approach.
			{"id": "door-threshold", "position": Vector3(0.0, 4.45, 3.45),
				"target": Vector3(0.0, 4.35, 1.25)},
			{"id": "stair-profile", "position": Vector3(-10.0, 4.5, 8.0)
					if String(case_value.id).begins_with("left")
					else Vector3(10.0, 4.5, 8.0),
				"target": Vector3(0.0, 2.4, 2.2)},
			{"id": "underside", "position": Vector3(-7.0, 1.4, 7.0)
					if String(case_value.id).begins_with("left")
					else Vector3(7.0, 1.4, 7.0),
				"target": Vector3(0.0, 2.6, 1.8)},
		]:
			camera.position = view.position as Vector3
			camera.look_at(view.target as Vector3)
			for unused in 5:
				await process_frame
			RenderingServer.force_draw()
			await process_frame
			var path := "/tmp/warren-balcony-%s-%s.png" % [
				String(case_value.id), String(view.id)]
			var image := root.get_texture().get_image()
			assert(image != null and image.save_png(path) == OK)
			print("[balcony_recipe_review] captured %s" % path)
		construction.queue_free()
		await process_frame
	quit()


func _commit_recipe(parent: Node3D, recipe: FabricRecipe,
		catalog: EnvironmentCatalog, parent_pose: Transform3D) -> void:
	assert(recipe != null)
	for placement: Dictionary in recipe.placements:
		_commit_asset(parent, StringName(placement.asset_id), catalog,
			parent_pose * (placement.transform as Transform3D))


func _commit_asset(parent: Node3D, asset_id: StringName,
		catalog: EnvironmentCatalog, pose: Transform3D) -> void:
	var descriptor := catalog.descriptor(asset_id)
	assert(descriptor != null)
	var visual := load(descriptor.visual_path) as EnvironmentVisual
	assert(visual != null)
	for piece: EnvironmentVisualPiece in visual.pieces:
		var instance := MeshInstance3D.new()
		instance.mesh = piece.mesh
		instance.transform = pose * piece.local_transform
		instance.material_override = piece.material_override
		parent.add_child(instance)


func _transform(origin: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, origin)
