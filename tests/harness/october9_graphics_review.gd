extends SceneTree
var scene: Node3D
var camera: Camera3D
var director: AtmosphereDirector
var output := "res://docs/qa/2026-10-09-manual-pass"
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	# Read original textures exported from the baseline revision by the QA command.
	# This harness never replaces production textures.
	DirAccess.make_dir_recursive_absolute("/tmp/oct9-roof-before")
	for id in ["173753758685fa88a5cb", "19c539ddc9e7ae32cf6b", "3939f12f65493ec760ed", "e373c53c6944687f9278"]:
		var path := "/tmp/oct9-roof-before/" + id + ".res"
		if not FileAccess.file_exists(path):
			push_error("Run the roof baseline export documented in the QA report first: " + path)
			quit(1)
			return
	root.size = Vector2i(1280,720)
	scene = Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = ProceduralSkyMaterial.new()
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	scene.add_child(sun)
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	director = AtmosphereDirector.new()
	director.environment_node = environment
	director.sun = sun
	director.camera = camera
	scene.add_child(director)
	director._update_mood(0.0, {&"amber_heath":1.0})
	var roof := load("res://terrain/environment/visuals/suntail_village_kit/suntail_roof_roof_1_red.tres") as EnvironmentVisual
	var instances: Array[MeshInstance3D] = []
	for x in 3:
		for piece in roof.pieces:
			var instance := MeshInstance3D.new()
			instance.mesh = piece.mesh
			instance.transform = piece.local_transform
			instance.scale *= 5.0
			instance.position.x += (x-1)*12.0
			scene.add_child(instance)
			instances.append(instance)
	camera.position = Vector3(23,20,44)
	camera.look_at(Vector3(0,4,0))
	for mode in ["before", "after"]:
		for instance in instances:
			for surface in instance.mesh.get_surface_count():
				var material := instance.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
				if mode == "before" and material.resource_name.begins_with("Roof_"):
					for property in ["albedo_texture", "normal_texture"]:
						var texture: Texture2D = material.get(property)
						if texture != null:
							material.set(property, load("/tmp/oct9-roof-before/"+texture.resource_path.get_file()))
				instance.set_surface_override_material(surface, material)
		await _shot("roof_"+mode)
	for instance in instances: instance.free()
	# Exercise all changed shader stages in the real renderer.
	var visual := load("res://terrain/environment/visuals/angry_mesh_meadow/meadow_birch_03_summer.tres") as EnvironmentVisual
	EnvironmentRenderCache._crossfade_tree(visual)
	for piece in visual.pieces:
		var mesh := MeshInstance3D.new()
		mesh.mesh = piece.mesh
		mesh.transform = piece.local_transform
		scene.add_child(mesh)
	var card := MeshInstance3D.new()
	card.mesh = QuadMesh.new()
	card.material_override = EnvironmentCommitQueue.imposter_material(visual.imposter)
	scene.add_child(card)
	EnvironmentCommitQueue.set_imposter_distance(100)
	camera.position = Vector3(0,7,99)
	camera.look_at(Vector3(0,5,0))
	await _shot("tree_after_100m")
	var frontier := preload("res://scripts/terrain/diagnostics/LoadingFrontierFog.gd").new()
	scene.add_child(frontier)
	frontier.update_view(camera, {Vector2i(0,0): true, Vector2i(-1,0):true}, Color("cdb295"))
	await _shot("frontier_shader_check")
	print("GRAPHICS_REVIEW_DONE")
	quit()
func _shot(name: String) -> void:
	for i in 12:
		await process_frame
		RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
