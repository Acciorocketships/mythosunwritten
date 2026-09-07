extends SceneTree

## Fast geometric diagnosis only. Final acceptance uses village_reported_qa's
## streamed terrain and matched cameras, not this isolated construction view.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920,1080)
	Engine.max_fps = 30
	var stage := Node3D.new()
	root.add_child(stage)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	for child in world.get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			world.remove_child(child)
			stage.add_child(child)
	world.free()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464,Vector2i(11,12))
	var spatial := WarrenVolumetricSolver.solve(seed_value,{},program,WarrenVillageScaleProfile.select(seed_value))
	var plan := spatial.compiled_fabric_cache()
	var town := Node3D.new()
	town.transform = Transform3D(Basis(Vector3.UP,PI*0.5).scaled(Vector3.ONE*2),Vector3(268.5,5.08,309.5))
	stage.add_child(town)
	for placement: Dictionary in plan.expanded_placements():
		var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
		for piece: EnvironmentVisualPiece in visual.pieces:
			var mesh := MeshInstance3D.new()
			mesh.mesh = piece.mesh
			mesh.material_override = piece.material_override
			mesh.transform = (placement.transform as Transform3D) * piece.local_transform
			mesh.set_meta("owner",placement.stable_id)
			town.add_child(mesh)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	var output := "/tmp/village-facade-isolation"
	DirAccess.make_dir_recursive_absolute(output)
	for spot: Array in [["door",Vector3(282.9,5,305.1),Vector3(282.6,5.2,305.3)], ["upper",Vector3(258.8,27.6,306.3),Vector3(258.4,27.9,306.2)]]:
		camera.position = ReviewCam.solve_cam(spot[1],spot[2])
		camera.look_at(spot[1],Vector3.UP)
		for frame in 10: await process_frame
		RenderingServer.force_draw()
		await process_frame
		root.get_texture().get_image().save_png(output+"/"+spot[0]+".png")
		print("ISOLATED ",spot[0]," camera=",camera.position)
		if spot[0] == "door":
			for pixel: Vector2 in [Vector2(1490,390),Vector2(1570,310),Vector2(1550,450)]:
				var ray := camera.project_ray_normal(pixel)
				for mesh: MeshInstance3D in town.get_children():
					var bounds := mesh.global_transform * mesh.mesh.get_aabb()
					if bounds.intersects_ray(camera.position,ray) != null:
						print("RAY ",pixel," owner=",mesh.get_meta("owner")," bounds=",bounds)
	quit()
