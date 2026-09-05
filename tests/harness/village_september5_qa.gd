extends "res://tests/harness/village_reported_qa.gd"

func _spots() -> Array:
	return [
		["stone_joints_facade", "Screenshot 2026-09-05 at 10.57.38 AM.png",
			Vector3(259.8, 5.0, 299.5), Vector3(260.1, 5.2, 299.3)],
		["unsupported_room", "Screenshot 2026-09-05 at 11.00.18 AM.png",
			Vector3(239.0, 17.1, 295.4), Vector3(238.6, 17.3, 295.4)],
		["ground_slopes_path_edges", "Screenshot 2026-09-05 at 10.58.10 AM.png",
			Vector3(308.9, 4.2, 275.5), Vector3(309.1, 4.4, 275.2)],
		["turf_wood_overlap", "Screenshot 2026-09-05 at 10.59.49 AM.png",
			Vector3(239.4, 17.1, 300.1), Vector3(239.6, 17.3, 300.4)],
	]

func _capture_spot(spot: Array) -> void:
	await super._capture_spot(spot)
	var camera_position := ReviewCam.solve_cam(Vector3(spot[2]), Vector3(spot[3]))
	for sample in 4:
		_camera.global_position = camera_position + Vector3(0.015 * (sample % 2), 0, 0)
		_camera.look_at(Vector3(spot[2]), Vector3.UP)
		_camera.force_update_transform()
		for frame in 4:
			await get_tree().process_frame
		await _shot("%s_jitter_%d" % [spot[0], sample])
	if String(spot[0]) == "unsupported_room":
		_camera.global_position = Vector3(232, 8, 281)
		_camera.look_at(Vector3(246, 10, 291), Vector3.UP)
		_camera.force_update_transform()
		for frame in 4:
			await get_tree().process_frame
		await _shot("unsupported_room_ground_contact")
	if String(spot[0]) == "ground_slopes_path_edges":
		_camera.global_position = camera_position
		_camera.look_at(Vector3(spot[2]), Vector3.UP)
		for pixel: Vector2 in [Vector2(330,210), Vector2(420,220), Vector2(500,230)]:
			var ray := _camera.project_ray_normal(pixel)
			var query := PhysicsRayQueryParameters3D.create(camera_position, camera_position + ray * 200)
			print("[slope_probe] ",pixel," ",get_world_3d().direct_space_state.intersect_ray(query))
		var lights := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
		var shadows: Array[bool] = []
		for light: DirectionalLight3D in lights:
			shadows.append(light.shadow_enabled)
			light.shadow_enabled = false
		for frame in 4:
			await get_tree().process_frame
		await _shot("ground_slopes_path_edges_no_shadows")
		for index in lights.size():
			lights[index].shadow_enabled = shadows[index]
