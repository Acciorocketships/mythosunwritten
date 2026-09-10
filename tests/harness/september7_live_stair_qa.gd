extends "res://tests/harness/village_september7_qa.gd"

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
	for transition: WarrenVolumeTransition in volume.transitions:
		if transition.kind!=WarrenVolumeTransition.Kind.STAIR: continue
		var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
		var a: Vector3 = pose*ends.start
		var b: Vector3 = pose*ends.end
		var low := a if a.y<b.y else b
		var high := b if a.y<b.y else a
		var forward := ((high-low)*Vector3(1,0,1)).normalized()
		_character.global_position=low-forward*1.2+Vector3.UP*0.03
		_character.velocity=Vector3.ZERO
		controller.direction=Vector2.ZERO
		for tick in 30:
			await get_tree().physics_frame
			_character._physics_process(1.0/60)
		var start := _character.global_position
		_camera.global_position=low-forward*3+Vector3.UP*2
		_camera.look_at(low+forward*2+Vector3.UP,Vector3.UP)
		await _shot("%s_start" % transition.stable_id)
		var trace: Array = []
		controller.direction=Vector2(forward.x,forward.z)
		for tick in 150:
			await get_tree().physics_frame
			_character._physics_process(1.0/60)
			if tick%10==0:
				var collisions: Array = []
				for index in _character.get_slide_collision_count():
					var hit := _character.get_slide_collision(index)
					collisions.append({"normal":str(hit.get_normal()),"position":str(hit.get_position()),"shape":hit.get_collider_shape_index()})
				trace.append({"tick":tick,"position":str(_character.global_position),"velocity":str(_character.velocity),"floor":_character.is_on_floor(),"hits":collisions})
			if tick in [30,60,120]: await _shot("%s_tick_%d" % [transition.stable_id,tick])
			if (_character.global_position-high).dot(forward)>=0.8: break
		var success := _character.global_position.y>=high.y-0.1 and (_character.global_position-high).dot(forward)>=0.6
		await _shot("%s_end" % transition.stable_id)
		var row := {"id":str(transition.stable_id),"start":str(start),"low":str(low),"high":str(high),"end":str(_character.global_position),"passed":success,"trace":trace}
		report.append(row)
		print("LIVE_STAIR ",JSON.stringify(row))
	if "--slope" in OS.get_cmdline_user_args():
		for reverse in [false,true]:
			var low := Vector3(268,8.02,-346)
			var high := Vector3(252.2,11.02,-346)
			var start := high if reverse else low
			var finish := low if reverse else high
			var forward := ((finish-start)*Vector3(1,0,1)).normalized()
			_character.global_position=start
			_character.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			var name := "slope_descent" if reverse else "slope_ascent"
			_camera.global_position=Vector3(257,18,-332)
			_camera.look_at(Vector3(258,9,-346),Vector3.UP)
			controller.direction=Vector2(forward.x,forward.z)
			var trace: Array = []
			for tick in 300:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				if tick%15==0: trace.append({"tick":tick,"position":str(_character.global_position),"floor":_character.is_on_floor()})
				if tick in [30,60,120]: await _shot("%s_tick_%d" % [name,tick])
				if (_character.global_position-finish).dot(forward)>=-0.1: break
			var success := (_character.global_position-finish).dot(forward)>=-0.3 and absf(_character.global_position.y-finish.y)<0.25
			await _shot(name+"_end")
			var row := {"id":name,"passed":success,"start":str(start),"end":str(_character.global_position),"trace":trace}
			report.append(row)
			print("LIVE_SLOPE ",JSON.stringify(row))
	FileAccess.open(_output_dir+"/walking.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	controller.direction=Vector2.ZERO
	for spot: Array in _spots(): await _capture_spot(spot)
	get_tree().quit()
