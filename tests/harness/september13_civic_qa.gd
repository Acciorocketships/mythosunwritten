extends "res://tests/harness/september13_path_qa.gd"
func _spots() -> Array:
	return [["P23_paths","2026-09-12 12.20.05 PM",Vector3(-248.9,12,432.7),Vector3(-248.8,12,435.9)],
		["P21_square","2026-09-12 12.18.58 PM",Vector3(241.0,12,493.4),Vector3(229.7,12,487.5)],
		# Nearby public square position; retain the photographed viewing direction.
		["P21_centre","P21 nearby",Vector3(228,12,486),Vector3(216.7,12,480.1)]]
