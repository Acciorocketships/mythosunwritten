extends "res://tests/harness/september11_movement_qa.gd"
const CONTROL_BEFORE := preload("res://tests/fixtures/september11/ControlsBefore.gd")
const CONTROL_AFTER := preload("res://scripts/camera/camera.gd")
var _view: SubViewport

func _run() -> void:
	assert(_frozen,"This control comparison uses the saved native world; live walking is separate")
	await get_tree().create_timer(2.0).timeout
	_camera.set_physics_process(false)
	_camera._visibility.clear()
	_camera.free()
	var world := _character.get_parent().get_parent()
	_view = SubViewport.new()
	_view.size = Vector2i(1920,1080)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	world.reparent(_view)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_character.anim_tree.active = false
	var layer := CanvasLayer.new()
	add_child(layer)
	var display := TextureRect.new()
	display.size = Vector2(1920,1080)
	display.texture = _view.get_texture()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(display)
	var output := _output_dir
	var records := []
	for scenario: String in (["close_mouse"] if OS.get_cmdline_user_args().has("--mouse-only") else ["pin","tactical_strafe","close_mouse","close_strafe"]):
		for before: bool in [true,false]:
			_character.rotation.y = 0.0
			_character.global_position = _spot[2]
			_character.step_visual_offset_y = 0.0
			_character._update_step_visual_smoothing(0.0)
			var eye := ReviewCam.solve_cam(_spot[2],_spot[3],26.0,16.0,1.0)
			_camera = Camera3D.new()
			_camera.set_script(CONTROL_BEFORE if before else CONTROL_AFTER)
			_camera.target = _character
			_camera.position = eye
			_camera.process_mode = Node.PROCESS_MODE_ALWAYS
			world.add_child(_camera)
			_camera.make_current()
			_camera.set_physics_process(false)
			_camera._physics_process(0.0)
			var right := _camera.global_basis.x
			if scenario.begins_with("close"):
				_camera.toggle_view()
				if not before: _camera._release_look()
			_camera.set_process_input(false)
			_camera.set_process_unhandled_input(false)
			for frame in 12:
				_camera._physics_process(.1)
				await get_tree().process_frame
			var samples := []
			var initial_yaw: float = _camera._yaw
			var initial_basis: Basis = _camera.global_basis
			if scenario != "pin":
				for frame in 60:
					if scenario.ends_with("strafe"):
						_character.global_position = Vector3(_spot[2])+right*(frame+1)/15.0
					if scenario == "close_mouse" and frame < 4:
						var motion := InputEventMouseMotion.new()
						motion.relative = Vector2(25,-12.5)
						motion.position = _view.size/2
						if not before:
							_camera._apply_look_motion(motion.relative)
						else:
							_camera._input(motion)
					_camera._physics_process(1.0/60)
					# Keep the frozen actor posed consistently with production mouse aim.
					if not before and scenario.begins_with("close"):
						var facing: Vector2 = _camera.facing_direction(_character.global_position)
						_character.rotation.y = atan2(facing.x,facing.y)
					samples.append({"player":str(_character.global_position),"eye":str(_camera.global_position),"basis":str(_camera.global_basis),"yaw":_camera._yaw})
					await get_tree().process_frame
			if not before and scenario == "close_mouse":
				assert(_camera._yaw < initial_yaw-.03,"Mouse replay must really turn yaw")
				assert((-_camera.global_basis.z).y > (-initial_basis.z).y+.02,"Mouse replay must really turn pitch")
			_output_dir = output.path_join("before" if before else "after")
			DirAccess.make_dir_recursive_absolute(_output_dir)
			await _shot(String(_spot[0])+"_"+scenario)
			records.append({"before":before,"scenario":scenario,"samples":samples,"camera":str(_camera.global_transform),"initial_basis":str(initial_basis)})
			_camera._visibility.clear()
			_camera.free()
	FileAccess.open(output.path_join(String(_spot[0])+"-trajectory.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	_streamer.free()
	get_tree().quit()

func _draw_capture() -> void:
	RenderingServer.force_draw(true)

func _shot(label: String) -> void:
	await get_tree().process_frame
	_draw_capture.call_deferred()
	await RenderingServer.frame_post_draw
	var image := _view.get_texture().get_image()
	assert(image.save_png(_output_dir.path_join(label+".png")) == OK)
	print("CONTROL_CAPTURE ",label," ",_output_dir)
