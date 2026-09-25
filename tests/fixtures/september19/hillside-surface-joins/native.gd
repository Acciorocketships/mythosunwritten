extends SceneTree

func _init() -> void: _run.call_deferred()

func _run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1280,800)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("91adbb")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.7
	root.add_child(env)
	var light:=DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees=Vector3(-45,-30,0)
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	
	var builder:=WaterSurfaceBuilder.new()
	var experiment := "--reaches" in OS.get_cmdline_user_args()
	var water:WaterPlan=preload("res://tests/fixtures/september19/hillside-native-reaches/long_reach_plan.gd").new(2697992464,TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS) if experiment else TerrainWorldTuning.make_water(2697992464)
	print("HILLSIDE_NATIVE experiment=",experiment)
	var geology := TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,geology)
	var fields:=preload("res://tests/fixtures/september19/hillside-surface-joins/candidate_cache.gd").new(plan,water,26,0,64)
	var folder:="res://docs/qa/2026-09-19-manual/114-hillside-surface-joins/after"
	var selected:=PackedStringArray(["P21"])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		if arg.begins_with("--spots="): selected=arg.trim_prefix("--spots=").split(",")
	var poses:Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-16-manual/photo-poses.json"))
	var original_material:=WaterSurfaceBuilder.sheet_material()
	var frozen_shader:=Shader.new()
	frozen_shader.code=original_material.shader.code.replace("TIME","0.0")
	var material := original_material.duplicate(true) as ShaderMaterial
	material.shader=frozen_shader
	material.set_shader_parameter("noise_tex",original_material.get_shader_parameter("noise_tex"))
	WaterSurfaceBuilder._sheet_material=material
	var diagnostic:=StandardMaterial3D.new()
	diagnostic.albedo_color=Color("27aacc")
	diagnostic.cull_mode=BaseMaterial3D.CULL_DISABLED
	for spot:Dictionary in poses:
		if not String(spot.id) in selected: continue
		var feet:=Vector3(spot.player[0],spot.player[1],spot.player[2])
		var crosshair:=Vector3(spot.crosshair[0],spot.crosshair[1],spot.crosshair[2])
		var centre_chunk:=Vector2i((Vector2(feet.x,feet.z)/192).floor())
		var stage: Node3D = load("res://docs/qa/2026-09-19-manual/112-hillside-native-reaches/before/"+spot.id+"/geometry.scn").instantiate()
		# Preserve the exact saved native terrain and its collision. Only the
		# old water meshes are replaced, using the original carving plan above.
		for old: MeshInstance3D in stage.find_children("*","MeshInstance3D",true,false):
			if old.is_in_group("tactical_preserve_surface"): old.free()
		root.add_child(stage)
		var output:=folder.path_join(spot.id)
		DirAccess.make_dir_recursive_absolute(output)
		var records:=[]
		for z in range(-1,2):
			for x in range(-1,2):
				var chunk:=centre_chunk+Vector2i(x,z)
				var region:=fields.region(chunk)
				if experiment and not water.get("rejected_routes").is_empty():
					push_error("NATIVE_REACHES_ABORT: unresolved route; no capture is valid")
					quit(1)
					return
				var field:=fields.water(chunk)
				var skin:=builder.compute_chunk(water,chunk,region,field)
				var sheet:=builder.commit_chunk(skin)
				if sheet!=null: stage.add_child(sheet)
				records.append({"chunk":str(chunk),"water_triangles":0 if skin.is_empty() else skin.arrays[Mesh.ARRAY_INDEX].size()/3})
				print("WATER_NATIVE_CHUNK ",spot.id," ",chunk)
				await process_frame
		if spot.id=="P10":
			var samples: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-19-manual/113-hillside-stable-terrain/supply-P10.json"))[1].samples
			var rows: Array[Dictionary] = []
			for i in range(166,200):
				var sample: Dictionary = samples[i]
				var p := Vector2(sample.x,sample.z)
				rows.append({"index":i,"point":[p.x,p.y],"field":fields.water_at(p).level_at(p),"ground":TerrainSurfaceField.surface_y(fields.region_at(p),p.x,p.y)})
			FileAccess.open("res://docs/qa/2026-09-19-manual/114-hillside-surface-joins/candidate-samples.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
		var snapshot_character := Node3D.new()
		preload("res://tests/harness/september11_snapshot.gd").save(stage,snapshot_character,output.path_join("geometry.scn"))
		snapshot_character.free()
		if "--opaque-water" in OS.get_cmdline_user_args():
			for sheet:MeshInstance3D in stage.find_children("WaterSheet","MeshInstance3D",true,false):
				sheet.material_override=diagnostic
		var target:=feet+Vector3.UP
		# Sub-metre crosshair offsets identify the old elevated camera. Larger
		# separations use its close mouse view. Both retain the reported heading.
		var tactical:=Vector2(feet.x-crosshair.x,feet.z-crosshair.z).length()<1
		var eye:=ReviewCam.solve_cam(feet,crosshair,26,16,1)
		if not tactical:
			target=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
			var backward:=(target-crosshair).normalized()
			eye=ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
				CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
		var cameras:=[]
		for angle:int in [0,-8,8,90]:
			camera.fov=50 if tactical else 75
			camera.position=target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(target)
			cameras.append({"angle":angle,"camera":str(camera.transform),"target":str(target)})
			for frame in 10: await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(output.path_join("view_%d.png"%angle))
		# Independent elevated view exposes actual water support around the pin.
		camera.fov=50
		camera.position=feet+Vector3(50,55,50)
		camera.look_at(feet)
		for frame in 10: await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(output.path_join("overview.png"))
		FileAccess.open(output.path_join("audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"spot":spot,"chunks":records,"cameras":cameras},"  "))
		stage.free()
		await process_frame
	if experiment: water.set("_study",null)
	quit()
