extends SceneTree
## Non-kit assets left in a production village record. -s record_census.gd -- --super 0,1
func _init() -> void:
	var seed_value := 2697992464
	var sc := Vector2i(0, 1)
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--super": sc = Vector2i(int(args[i+1].get_slice(",",0)), int(args[i+1].get_slice(",",1)))
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fp := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water, fp.query_margin, fp.shore_distance_limit, fp.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value, water, fields, fp, SettlementPlan.new(seed_value, water))
	var record := world.village_plan().record_for(world.frame_for(sc))
	for asset_id in record.payload.asset_ids():
		if String(asset_id).begins_with("suntail."): continue
		var b: Dictionary = record.payload.batches[asset_id]
		var pre := {}
		for id in b.ids: pre[String(id).get_slice("/", 1).get_slice("/", 0)] = true
		print("LEGACY %4d %s %s" % [b.transforms.size(), asset_id, str(pre.keys().slice(0, 3))])
	quit()
