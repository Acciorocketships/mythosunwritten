extends RefCounted

func run(review: Node) -> void:
	var before := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	for visual: EnvironmentVisual in review._streamer._environment_cache._visuals.values():
		preload("res://scripts/terrain/environment/EnvironmentTextureSharing.gd").prepare(visual)
	await review._capture_all(4)
	await review.get_tree().create_timer(2.0).timeout
	preload("res://tests/harness/october9_live_texture_inventory.gd").new().run(review)
	print("TEXTURE_SHARING_TRIAL_DONE before=",before," after=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
