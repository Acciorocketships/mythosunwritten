extends "res://tests/harness/september13_path_qa.gd"
func _spots() -> Array:
	return [["P05_stone","2026-09-12 12.00.37 PM",Vector3(-217.9,20.4,-945.9),Vector3(-212.6,21.7,-946)]]

func _walk_corridor(world: Node3D) -> void:
	var controller := WalkController.new()
	_character.controller = controller
	_character.set_physics_process(false)
	_character.anim_tree.active = true
	var reports := []
	for sign_value: float in [-1,1]:
		for offset: float in [-1.5,-.75,0,.75,1.5]:
			var start_x := -217.9 if sign_value > 0 else -205.5
			var end_x := -205.5 if sign_value > 0 else -217.9
			_character.global_position = Vector3(start_x,minf(23.16,20.08+(start_x+219)*.25)+.1,-945.9+offset)
			_character.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			var start := _character.global_position
			var trace := []
			controller.direction = Vector2(sign_value,0)*.55
			var passed := false
			for tick in 420:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				trace.append({"tick":tick,"x":_character.global_position.x,"y":_character.global_position.y,"z":_character.global_position.z,"floor":_character.is_on_floor()})
				if (_character.global_position.x-end_x)*sign_value >= 0:
					passed = true
					break
			controller.direction = Vector2.ZERO
			reports.append({"direction":sign_value,"offset":offset,"start":str(start),"end":str(_character.global_position),"passed":passed,"trace":trace})
			print("STONE_WALK direction=",sign_value," offset=",offset," passed=",passed)
			await _shot("walk_%d_%d"%[int(sign_value),roundi(offset*10)])
	FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
