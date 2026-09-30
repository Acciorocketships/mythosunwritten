extends SceneTree
## Lists country-road lattice cells that run beside a one-storey slope, as
## survey sites for the photo 9 pattern.
##   godot --headless --path . -s res://docs/qa/2026-09-27-judging/slopes/road_slope_sites.gd -- --blocks -2,4:3,6
func _init() -> void:
	var seed_value := 2697992464
	var lo := Vector2i(-2, 4)
	var hi := Vector2i(3, 6)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--blocks":
			var p := args[i + 1].split(":")
			var a := p[0].split(","); var b := p[1].split(",")
			lo = Vector2i(int(a[0]), int(a[1])); hi = Vector2i(int(b[0]), int(b[1]))
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program, SettlementPlan.new(seed_value, water))
	for bz in range(lo.y, hi.y + 1):
		for bx in range(lo.x, hi.x + 1):
			var block := Vector2i(bx, bz)
			var ground := world.path_plan().context_for(block).ground_field()
			var region: HeightfieldRegion = fields.region(block)
			for cell: Vector2i in ground._connection_masks:
				if cell.x < bx * 8 or cell.x >= bx * 8 + 8 or cell.y < bz * 8 or cell.y >= bz * 8 + 8: continue
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var ds := region.storey_at(cell.x + d.x, cell.y + d.y) - region.storey_at(cell.x, cell.y)
					if absi(ds) == 1:
						print("SITE cell=%s d=%s ds=%d world=%s h=%.1f" % [cell, d, ds, Vector2(cell) * 24.0, region.surface_height(cell.x, cell.y)])
	quit()
