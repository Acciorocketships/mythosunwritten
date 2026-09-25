extends "res://tests/harness/september8_gate_walk.gd"

## Additional finish review: the short turnout in photo 9 must reach its porch.
func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = get_viewport().get_camera_3d()
	_camera.set("target",null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	_character.set_physics_process(false)
	assert(await _wait_for_site())
	var frame := _streamer._features.frame_for(Vector2i(0,-1))
	var outskirts := _streamer._features.village_plan().record_for(frame).outskirts
	var porch: VillageMassingPlacement
	for placement: VillageMassingPlacement in outskirts.placements:
		if placement.asset_id == &"sfv.building.interior.blue.006":
			porch = placement
			break
	assert(porch != null)
	var outward := Vector3(porch.entrance_outward.x,0,porch.entrance_outward.y)
	var side := outward.cross(Vector3.UP)
	var low := Vector3(porch.street_contact.x,porch.street_contact_y,porch.street_contact.y)
	var toe := Vector3(porch.entrance_ground_contact.x,porch.entrance_ground_y,porch.entrance_ground_contact.y)
	# Stop on the native landing, 0.50 authored metres inward, before the
	# capsule reaches the closed doorway/jambs beyond it.
	var high := toe-outward*1.0+Vector3.UP*0.786
	var controller := WalkController.new()
	_character.controller = controller
	# Capture the matched stills before walking changes the animation state.
	await _capture_spot(_spot)
	var report: Array = []
	for offset: float in [-1.0,0.0,1.0]:
		for reverse: bool in [false,true]:
			var start := (high if reverse else low)+side*offset
			var end := (low if reverse else high)+side*offset
			var forward := ((end-start)*Vector3(1,0,1)).normalized()
			_character.global_position = start+Vector3.UP*0.1
			_character.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			var trace: Array = []
			controller.direction = Vector2(forward.x,forward.z)
			for tick in 300:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				trace.append({"tick":tick,"xyz":[_character.position.x,_character.position.y,_character.position.z],"ground":_character.is_on_floor()})
				if (_character.global_position-end).dot(forward)>=0: break
			var success := trace.size()<300 and (_character.global_position-end).dot(forward)>=0 and absf(_character.position.y-end.y)<0.25
			report.append({"descent":reverse,"offset":offset,"passed":success,"trace":trace})
			print("PORCH_WALK descent=",reverse," offset=",offset," passed=",success," end=",_character.position)
	controller.direction = Vector2.ZERO
	_character.velocity = Vector3.ZERO
	_camera.global_position = toe+outward*9+side*7+Vector3.UP*5
	_camera.look_at(toe+Vector3.UP)
	_camera.force_update_transform()
	for frame_index in 4: await get_tree().process_frame
	await _shot("porch_ground_view")
	FileAccess.open(_output_dir+"/walking.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	var passed := not report.is_empty()
	for row: Dictionary in report: passed = passed and bool(row.passed)
	get_tree().quit(0 if passed else 1)
