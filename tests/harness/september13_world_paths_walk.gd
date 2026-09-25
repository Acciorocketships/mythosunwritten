extends "res://tests/harness/september13_world_paths_qa.gd"
class RoadController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character:CharacterBody3D,_delta:float)->Vector2: return direction
func _run()->void:
	await get_tree().create_timer(5).timeout
	_camera = _capture_view.get_camera_3d()
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	_camera._visibility.clear()
	var controller := RoadController.new()
	_character.controller = controller
	var route:Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/36-world-paths/after/route-0.bin",FileAccess.READ).get_var()
	var points:Array[Vector2] = []
	# These ends are outside the town's replaced public street fabric. The
	# town-side handoff is checked separately; this traverses the country road.
	for index in range(6,35): points.append(Vector2(route.connections[index].a)*TerrainSurfaceField.TILE)
	var rows:Array = []
	for reverse:bool in [false,true]:
		var ordered := points.duplicate()
		if reverse: ordered.reverse()
		var point:Vector2 = ordered[0]
		var start_y := 8.0 if reverse else 40.0
		_spot = ["walk","road traversal",Vector3(point.x,start_y,point.y),Vector3(point.x,start_y+1,point.y-1)]
		_character.set_physics_process(false)
		_character.global_position = _spot[2]
		assert(await _wait_for_site())
		var space := _camera.get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,start_y+50,point.y),Vector3(point.x,start_y-50,point.y),1,[_character.get_rid()]))
		assert(not hit.is_empty())
		_character.global_position = hit.position+Vector3.UP*.1
		_character.velocity = Vector3.ZERO
		_character.set_physics_process(true)
		var index := 1
		var trace:Array = []
		var started := Time.get_ticks_msec()
		var last_progress := started
		var progress_position := _character.global_position
		var tick := 0
		var failure := ""
		while index<ordered.size():
			await get_tree().physics_frame
			var p := _character.global_position
			var delta:Vector2 = ordered[index]-Vector2(p.x,p.z)
			if delta.length()<.35:
				index += 1
				last_progress = Time.get_ticks_msec()
				print("ROAD_WALK segment=",index," reverse=",reverse," p=",p)
				continue
			controller.direction = delta.normalized()*.75
			_camera.global_position = p+Vector3(0,18,26)
			_camera.look_at(p+Vector3.UP)
			var frozen := _streamer._player_frozen
			if p.distance_to(progress_position)>1 or frozen:
				progress_position = p
				last_progress = Time.get_ticks_msec()
			if tick%30==0:
				trace.append({"tick":tick,"position":str(p),"segment":index,"frozen":frozen,"floor":_character.is_on_floor()})
			if Time.get_ticks_msec()-last_progress>12000:
				failure = "Physical progress stopped"
				break
			if Time.get_ticks_msec()-started>600000:
				failure = "Traversal exceeded ten minutes"
				break
			tick += 1
		controller.direction = Vector2.ZERO
		rows.append({"reverse":reverse,"passed":index>=ordered.size(),"segments":index-1,"failure":failure,"elapsed_ms":Time.get_ticks_msec()-started,"trace":trace})
		FileAccess.open(_output_dir.path_join("walking.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
		await _shot("walk_%s"%str(reverse))
		print("ROAD_WALK_RESULT ",reverse," passed=",index>=ordered.size()," failure=",failure)
	get_tree().quit()
