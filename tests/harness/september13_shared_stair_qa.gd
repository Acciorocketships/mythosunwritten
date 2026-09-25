extends "res://tests/harness/september13_path_qa.gd"
func _spots() -> Array:
	return [["P07_platform","2026-09-12 12.02.18 PM",Vector3(-225.8,14.1,-977.8),Vector3(-226,15.4,-978.1)],
		["P07_entry","connection detail",Vector3(-222,14.1,-976),Vector3(-222,17.8,-964)]]

func _walk_corridor(_world: Node3D) -> void:
	var controller := WalkController.new()
	_character.controller = controller
	_character.set_physics_process(false)
	var routes := []
	for offset: float in [-2,-1,0,1,2]:
		routes.append([Vector3(-222+offset,14.08,-976),Vector3(-222+offset,17.08,-964)])
		routes.append([Vector3(-234,14.08,-964+offset),Vector3(-222,17.08,-964+offset)])
	routes.append([Vector3(-222,14.08,-976),Vector3(-222,17.08,-964),Vector3(-234,14.08,-964)])
	var results := []
	for route_index in routes.size():
		for reverse in [false,true]:
			var route: Array = routes[route_index].duplicate()
			if reverse: route.reverse()
			_character.global_position = route[0]+Vector3.UP*.1
			_character.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			var trace := []
			var passed := true
			for leg in range(1,route.size()):
				var target: Vector3 = route[leg]
				var delta: Vector3 = target-route[leg-1]
				var direction := Vector2(delta.x,delta.z).normalized()
				controller.direction = direction*.55
				var reached := false
				for tick in 360:
					await get_tree().physics_frame
					_character._physics_process(1.0/60)
					trace.append(str(_character.global_position))
					var remain := target-_character.global_position
					if Vector2(remain.x,remain.z).dot(direction)<=.15 and absf(remain.y)<.5:
						reached = true
						break
				if not reached:
					passed=false
					break
			controller.direction=Vector2.ZERO
			results.append({"route":str(route),"passed":passed,"end":str(_character.global_position),"trace":trace})
			print("SHARED_STAIR_WALK ",route_index," ",reverse," ",passed," ",_character.global_position)
			await _shot("walk_%d_%d"%[route_index,int(reverse)])
	FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
