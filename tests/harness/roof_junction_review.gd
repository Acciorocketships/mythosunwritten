extends SceneTree

## Commits one production-classified modular T-junction from the same sealed
## recipes used by towns. This catches handedness, doubled gables, and valley
## gaps that topology tests cannot see.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_build_environment(world)
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	var proposals: Array[Dictionary] = [
		{"stable_id": &"host", "kind": &"building", "origin": Vector3i.ZERO,
			"yaw_quarters": 0, "storeys": 2, "route_y": 0},
		{"stable_id": &"branch", "kind": &"long", "origin": Vector3i(5, 0, -1),
			"yaw_quarters": 1, "storeys": 2, "route_y": 0},
	]
	var topology := FabricRoofTopologyPlan.build(proposals)
	assert(topology != null and WarrenAssetCompiler._assign_neighborhood_styles(
		proposals, topology, 701))
	var payload := EnvironmentInstancePayload.new()
	for proposal: Dictionary in proposals:
		for component: Dictionary in StaggeredFabricCompiler.proposal_components(
				proposal):
			if StringName(component.role) != &"roof":
				continue
			var recipe_value := program.recipe(StringName(component.recipe_id))
			assert(recipe_value != null)
			var component_transform := FabricRecipe.lattice_transform(
				component.origin as Vector3i, int(component.yaw_quarters))
			# Bring the isolated roof junction down to the review ground plane.
			component_transform.origin.y -= 6.0
			for placement: Dictionary in recipe_value.placements:
				payload.add(StringName(placement.asset_id), component_transform \
					* (placement.transform as Transform3D), Color.WHITE,
					StringName("%s/%s" % [proposal.stable_id, placement.id]))
			print("[roof_junction_review] %s -> %s" % [proposal.stable_id,
				component.recipe_id])
	assert(payload.validate())
	var cache := EnvironmentRenderCache.new(catalog)
	assert(cache.prepare(payload.asset_ids()))
	var queue := EnvironmentCommitQueue.new(cache, &"RoofJunction")
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, world, payload)
	while queue.pending_count() > 0:
		queue.drain(64)
	var camera := Camera3D.new()
	camera.fov = 46.0
	camera.position = Vector3(20.0, 17.0, 24.0)
	world.add_child(camera)
	camera.look_at(Vector3(3.5, 1.5, -0.5))
	for unused in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var output := _argument("--output", "/tmp/warren-roof-junction-review.png")
	var captured := root.get_texture().get_image()
	assert(captured != null and captured.save_png(output) == OK)
	print("[roof_junction_review] captured %s" % output)
	quit()


static func _build_environment(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a6b4bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.75
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(35.0, 30.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718d50")
	material.roughness = 1.0
	plane.material = material
	ground.mesh = plane
	world.add_child(ground)


static func _argument(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
	return fallback
