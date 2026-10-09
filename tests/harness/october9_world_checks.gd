extends RefCounted
func run(review: Node) -> void:
	var streamer = review._streamer
	var director: AtmosphereDirector = review.find_child("AtmosphereDirector", true, false)
	director.camera = review._camera
	print("WORLD_CHECK start loaded=", streamer._built.size())
	# At a missing eastern neighbour, repeated input must stop, slide, retreat.
	var c: Vector2i = streamer._built.keys()[0]
	for key: Vector2i in streamer._built:
		if not streamer._built.has(key+Vector2i.RIGHT):
			c=key
			break
	var start := Vector3((c.x+1)*192-2,100,c.y*192+96)
	var stopped: Vector3 = streamer._guard_player_motion(start,start+Vector3(8,0,0))
	var retreat: Vector3 = streamer._guard_player_motion(stopped,stopped-Vector3(5,0,0))
	assert(stopped.x < (c.x+1)*192)
	assert(retreat.x < stopped.x-4.9)
	print("WORLD_BOUNDARY stopped=",stopped," retreat=",retreat," frozen=",streamer._player_frozen)
	# Compare lighting with identical geometry and camera, then each biome's art controls.
	var old_settings := director.biome_visual_settings
	var old_mood: Dictionary = director._mood_weights.duplicate()
	for mode in ["before", "after"]:
		director.set_process(false)
		if mode == "before":
			director.biome_visual_settings = []
			director._apply_grade()
			director._apply_mood(BiomeRegistry.blend_atmosphere(old_mood))
		else:
			director.biome_visual_settings = old_settings
			director._apply_visual_settings()
		director._frontier.update_view(review._camera,streamer._built,director.frontier_color())
		await review._capture_all(30 if mode=="before" else 31)
	director.biome_visual_settings = old_settings
	director.set_process(true)
	print("WORLD_CHECK_DONE")
