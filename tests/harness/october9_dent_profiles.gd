extends SceneTree
## Isolate wall-width variation from the cliff-end transition on the saved photo lattice.
func _init() -> void:
	var saved: Dictionary = FileAccess.open("res://tests/fixtures/october8/dents-lattice.var", FileAccess.READ).get_var()
	var region := HeightfieldRegion.new(saved.storeys, saved.levels)
	var ground := func(p: Vector2) -> float: return TerrainTileField.surface_y(region, p.x, p.y)
	var original := FileAccess.get_file_as_string("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
	var results: Array = []
	for mode in ["baseline", "narrow", "middle", "wide"]:
		var source := GDScript.new()
		source.source_code = original
		if mode != "baseline":
			var weight := "0.0" if mode == "narrow" else ("0.5" if mode == "middle" else "1.0")
			source.source_code = original.replace("var ridge:=lerpf(PLAIN,t[idx],smoothstep(VARIED.x,VARIED.y,drop[idx]))", "var ridge:=" + weight)
		if source.reload() != OK:
			quit(1)
			return
		var env = source._build(Rect2(-336, 1332, 60, 48), ground, Callable(), 2697992464, Callable(), Callable(), Callable(), true, 1)
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
	FileAccess.open("/tmp/oct9-dent-profiles.json", FileAccess.WRITE).store_string(JSON.stringify(results, "  "))
	quit()
