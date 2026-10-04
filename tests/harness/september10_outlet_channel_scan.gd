extends SceneTree
## Re-pin scan for two tests in test_september10_water_surface.gd over the
## frozen photographed geography (tests/fixtures/September10WaterFields.gd):
## - OUTLET: a lip where supplied upper water crosses a wall whose normal runs
##   along +-x (the test walks 15 m rows along x across it): every 0.01 m
##   sample of three rows 3 m apart along the wall, from 6 m behind the lip to
##   9 m past it, is wet with no step over 0.03 m, and the bank 9 m to the
##   -z side of the lip is dry.
## - CHANNEL: a wet 1 m sample whose level is a whole river head (a multiple
##   of 0.1 m to 1 mm) while its nearest coarse fill node is dry: a real fine
##   channel across a coarse dry edge.
## usage: godot --headless -s res://tests/harness/september10_outlet_channel_scan.gd -- x0 z0 x1 z1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lo := Vector2i(int(args[0]), int(args[1]))
	var hi := Vector2i(int(args[2]), int(args[3]))
	var fields: WorldFieldBlockCache = preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	var outlets := 0
	var channels := 0
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cz)
			var field := fields.water(key)
			if not field.has_sources():
				continue
			var region := fields.region(key)
			var rect := Rect2(Vector2(key) * 192.0, Vector2(192, 192))
			for seg: Dictionary in TerrainTileField.wall_segments(region, rect):
				var n: Vector2 = seg.normal
				if absf(n.x) < 0.5:
					continue
				var mid: Vector2 = (seg.a + seg.b) * 0.5
				if _outlet(field, mid, n):
					print("OUTLET chunk=", key, " lip=", mid, " normal=", n)
					outlets += 1
			var ctx := field.raw_context()
			var base: Vector2 = ctx.fill_base
			var size: int = ctx.get("fill_size", WaterField.FILL_M + 1)
			var levels: PackedFloat32Array = ctx.fill.levels
			for z in 192:
				for x in 192:
					var p := Vector2(key) * 192.0 + Vector2(x, z)
					if not field.is_wet(p):
						continue
					var level := field.level_at(p)
					if absf(level * 10.0 - roundf(level * 10.0)) > 0.01:
						continue
					var node := Vector2i(((p - base) / WaterField.FILL_STEP).round())
					if node.x < 0 or node.y < 0 or node.x >= size or node.y >= size:
						continue
					if is_finite(levels[node.y * size + node.x]):
						continue
					if channels < 20:
						print("CHANNEL chunk=", key, " p=", p, " level=", level)
					channels += 1
	print("OUTLET_CHANNEL_SCAN_DONE outlets=", outlets, " channels=", channels)
	quit()

func _outlet(field: WaterFieldContext, mid: Vector2, n: Vector2) -> bool:
	# The higher bank beside the rows stays dry (the test's crown point).
	if field.is_wet(mid + Vector2(0, -9)):
		return false
	for dz in [-3.0, 0.0, 3.0]:
		var previous := NAN
		for i in 1501:
			var p := mid - n * 6.0 + n * (i * 0.01) + Vector2(0, dz)
			var level := field.level_at(p)
			if not is_finite(level):
				return false
			if is_finite(previous) and absf(previous - level) >= 0.03:
				return false
			previous = level
	return true
