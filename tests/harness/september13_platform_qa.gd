extends "res://tests/harness/september13_path_qa.gd"
func _spots() -> Array:
	return [["P07_platform","2026-09-12 12.02.18 PM",Vector3(-225.8,14.1,-977.8),Vector3(-226,15.4,-978.1)],
		["P07_entry","connection detail",Vector3(-229.5,14.1,-969.5),Vector3(-229.5,15.8,-964)]]

func _walk_corridor(_world: Node3D) -> void:
	var controller := WalkController.new()
	_character.controller = controller
	_character.set_physics_process(false)
	var results := []
	for x: float in [-230.4,-229.5,-228.5]:
		for sign_value: float in [-1,1]:
			var start_z: float = -969.5 if sign_value<0 else -964
			var end_z: float = -964 if sign_value<0 else -969.5
			# Walking north is -Z; the sign identifies the source side here.
			var direction := -sign_value
			var y := 14.08 if start_z< -967 else 14.08+(x+231)*.5
			_character.global_position = Vector3(x,y+.1,start_z)
			_character.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			controller.direction = Vector2(0,direction)*.55
			var trace := []
			var passed := false
			for tick in 300:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				trace.append(str(_character.global_position))
				if (_character.global_position.z-end_z)*direction>=0:
					passed=true
					break
			controller.direction=Vector2.ZERO
			results.append({"x":x,"source_z":start_z,"target_z":end_z,"passed":passed,"end":str(_character.global_position),"trace":trace})
			print("PLATFORM_WALK ",x," ",start_z," ",passed," ",_character.global_position)
			await _shot("walk_%d_%d"%[roundi(x*10),int(sign_value)])
	FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
