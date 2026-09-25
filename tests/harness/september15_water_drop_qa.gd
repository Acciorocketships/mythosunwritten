extends "res://tests/harness/september15_reported_qa.gd"

var _timed_water: Array[ShaderMaterial] = []

func _freeze_material_clocks(world: Node3D) -> void:
	if "--timed" in OS.get_cmdline_user_args():
		for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
			if not node.is_in_group("tactical_preserve_surface"): continue
			var material:=node.get_active_material(0) as ShaderMaterial
			if material==null or material in _timed_water: continue
			var shader:=Shader.new()
			shader.code=material.shader.code.replace("TIME","review_water_time").replace("shader_type spatial;","shader_type spatial;\nuniform float review_water_time = 0.0;")
			material.shader=shader
			_timed_water.append(material)
	await super._freeze_material_clocks(world)

func _capture_views(world: Node3D) -> void:
	assert(_frozen,"Water geometry comparison retains the frozen production world")
	if "--rebuild-water" in OS.get_cmdline_user_args():
		var material: Material
		for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
			if not node.is_in_group("tactical_preserve_surface"): continue
			if material==null: material=node.get_active_material(0)
			node.free()
		assert(material!=null)
		var water := TerrainWorldTuning.make_water(WORLD_SEED)
		var plan := TerrainWorldTuning.make_heightfield(WORLD_SEED,water)
		var fields := WorldFieldBlockCache.new(plan,water,26,0,64)
		var builder := WaterSurfaceBuilder.new()
		var centre := FieldTerrainStreamer.chunk_of(_spot[2])
		var worker := Thread.new()
		worker.start(func() -> Array:
			var payloads:=[]
			for z in range(-1,2):
				for x in range(-1,2):
					var chunk:=centre+Vector2i(x,z)
					payloads.append(builder.compute_chunk(water,chunk,fields.region(chunk),fields.water(chunk)))
			return payloads)
		while worker.is_alive(): await get_tree().process_frame
		var payloads: Array=worker.wait_to_finish()
		for payload: Dictionary in payloads:
			var node:=builder.commit_chunk(payload)
			if node==null:continue
			world.add_child(node)
			for sheet:MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
				sheet.material_override=material
		print("DROP_WATER_REBUILT ",payloads.size())
	await super._capture_views(world)

func _shot(label: String) -> void:
	if label=="P10_0":
		var records:=[]
		for pixel:Vector2 in [Vector2(300,280),Vector2(350,285),Vector2(380,285),Vector2(880,300),Vector2(960,300)]:
			var origin:=_camera.project_ray_origin(pixel)
			var query:=PhysicsRayQueryParameters3D.create(origin,origin+_camera.project_ray_normal(pixel)*200)
			query.exclude=[_character.get_rid()]
			var hit:=_camera.get_world_3d().direct_space_state.intersect_ray(query)
			records.append({"pixel":str(pixel),"position":str(hit.get("position",Vector3.INF))})
		FileAccess.open(_output_dir.path_join("rays.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	if _timed_water.is_empty():
		await super._shot(label)
	else:
		for time:float in [0.0,1.75,4.25]:
			for material:ShaderMaterial in _timed_water: material.set_shader_parameter("review_water_time",time)
			await super._shot(label+"_t"+str(roundi(time*100)))
