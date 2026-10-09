extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.SHARED_PROFILE
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	preload("res://scripts/native/NativeWaterFill.gd").setup()
	WaterField.SOURCE_SUPPORT = true
	var catalog := EnvironmentCatalog.load_default()
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"), catalog)
	var results := []
	var failures := 0
	for seed_value: int in [2697992464, 99]:
		var water := TerrainWorldTuning.make_water(seed_value)
		var plan := TerrainWorldTuning.make_heightfield(seed_value, water)
		var fields := WorldFieldBlockCache.new(
			plan, water, program.query_margin, program.shore_distance_limit, 16
		)
		var start_x := -2 if seed_value == 2697992464 else 1
		for z in range(4, 7):
			for x in range(start_x, start_x + 3):
				var chunk := Vector2i(x, z)
				for axis: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
					var other := chunk + axis
					if other.x >= start_x + 3 or other.y >= 7:
						continue
					var a := fields.water(chunk)
					var b := fields.water(other)
					var origin := Vector2(other) * 192.0
					var tangent := Vector2(0, 1) if axis.x else Vector2(1, 0)
					var wet := 0
					var mismatch := 0
					var worst := 0.0
					for i in 385:
						var p := origin + tangent * (i * .5)
						var ya := a.level_at(p)
						var yb := b.level_at(p)
						if not is_finite(ya) and not is_finite(yb):
							continue
						wet += 1
						if is_finite(ya) != is_finite(yb):
							mismatch += 1
						elif ya != yb:
							worst = maxf(worst, absf(ya - yb))
					if mismatch > 0 or worst > 0:
						failures += 1
					var row := {
						"seed": seed_value,
						"a": str(chunk),
						"b": str(other),
						"wet": wet,
						"wet_mismatch": mismatch,
						"height_difference": worst
					}
					results.append(row)
					print("SUPPORTED_WATER_SEAM ", JSON.stringify(row))
					(
						FileAccess
						. open("/tmp/oct9-supported-water-seams.json", FileAccess.WRITE)
						. store_string(JSON.stringify(results, "  "))
					)
	quit(0 if failures == 0 else 1)
