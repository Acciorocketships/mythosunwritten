extends "res://tests/harness/september11_bubble_qa.gd"

func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = _capture_view.get_camera_3d() if _capture_view != null else get_viewport().get_camera_3d()
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	if not _frozen:
		print("FLOATING_WAIT_SITE")
		assert(await _wait_for_site())
	_character.set_physics_process(false)
	_camera._visibility.clear()
	var world := _character.get_parent().get_parent()
	if not _frozen:
		preload("res://tests/harness/september11_snapshot.gd").save(world, _character,
			_output_dir.path_join("village.scn"))
	if _capture_view == null:
		_capture_view = SubViewport.new()
		_capture_view.size = Vector2i(1920,1080)
		_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_view)
		_show_capture_view()
		world.reparent(_capture_view)
		_camera.make_current()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_character.anim_tree.active = false
	var persistent_bubble := OS.get_cmdline_user_args().has("--persistent-bubble")
	var shared_bubble: CameraVisibilityBubble = _camera._visibility
	var poses: Array[Dictionary] = []
	for spot: Array in _spots():
		_character.global_position = spot[2]
		_character.step_visual_offset_y = 0.0
		_character._update_step_visual_smoothing(0.0)
		var eye := ReviewCam.solve_cam(spot[2],spot[3],26,16,1)
		for angle: float in [0.0,-8.0,8.0]:
			_camera.global_position = Vector3(spot[2])+(eye-Vector3(spot[2])).rotated(Vector3.UP,deg_to_rad(angle))
			_camera.look_at(Vector3(spot[2])+Vector3.UP)
			poses.append({"spot":spot[0], "angle":angle, "camera":str(_camera.global_transform)})
			var bubble := shared_bubble if persistent_bubble else CameraVisibilityBubble.new()
			if not persistent_bubble: add_child(bubble)
			for frame in 30:
				bubble.update_bubble(_camera,_character,spot[2],CameraVisibilityBubble.screen_radius(_camera,spot[2]),.12,.1)
				await get_tree().process_frame
			await _shot("%s_%d" % [spot[0],int(angle)])
			if not persistent_bubble:
				bubble.clear()
				bubble.free()
	shared_bubble.clear()
	FileAccess.open(_output_dir.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	if _frozen: _streamer.free()
	get_tree().quit()
