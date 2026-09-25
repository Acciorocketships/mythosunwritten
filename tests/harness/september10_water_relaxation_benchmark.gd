extends SceneTree
const Reference = preload("res://tests/fixtures/September10SurfaceReconciliationReference.gd")
func _init() -> void:
	var rows: Array = []
	for mode in ["flat_lake", "joined_heads", "channels"]:
		var ground := PackedFloat32Array(); ground.resize(400 * 300); ground.fill(0.0)
		var levels := ground.duplicate(); levels.fill(3.0)
		for z in 300:
			for x in 400:
				if mode == "joined_heads" and x > 200: levels[z * 400 + x] = 12.0
				if mode == "channels": levels[z * 400 + x] = 3.0 + x * .5 if z % 20 < 6 else -INF
		var before: Array = []; var after: Array = []; var offers := 0
		for sample in 3:
			var expected := levels.duplicate()
			var candidate := levels.duplicate()
			var started := Time.get_ticks_usec()
			Reference.reconcile(expected, ground, 400, 3.0)
			before.append((Time.get_ticks_usec() - started) / 1000.0)
			started = Time.get_ticks_usec()
			offers = WaterField._reconcile_connected_surface(candidate, ground, 400, 3.0)
			after.append((Time.get_ticks_usec() - started) / 1000.0)
			assert(expected == candidate)
		rows.append({"mode": mode, "before_ms": before, "after_ms": after, "initial_offers": offers, "identical": true})
	FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print(JSON.stringify(rows))
	quit()
