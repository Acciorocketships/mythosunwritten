extends RefCounted


func run(review: Node) -> void:
	var refine := GDScript.new()
	refine.source_code = FileAccess.get_file_as_string(
		"res://scripts/terrain/water/WaterSurfaceRefinement.gd"
	)
	if refine.reload() != OK:
		return
	var skin: GDScript = load("res://scripts/terrain/water/WaterSkin.gd")
	var results := []
	for chunk: Vector2i in [Vector2i(-1, 5), Vector2i(-1, 6)]:
		var root: Node = review._streamer._built[chunk]
		var meshes := root.find_children("WaterSheet", "MeshInstance3D", true, false)
		if meshes.is_empty():
			continue
		var mesh: MeshInstance3D = meshes[0]
		var arrays := mesh.mesh.surface_get_arrays(0)
		var water: WaterFieldContext = review._inputs[chunk].water
		var st: Dictionary = {
			"ctx": water.raw_context(),
			"region": water._region,
			"rect": Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0),
			"verts": arrays[Mesh.ARRAY_VERTEX].duplicate(),
			"idx": arrays[Mesh.ARRAY_INDEX].duplicate(),
			"normal_accum": arrays[Mesh.ARRAY_NORMAL].duplicate(),
			"weld": {}
		}
		for vi in st.verts.size():
			var v: Vector3 = st.verts[vi]
			st.weld[Vector3i(roundi(v.x * 64.0), roundi(v.z * 64.0), roundi(v.y * 64.0))] = vi
		var started := Time.get_ticks_usec()
		var result: Dictionary = refine.refine(
			st, func(p: Vector2) -> float: return WaterField.level_at(st.ctx, p)
		)
		result["ms"] = (Time.get_ticks_usec() - started) / 1000.0
		result["chunk"] = str(chunk)
		print("ADAPTIVE_FULL ", result)
		results.append(result)
	(
		FileAccess
		. open(review._output_dir + "/water-adaptive-full.json", FileAccess.WRITE)
		. store_string(JSON.stringify(results, "  "))
	)
