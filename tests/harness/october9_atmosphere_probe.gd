extends RefCounted
func run(review: Node) -> void:
	var director: AtmosphereDirector = review.get_tree().root.find_child("AtmosphereDirector",true,false)
	if director == null:
		print("ATMOSPHERE_PROBE no director")
		return
	director.set_process(false)
	var env := director.environment_node.environment
	var old: Array = review._views.duplicate()
	review._views.clear()
	for point: Vector2 in [Vector2(675,1538),Vector2(650,1550),Vector2(720,1640)]:
		var chunk := FieldTerrainStreamer.chunk_of(Vector3(point.x,0,point.y))
		var ctx: WaterFieldContext = review._streamer._fields.water(chunk)
		var height := TerrainTileField.surface_y(ctx._region,point.x,point.y)
		var pos := Vector3(point.x,height+2.0,point.y)
		review._views.append({"id":"forest_%d" % review._views.size(),"position":pos,"target":pos+Vector3(-30,8,-11),"fov":65.0,"player":pos})
		print("FOG_POSE ",pos)
	var variants := [
		{"id":16,"density":0.02,"scatter":5.0,"ambient":0.05,"sky":0.15},
		{"id":17,"density":0.009,"scatter":3.0,"ambient":0.06,"sky":0.25},
		{"id":18,"density":0.014,"scatter":2.0,"ambient":0.03,"sky":0.10}]
	for v in variants:
		director._mood_weights = {&"deep_forest":1.0}
		director._apply_mood(BiomeRegistry.blend_atmosphere(director._mood_weights))
		director._apply_visual_settings()
		env.volumetric_fog_density = v.density
		env.volumetric_fog_length = 60.0
		env.volumetric_fog_detail_spread = 0.75
		env.volumetric_fog_ambient_inject = v.ambient
		env.volumetric_fog_sky_affect = v.sky
		director.sun.light_volumetric_fog_energy = v.scatter
		print("FOG_STATE ",env.volumetric_fog_enabled," density=",env.volumetric_fog_density," sun=",director.sun.global_basis.z)
		await review._capture_all(v.id)
	review._views.assign(old)
	director.set_process(true)
	print("ATMOSPHERE_PROBE_DONE")
