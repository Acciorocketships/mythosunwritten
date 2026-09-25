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
	var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/september9-east-source.txt"),program).compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	var town:=Node3D.new()
	stage.add_child(town)
	town.transform=Transform3D(Basis.from_scale(Vector3.ONE*2),Vector3(238.5,8.08,-365.5))
	var cache:=EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var queue:=EnvironmentCommitQueue.new(cache,&"FrozenExterior")
	queue.register_chunk(Vector2i.ZERO,1)
	queue.enqueue(Vector2i.ZERO,1,town,payload)
	queue.drain(100000)
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.current=true
	camera.fov=75.0
	var player:=Vector3(268.2,8,-359.4)
	var crosshair:=Vector3(268.2,8.2,-359)
	camera.position=ReviewCam.solve_cam(player,crosshair)
	camera.look_at(player)
	camera.force_update_transform()
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/september10-wall-isolated.png")
	var entries:Array=[]
	for unit:FabricUnit in fabric.units:
		if "house.009" in String(unit.stable_id) or "house.011.part00" in String(unit.stable_id): print("ROOM ",unit.stable_id," ",unit.recipe_id," ",unit.lattice_origin," ",unit.yaw_quarters," suppressed ",unit.suppressed_placement_ids)
	for entry:Dictionary in fabric.expanded_placements():
		var box:AABB=town.transform*entry.bounds
		if box.grow(8).has_point(player):
			entries.append({"id":str(entry.stable_id),"asset":str(entry.asset_id),"bounds":str(box),"transform":str(entry.transform)})
	FileAccess.open("/tmp/september10-wall-isolated.json",FileAccess.WRITE).store_string(JSON.stringify(entries,"  "))
	for pixel:Vector2 in [Vector2(444,325),Vector2(465,380),Vector2(843,230),Vector2(849,170),Vector2(452,250)]:
		var ray:=camera.project_ray_normal(pixel)
		var hits:Array=[]
		for asset:StringName in payload.batches:
			var batch:Dictionary=payload.batches[asset]
			var visual:=cache.visual(asset)
			for j in batch.transforms.size():
				var pose:Transform3D=town.transform*batch.transforms[j]
				var bounds:AABB=pose*catalog.descriptor(asset).measured_aabb
				if bounds.intersects_ray(camera.position,ray)==null:continue
				var nearest:=INF
				for piece:EnvironmentVisualPiece in visual.pieces:
					var faces:=pose*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh)
					for k in range(0,faces.size(),3):
						var hit:Variant=Geometry3D.ray_intersects_triangle(camera.position,ray,faces[k],faces[k+1],faces[k+2])
						if hit!=null:nearest=minf(nearest,camera.position.distance_to(hit))
				if nearest<INF:hits.append([nearest,batch.ids[j],asset])
		hits.sort_custom(func(a,b):return a[0]<b[0])
		print("PIXEL ",pixel," ",hits.slice(0,3))
	quit()
