extends SceneTree
## Isolate wall-width variation from the cliff-end transition on the saved photo lattice.
func _init() -> void:
	var saved: Dictionary = FileAccess.open("res://tests/fixtures/october8/dents-lattice.var", FileAccess.READ).get_var()
	var region := HeightfieldRegion.new(saved.storeys, saved.levels)
	var ground := func(p: Vector2) -> float: return TerrainTileField.surface_y(region, p.x, p.y)
	var original := FileAccess.get_file_as_string("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	var results: Array = []
	for mode in ["baseline", "slope_guard_2", "slope_guard_4"]:
		var source := GDScript.new()
		source.source_code = original
		if source.reload() != OK:
			quit(1)
			return
		var env = source._build(Rect2(-336, 1332, 60, 48), ground, Callable(), 2697992464, Callable(), Callable(), Callable(), true, 1)
		if mode != "baseline":
			var tiles: Dictionary = {}
			for idx in env.surface.size():
				if env.surface[idx] <= env.ground[idx]: continue
				var p: Vector2 = env.origin + Vector2(idx % env.w, idx / env.w) * 0.5
				var tile := Vector2i((p / 12.0).floor())
				var distance := 12.0
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var key := tile + Vector2i(dx, dz)
						if not tiles.has(key):
							var params := TerrainTileField.tile_params(region, key)
							tiles[key] = params[4] + params[5] + params[6] + params[7] == 0
						if not tiles[key]: continue
						var lo := Vector2(key) * 12.0
						var nearest := p.clamp(lo, lo + Vector2.ONE * 12.0)
						distance = minf(distance, p.distance_to(nearest))
				var width := 2.0 if mode == "slope_guard_2" else 4.0
				env.surface[idx] = lerpf(env.ground[idx], env.surface[idx], smoothstep(0.0, width, distance))
		FileAccess.open("/tmp/oct9-dent-" + mode + ".var",FileAccess.WRITE).store_var({"origin":env.origin,"w":env.w,"h":env.h,"surface":env.surface,"ground":env.ground})
		var worst := 0.0
		var where := Vector2.ZERO
		var count := 0
		for z in range(2676, 2716):
			for x in range(-658, -594):
				var p := Vector2(x, z) * 0.5
				for axis in [Vector2.RIGHT, Vector2.DOWN]:
					var a: float = ground.call(p - axis * 2)
					var b: float = ground.call(p)
					var c: float = ground.call(p + axis * 2)
					var dip: float = minf(env.at(p - axis * 2), env.at(p + axis * 2)) - env.at(p) - maxf(0, minf(a, c) - b)
					if dip > 0.04: count += 1
					if dip > worst:
						worst = dip
						where = p
		var row := {"mode": mode, "worst_added_dip": worst, "position": str(where), "sections_over_4cm": count}
		results.append(row)
		print("DENT_PROFILE ", JSON.stringify(row))
	FileAccess.open("/tmp/oct9-dent-guard-profiles.json", FileAccess.WRITE).store_string(JSON.stringify(results, "  "))
	quit()
