extends RefCounted

## Save actual generated render nodes after profiling has stopped generation.
## Runtime scripts are omitted; external shaders stay external for comparisons.
static func save_world(world:Node3D,path:String)->Error:
	var copy:=world.duplicate(0) as Node3D
	copy.process_mode=Node.PROCESS_MODE_DISABLED
	_own_children(copy,copy)
	# Godot's global readback API is editor-only. Read the owning adapters once,
	# after measurement, instead of synchronizing with the rendering server.
	var stream:=world.get_node("FieldTerrain") as FieldTerrainStreamer
	var grass:=stream._grass_streamer
	var trample:=stream._trample_field
	var map:BiomeGroundMap=world.get_node("AtmosphereDirector")._ground_map
	var globals:Dictionary={
		"biome_ground_a":map._maps[0],"biome_ground_b":map._maps[1],"biome_ground_color":map._maps[2],
		"biome_ground_origin":map._centre-Vector2.ONE*BiomeGroundMap.SPAN*0.5,
		"grass_lod_origin":grass._lod_origin,"wind_direction":GrassStreamer.WIND_DIRECTION.normalized(),
		"wind_idle_bend":GrassStreamer.WIND_IDLE_BEND,"wind_gust_texture":grass._wind_texture,
		"wind_gust_scale":GrassStreamer.WIND_GUST_SCALE,"wind_gust_speed":GrassStreamer.WIND_GUST_SPEED,
		"wind_gust_bend":GrassStreamer.WIND_GUST_BEND,
		"grass_trample_texture":trample._texture,"grass_static_trample_texture":trample._static_texture,
		"grass_trample_origin":trample._texture_origin,"grass_trample_size":TrampleField.DOMAIN_SIZE,
		"grass_trample_epoch":trample._now}
	copy.set_meta("shader_globals",globals)
	var packed:=PackedScene.new()
	var error:=packed.pack(copy)
	if error==OK:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		error=ResourceSaver.save(packed,path)
	copy.free()
	return error

static func _own_children(node:Node,root:Node)->void:
	for child:Node in node.get_children():
		child.owner=root
		_own_children(child,root)
