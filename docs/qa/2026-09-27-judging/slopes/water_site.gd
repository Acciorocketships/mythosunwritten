extends SceneTree
## Storeys and water (level/ground) around a world point, both natural region.
##   ... -- --at X,Z
func _init() -> void:
	var at := Vector2(252, 1452)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--at":
			var p := args[i + 1].split(","); at = Vector2(float(p[0]), float(p[1]))
	var water := TerrainWorldTuning.make_water(2697992464)
	var heightfield := TerrainWorldTuning.make_heightfield(2697992464, water)
	var fields := WorldFieldBlockCache.new(heightfield, water, 0.0, 0.0, 64)
	var block := WorldFieldBlockCache.key_of(at)
	var region: HeightfieldRegion = fields.region(block)
	var c := Vector2i((at / 24.0).round())
	for z in range(c.y - 3, c.y + 4):
		var line := "z=%d: " % z
		for x in range(c.x - 3, c.x + 4):
			line += "%2d%s%s " % [region.storey_at(x, z), "C" if TerrainSurfaceField._is_cliff_top(region, x, z) else " ", "~" if region.is_carved(x, z) else " "]
		print(line)
	var ctx: WaterFieldContext = fields.water(block)
	for dz in range(-24, 25, 4):
		var line := "Z=%d " % int(at.y + dz)
		for dx in range(-24, 25, 4):
			var q := at + Vector2(dx, dz)
			if not ctx.covers(q): line += "    ..    "; continue
			var lv := ctx.level_at(q)
			line += ("%5.1f/%4.1f " % [lv, TerrainSurfaceField.surface_y(region, q.x, q.y)]) if is_finite(lv) else ("  -  /%4.1f " % TerrainSurfaceField.surface_y(region, q.x, q.y))
		print(line)
	quit()
