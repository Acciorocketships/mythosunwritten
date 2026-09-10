extends "res://tests/harness/village_september8_qa.gd"

class BankController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2:
		return direction

func _spots() -> Array:
	return super._spots().filter(func(spot: Array) -> bool: return spot[0] == "10_river_bank")

func _ground(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*100,
		point-Vector3.UP*100,1,[_character.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty(),"river review needs committed terrain collision")
	return hit.position

func _capture_spot(spot: Array) -> void:
	# Preserve the exact camera despite the changed bank height. A frozen player
	# at the old elevation would float above the repaired ground in this pair.
	_character.visible = false
	await super._capture_spot(spot)
	_character.visible = true
	var standing := _ground(Vector3(-518.4,12,-235)) + Vector3.UP*0.08
	_character.global_position = standing
	_camera.global_position = ReviewCam.solve_cam(standing,standing+Vector3(spot[3])-Vector3(spot[2]))
	_camera.look_at(standing)
	for frame in 4: await get_tree().process_frame
	await _shot("10_river_bank_grounded")
	var controller := BankController.new()
	_character.controller = controller
	var report: Array = []
	for x in [-528.0,-518.4]:
		var start := _ground(Vector3(x,12,-285))+Vector3.UP*0.08
		_character.global_position = start
		_character.velocity = Vector3.ZERO
		controller.direction = Vector2.ZERO
		for tick in 30:
			await get_tree().physics_frame
			_character._physics_process(1.0/60)
		for returning in [false,true]:
			var trace := []
			var passed := false
			var previous := _character.position.y
			var largest_change := 0.0
			controller.direction = Vector2(0,-1 if returning else 1)
			for tick in 1000:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				largest_change = maxf(largest_change,absf(_character.position.y-previous))
				previous = _character.position.y
				trace.append({"tick":tick,"position":str(_character.position),
					"ground":_character.is_on_floor(),"wading":_character.wading})
				if returning and _character.position.z <= start.z+0.2:
					passed = absf(_character.position.y-start.y)<0.3
					break
				if not returning and _character.wading:
					passed = largest_change<0.4
					break
			var row := {"x":x,"returning":returning,"passed":passed,
				"largest_frame_height_change":largest_change,"trace":trace}
			report.append(row)
			print("BANK_WALK x=",x," returning=",returning," passed=",passed," max_step=",largest_change)
		controller.direction = Vector2.ZERO
	FileAccess.open(_output_dir+"/walking.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
