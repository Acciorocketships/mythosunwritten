extends RefCounted
func run(review: Node) -> void:
	var director: AtmosphereDirector = review.get_tree().root.find_child("AtmosphereDirector",true,false)
	director.set_process(false)
	var old: Array = review._views.duplicate()
	review._views.clear()
	var point := Vector2(675,1538)
	var ctx: WaterFieldContext = review._streamer._fields.water(FieldTerrainStreamer.chunk_of(Vector3(point.x,0,point.y)))
	var pos := Vector3(point.x,TerrainTileField.surface_y(ctx._region,point.x,point.y)+2.0,point.y)
	review._views.append({"id":"canopy","position":pos,"target":pos+Vector3(-30,8,-11),"fov":65.0,"player":pos})
	var index := 20
	for biome: StringName in [&"meadow",&"deep_forest",&"twilight_marsh",&"amber_heath",&"jade_wetlands",&"blossom_grove",&"highland"]:
		director._mood_weights = {biome:1.0}
		director._apply_mood(BiomeRegistry.blend_atmosphere(director._mood_weights))
		director._apply_visual_settings()
		await review._capture_all(index)
		print("PRODUCTION_LIGHTING ",index," ",biome)
		index += 1
	review._views.assign(old)
	director.set_process(true)
