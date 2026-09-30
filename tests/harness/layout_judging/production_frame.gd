extends SceneTree
## Prints the production world frame (kit_town_review --frame) of the village
## in each requested super cell of world seed 2697992464 (slow: it builds the
## real world plan, ~5 min).  -- SX,SZ [SX,SZ ...]
func _init() -> void:
	var seed_value := 2697992464
	var catalog := EnvironmentCatalog.load_default()
	var feature_program := FeatureProgram.compile(catalog)
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		feature_program.query_margin, feature_program.shore_distance_limit,
		feature_program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields, feature_program, settlements)
	for arg in OS.get_cmdline_user_args():
		var p := arg.split(",")
		var frame := world.frame_for(Vector2i(int(p[0]), int(p[1])))
		var record := world.village_plan().record_for(frame)
		var t := record.urban_fabric.world_transform
		print("FRAME ", arg, " %f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f" % [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z])
	quit()
