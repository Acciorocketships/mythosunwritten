extends "res://tests/harness/september13_visibility_qa.gd"
func _spots()->Array:
	return [["south_road","road restoration",Vector3(-216,8,-864),Vector3(-216,9.2,-865)],
		["high_road","road restoration",Vector3(-480,40,-456),Vector3(-480,41.2,-457)],
		["east_road","road restoration",Vector3(96,8,-384),Vector3(97,9.2,-384)]]
func _run()->void:
	await get_tree().create_timer(5).timeout
	_camera = _capture_view.get_camera_3d()
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	_camera._visibility.clear()
	var world := _character.get_parent().get_parent()
	var rows: Array = []
	for spot: Array in ([_spot] if OS.get_cmdline_user_args().has("--single") else _spots()):
		_spot = spot
		world.process_mode = Node.PROCESS_MODE_INHERIT
		_character.set_physics_process(false)
		_character.global_position = spot[2]
		print("ROAD_WAIT ",spot[0])
		assert(await _wait_for_site())
		_character.set_physics_process(false)
		_camera._visibility.clear()
		for body:Node in world.find_children("*","CollisionObject3D",true,false):
			body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		world.process_mode = Node.PROCESS_MODE_DISABLED
		_character.anim_tree.active = false
		var feet:Vector3 = spot[2]
		var hit := _camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*50,feet-Vector3.UP*50,1,[_character.get_rid()]))
		if not hit.is_empty(): feet.y = hit.position.y
		_character.global_position = feet
		_character.step_visual_offset_y = 0
		_character._update_step_visual_smoothing(0)
		var target := feet + Vector3(spot[3])-Vector3(spot[2])
		var eye := ReviewCam.solve_cam(feet,target,26,16,1)
		var site_dir := _output_dir.path_join(spot[0])
		DirAccess.make_dir_recursive_absolute(site_dir)
		preload("res://tests/harness/september11_snapshot.gd").save(world,_character,site_dir.path_join("world.scn"))
		var output := _output_dir
		_output_dir = site_dir
		for angle:float in [0,-12,12]:
			_camera.global_position = feet+(eye-feet).rotated(Vector3.UP,deg_to_rad(angle))
			_camera.look_at(feet+Vector3.UP)
			rows.append({"spot":spot[0],"feet":str(feet),"target":str(target),"angle":angle,"camera":str(_camera.global_transform)})
			await _shot("road_%d"%int(angle))
		_output_dir = output
	FileAccess.open(_output_dir.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	get_tree().quit()
