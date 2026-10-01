extends SceneTree
## Re-pin scan for test_september13_water_corner (12 m dual-grid terrain moved
## the photographed bank). Finds production sites, seed 2697992464, with the
## same shape as the reported corner: a 6 m line along +x that is wet at every
## 0.25 m sample, whose far end stands at least 0.3 m above its near (lower
## reach) end -- upper connected water above a lower reach -- and that runs
## beside a high dry bank: a sample 3 m to either side of the far half is dry
## ground standing above the far-end water level.
## usage: godot --headless -s res://tests/harness/september13_water_corner_scan.gd -- x0 z0 x1 z1
## (chunk range, inclusive). Prints CORNER lines: start, rise, bank point.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lo := Vector2i(int(args[0]), int(args[1]))
	var hi := Vector2i(int(args[2]), int(args[3]))
	var water := TerrainWorldTuning.make_water(2697992464)
	var fields := WorldFieldBlockCache.new(
		TerrainWorldTuning.make_heightfield(2697992464, water), water, 26, 0, 64)
	var found := 0
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cz)
			var field := fields.water(key)
			if not field.has_sources():
				continue
			var region := fields.region(key)
			var origin := Vector2(key) * 192.0
			for row in range(2, 64):
				var z := origin.y + row * 3.0 + 0.625
				# wet[i] at x = origin.x + i * 0.25
				var levels := PackedFloat32Array()
				for i in 769:
					levels.append(field.level_at(Vector2(origin.x + i * 0.25, z)))
				var start := 0
				while start + 24 < 769:
					var ok := true
					for k in 25:
						if not is_finite(levels[start + k]):
							ok = false
							break
					if ok and levels[start + 24] - levels[start] >= 0.3:
						var far := Vector2(origin.x + (start + 20) * 0.25, z)
						for side in [-3.0, 3.0]:
							var bank := far + Vector2(0, side)
							if not field.covers(bank) or field.is_wet(bank):
								continue
							var ground := TerrainSurfaceField.surface_y(region, bank.x, bank.y)
							if ground > levels[start + 24]:
								print("CORNER start=", Vector2(origin.x + start * 0.25, z),
									" rise=", levels[start + 24] - levels[start],
									" bank=", bank, " bank_ground=", ground,
									" low=", levels[start], " high=", levels[start + 24])
								found += 1
								break
						start += 24
					else:
						start += 1
	print("CORNER_SCAN_DONE found=", found)
	quit()
