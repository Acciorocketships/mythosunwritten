extends "res://tests/harness/village_reported_qa.gd"
## Current-world integration review for the new framing and visibility bubble.
func _spots() -> Array:
	return [
		["town_ground", "current-world tactical review", Vector3(237.4,8,-370.2), Vector3.ZERO],
		["town_balcony", "current-world tactical review", Vector3(227.1,20.1,-369.7), Vector3.ZERO]
	]

func _capture_spot(spot: Array) -> void:
	_spot = spot
	_character.global_position = spot[2]
	assert(await _wait_for_site())
	_camera._visibility.clear()
	_character.anim_tree.active = false
	var metrics := []
	var support_query := PhysicsRayQueryParameters3D.create(Vector3(spot[2]) + Vector3.UP*0.5,
		Vector3(spot[2]) - Vector3.UP*3.0, 1, [_character.get_rid()])
	var support := get_world_3d().direct_space_state.intersect_ray(support_query)
	print("TACTICAL support: ",support.get("position",Vector3.INF))
	var bubble := CameraVisibilityBubble.new()
	add_child(bubble)
	for angle in [0.0, PI/2, PI, PI*1.5]:
		_camera.global_position = Vector3(spot[2]) + Vector3(0,16,14).rotated(Vector3.UP,angle)
		_camera.look_at(Vector3(spot[2]) + Vector3.UP)
		for frame in 5: await get_tree().process_frame
		await _shot("%s_%d_before" % [spot[0], int(rad_to_deg(angle))])
		for frame in 5:
			bubble.update_bubble(_camera,_character,spot[2],3.8,1.0,1.0/30)
			await get_tree().process_frame
		await _shot("%s_%d_zero" % [spot[0], int(rad_to_deg(angle))])
		var timings := PackedFloat64Array()
		for frame in 30:
			var started := Time.get_ticks_usec()
			bubble.update_bubble(_camera,_character,spot[2],3.8,0.12,1.0/30)
			timings.append(float(Time.get_ticks_usec()-started)/1000.0)
			await get_tree().process_frame
		await _shot("%s_%d_after" % [spot[0], int(rad_to_deg(angle))])
		print("TACTICAL world active: ",bubble._active.size()," materials: ",bubble._materials.size())
		timings.sort()
		metrics.append({"yaw_degrees":rad_to_deg(angle),"components":bubble._active.size(),
			"materials":bubble._materials.size(),"shader_variants":bubble._shaders.size(),
			"update_median_ms":timings[15],"update_p95_ms":timings[28],"update_max_ms":timings[29]})
		bubble.clear()
	var file := FileAccess.open(_output_dir.path_join(String(spot[0])+"_metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"support":str(support.get("position",Vector3.INF)),"views":metrics},"  "))
	bubble.queue_free()
