extends RefCounted
const Candidate = preload("res://tests/harness/october9_support_node_sample.gd")


func run(review: Node) -> void:
	var results := []
	for chunk: Vector2i in [Vector2i(-1, 5), Vector2i(-1, 6)]:
		var field: WaterFieldContext = review._streamer._fields.water(chunk)
		var ctx: Dictionary = field._ctx.duplicate(true)
		var n := (int(ctx.get("fill_size", WaterField.FILL_M + 1)) - 1) * 2 + 1
		var rows: int = ctx.fill.sub_levels.size() / n
		var before := PackedFloat64Array()
		before.resize(n * rows)
		var after := before.duplicate()
		var times := {}
		for mode: String in ["before", "after"]:
			var started := Time.get_ticks_usec()
			for z in rows:
				for x in n:
					var index := z * n + x
					var p: Vector2 = ctx.fill_base + Vector2(x, z) * 3
					var head := (
						WaterField._fill_bilinear(ctx, p)
						if mode == "before"
						else Candidate.sample(ctx, p, index)
					)
					var ground: float = ctx.fill.sub_ground[index]
					if ground == INF:
						ground = TerrainTileField.surface_y(ctx.region, p.x, p.y)
						ground = PackedFloat32Array([ground])[0]
					if not is_finite(head) or head <= ground + WaterField.EPS:
						head = -INF
					if mode == "before":
						before[index] = head
					else:
						after[index] = head
			times[mode] = (Time.get_ticks_usec() - started) / 1000.0
		var mismatches := []
		for index in before.size():
			if before[index] != after[index]:
				mismatches.append([index, before[index], after[index]])
		var row := {
			"chunk": str(chunk),
			"samples": before.size(),
			"mismatches": mismatches,
			"milliseconds": times
		}
		results.append(row)
		print("SUPPORT_NODE_REVIEW ", JSON.stringify(row))
	(
		FileAccess
		. open(review._output_dir + "/support-node-review.json", FileAccess.WRITE)
		. store_string(JSON.stringify(results, "  "))
	)
