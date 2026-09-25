extends RefCounted
## Frozen geometry/physics from a completely streamed production site. This
## accelerates repeated camera tests; generation and readiness tests stay live.
static func save(world: Node3D, actor: Node3D, path: String) -> void:
	var stage := Node3D.new()
	stage.name = "FrozenVillage"
	for source: Node in world.find_children("*","",true,false):
		if source == actor or actor.is_ancestor_of(source): continue
		var copy: Node
		if source is GeometryInstance3D or source is Light3D or source is FogVolume:
			copy = source.duplicate(Node.DUPLICATE_GROUPS)
			for child: Node in copy.get_children(): child.free()
			copy.set_script(null)
			copy.transform = source.global_transform
		elif source is WorldEnvironment:
			copy = source.duplicate(Node.DUPLICATE_GROUPS)
		elif source is CollisionShape3D and source.get_parent() is StaticBody3D:
			var body := StaticBody3D.new()
			body.collision_layer = source.get_parent().collision_layer
			body.collision_mask = source.get_parent().collision_mask
			for group: StringName in source.get_parent().get_groups():
				body.add_to_group(group, true)
			var shape := CollisionShape3D.new()
			shape.name = source.name
			shape.shape = source.shape
			shape.transform = source.global_transform
			shape.disabled = source.disabled
			body.add_child(shape)
			copy = body
		else: continue
		stage.add_child(copy)
		copy.owner = stage
		for child: Node in copy.get_children(): child.owner = stage
	var globals := {}
	for key: StringName in RenderingServer.global_shader_parameter_get_list():
		globals[key] = RenderingServer.global_shader_parameter_get(key)
	# Runtime bindings differ from project defaults returned by the editor
	# inspection API. Preserve the actual owners' published textures/origins.
	for source: Node in world.find_children("*","",true,false):
		if source is AtmosphereDirector and source._ground_map._maps.size()==3:
			var map: BiomeGroundMap = source._ground_map
			globals[&"biome_ground_a"] = map._maps[0]
			globals[&"biome_ground_b"] = map._maps[1]
			globals[&"biome_ground_color"] = map._maps[2]
			globals[&"biome_ground_origin"] = map._centre-Vector2.ONE*BiomeGroundMap.SPAN*.5
		if source is FieldTerrainStreamer and source._grass_streamer != null:
			var grass: GrassStreamer = source._grass_streamer
			globals[&"grass_lod_origin"] = grass._lod_origin
			globals[&"wind_direction"] = GrassStreamer.WIND_DIRECTION.normalized()
			globals[&"wind_idle_bend"] = GrassStreamer.WIND_IDLE_BEND
			globals[&"wind_gust_texture"] = grass._wind_texture
			globals[&"wind_gust_scale"] = GrassStreamer.WIND_GUST_SCALE
			globals[&"wind_gust_speed"] = GrassStreamer.WIND_GUST_SPEED
			globals[&"wind_gust_bend"] = GrassStreamer.WIND_GUST_BEND
		if source is TrampleField:
			globals[&"grass_trample_texture"] = source._texture
			globals[&"grass_static_trample_texture"] = source._static_texture
			globals[&"grass_trample_origin"] = source._texture_origin
			globals[&"grass_trample_size"] = TrampleField.DOMAIN_SIZE
			globals[&"grass_trample_epoch"] = source._now
	stage.set_meta("shader_globals",globals)
	var packed := PackedScene.new()
	assert(packed.pack(stage)==OK)
	assert(ResourceSaver.save(packed,path)==OK)
	stage.free()
	print("VILLAGE_SNAPSHOT ",path)
