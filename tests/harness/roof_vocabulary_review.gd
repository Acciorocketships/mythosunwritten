extends SceneTree

## Focused visual gate for the production roof vocabulary.  City screenshots
## are intentionally hostile to broad composition failures, but they are a bad
## place to diagnose a two-metre roof seam.  This harness commits the exact
## baked placements from SettlementFabricProgram at review scale; a dormer,
## material family, or junction component is therefore ineligible for the town
## until it also reads cleanly here.
const RECIPE_IDS: Array[StringName] = [
	&"roof.long.blue",
	&"roof.long.blue.dormer.left",
	&"roof.long.blue.dormer.right",
	&"roof.long.orange",
	&"roof.long.orange.dormer.left",
	&"roof.long.orange.dormer.right",
	&"roof.long.blue.dormer.pair.left",
	&"roof.long.blue.dormer.pair.right",
	&"roof.long.orange.dormer.pair.left",
	&"roof.long.orange.dormer.pair.right",
	&"roof.tower.blue",
	&"roof.tower.orange",
	&"roof.tower.chimney.blue",
	&"roof.tower.chimney.orange",
	&"roof.slim.blue",
	&"roof.slim.orange",
	&"roof.slim.chimney.blue",
	&"roof.slim.chimney.orange",
	&"roof.square.01",
	&"roof.square.02",
	&"roof.square.04",
	&"roof.square.05",
	&"roof.square.blue.dormer.left",
	&"roof.square.blue.dormer.right",
	&"roof.square.orange.dormer.left",
	&"roof.square.orange.dormer.right",
]
const SPACING := Vector2(13.0, 13.0)
const COLUMNS := 4


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_build_environment(world)
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(catalog != null and program != null)
	var payload := EnvironmentInstancePayload.new()
	for index in RECIPE_IDS.size():
		var recipe_value := program.recipe(RECIPE_IDS[index])
		assert(recipe_value != null and recipe_value.is_sealed())
		var column := index % COLUMNS
		var row := index / COLUMNS
		var row_count := ceili(float(RECIPE_IDS.size()) / float(COLUMNS))
		var anchor := Vector3((float(column) - float(COLUMNS - 1) * 0.5) \
			* SPACING.x, 0.0,
			(float(row) - float(row_count - 1) * 0.5) * SPACING.y)
		var anchor_transform := Transform3D(Basis.IDENTITY, anchor)
		for placement: Dictionary in recipe_value.placements:
			payload.add(StringName(placement.asset_id), anchor_transform \
				* (placement.transform as Transform3D), Color.WHITE,
				StringName("%s/%s" % [RECIPE_IDS[index], placement.id]))
		var label := Label3D.new()
		label.text = String(RECIPE_IDS[index]).trim_prefix("roof.")
		label.font_size = 80
		label.pixel_size = 0.0065
		label.outline_size = 12
		label.position = anchor + Vector3(0.0, 6.2, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		world.add_child(label)
	assert(payload.validate())
	var cache := EnvironmentRenderCache.new(catalog)
	assert(cache.prepare(payload.asset_ids()))
	var queue := EnvironmentCommitQueue.new(cache, &"RoofVocabulary")
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, world, payload)
	while queue.pending_count() > 0:
		queue.drain(64)
	for unused in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var output := _argument("--output",
		"/tmp/warren-roof-vocabulary-review.png")
	var image := root.get_texture().get_image()
	assert(image != null and image.save_png(output) == OK)
	print("[roof_vocabulary_review] captured %s" % output)
	quit()


static func _build_environment(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9eacb4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var row_count := ceili(float(RECIPE_IDS.size()) / float(COLUMNS))
	plane.size = Vector2(float(COLUMNS) * SPACING.x + 10.0,
		float(row_count) * SPACING.y + 10.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718d50")
	material.roughness = 1.0
	plane.material = material
	ground.mesh = plane
	world.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 48.0
	var span := maxf(float(COLUMNS) * SPACING.x,
		float(row_count) * SPACING.y)
	camera.position = Vector3(span * 0.75, span * 0.72, span * 0.92)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.8, 0.0))


static func _argument(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
	return fallback
