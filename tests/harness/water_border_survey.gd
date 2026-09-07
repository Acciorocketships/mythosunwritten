extends SceneTree

func _initialize() -> void:
	var seed_value := 2697992464
	var output := "/private/tmp/water-border-survey.json"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--report" and i + 1 < args.size(): output = args[i + 1]
		if args[i] == "--seed" and i + 1 < args.size(): seed_value = int(args[i + 1])
	var water := TerrainWorldTuning.make_water(seed_value)
	var plan := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fields := WorldFieldBlockCache.new(plan, water, 0.0, 0.0, 128)
	var rows: Array = []
	var start := Time.get_ticks_msec()
	for z in range(-3, 3):
		for x in range(-3, 3):
			var chunk := Vector2i(x, z)
			var own := fields.water(chunk)
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other := fields.water(chunk + direction)
				var mismatches := 0
				var max_jump := 0.0
				var worst := Vector2.ZERO
				for along in range(0, 193, 3):
					var p := Vector2(chunk) * 192.0 + (Vector2(192, along) if direction.x else Vector2(along, 192))
					var a := own.level_at(p)
					var b := other.level_at(p)
					var jump := absf(a - b) if is_finite(a) and is_finite(b) else 1000.0 if is_finite(a) != is_finite(b) else 0.0
					if jump > 0.01:
						mismatches += 1
						if jump > max_jump:
							max_jump = jump
							worst = p
				if mismatches:
					var row := {"chunk": str(chunk), "neighbour": str(chunk + direction), "mismatches": mismatches, "max_jump": max_jump, "point": str(worst), "a": str(own.level_at(worst)), "b": str(other.level_at(worst)), "ground": TerrainSurfaceField.surface_y(fields.region(chunk), worst.x, worst.y)}
					rows.append(row)
					print("WATER_BORDER ", JSON.stringify(row))
		print("WATER_SURVEY row=", z, " ms=", Time.get_ticks_msec() - start)
	var boundaries: Array = []
	for source: Dictionary in WaterField._basin_cache.values():
		boundaries.append({"base": str(source.base), "size": source.size, "boundary_wet": source.boundary_wet})
	print("WATER_DOMAINS ",JSON.stringify(boundaries))
	var out := FileAccess.open(output, FileAccess.WRITE)
	out.store_string(JSON.stringify({"seed": seed_value, "seams": rows, "domains": boundaries, "elapsed_ms": Time.get_ticks_msec() - start}, "  "))
	quit()
