extends SceneTree
func _initialize() -> void:
	var full := OS.get_cmdline_user_args().has("--full")
	for seed_v in ([991177] if full else [991177, 2697992464, 314159]):
		var w := WaterPlan.new(seed_v, 22.0, 8)
		var count := 0
		var lakes := 0
		var long_count := 0
		var total := 0.0
		var extent := 0.0
		var records: Array = []
		for z in range(-4, 5):
			for x in range(-4, 5):
				var t := w.river_for(Vector2i(x,z), WaterPlan.JOIN_DEPTH if full else 0)
				if t == null:
					continue
				count += 1
				lakes += int(t.pond != null)
				var length := (t.points.size() - 1) * WaterPlan.TRACE_STEP
				total += length
				extent += t.bounds().size.length()
				long_count += int(length >= 2000)
				records.append({"cell": str(t.source_cell), "points": Array(t.points).map(func(p): return [p.x,p.y]), "length": length})
		print("CORPUS seed=%d sources=%d long=%d mean_length=%.0f mean_extent=%.0f lakes=%d full=%s" % [seed_v, count, long_count, total/maxi(count,1), extent/maxi(count,1), lakes, full])
		if seed_v in [991177, 2697992464]:
			var old := preload("res://tests/fixtures/ReportedWaterPlan.gd").new(seed_v)
			var old_count := 0
			var old_lakes := 0
			for z in range(-4, 5):
				for x in range(-4, 5):
					var t := old.river_for(Vector2i(x, z))
					if t != null:
						old_count += 1
						old_lakes += int(t.pond != null)
			print("BASELINE seed=%d sources=%d terminal_lakes=%d" % [seed_v, old_count, old_lakes])
		var file := FileAccess.open("/tmp/river-corpus-%d-%s.json" % [seed_v, "full" if full else "raw"], FileAccess.WRITE)
		file.store_string(JSON.stringify(records))
	quit()
