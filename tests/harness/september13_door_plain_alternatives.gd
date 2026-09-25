extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,800)
	Engine.max_fps = 30
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("738080")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .8
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees = Vector3(-45,-30,0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 50
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var towns: Array[Node3D] = []
	for name: String in ["before","plain_full","plain_half"]:
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/39-door-panels/before-payload.bin",FileAccess.READ).get_var()
		var town := Node3D.new()
		stage.add_child(town)
		town.transform = data.transform
		if name != "before":
			var id := &"sfv.fabric.wall.wood.door.closed.001"
			cache.prepare([id])
			var source_root: Node = load("res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Door/SFV_Door_Wall_Wooden_001_1.fbx").instantiate()
			var source := EnvironmentBakeGeometry.merge_pieces(source_root,Transform3D.IDENTITY)
			var side_root: Node = load("res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Walls/SFV_Wall_Wooden_M_001.fbx").instantiate()
			var side := EnvironmentBakeGeometry.merge_pieces(side_root,Transform3D.IDENTITY)
			var mesh := EnvironmentBakeGeometry.finish_facade_sides(source,side,.12)
			if false:
				mesh = EnvironmentBakeGeometry.transform_mesh(mesh,Transform3D(Basis(Vector3.RIGHT,Vector3.UP,Vector3.FORWARD),Vector3.ZERO))
			else:
				var plain_root: Node = load("res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Walls/SFV_Wall_Wooden_M_005.fbx").instantiate()
				var plain := EnvironmentBakeGeometry.merge_pieces(plain_root,Transform3D.IDENTITY)
				mesh = EnvironmentBakeGeometry.finish_facade_sides(source,plain,plain.get_aabb().size.z*(1.0 if name == "plain_full" else .5))
				plain_root.free()
			var visual := cache.visual(id).duplicate(true) as EnvironmentVisual
			visual.pieces[0].mesh = mesh
			cache._visuals[id] = visual
			source_root.free()
			side_root.free()
		var payload := preload("res://tests/fixtures/september11/floating_payload.gd").payload(data,false)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count()>0:
			queue.drain(100000,100000,100000)
			await process_frame
		town.visible = false
		towns.append(town)
	await physics_frame
	await physics_frame
	var second := "--p41" in OS.get_cmdline_user_args()
	var feet := Vector3(997.5,26.1,-412.7)
	var target := feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var crosshair := Vector3(993.2,27.2,-415)
	var backward := (target-crosshair).normalized()
	var eye := ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.fov = 75
	var output := "res://docs/qa/2026-09-13-manual/39-door-panels/plain-depth-alternatives"
	output = output.path_join("P37")
	var poses := []
	for angle: int in [0,-8,8]:
		camera.position = CameraObstructionSolver.new().resolve_boom(stage.get_world_3d().direct_space_state,target,target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle)),[])
		camera.look_at(target)
		poses.append({"angle":angle,"camera":str(camera.transform),"target":str(target)})
		for index in towns.size():
			towns[index].visible = true
			for frame in 10: await process_frame
			RenderingServer.force_draw(false)
			var directory := output.path_join(["before","plain_full","plain_half"][index])
			DirAccess.make_dir_recursive_absolute(directory)
			root.get_texture().get_image().save_png(directory.path_join("detail_%d.png"%angle))
			towns[index].visible = false
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()

func _housing(source: ArrayMesh, side: ArrayMesh, depth_scale: float) -> ArrayMesh:
	var box := source.get_aabb()
	var stock := side.get_aabb()
	var assembly := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = EnvironmentBakeGeometry.clip_axis_range(source,Vector3.AXIS_X,box.position.x+.12*.88,box.end.x-.12*.88)
	assembly.add_child(body)
	for sign_value: float in [-1,1]:
		var normal := Vector3.RIGHT*sign_value
		var basis := Basis(Vector3.UP.cross(normal)*box.size.z/stock.size.x,Vector3.UP*box.size.y/stock.size.y,normal*depth_scale)
		var anchor := Vector3(box.end.x if sign_value>0 else box.position.x,box.position.y,box.get_center().z)
		var piece := MeshInstance3D.new()
		piece.mesh = side
		piece.transform = Transform3D(basis,anchor-basis*Vector3(stock.get_center().x,stock.position.y,stock.end.z))
		assembly.add_child(piece)
	var result := EnvironmentBakeGeometry.merge_pieces(assembly,Transform3D.IDENTITY)
	assembly.free()
	return result
