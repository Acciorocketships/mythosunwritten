extends SceneTree

## Headless structural diagnostic for one production settlement. This keeps
## rejection analysis on the same field/cache path as runtime generation.
func _init() -> void:
	var seed_value := 2697992464
	var super_cell := Vector2i(0, -1)
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--seed":
				if index + 1 < args.size():
					seed_value = int(args[index + 1])
			"--super-x":
				if index + 1 < args.size():
					super_cell.x = int(args[index + 1])
			"--super-z":
				if index + 1 < args.size():
					super_cell.y = int(args[index + 1])
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var feature_program := FeatureProgram.compile(
		EnvironmentCatalog.load_default())
	assert(feature_program != null)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		feature_program.query_margin,
		feature_program.shore_distance_limit,
		feature_program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields,
		feature_program, settlements)
	var frame := world.frame_for(super_cell)
	assert(frame != null)
	var started := Time.get_ticks_usec()
	var plan := world.village_plan().record_for(frame)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var fabric := plan.urban_fabric
	var report := {
		"seed": seed_value,
		"super_cell": [super_cell.x, super_cell.y],
		"settlement_id": String(frame.settlement_id),
		"tier": String(plan.tier),
		"accepted": fabric.accepted,
		"reason": String(fabric.reason),
		"payload_instances": plan.payload.instance_count,
		"elapsed_ms": elapsed_ms,
	}
	if fabric.accepted:
		if fabric.generation_kind in [
				VillageUrbanFabricPlan.GenerationKind.SECTIONAL_WARREN,
				VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN]:
			report["fabric_audit"] = fabric.fabric_audit
			report["route_signature"] = String(
				fabric.fabric_audit.maze_route_signature)
			report["construction_signature"] = String(
				fabric.fabric_audit.construction_signature)
	print(JSON.stringify(report, "  "))
	quit(0 if fabric.accepted else 1)

