extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1920,1080)
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
	for name: String in ["after"]:
		var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-18-manual/84-cliff-curved-masses/town-soffits/%s-payload.bin" % name,FileAccess.READ).get_var()
		var town := Node3D.new()
		stage.add_child(town)
		town.transform = data.transform
		var payload := EnvironmentInstancePayload.new()
		payload.collision_boxes.assign(data.collision_boxes);payload.surface_meshes.assign(data.surface_meshes)
		var skin:Dictionary=str_to_var(FileAccess.get_file_as_string("res://docs/qa/2026-09-18-manual/83-cliff-fresh-world/town-P02/current-skin.txt"))
		var changed:=0
		for asset:StringName in data.batches:
			var batch:Dictionary=data.batches[asset]
			for i in batch.ids.size():
				var id:String=String(batch.ids[i]);var pose:Transform3D=batch.transforms[i];var chosen:=asset
				if id.begins_with("masonry-joint/"):
					var parts:=id.split("/");var key:=Vector3i(int(parts[1]),int(parts[2]),int(parts[3]))
					var stone_only:=true
					for dx:int in [-1,1]:
						for dz:int in [-1,1]:
							var cell:=Vector3i((key.x+dx)/2,key.y,(key.z+dz)/2)
							if skin.solids.has(cell) and not skin.retained.has(cell):stone_only=false
					if stone_only:
						var width:=SettlementFabricAssembler.STONE_CAP_HALF_DEPTH*2.0
						var bounds:=catalog.descriptor(&"sfv.fabric.wall.rock.corner.s.001").measured_aabb
						var basis:=Basis.from_scale(Vector3(width/bounds.size.x,FabricRecipe.CELL_SIZE/bounds.size.y,width/bounds.size.z))
						pose=Transform3D(basis,pose.origin-basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))
						chosen=&"sfv.fabric.wall.rock.corner.s.001";changed+=1
				payload.add(chosen,pose,batch.colors[i],batch.ids[i],batch.collision_enabled[i])
		print("STONE_JOINT_STUDY replacements=",changed)
		cache.prepare(payload.asset_ids())
		var queue := FeatureCommitQueue.new(cache)
		queue.enqueue(Vector2i.ZERO,1,town,payload)
		while queue.pending_count()>0:
			queue.drain(100000,100000,100000)
			await process_frame
		town.visible = false
		towns.append(town)

	var output := "res://docs/qa/2026-09-18-manual/85-cliff-anchored-stones/town-native-corners"
	DirAccess.make_dir_recursive_absolute(output)
	towns[0].visible=true
	var shots:Array=[
	 ["front",Vector3(-1057,17,1043),Vector3(-1048,12,1065),65.0],
	 ["overhead",Vector3(-1048,45,1050),Vector3(-1048,8,1065),50.0],
	 ["side",Vector3(-1028,16,1057),Vector3(-1048,11,1065),65.0]]
	for shot:Array in shots:
		camera.position=shot[1];camera.look_at(shot[2]);camera.fov=shot[3]
		for frame in 10:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(output.path_join(shot[0]+".png"))
		print("P02_NATIVE ",shot[0])
	quit()
