extends SceneTree
## Re-pin scan for the three photo-16 free-shore interpolation tests in
## test_september10_water_surface.gd (dual-grid terrain, 2026-09-30). Their
## frozen fill (shore_before.bin) was solved by the retired pre-September-15
## WaterField over retired 24 m cell ground and cannot be re-frozen on 12 m
## points. This scan finds a LIVE free shoreline over flat ground in the same
## photographed geography (tests/fixtures/September10WaterFields.gd):
## a 6 x 6 m window, origin on a whole metre, whose ground is flat (every 1 m
## sample within 1 mm) and which holds both wet and dry 1 m samples. Each
## candidate is then measured with the test's exact 0.01 m / 0.1 m routine
## (crossings over unchanged ground in both grid directions, worst entry depth,
## worst wet-to-wet step).
## usage: godot --headless -s res://tests/harness/september10_free_shore_scan.gd -- x0 z0 x1 z1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lo := Vector2i(int(args[0]), int(args[1]))
	var hi := Vector2i(int(args[2]), int(args[3]))
	var fields := preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	var found := 0
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cz)
			var field := fields.water(key)
			if not field.has_sources():
				continue
			var ctx := field.raw_context()
			var region: HeightfieldRegion = ctx.region
			var origin := Vector2(key) * 192.0
			var ground := PackedFloat32Array()
			var wet := PackedByteArray()
			for j in 193:
				for i in 193:
					var p := origin + Vector2(i, j)
					var g := TerrainSurfaceField.surface_y(region, p.x, p.y)
					var level := WaterField.level_at(ctx, p)
					ground.append(g)
					wet.append(1 if is_finite(level) and level > g + WaterField.EPS else 0)
			var candidates: Array = []
			for j in range(0, 187, 3):
				for i in range(0, 187, 3):
					var g0 := ground[j * 193 + i]
					var flat := true
					var wets := 0
					for b in 7:
						for a in 7:
							var k := (j + b) * 193 + i + a
							if absf(ground[k] - g0) > 0.001:
								flat = false
							wets += wet[k]
					if flat and wets > 6 and wets < 43:
						candidates.append([absi(wets - 24), origin + Vector2(i, j)])
			candidates.sort_custom(func(a, b): return a[0] < b[0])
			for c in candidates.slice(0, 3):
				var m := _measure(ctx, c[1])
				print("FREE_SHORE window=", c[1], " crossings=", m.x, " worst_entry=", m.y,
					" worst_step=", m.z)
				found += 1
	print("FREE_SHORE_SCAN_DONE found=", found)
	quit()

func _measure(ctx: Dictionary, corner: Vector2) -> Vector3:
	var crossing_count := 0
	var worst_entry := 0.0
	var worst_step := 0.0
	for axis in 2:
		for row in 61:
			var previous: Dictionary = {}
			for column in 601:
				var p := corner + (Vector2(column * .01, row * .1) if axis == 0 \
					else Vector2(row * .1, column * .01))
				var ground := TerrainSurfaceField.surface_y(ctx.region, p.x, p.y)
				var level := WaterField.level_at(ctx, p)
				var wet := is_finite(level) and level > ground + WaterField.EPS
				if not previous.is_empty() and absf(previous.ground - ground) < .001:
					if wet != previous.wet:
						worst_entry = maxf(worst_entry, level - ground if wet \
							else previous.level - previous.ground)
						crossing_count += 1
					if wet and previous.wet:
						worst_step = maxf(worst_step, absf(level - previous.level))
				previous = {"ground": ground, "level": level, "wet": wet}
	return Vector3(crossing_count, worst_entry, worst_step)
