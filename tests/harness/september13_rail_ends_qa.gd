extends "res://tests/harness/september13_path_qa.gd"
func _spots() -> Array:
	return [["P40_rail_ends","2026-09-13 5.45.47 PM",Vector3(989.0,23.1,-400.8),Vector3(992.4,23.5,-403.5)]]

func _walk_corridor(_world: Node3D) -> void:
	var controller := WalkController.new()
	_character.controller = controller
	_character.set_physics_process(false)
	_character.anim_tree.active = true
	var reports := []
	for reverse: bool in [false,true]:
		for offset: float in [-.7,0,.7]:
			var route := [Vector3(990+offset,23.3,-401.5),Vector3(990+offset,26.2,-410.5),Vector3(996,26.2,-410.5)]
			if reverse: route.reverse()
			_character.global_position = route[0]
			_character.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			var trace := []
			var passed := true
			for target: Vector3 in route.slice(1):
				var reached := false
				for tick in 240:
					var delta := Vector2(target.x-_character.global_position.x,target.z-_character.global_position.z)
					if delta.length() < .2:
						reached = true
						break
					controller.direction = delta.normalized()*.4
					await get_tree().physics_frame
					_character._physics_process(1.0/60)
					trace.append({"x":_character.global_position.x,"y":_character.global_position.y,"z":_character.global_position.z,"floor":_character.is_on_floor()})
				passed = passed and reached
			controller.direction = Vector2.ZERO
			reports.append({"reverse":reverse,"offset":offset,"passed":passed,"trace":trace})
			print("RAIL_WALK reverse=",reverse," offset=",offset," passed=",passed)
			await _shot("walk_%d_%d"%[int(reverse),roundi(offset*10)])
	FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
