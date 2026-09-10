extends "res://tests/harness/village_reported_qa.gd"

## September 7 manual pass, in the owner's attachment order. The F3 values
## are rounded to 0.1 m; ReviewCam recovers the corresponding orbit direction.
func _spots() -> Array:
	return [
		["01_upper_door_gap", "Screenshot 2026-09-07 at 9.18.24 PM.png",
			Vector3(227.1,20.1,-369.7), Vector3(227.4,20.4,-369.8)],
		["02_gallery_gaps_flicker", "Screenshot 2026-09-07 at 9.17.35 PM.png",
			Vector3(224.7,20.1,-373.8), Vector3(224.4,20.3,-373.9)],
		["03_parallel_paths", "Screenshot 2026-09-07 at 9.16.07 PM.png",
			Vector3(241.9,8.0,-388.0), Vector3(241.6,8.2,-388.1)],
		["04_garden_wall", "Screenshot 2026-09-07 at 9.18.42 PM.png",
			Vector3(253.1,20.1,-374.5), Vector3(253.4,20.3,-374.5)],
		["05_ground_gaps", "Screenshot 2026-09-07 at 9.15.45 PM.png",
			Vector3(254.8,8.0,-366.3), Vector3(254.6,8.2,-366.0)],
		["06_town_slopes", "Screenshot 2026-09-07 at 9.15.23 PM.png",
			Vector3(258.1,8.0,-332.4), Vector3(258.2,8.2,-332.1)],
	]

func _ready() -> void:
	super._ready()
	# Match the photographed game viewport, excluding the editor toolbar.
	get_window().size = Vector2i(1718,1035)

func _capture_spot(spot: Array) -> void:
	await super._capture_spot(spot)
	var camera_position := ReviewCam.solve_cam(spot[2],spot[3])
	for sample in 2:
		_camera.global_position = camera_position + Vector3(0.015 * sample,0,0)
		_camera.look_at(spot[2],Vector3.UP)
		_camera.force_update_transform()
		for frame in 4:
			await get_tree().process_frame
		await _shot("%s_jitter_%d" % [spot[0],sample])
	# Keep the original transform even if a repaired wall now obstructs its
	# boom. These separately labelled views inspect the same join from closer
	# along that ray; they never replace the reconstructed original capture.
	if String(spot[0]) in ["01_upper_door_gap", "02_gallery_gaps_flicker", "05_ground_gaps"]:
		var forward := (Vector3(spot[2])-camera_position).normalized()
		for distance in [2.0,4.0,6.0]:
			_camera.global_position = camera_position + forward * distance
			_camera.look_at(spot[2],Vector3.UP)
			_camera.force_update_transform()
			for frame in 4: await get_tree().process_frame
			await _shot("%s_forward_%d" % [spot[0],int(distance)])
		var relative := camera_position - Vector3(spot[2])
		for turn in [-90.0,90.0,180.0]:
			_camera.global_position = Vector3(spot[2]) + relative.rotated(Vector3.UP,deg_to_rad(turn))
			_camera.look_at(spot[2],Vector3.UP)
			_camera.force_update_transform()
			for frame in 4: await get_tree().process_frame
			await _shot("%s_orbit_%d" % [spot[0],int(turn)])

	# Independently exercise the production obstruction solver at the pinned
	# player position. This is an additional gameplay view, not the pixel pin.
	var solver := CameraObstructionSolver.new()
	var space := _camera.get_world_3d().direct_space_state
	var excluded: Array[RID] = [_character.get_rid()]
	var pivot := solver.resolve_ceiling(space,spot[2],1.35,5.0,excluded)
	var horizontal := camera_position-Vector3(spot[2])
	horizontal.y = 0.0
	_camera.global_position = solver.resolve_boom(space,pivot,pivot+horizontal,excluded)
	_camera.look_at(spot[2],Vector3.UP)
	_camera.force_update_transform()
	for frame in 4: await get_tree().process_frame
	await _shot("%s_gameplay_camera" % spot[0])
