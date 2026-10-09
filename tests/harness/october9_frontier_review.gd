extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("a8bac5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.4
	env.environment.volumetric_fog_enabled = true
	env.environment.volumetric_fog_density = 0.0
	env.environment.volumetric_fog_length = 192.0
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45,-25,0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	camera.look_at_from_position(Vector3(90,16,90),Vector3(230,0,230))
	var fog_color := Color("a8bac5")
	var loaded := {Vector2i.ZERO:true, Vector2i.RIGHT:true, Vector2i.DOWN:true}
	for key: Vector2i in loaded:
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size=Vector2(192,192)
		ground.mesh=plane
		ground.position=Vector3(key.x*192+96,0,key.y*192+96)
		var material := StandardMaterial3D.new()
		material.albedo_color=Color("709a4a")
		material.roughness=1
		ground.material_override=material
		scene.add_child(ground)
		for i in 5:
			var stone := MeshInstance3D.new()
			stone.mesh=BoxMesh.new()
			stone.scale=Vector3(5,8,5)
			stone.position=ground.position+Vector3((i-2)*26,4,20)
			scene.add_child(stone)
	var fog := preload("res://scripts/terrain/diagnostics/LoadingFrontierFog.gd").new()
	scene.add_child(fog)
	fog.update_view(camera,loaded,fog_color)
	var current: Shader = fog._material.shader
	var old := Shader.new()
	old.code=FileAccess.get_file_as_string("res://docs/qa/2026-10-09-manual-pass/frontier-baseline.gdshader")
	for mode in ["before","after"]:
		fog._material.shader=old if mode=="before" else current
		fog._volume.visible=mode=="after"
		fog.update_view(camera,loaded,fog_color)
		for i in 24:
			await process_frame
			RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/qa/2026-10-09-manual-pass/frontier_"+mode+".png")
	print("FRONTIER_REVIEW_DONE")
	quit()
