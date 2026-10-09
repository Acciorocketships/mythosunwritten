extends RefCounted
func run(review: Node) -> void:
	var director: AtmosphereDirector = review.find_child("AtmosphereDirector",true,false)
	if director == null:
		for node in review.find_children("*","",true,false):
			if node is AtmosphereDirector: director = node; break
	assert(director != null)
	var env := director.environment_node.environment
	print("LIGHT_BEFORE white=",env.tonemap_white," glow=",env.glow_strength," normalized=",env.glow_normalized)
	env.glow_normalized = true
	env.glow_strength = .6
	env.tonemap_white = 2.0
	for settings in director.biome_visual_settings:
		settings.bloom *= .2
		settings.glow_threshold = maxf(settings.glow_threshold,1.5)
	director._apply_visual_settings()
	await review._capture_all(1)
	print("LIGHT_TRIAL_DONE")
