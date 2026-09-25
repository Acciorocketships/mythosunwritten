extends "res://tests/harness/september12_ground_qa.gd"

func _run() -> void:
	await get_tree().create_timer(5).timeout
	_capture_view = SubViewport.new()
	_capture_view.size = Vector2i(1716,1033)
	_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_capture_view)
	var world := _character.get_parent().get_parent()
	world.reparent(_capture_view)
	_show_capture_view()
	_camera.make_current()
	_camera.set_physics_process(false)
	_camera._visibility.clear()
	_camera._actor_marker.clear()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_character.anim_tree.active = false
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var output := _output_dir
	var eye := ReviewCam.solve_cam(_spot[2],_spot[3],26,16,1)
	var results := []
	for trial in 4:
		var marker := preload("res://scripts/camera/OccludedActor.gd").new()
		add_child(marker)
		var bubble := CameraVisibilityBubble.new()
		add_child(bubble)
		var elapsed: Array[float] = []
		var cpu: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in 150:
			var phase := TAU * float(frame) / 150.0
			_character.global_position = Vector3(_spot[2]) + Vector3(sin(phase)*1.5,maxf(0,sin(phase*2))*2.0,0)
			_character.step_visual_offset_y = 0
			_character._update_step_visual_smoothing(0)
			_camera.global_position = Vector3(_spot[2]) + (eye-Vector3(_spot[2])).rotated(Vector3.UP,sin(phase)*.22)
			_camera.look_at(_character.global_position + Vector3.UP)
			bubble.update_bubble(_camera,_character,_character.global_position,CameraVisibilityBubble.screen_radius(_camera,_character.global_position),.12,.1)
			var start := Time.get_ticks_usec()
			if trial % 2 == 1: marker.update_actor(_camera,_character)
			if frame > 10: cpu.append(float(Time.get_ticks_usec()-start)/1000)
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			if frame > 10: elapsed.append(float(now-previous)/1000)
			previous = now
			if trial >= 2 and frame % 25 == 0:
				_output_dir = output.path_join("marker" if trial == 3 else "solid-ground")
				DirAccess.make_dir_recursive_absolute(_output_dir)
				await _shot("frame_%03d"%frame)
				previous = Time.get_ticks_usec()
		elapsed.sort()
		cpu.sort()
		results.append({"trial":trial,"marker":trial%2==1,"frame_ms_median":elapsed[elapsed.size()/2],"frame_ms_p95":elapsed[int(elapsed.size()*.95)],"cpu_ms_p95":cpu[int(cpu.size()*.95)]})
		print("MARKER_PERF ",results[-1])
		bubble.clear()
		bubble.free()
		marker.free()
	FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	_streamer.free()
	get_tree().quit()
