extends "res://tests/harness/village_september5_qa.gd"

func _spots() -> Array:
	return [
		["door_wall_openings", "Screenshot 2026-09-05 at 5.51.08 PM.png",
			Vector3(282.9, 5.0, 305.1), Vector3(282.6, 5.2, 305.3)],
		["upper_facade_overlap", "Screenshot 2026-09-05 at 5.51.45 PM.png",
			Vector3(258.8, 27.6, 306.3), Vector3(258.4, 27.9, 306.2)],
		["north_path_junction", "Screenshot 2026-09-05 at 5.52.33 PM.png",
			Vector3(260.1, 4.8, 270.1), Vector3(260.0, 5.1, 269.7)],
		["east_path_house", "Screenshot 2026-09-05 at 5.52.23 PM.png",
			Vector3(303.0, 5.0, 272.9), Vector3(303.2, 5.2, 272.7)],
	]

func _capture_spot(spot: Array) -> void:
	await super._capture_spot(spot)
	if String(spot[0]) == "north_path_junction":
		# The restored outskirts house now occupies part of the historical
		# camera position. Keep the exact capture and add a clear street view.
		_camera.global_position = Vector3(249, 25, 255)
		_camera.look_at(Vector3(264, 5, 281), Vector3.UP)
		_camera.force_update_transform()
		for frame in 4:
			await get_tree().process_frame
		await _shot("north_path_junction_overview")
