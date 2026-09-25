extends SceneTree
## Lists settlements (tier, kind, world centre) for super cells in a square.
## -s settlement_sites.gd -- --seed 2697992464 --radius 3
func _init() -> void:
	var seed_value := 2697992464
	var radius := 3
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed": seed_value = int(args[i + 1])
		if args[i] == "--radius": radius = int(args[i + 1])
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var feature_program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water,
		feature_program.query_margin, feature_program.shore_distance_limit,
		feature_program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields, feature_program, settlements)
	for sx in range(-radius, radius + 1):
		for sz in range(-radius, radius + 1):
			var frame := world.frame_for(Vector2i(sx, sz))
			if frame == null: continue
			var record := world.village_plan().record_for(frame)
			if record == null: continue
			var kind := "?"
			if record.urban_fabric != null:
				kind = str(record.urban_fabric.fabric_audit.get("generation_source", record.urban_fabric.generation_kind))
			var c := record.bounds.get_center()
			print("SITE super=%d,%d tier=%s kind=%s centre=%.0f,%.0f instances=%d" % [sx, sz, record.tier, kind, c.x, c.y, record.payload.instance_count])
	quit()
