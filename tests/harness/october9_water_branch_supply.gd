extends RefCounted

var sample_step := .5
var diagonals := false
var level_tolerance := .001
var output_suffix := ""
var support_trial := false
var sample_origin := Vector2(-80, 1100)


## Check whether the photographed side branch has a wet, non-uphill path from
## an actual river trace. This is a hydraulic placement diagnostic, not a mesh test.
func run(review: Node) -> void:
	var origin := sample_origin
	var step := sample_step
	var size := roundi(80.0 / step) + 1
	var levels := PackedFloat64Array()
	levels.resize(size * size)
	levels.fill(-INF)
	var fields: Dictionary = {}
	var wet := 0
	for zi in size:
		for xi in size:
			var p := origin + Vector2(xi, zi) * step
			var chunk := FieldTerrainStreamer.chunk_of(Vector3(p.x, 0, p.y))
			if not fields.has(chunk):
				fields[chunk] = review._streamer._fields.water(chunk)
			var field: WaterFieldContext = fields[chunk]
			var level := field.level_at(p)
			if is_finite(level):
				levels[zi * size + xi] = level
				wet += 1
	var queue: Array[int] = []
	var reached := PackedByteArray()
	reached.resize(levels.size())
	var traces: Dictionary = {}
	for field: WaterFieldContext in fields.values():
		for trace: RiverTrace in field._ctx.rivers:
			traces[trace.source_cell] = trace
	for trace: RiverTrace in traces.values():
		for i in trace.points.size() - 1:
			var a := trace.points[i]
			var b := trace.points[i + 1]
			var count := maxi(1, ceili(a.distance_to(b) / step))
			for j in count + 1:
				var q: Vector2 = (a.lerp(b, float(j) / count) - origin) / step
				var x := roundi(q.x)
				var z := roundi(q.y)
				if x < 0 or z < 0 or x >= size or z >= size:
					continue
				var index := z * size + x
				if is_finite(levels[index]) and reached[index] == 0:
					reached[index] = 1
					queue.append(index)
	var source_indices := PackedInt32Array(queue)
	var seeds := queue.size()
	var neighbors: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	if diagonals:
		neighbors.append_array([Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)])
	var cursor := 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		var x := index % size
		var z := index / size
		for delta: Vector2i in neighbors:
			var nx := x + delta.x
			var nz := z + delta.y
			if nx < 0 or nz < 0 or nx >= size or nz >= size:
				continue
			var ni := nz * size + nx
			if (
				reached[ni] != 0
				or not is_finite(levels[ni])
				or levels[ni] > levels[index] + level_tolerance
			):
				continue
			reached[ni] = 1
			queue.append(ni)
	var support := PackedFloat32Array()
	var support_stats := {}
	var conservative_support := PackedFloat32Array()
	if support_trial:
		var ground := PackedFloat32Array()
		ground.resize(levels.size())
		ground.fill(INF)
		for index in levels.size():
			if not is_finite(levels[index]):
				continue
			var p := origin + Vector2(index % size, int(index / size)) * step
			var chunk := FieldTerrainStreamer.chunk_of(Vector3(p.x, 0, p.y))
			var field: WaterFieldContext = fields[chunk]
			ground[index] = TerrainTileField.surface_y(field._region, p.x, p.y)
		# Give the local diagnostic every possible external supply at its
		# boundary, plus every intersecting pond footprint. If a branch still
		# dries, truncating the survey or omitting a pond cannot explain it.
		var conservative_roots := source_indices.duplicate()
		var ponds: Array[PondStamp] = []
		for field: WaterFieldContext in fields.values():
			for pond: PondStamp in field._ctx.ponds:
				if not ponds.has(pond):
					ponds.append(pond)
		var pond_roots := 0
		for index in levels.size():
			if not is_finite(levels[index]):
				continue
			var x := index % size
			var z := int(index / size)
			if x == 0 or z == 0 or x == size - 1 or z == size - 1:
				conservative_roots.append(index)
			var p := origin + Vector2(x, z) * step
			for pond: PondStamp in ponds:
				if p.distance_to(pond.center) <= pond.bound_radius() and pond.footprint_t(p) < 1.0:
					conservative_roots.append(index)
					pond_roots += 1
					break
		var candidate = load("res://tests/harness/october9_water_support_candidate.gd")
		var started := Time.get_ticks_usec()
		support = candidate.constrain(
			PackedFloat32Array(Array(levels)), ground, size, source_indices
		)
		support_stats = {
			"milliseconds": (Time.get_ticks_usec() - started) / 1000.0, "dried": 0, "lowered": 0
		}
		conservative_support = candidate.constrain(
			PackedFloat32Array(Array(levels)), ground, size, conservative_roots
		)
		support_stats.pond_roots = pond_roots
		support_stats.conservative_roots = conservative_roots.size()
		support_stats.conservative_dried = 0
		support_stats.conservative_lowered = 0
		for index in levels.size():
			if not is_finite(levels[index]):
				continue
			if not is_finite(conservative_support[index]):
				support_stats.conservative_dried += 1
			elif conservative_support[index] < levels[index] - .001:
				support_stats.conservative_lowered += 1
			if not is_finite(support[index]):
				support_stats.dried += 1
			elif support[index] < levels[index] - .001:
				support_stats.lowered += 1
		(
			FileAccess
			. open(
				review._output_dir + "/water-support-grid" + output_suffix + ".bin",
				FileAccess.WRITE
			)
			. store_var(
				{
					"origin": origin,
					"step": step,
					"size": size,
					"levels": PackedFloat32Array(Array(levels)),
					"ground": ground,
					"roots": source_indices,
					"supported": support,
					"conservative_roots": conservative_roots,
					"conservative_supported": conservative_support
				}
			)
		)
	var probes := []
	for p: Vector2 in [
		Vector2(-26, 1142), Vector2(-26, 1138), Vector2(-25, 1146), Vector2(-39, 1144)
	]:
		var q: Vector2 = (p - origin) / step
		var index := roundi(q.y) * size + roundi(q.x)
		probes.append(
			{
				"at": str(p),
				"sample_at": str(origin + Vector2(roundi(q.x), roundi(q.y)) * step),
				"level": levels[index] if is_finite(levels[index]) else null,
				"supplied": reached[index] != 0,
				"conservative_head":
				(
					conservative_support[index]
					if (
						not conservative_support.is_empty()
						and is_finite(conservative_support[index])
					)
					else null
				),
				"supported_head":
				support[index] if not support.is_empty() and is_finite(support[index]) else null
			}
		)
	var result: Dictionary = {
		"support_trial": support_stats,
		"origin": str(origin),
		"step": step,
		"diagonals": diagonals,
		"level_tolerance": level_tolerance,
		"size": size,
		"wet": wet,
		"seeds": seeds,
		"reachable": queue.size(),
		"probes": probes
	}
	(
		FileAccess
		. open(
			review._output_dir + "/water-branch-supply" + output_suffix + ".json", FileAccess.WRITE
		)
		. store_string(JSON.stringify(result, "  "))
	)
	print("WATER_BRANCH_SUPPLY ", JSON.stringify(result))
