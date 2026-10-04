extends SceneTree
## Re-pin scan for test_september15_water_drops: production sites (seed
## 2697992464) where a river pours over a cliff. For every wall half-segment
## (TerrainTileField.wall_segments) in the chunk range it checks what the tests
## assert about a lip (normal n points from the high side to the low side):
## - SPILL: wet at 0.1 m steps from 3 m behind the lip to 3 m past it at 10%,
##   50% and 90% along the segment, with water above the ground by more than
##   EPS throughout, wet 4 m past the lip, and dry ground 12 m behind it (a
##   high dry bank);
## - CROSS: wet from 6 m behind to 6 m past the lip at 12.5-87.5% along it.
## usage: godot --headless -s res://tests/harness/september15_water_drop_scan.gd -- x0 z0 x1 z1
## (chunk range, inclusive). Prints SPILL / CROSS lines: a, b, normal.

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
			var rect := Rect2(Vector2(key) * 192.0, Vector2(192, 192))
			for seg: Dictionary in TerrainTileField.wall_segments(region, rect):
				var a: Vector2 = seg.a
				var b: Vector2 = seg.b
				var n: Vector2 = seg.normal
				var mid := (a + b) * 0.5
				if not field.is_wet(mid - n) or not field.is_wet(mid + n):
					continue
				if _crosses(field, a, b, n):
					print("CROSS a=", a, " b=", b, " normal=", n)
					found += 1
				if _spills(field, region, a, b, n):
					print("SPILL a=", a, " b=", b, " normal=", n, " top=", seg.top)
					found += 1
	print("DROP_SCAN_DONE found=", found)
	quit()

func _spills(field: WaterFieldContext, region: HeightfieldRegion, a: Vector2, b: Vector2, n: Vector2) -> bool:
	var mid := (a + b) * 0.5
	if not field.is_wet(mid + n * 4.0) or field.is_wet(mid - n * 12.0):
		return false
	for t: float in [0.1, 0.5, 0.9]:
		var m := a.lerp(b, t)
		for offset in range(1, 61):
			var p := m - n * 3.0 + n * (offset * 0.1)
			if not field.is_wet(p):
				return false
			var depth := WaterField.level_at(field.raw_context(), p) - TerrainTileField.surface_y(region, p.x, p.y)
			if depth <= WaterField.EPS:
				return false
	return true

func _crosses(field: WaterFieldContext, a: Vector2, b: Vector2, n: Vector2) -> bool:
	for t: float in [0.125, 0.375, 0.625, 0.875]:
		for i in 97:
			if not field.is_wet(a.lerp(b, t) - n * 6.0 + n * (i * 0.125)):
				return false
	return true
