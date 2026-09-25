extends "res://tests/harness/warren_spatial_review.gd"

## Fixed authored-world cameras: generation cannot reframe its own comparison.
func _review_views() -> Array[Dictionary]:
	return [
		{"id": "north-east", "eye": Vector3(65, 58, 65)},
		{"id": "south-west", "eye": Vector3(-65, 48, -65)},
		{"id": "north-west", "eye": Vector3(-65, 58, 65)},
		{"id": "south-east", "eye": Vector3(65, 48, -65)},
		{"id": "plan", "eye": Vector3(0, 95, 0.1)},
	]

func _capture_all() -> void:
	var views := _review_views()
	_scale_character.visible = false
	for view: Dictionary in views:
		_camera.fov = 45.0
		var target := Vector3(0, 8, 0)
		_camera.look_at_from_position(view.eye, target)
		for frame in 12:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var path := "%s/seed-%03d-%s.png" % [_output_dir, _world_seed, view.id]
		assert(get_viewport().get_texture().get_image().save_png(path) == OK)
		_captures.append({"screenshot_id": view.id, "image": path,
			"position": _v3(view.eye), "target": _v3(target), "fov": 45.0})
	_write_manifest()
	var source: WarrenMazeSourcePlan = _spatial.source_volume.mass_context.get(&"maze_source_plan")
	var prefab_records: Array = []
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"prefab_landmark":
			continue
		prefab_records.append({"id": feature.stable_id, "audit": feature.audit,
			"construction": feature.construction_records})
	var data := {"seed": _world_seed, "scale": _scale_id,
		"prefabs": prefab_records, "buildings": _spatial.buildings.size()}
	if source != null:
		data["columns"] = source.massif.columns
		data["plots"] = source.plots
		data["source_audit"] = source.audit
	var census := FileAccess.open(_output_dir.path_join("census.json"), FileAccess.WRITE)
	census.store_string(JSON.stringify(data, "  "))
	get_tree().quit()
