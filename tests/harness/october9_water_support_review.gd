extends RefCounted

func run(review: Node) -> void:
	var old: Array[Dictionary] = review._views.duplicate()
	review._views.clear()
	review._views.append(
		{
			"id": "river_shallow_supported",
			"position": Vector3(-60.09403, 107.6657, 1180.82),
			"target": Vector3(-39.17648, 75.66567, 1144.4),
			"fov": 60.0,
			"player": Vector3(-39.17648, 75.66567, 1144.4)
		}
	)
	review._views.append(
		{
			"id": "river_drop_supported",
			"position": Vector3(-49.68816, 97.45589, 1186.797),
			"target": Vector3(-28.77061, 65.45589, 1150.376),
			"fov": 60.0,
			"player": Vector3(-28.77061, 65.45589, 1150.376)
		}
	)
	await review._capture_all(54)
	review._views = old
	var checker := GDScript.new()
	checker.source_code = FileAccess.get_file_as_string(
		"res://tests/harness/october9_water_mesh_clearance.gd"
	)
	if checker.reload() == OK:
		await checker.new().run(review)

	print("SOURCE_SUPPORT_REVIEW done")
