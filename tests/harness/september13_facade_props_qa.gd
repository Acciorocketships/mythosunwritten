extends "res://tests/harness/september13_path_qa.gd"
func _grass_enabled() -> bool:
	return true

func _spots() -> Array:
	return [["P29_props","2026-09-12 12.30.00 PM",Vector3(-247.5,12,-996.5),Vector3(-237.8,15,-972.8)],["P38_props","2026-09-13 5.44.11 PM",Vector3(997.4,26.1,-412.2),Vector3(994.5,26.8,-403.1)],
		["P41_props","2026-09-13 5.45.53 PM",Vector3(1000.4,26.1,-408.4),Vector3(995.9,29.2,-435.2)]]

func _wait_for_site() -> bool:
	if not await super._wait_for_site(): return false
	# Grass has its own visual worker; terrain-worker idleness is insufficient.
	var origin := Vector2(_spot[2].x,_spot[2].z)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 120000:
		var missing := 0
		for tile: Vector2i in GrassStreamer.desired_tiles(origin):
			if GrassStreamer.distance_to_tile(origin,tile) <= 24.0 and not _streamer._grass_streamer._built.has(tile): missing += 1
		if missing == 0: return true
		await get_tree().create_timer(.25).timeout
	push_error("Facade review grass preparation timed out")
	return false
