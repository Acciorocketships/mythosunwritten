extends RefCounted


func run(review: Node) -> void:
	var reference := GDScript.new()
	reference.source_code = FileAccess.get_file_as_string(
		"res://docs/qa/2026-10-08-manual-pass/water-refinement-before-face-cache.gd"
	)
	if reference.reload() != OK:
		return
	var current: GDScript = load("res://scripts/terrain/water/WaterSurfaceRefinement.gd")
	var skin := GDScript.new()
	var call := "\tSURFACE_REFINEMENT.refine(st, func(p: Vector2) -> float: return WaterField.level_at(ctx, p))"
	skin.source_code = (
		FileAccess
		. get_file_as_string("res://scripts/terrain/water/WaterSkin.gd")
		. replace("class_name WaterSkin", "")
		. replace(call, "")
	)
	if skin.reload() != OK:
		return
	var rows := []
	for chunk: Vector2i in [Vector2i(-1, 5), Vector2i(-1, 6)]:
		var features: FeatureContext = review._streamer._features.context_for(chunk, Callable())
		var region: HeightfieldRegion = features.graded_region(
			review._streamer._fields.region(chunk)
		)
		var water: WaterFieldContext = review._streamer._fields.water(chunk)
		var payload: Dictionary = skin.build(review._streamer._water, chunk, region, water)
		if payload.is_empty():
			continue
		var st: Dictionary = {
			"rect": Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0),
			"verts": payload.arrays[Mesh.ARRAY_VERTEX],
			"idx": payload.arrays[Mesh.ARRAY_INDEX],
			"normal_accum": payload.arrays[Mesh.ARRAY_NORMAL],
			"weld": {}
		}
		for vi in st.verts.size():
			var v: Vector3 = st.verts[vi]
			st.weld[Vector3i(roundi(v.x * 64), roundi(v.z * 64), roundi(v.y * 64))] = vi
		for repeat in 2:
			var states: Dictionary = {}
			var times: Dictionary = {}
			var calls: Dictionary = {}
			for kind: String in ["before", "after"] if repeat == 0 else ["after", "before"]:
				var target: Dictionary = st.duplicate(true)
				var counter: Dictionary = {"n": 0}
				var query := func(p: Vector2) -> float:
					counter.n += 1
					return WaterField.level_at(water.raw_context(), p)
				var started := Time.get_ticks_usec()
				var script: GDScript = reference if kind == "before" else current
				script.refine(target, query)
				times[kind] = (Time.get_ticks_usec() - started) / 1000.0
				calls[kind] = counter.n
				states[kind] = target
			var same := var_to_bytes(states.before) == var_to_bytes(states.after)
			var row: Dictionary = {
				"chunk": str(chunk),
				"repeat": repeat,
				"same": same,
				"times_ms": times,
				"queries": calls
			}
			rows.append(row)
			print("REFINEMENT_FULL_CACHE_CHECK ", JSON.stringify(row))
	(
		FileAccess
		. open(review._output_dir + "/refinement-full-cache-check.json", FileAccess.WRITE)
		. store_string(JSON.stringify(rows, "  "))
	)
