extends SceneTree
## Prints storeys/levels, cliff-top flags and envelope lift around a cell.
##   godot --headless --path . -s res://docs/qa/2026-09-27-judging/slopes/probe_site.gd -- --cell 17,39
func _init() -> void:
	var seed_value := 2697992464
	var cell := Vector2i(17, 39)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--cell":
			var p := args[i + 1].split(",")
			cell = Vector2i(int(p[0]), int(p[1]))
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program, SettlementPlan.new(seed_value, water))
	var chunk := Vector2i(floori(float(cell.x) / 8.0), floori(float(cell.y) / 8.0))
	var features: FeatureContext = world.context_for(chunk)
	var region: HeightfieldRegion = features.graded_region(fields.region(chunk))
	print("chunk ", chunk)
	for z in range(cell.y - 3, cell.y + 4):
		var line := "z=%d: " % z
		for x in range(cell.x - 3, cell.x + 4):
			var c := "C" if TerrainSurfaceField._is_cliff_top(region, x, z) else ("I" if TerrainSurfaceField.has_inner_corner(region, x, z) else " ")
			line += "%3d.%d%s " % [region.storey_at(x, z), region.level_at(x, z), c]
		print(line)
	quit()
