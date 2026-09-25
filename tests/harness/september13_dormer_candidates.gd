extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1000,700)
	Engine.max_fps = 30
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a6b4bd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .72
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40
	world.add_child(camera)
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var output := "res://docs/qa/2026-09-13-manual/41-dormers/alternatives"
	DirAccess.make_dir_recursive_absolute(output)
	for kind: String in ["tower","square"]:
		var recipe := program.recipe(StringName("roof.%s.orange.dormer.right"%kind))
		for radial: float in ([-.6,-.4,-.2] if kind=="tower" else [-.2,0,.2]):
			for rise: float in ([-.2,0,.2] if kind=="tower" else [0,.2,.4]):
				var construction := Node3D.new()
				world.add_child(construction)
				var dormer_pose := Transform3D.IDENTITY
				for placement: Dictionary in recipe.placements:
					var visual := load(catalog.descriptor(placement.asset_id).visual_path) as EnvironmentVisual
					var pose: Transform3D = placement.transform
					if str(placement.id).contains("dormer"):
						dormer_pose = pose
						pose.origin += (pose.basis*Vector3.BACK).normalized()*radial+Vector3.UP*rise
					for piece: EnvironmentVisualPiece in visual.pieces:
						var mesh := MeshInstance3D.new()
						mesh.mesh = piece.mesh
						mesh.transform = pose*piece.local_transform
						mesh.material_override = piece.material_override
						construction.add_child(mesh)
				var target := dormer_pose.origin+Vector3.UP*.8
				var outward := (dormer_pose.basis*Vector3.BACK).normalized()
				var side := Vector3(outward.z,0,-outward.x)
				for view: String in ["front","oblique","side"]:
					var dir := outward if view=="front" else ((outward+side).normalized() if view=="oblique" else side)
					camera.position = target+dir*6+Vector3.UP*(1.2 if view!="side" else .4)
					camera.look_at(target)
					for frame in 4: await process_frame
					RenderingServer.force_draw()
					await process_frame
					root.get_texture().get_image().save_png(output.path_join("%s-r%d-y%d-%s.png"%[kind,roundi(radial*100),roundi(rise*100),view]))
				construction.free()
	quit()
