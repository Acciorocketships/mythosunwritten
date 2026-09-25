extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1920,1080)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("91adbb")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.65
	root.add_child(environment)
	var light:=DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees=Vector3(-45,-30,0)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	camera.fov=50
	var mesher:=TerrainChunkMesher.new()
	mesher.set_seed(2697992464)
	mesher.prepare_resources()
	var water_builder:=WaterSurfaceBuilder.new()
	var folder:="res://docs/qa/2026-09-11-manual/12-landforms/water-landmarks/"
	var poses:Array[Dictionary]=[]
	for phase:String in ["before","after"]:
		var water:=preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd").make_water(2697992464) if phase=="before" else TerrainWorldTuning.make_water(2697992464)
		var plan:=preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd").make_heightfield(2697992464,water) if phase=="before" else TerrainWorldTuning.make_heightfield(2697992464,water)
		var fields:=WorldFieldBlockCache.new(plan,water,26,0)
		for site:int in 2:
			var point:=Vector2(-1146.394,1874.850) if site==0 else Vector2(-1316.635,-354.345)
			var center_chunk:=Vector2i((point/192).floor())
			var stage:=Node3D.new()
			root.add_child(stage)
			for z in range(-1,2):
				for x in range(-1,2):
					var chunk:=center_chunk+Vector2i(x,z)
					var region:=fields.region(chunk)
					var field:=fields.water(chunk)
					stage.add_child(mesher.commit_chunk(mesher.compute_chunk(chunk,region,field)))
					var sheet:=water_builder.commit_chunk(water_builder.compute_chunk(water,chunk,region,field))
					if sheet!=null: stage.add_child(sheet)
					await process_frame
			var output:=folder+phase
			DirAccess.make_dir_recursive_absolute(output)
			var target:=Vector3(point.x,6 if site==0 else 20,point.y)
			for height:float in ([90,170] if site==0 else [35,80]):
				for angle:float in [-35,0,35]:
					var distance:=140.0 if site==0 else 85.0
					camera.position=target+Vector3(distance,height,distance).rotated(Vector3.UP,deg_to_rad(angle))
					camera.look_at(target)
					var id:="%d_%d_%d" % [site,height,angle]
					if phase=="before": poses.append({"id":id,"camera":str(camera.transform)})
					for frame in 10: await process_frame
					_draw.call_deferred()
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(id+".png"))
			FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
			stage.queue_free()
			await process_frame
	quit()

func _draw() -> void: RenderingServer.force_draw(true)
