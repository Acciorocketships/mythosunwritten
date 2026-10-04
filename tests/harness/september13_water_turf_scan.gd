extends SceneTree
## Re-pin scan for test_september13_water_turf: the densest 12 x 8 m windows of
## shallow water (0.1 to 0.4 m deep: standing water a wave trough could bare;
## thinner water is the shore band, where the skin curls under the ground) in
## production chunks, seed 2697992464. Depth is sampled every 1 m; a window is
## scored by its shallow sample count (96 at most) and steps by 2 m; the best
## window of each chunk is listed.
## usage: godot --headless -s res://tests/harness/september13_water_turf_scan.gd -- x0 z0 x1 z1
## (chunk range, inclusive). Prints the best TURF windows: chunk, corner, count.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lo := Vector2i(int(args[0]), int(args[1]))
	var hi := Vector2i(int(args[2]), int(args[3]))
	var water := TerrainWorldTuning.make_water(2697992464)
	var fields := WorldFieldBlockCache.new(
		TerrainWorldTuning.make_heightfield(2697992464, water), water, 26, 0, 64)
	var hits: Array = []
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cz)
			var field := fields.water(key)
			if not field.has_sources():
				continue
			var region := fields.region(key)
			var origin := Vector2(key) * 192.0
			var shallow := PackedByteArray()
			shallow.resize(192 * 192)
			for z in 192:
				for x in 192:
					var p := origin + Vector2(x + 0.5, z + 0.5)
					var level := field.level_at(p)
					if not is_finite(level):
						continue
					var depth := level - TerrainTileField.surface_y(region, p.x, p.y)
					shallow[z * 192 + x] = int(depth > 0.1 and depth <= 0.4)
			for wz in range(0, 192 - 8, 2):
				for wx in range(0, 192 - 12, 2):
					var count := 0
					for z in 8:
						for x in 12:
							count += shallow[(wz + z) * 192 + wx + x]
					if count >= 24:
						hits.append([count, key, origin + Vector2(wx, wz)])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var shown := {}
	for hit: Array in hits:
		if shown.has(hit[1]) or shown.size() >= 12:
			continue
		shown[hit[1]] = true
		print("TURF chunk=", hit[1], " corner=", hit[2], " shallow=", hit[0])
	print("TURF_SCAN_DONE windows=", hits.size())
	quit()
