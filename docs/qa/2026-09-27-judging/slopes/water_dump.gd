extends SceneTree
## Dumps the water level on a 2 m lattice for every block with carved water
## in a block range, for a before/after wetness diff.
##   godot --headless --path . -s .../water_dump.gd -- --blocks -4,2:4,8 --out FILE
func _init() -> void:
	var seed_value := 2697992464
	var lo := Vector2i(-4, 2)
	var hi := Vector2i(4, 8)
	var out_path := "user://water_dump.txt"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--blocks":
			var p := args[i + 1].split(":")
			var a := p[0].split(","); var b := p[1].split(",")
			lo = Vector2i(int(a[0]), int(a[1])); hi = Vector2i(int(b[0]), int(b[1]))
		if args[i] == "--out": out_path = args[i + 1]
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fields := WorldFieldBlockCache.new(heightfield, water, 0.0, 0.0, 64)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	for bz in range(lo.y, hi.y + 1):
		for bx in range(lo.x, hi.x + 1):
			var block := Vector2i(bx, bz)
			var region: HeightfieldRegion = fields.region(block)
			var any := false
			for cz in range(bz * 8 - 1, bz * 8 + 9):
				for cx in range(bx * 8 - 1, bx * 8 + 9):
					any = any or region.is_carved(cx, cz)
			if not any: continue
			var ctx: WaterFieldContext = fields.water(block)
			var o := Vector2(block) * 192.0 - Vector2.ONE * 12.0
			for iz in 96:
				for ix in 96:
					var q := o + Vector2(ix, iz) * 2.0
					var level := ctx.level_at(q)
					if is_finite(level):
						f.store_line("%d %d %.3f %.3f" % [int(q.x), int(q.y), level, TerrainSurfaceField.surface_y(region, q.x, q.y)])
			print("block ", block)
	f.close()
	quit()
