extends SceneTree
const Refiner = preload("res://scripts/terrain/water/WaterSurfaceRefinement.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the saved pre-optimization refiner script")
		quit(1)
		return
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string(args[0])
	if baseline.reload() != OK:
		quit(1)
		return
	var cases: Array[Callable] = [
		func(p: Vector2) -> float: return 4.0 + p.x * .2 + p.y * .3,
		func(p: Vector2) -> float: return 5.0 + 2.0 * sin(p.x * .7) * cos(p.y * .8),
		func(p: Vector2) -> float: return 8.0 + p.x * .5 + 4.0 * exp(-p.length_squared() * .2),
		func(p: Vector2) -> float: return 8.0 + maxf(0.0, 2.0 - p.distance_to(Vector2(1, 1))) ** 2,
	]
	var before_usec := 0
	var after_usec := 0
	var failures := 0
	var rows := []
	for repeat in 5:
		for ci in cases.size():
			var level: Callable = cases[ci]
			var source := _mesh(level)
			var a: Dictionary = source.duplicate(true)
			var b: Dictionary = source.duplicate(true)
			var start := Time.get_ticks_usec()
			var first: Dictionary = baseline.refine(a, level)
			before_usec += Time.get_ticks_usec() - start
			start = Time.get_ticks_usec()
			var second: Dictionary = Refiner.refine(b, level)
			after_usec += Time.get_ticks_usec() - start
			var same := var_to_bytes(a) == var_to_bytes(b) and first == second
			if not same:
				failures += 1
			if repeat == 0:
				rows.append(
					{
						"case": ci,
						"same": same,
						"stats": second,
						"digest": var_to_bytes(b).hex_encode().sha256_text()
					}
				)
	var result: Dictionary = {
		"cases": 20,
		"failures": failures,
		"before_ms": before_usec / 1000.0,
		"after_ms": after_usec / 1000.0,
		"rows": rows
	}
	FileAccess.open("/tmp/oct9-refinement-cache-check.json", FileAccess.WRITE).store_string(
		JSON.stringify(result, "  ")
	)
	print("REFINEMENT_CACHE_CHECK ", JSON.stringify(result))
	quit(0 if failures == 0 else 1)


func _mesh(level: Callable) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var weld: Dictionary = {}
	for z in 5:
		for x in 5:
			var p := Vector2(x * 2 - 4, z * 2 - 4)
			var y: float = level.call(p)
			weld[Vector3i(roundi(p.x * 64), roundi(p.y * 64), roundi(y * 64))] = vertices.size()
			vertices.append(Vector3(p.x, y, p.y))
			normals.append(Vector3.UP)
	for z in 4:
		for x in 4:
			var a := z * 5 + x
			indices.append_array([a, a + 5, a + 6, a, a + 6, a + 1])
	return {
		"rect": Rect2(-4, -4, 8, 8),
		"verts": vertices,
		"normal_accum": normals,
		"idx": indices,
		"weld": weld
	}
