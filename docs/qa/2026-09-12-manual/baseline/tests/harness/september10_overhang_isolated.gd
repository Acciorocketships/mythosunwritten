extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1718,1035)
	var stage:=Node3D.new()
	root.add_child(stage)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("738080")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=0.8
	stage.add_child(env)
	var light:=DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees=Vector3(-45,-30,0)
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var photo1 := false
	var fixture := "september10-skywalk-source.txt" if photo1 else "september10-stone-source.txt"
	var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/"+fixture),program).compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.terrace_retaining_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan, SettlementFabricAssembler.maze_module_footprints(fabric), SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric), fabric.planned_plaza_cells))
	var town:=Node3D.new()
	stage.add_child(town)
	town.transform=Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE*2),Vector3(481.5,12.08,-2066.5)) if photo1 else Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(1822.5,12.08,-269.5))
	var cache:=EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var queue:=FeatureCommitQueue.new(cache)
	queue.enqueue(Vector2i.ZERO,1,town,payload)
	while queue.pending_count() > 0:
		queue.drain(100000,100000,100000)
		await process_frame
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=75.0
	var player:=Vector3(475,21.1,-2077.8) if photo1 else Vector3(1861.4,16.6,-265.7)
	var crosshair:=Vector3(474.6,21.4,-2077.9) if photo1 else Vector3(1861.8,16.9,-265.7)
	camera.position=ReviewCam.solve_cam(player,crosshair)
	camera.look_at(player)
	camera.force_update_transform()
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var output := args[args.find("--output")+1] if "--output" in args else "/tmp/september10-roof.png"
	root.get_texture().get_image().save_png(output)
	var samples := [Vector2(450,290),Vector2(650,315),Vector2(1000,290)] if photo1 else [Vector2(760,160),Vector2(685,200),Vector2(820,235)]
	for pixel: Vector2 in samples:
		var ray := camera.project_ray_normal(pixel)
		var hits := []
		for mesh: Dictionary in payload.surface_meshes:
			var vertices: PackedVector3Array = mesh.vertices
			var ids: PackedInt32Array = mesh.indices
			var nearest := INF
			for i in range(0,ids.size(),3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(camera.position,ray,town.transform*vertices[ids[i]],town.transform*vertices[ids[i+1]],town.transform*vertices[ids[i+2]])
				if hit!=null: nearest=minf(nearest,camera.position.distance_to(hit))
			if nearest<INF:hits.append([nearest,mesh.stable_id,"generated"])
		for asset: StringName in payload.batches:
			var batch: Dictionary = payload.batches[asset]
			var visual := cache.visual(asset)
			for j in batch.transforms.size():
				var pose: Transform3D = town.transform*batch.transforms[j]
				if (pose*catalog.descriptor(asset).measured_aabb).intersects_ray(camera.position,ray)==null:continue
				var nearest := INF
				for piece: EnvironmentVisualPiece in visual.pieces:
					var faces := EnvironmentBakeGeometry.triangle_faces(piece.mesh,pose*piece.local_transform)
					for i in range(0,faces.size(),3):
						var hit: Variant = Geometry3D.ray_intersects_triangle(camera.position,ray,faces[i],faces[i+1],faces[i+2])
						if hit!=null:nearest=minf(nearest,camera.position.distance_to(hit))
				if nearest<INF:hits.append([nearest,batch.ids[j],asset])
		hits.sort_custom(func(a,b):return a[0]<b[0])
		print("OVERHANG_PIXEL ",pixel," ",hits.slice(0,4))
	if "--nearby" in args:
		var original := camera.position
		for angle in [-30,-12,12,30]:
			camera.position=player+(original-player).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(player)
			for frame in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.get_basename()+"_%d.png"%angle)
	quit()
