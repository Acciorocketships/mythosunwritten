extends "res://tests/harness/village_september8_qa.gd"

class WalkController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D,_delta: float) -> Vector2:
		return direction

func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = get_viewport().get_camera_3d()
	_camera.set("target",null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	_character.set_physics_process(false)
	var ready := await _wait_for_site()
	assert(ready)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(frozen.read("res://tests/fixtures/september7-manual-source.txt"))
	var controller := WalkController.new()
	_character.controller=controller
	var pose := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2),Vector3(238.5,8.08,-365.5))
	var report: Array = []
	_camera.target=_character
	for transition: WarrenVolumeTransition in volume.transitions:
		if transition.kind!=WarrenVolumeTransition.Kind.STAIR: continue
		var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
		var a: Vector3 = pose*ends.start
		var b: Vector3 = pose*ends.end
		var low := a if a.y<b.y else b
		var high := b if a.y<b.y else a
		var forward := ((high-low)*Vector3(1,0,1)).normalized()
		for descent: bool in [false,true]:
			var direction := -forward if descent else forward
			var start := high+forward*0.8 if descent else low-forward*1.2
			var end := low-forward*1.2 if descent else high+forward*0.8
			_character.global_position=start+Vector3.UP*0.03
			_character.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			_camera.global_position=start-direction*8+Vector3.UP*5
			_camera._have_prev=false
			_camera._last_back_dir=Vector3.ZERO
			_camera._v_ema=Vector3.ZERO
			_camera._pivot_height=-1
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				_camera._physics_process(1.0/60)
			var trace: Array=[]
			var success := false
			controller.direction=Vector2(direction.x,direction.z)
			for tick in 150:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				_camera._physics_process(1.0/60)
				trace.append({"tick":tick,"xyz":[_character.position.x,_character.position.y,_character.position.z],
					"visual_y":_character.body_model_root.global_position.y,"camera_y":_camera.global_position.y,
					"floor":_character.is_on_floor()})
				if String(transition.stable_id)=="volume.transition.07" and tick%3==0:
					_camera.force_update_transform()
					await _shot("motion_%s_%03d"%["down" if descent else "up",tick])
				if (_character.global_position-end).dot(direction)>=0:
					success=absf(_character.position.y-end.y)<0.15
					break
			controller.direction=Vector2.ZERO
			var row:Dictionary={"id":String(transition.stable_id),"descent":descent,"passed":success,"trace":trace}
			report.append(row)
			print("LIVE_MOTION ",transition.stable_id," descent=",descent," passed=",success)
	FileAccess.open(_output_dir+"/walking.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	controller.direction=Vector2.ZERO
	_character._update_step_visual_smoothing(1.0)
	_camera.target=null
	for spot: Array in _spots(): await _capture_spot(spot)
	get_tree().quit()
