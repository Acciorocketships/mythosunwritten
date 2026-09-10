extends "res://tests/harness/village_september5_evening_qa.gd"

## Additional matched gallery camera. The historical camera now intersects an
## occupied bridge room; preserve its captures and compare the same facades
## from this explicitly recorded open position in both revisions.
func _spots() -> Array:
	return [["upper_facade_overlap", "Screenshot 2026-09-05 at 5.51.45 PM.png",
		Vector3(258.8, 27.6, 306.3), Vector3(258.4, 27.9, 306.2)]]

func _capture_spot(spot: Array) -> void:
	await super._capture_spot(spot)
	for sample in 4:
		_camera.global_position = Vector3(257 + 0.015 * (sample % 2), 32, 305)
		_camera.look_at(Vector3(263, 28, 308), Vector3.UP)
		_camera.force_update_transform()
		for frame in 4:
			await get_tree().process_frame
		await _shot("upper_facade_overlap_gallery_jitter_%d" % sample)
