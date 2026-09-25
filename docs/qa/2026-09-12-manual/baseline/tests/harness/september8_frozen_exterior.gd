extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size=Vector2i(1920,1080)
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
	var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program).compiled_fabric_cache()
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
	for spot in [["03",Vector3(232.4731,19.1,-350.3636),Vector3(236.9,14.1,-343.7)],
		["04",Vector3(244.6452,13,-376.1599),Vector3(242.7,8,-368.4)],
		["09",Vector3(222.9064,17.3,-322.2),Vector3(222.9,12.3,-330.2)]]:
		camera.position=spot[1]
		camera.look_at(spot[2])
		camera.force_update_transform()
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/september8-frozen-%s.png"%spot[0])
		if spot[0]=="09":
			for pixel in [Vector2(1250,180),Vector2(1240,385),Vector2(1080,245)]:
				var ray:=camera.project_ray_normal(pixel)
				var hits:Array=[]
				for asset:StringName in payload.batches:
					var batch:Dictionary=payload.batches[asset]
					var visual:=cache.visual(asset)
					for j in batch.transforms.size():
						var pose:Transform3D=town.transform*batch.transforms[j]
						var bounds:AABB=pose*catalog.descriptor(asset).measured_aabb
						if bounds.intersects_ray(camera.position,ray)==null: continue
						var nearest:=INF
						for piece:EnvironmentVisualPiece in visual.pieces:
							var faces:=pose*piece.local_transform*piece.mesh.get_faces()
							for k in range(0,faces.size(),3):
								var hit=Geometry3D.ray_intersects_triangle(camera.position,ray,faces[k],faces[k+1],faces[k+2])
								if hit!=null: nearest=minf(nearest,camera.position.distance_to(hit))
						if nearest<INF: hits.append([nearest,batch.ids[j],asset])
				hits.sort_custom(func(a,b):return a[0]<b[0])
				print("SURFACE ",pixel," ",hits.slice(0,4))
	quit()
