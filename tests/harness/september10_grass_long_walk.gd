extends "res://tests/harness/september10_grass_latency.gd"

func _review_sites() -> Array:
	return [{"id":"far_grass", "player":Vector3(-1440,16,-3360),
		"cross":Vector3(-1440,16.2,-3359.7), "ground_snap":true}]

func _walk_review(site_data: Dictionary, camera: Camera3D) -> void:
	var began := Time.get_ticks_msec()
	for second: int in [20,40,46,48,50,54,60,80]:
		while Time.get_ticks_msec()-began < second*1000:
			await get_tree().process_frame
		# Fixed world cameras at the actual traversed corridor, independent of
		# tiny per-run physical timing differences. The player still walks there.
		var focus := Vector3(site_data.player.x,4 if second in [50,54] else 8,site_data.player.z-second*10)
		var shot := {"id":"far_walk", "player":focus, "cross":focus+Vector3(0,.2,.3)}
		await _capture(shot,ReviewCam.solve_cam(shot.player,shot.cross),"t%02d" % second,camera)
