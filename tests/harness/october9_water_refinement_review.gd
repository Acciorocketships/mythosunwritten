extends RefCounted


func run(review: Node) -> void:
	for path: String in [
		"res://scripts/terrain/water/WaterSurfaceRefinement.gd",
		"res://scripts/terrain/water/WaterSkin.gd"
	]:
		var script: GDScript = load(path)
		script.source_code = FileAccess.get_file_as_string(path)
		if script.reload(true) != OK:
			return
	var results := []
	for chunk: Vector2i in [Vector2i(-1, 5), Vector2i(-1, 6)]:
		var meshes: Array[Node] = review._streamer._built[chunk].find_children(
			"WaterSheet", "MeshInstance3D", true, false
		)
		if meshes.is_empty():
			continue
		var instance: MeshInstance3D = meshes[0]
		var input: Dictionary = review._inputs[chunk]
		var started := Time.get_ticks_msec()
		var payload: Dictionary = WaterSkin.build(
			review._streamer._water, chunk, input.region, input.water
		)
		if payload.is_empty():
			push_error("Refined water unexpectedly empty")
			return
		if not instance.has_meta("unrefined_mesh"):
			instance.set_meta("unrefined_mesh", instance.mesh)
		instance.mesh = WaterSkin.commit(payload.arrays)
		var row: Dictionary = {
			"chunk": str(chunk),
			"build_ms": Time.get_ticks_msec() - started,
			"vertices": payload.arrays[Mesh.ARRAY_VERTEX].size(),
			"triangles": payload.arrays[Mesh.ARRAY_INDEX].size() / 3
		}
		print("REFINED_WATER_BUILD ", row)
		results.append(row)
	var old: Array[Dictionary] = review._views.duplicate()
	review._views.clear()
	review._views.append(
		{
			"id": "river_shallow_refined",
			"position": Vector3(-60.09403, 107.6657, 1180.82),
			"target": Vector3(-39.17648, 75.66567, 1144.4),
			"fov": 60.0,
			"player": Vector3(-39.17648, 75.66567, 1144.4)
		}
	)
	review._views.append(
		{
			"id": "river_drop_refined",
			"position": Vector3(-49.68816, 97.45589, 1186.797),
			"target": Vector3(-28.77061, 65.45589, 1150.376),
			"fov": 60.0,
			"player": Vector3(-28.77061, 65.45589, 1150.376)
		}
	)
	await review._capture_all(44)
	review._views = old
	var checker := GDScript.new()
	checker.source_code = FileAccess.get_file_as_string(
		"res://tests/harness/october9_water_mesh_clearance.gd"
	)
	if checker.reload() == OK:
		await checker.new().run(review)
	DirAccess.rename_absolute(
		review._output_dir + "/water-mesh-clearance.json",
		review._output_dir + "/water-mesh-clearance-production-full.json"
	)
	(
		FileAccess
		. open(review._output_dir + "/water-refinement-builds.json", FileAccess.WRITE)
		. store_string(JSON.stringify(results, "  "))
	)
	print("REFINED_WATER_REVIEW done")
