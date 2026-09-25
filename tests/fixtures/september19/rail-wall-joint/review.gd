extends "res://tests/harness/september16_town_qa.gd"
class StairController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2: return direction

func _grass_enabled() -> bool: return true

func _capture_views(world: Node3D) -> void:
	await super._capture_views(world)
	var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-19-manual/109-rail-wall-joint/after/payload.bin",FileAccess.READ).get_var()
	var town: Transform3D = data.transform
	var controller := StairController.new()
	_character.controller = controller
	_character.visible = true
	_character.process_mode = Node.PROCESS_MODE_ALWAYS
	var results: Array = []
	for lateral: float in [-.75,0,.75]:
		for reverse: bool in [false,true]:
			var local_a := Vector3(2.75,7.55,12.75+lateral)
			var local_b := Vector3(-4.25,6.05,12.75+lateral)
			var start: Vector3 = town*(local_b if reverse else local_a)
			var end: Vector3 = town*(local_a if reverse else local_b)
			_character.set_physics_process(false)
			_character.global_position = start
			_character.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			_character.set_physics_process(true)
			for i in 20: await get_tree().physics_frame
			var ticks := 0
			var passed := false
			while ticks < 600:
				await get_tree().physics_frame
				var delta := Vector2(end.x-_character.global_position.x,end.z-_character.global_position.z)
				if delta.length()<.15:
					passed = true
					break
				controller.direction = delta.normalized()*.65
				ticks += 1
			controller.direction = Vector2.ZERO
			_character.set_physics_process(false)
			results.append({"lateral":lateral,"reverse":reverse,"passed":passed,"ticks":ticks,"position":str(_character.global_position)})
			_camera.global_position = town*Vector3(-1.0,13.0,19.5)
			_camera.look_at(_character.global_position+Vector3.UP)
			await _shot("stair_%s_%s" % [lateral,reverse])
			print("RAIL_STAIR_WALK ",results[-1])
	FileAccess.open(_output_dir.path_join("walks.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
