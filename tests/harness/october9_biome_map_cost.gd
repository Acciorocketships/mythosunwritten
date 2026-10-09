extends SceneTree

func _init() -> void:
	for origin in [Vector2(-1536, -1536), Vector2(-768, -1536)]:
		var started := Time.get_ticks_usec()
		var values := BiomeGroundMap.samples(origin, 2697992464)
		print("BIOME_MAP origin=", origin, " usec=", Time.get_ticks_usec() - started,
			" digest=", hash(values))
	var map := BiomeGroundMap.new()
	map._prepare(Vector2.ZERO, 2697992464)
	var times: Array[int] = []
	var done := false
	while not done:
		var started := Time.get_ticks_usec()
		done = map._prepare(Vector2(768, 0), 2697992464)
		times.append(Time.get_ticks_usec() - started)
	times.sort()
	print("BIOME_MAP_SCROLL frames=", times.size(), " p50_us=", times[times.size() / 2],
		" max_us=", times[-1], " digest=", hash(map._values))
	quit()
