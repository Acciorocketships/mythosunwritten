extends "res://tests/harness/village_reported_qa.gd"
func _spots() -> Array:
	return [["terrain_edge", "Screenshot 2026-09-10 at 7.12.13 PM.png",
		Vector3(-72.9,12.4,-201.4), Vector3(-72.8,13.6,-201.0)]]

func _capture_spot(spot: Array) -> void:
	get_window().size = Vector2i(1920,1156)
	_character.global_position = spot[2]
	_character.anim_tree.active = false
	_camera.fov = 50
	_camera._visibility.clear()
	var solved := ReviewCam.solve_cam(spot[2],spot[3],26.0,16.0,1.0)
	var offset := solved - Vector3(spot[2])
	var bubble := CameraVisibilityBubble.new()
	add_child(bubble)
	for angle in [0.0, -0.14, 0.14]:
		_camera.position = Vector3(spot[2]) + offset.rotated(Vector3.UP, angle)
		_camera.look_at(Vector3(spot[2]) + Vector3.UP)
		for frame in 10: await get_tree().process_frame
		await _shot("terrain_%s_opaque" % angle)
		for frame in 30:
			bubble.update_bubble(_camera, _character, spot[2], 3.8, 0.12, 1.0/30)
			await get_tree().process_frame
		await _shot("terrain_%s_fade" % angle)
		bubble.clear()
	bubble.queue_free()
