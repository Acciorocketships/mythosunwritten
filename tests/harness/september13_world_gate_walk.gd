extends "res://tests/harness/september13_world_gates_qa.gd"

func _walk_corridor(_world: Node3D) -> void:
	var ends: Array
	match _spot[0]:
		# Stop in the public square before its reserved central well/tree.
		"high_gate": ends = [Vector3(-480,40,-384),Vector3(-480,40,-318)]
		"east_gate": ends = [Vector3(144,8,-384),Vector3(234,8,-384)]
		_: ends = [Vector3(-216,8,-864),Vector3(-216,8,-900)]
	var controller := WalkController.new()
	_character.controller = controller
	_character.set_physics_process(false)
	_character.anim_tree.active = true
	var rows := []
	for reverse: bool in [false,true]:
		var start: Vector3 = ends[1] if reverse else ends[0]
		var end: Vector3 = ends[0] if reverse else ends[1]
		var hit := _camera.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(start+Vector3.UP*2,start-Vector3.UP*4,1,[_character.get_rid()]))
		assert(not hit.is_empty(),"The approach begins on physical ground")
		_character.global_position = hit.position+Vector3.UP*.1
		_character.velocity = Vector3.ZERO
		controller.direction = Vector2.ZERO
		for tick in 30:
			await get_tree().physics_frame
			_character._physics_process(1.0/60)
		var trace := []
		var passed := false
		for tick in 1800:
			var p := _character.global_position
			var delta := Vector2(end.x-p.x,end.z-p.z)
			if delta.length()<.35:
				passed = true
				break
			controller.direction = delta.normalized()*.75
			await get_tree().physics_frame
			_character._physics_process(1.0/60)
			if tick%10==0: trace.append({"tick":tick,"position":str(_character.global_position),"floor":_character.is_on_floor()})
		controller.direction = Vector2.ZERO
		rows.append({"reverse":reverse,"passed":passed,"start":str(start),"target":str(end),"end":str(_character.global_position),"trace":trace})
		print("ROAD_GATE_WALK ",_spot[0]," reverse=",reverse," passed=",passed," end=",_character.global_position)
		_camera.global_position = _character.global_position+Vector3(0,16,26)
		_camera.look_at(_character.global_position+Vector3.UP)
		await _shot("gate_walk_%s"%str(reverse))
	FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
