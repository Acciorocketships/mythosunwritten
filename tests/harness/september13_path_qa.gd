extends "res://tests/harness/september13_visibility_qa.gd"

func _spots() -> Array:
	return [["P04_barrier","2026-09-12 12.00.30 PM",Vector3(-222.4,17.7,-958.4),Vector3(-222.4,19.2,-954.7)]]

func _run() -> void:
	await get_tree().create_timer(5).timeout
	var world := _character.get_parent().get_parent()
	if _frozen:
		_capture_view = SubViewport.new()
		_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_view)
		world.reparent(_capture_view)
		_show_capture_view()
		_camera.make_current()
	_capture_view.size = Vector2i(1716,1033)
	if _frozen:
		var lighting := (load("res://docs/qa/2026-09-13-manual/02-background/enclosure/P33_background/world.scn") as PackedScene).instantiate()
		for node: Node in world.find_children("*","",true,false):
			if node is WorldEnvironment or node is DirectionalLight3D: node.free()
		for node: Node in lighting.get_children():
			if node is WorldEnvironment or node is DirectionalLight3D:
				lighting.remove_child(node)
				world.add_child(node)
		lighting.free()
	_camera = _capture_view.get_camera_3d()
	_camera.set_physics_process(false)
	_camera._visibility.clear()
	_character.set_physics_process(false)
	_character.global_position = _spot[2]
	if not _frozen:
		assert(await _wait_for_site())
		preload("res://tests/harness/september11_snapshot.gd").save(world,_character,_output_dir.path_join("world.scn"))
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	_camera._visibility.clear()
	for body: Node in world.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.visible = false
	_character.anim_tree.active = false
	_freeze_material_clocks(world)
	_character.global_position = _spot[2]
	_character.step_visual_offset_y = 0
	_character._update_step_visual_smoothing(0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var feet: Vector3 = _spot[2]
	var crosshair: Vector3 = _spot[3]
	var space := _camera.get_world_3d().direct_space_state
	var obstruction := CameraObstructionSolver.new()
	var excluded: Array[RID] = [_character.get_rid()]
	var pivot := obstruction.resolve_ceiling(space,feet,1.0,CameraMouseView.PIVOT_HEIGHT,excluded)
	var backward := (pivot-crosshair).normalized()
	var eye := ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		pivot.y-feet.y+backward.y*CameraMouseView.BOOM_LENGTH,pivot.y-feet.y)
	var rays := []
	for x: float in [-223.4,-222.9,-222.4,-221.9,-221.4]:
		for z: float in [-958.4,-957.4,-956.4,-955.4,-954.4,-953.4,-952.4,-951.4]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x,22,z),Vector3(x,10,z),1,excluded)
			var hit := space.intersect_ray(query)
			if not hit.is_empty(): rays.append({"x":x,"z":z,"point":str(hit.position),"normal":str(hit.normal),"body":str(hit.collider.get_path())})
	for y: float in [17.8,18.3,18.8,19.3,19.8]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-222.4,y,-958.4),Vector3(-222.4,y,-950.4),1,excluded))
		if not hit.is_empty(): rays.append({"y":y,"point":str(hit.position),"normal":str(hit.normal),"body":str(hit.collider.get_path())})
	FileAccess.open(_output_dir.path_join("rays.json"),FileAccess.WRITE).store_string(JSON.stringify(rays,"  "))
	var poses := []
	var wide := "--wide" in OS.get_cmdline_user_args()
	var tactical := "--tactical" in OS.get_cmdline_user_args()
	if wide or tactical:
		eye = ReviewCam.solve_cam(feet,crosshair,26,16,1)
		pivot = feet+Vector3.UP
	for angle: float in ([0,-30,30,90,180,-90] if wide else [0,-8,8]):
		_camera.fov = 50 if wide or tactical else 75
		var desired := pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle))
		_camera.global_position = desired if wide or tactical else obstruction.resolve_boom(space,pivot,desired,excluded)
		_camera.look_at(pivot)
		poses.append({"angle":angle,"camera":str(_camera.global_transform),"pivot":str(pivot),"fov":_camera.fov,"feet":str(feet),"crosshair":str(crosshair)})
		await _shot("%s_%d"%[_spot[0],int(angle)])
	FileAccess.open(_output_dir.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	if "--walk" in OS.get_cmdline_user_args(): await _walk_corridor(world)
	if _frozen: _streamer.free()
	get_tree().quit()

class WalkController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2:
		return direction

func _walk_corridor(world: Node3D) -> void:
	var controller := WalkController.new()
	_character.controller = controller
	_character.set_physics_process(false)
	_character.anim_tree.active = true
	var reports := []
	for sign_value: float in [-1,1]:
		for offset: float in [-.7,0,.7]:
			var start_z := -958.4 if sign_value > 0 else -952.5
			var end_z := -952.5 if sign_value > 0 else -958.4
			_character.global_position = Vector3(-222.4+offset,17.72999+(start_z+958.4)*.25+.1,start_z)
			_character.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			var start := _character.global_position
			var trace := []
			controller.direction = Vector2(0,sign_value)*.55
			var passed := false
			for tick in 180:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				trace.append({"tick":tick,"x":_character.global_position.x,"y":_character.global_position.y,"z":_character.global_position.z,"floor":_character.is_on_floor()})
				if (_character.global_position.z-end_z)*sign_value >= 0:
					passed = true
					break
			controller.direction = Vector2.ZERO
			reports.append({"direction":sign_value,"offset":offset,"start":str(start),"end":str(_character.global_position),"passed":passed,"trace":trace})
			print("PATH_WALK direction=",sign_value," offset=",offset," passed=",passed)
			await _shot("walk_%d_%d"%[int(sign_value),roundi(offset*10)])
	FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
