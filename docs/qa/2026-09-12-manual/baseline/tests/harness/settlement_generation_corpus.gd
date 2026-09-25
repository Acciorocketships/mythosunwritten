extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var world_seed := 2697992464
	var water := TerrainWorldTuning.make_water(world_seed)
	var sites := SettlementPlan.new(world_seed, water)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var failures := 0
	var count := 0
	for z in range(-8, 1):
		for x in range(-1, 5):
			var sc := Vector2i(x,z)
			var site := sites.site_for(sc)
			if site.is_empty(): continue
			count += 1
			var city_seed := VillagePlan.warren_seed_for_cell(world_seed,site.cell)
			var profile := WarrenVillageScaleProfile.select(city_seed)
			var started := Time.get_ticks_msec()
			var spatial := WarrenVolumetricSolver.solve(city_seed,{},program,profile)
			var errors := PackedStringArray()
			if spatial == null:
				errors.append(WarrenVolumetricSolver.last_failure)
			else:
				errors = WarrenSpatialFabricCompiler.validation_errors(spatial.compiled_fabric_cache())
				var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
				if not source.validate_construction():
					errors.append("source: " + source.last_rejection)
				if not spatial.validate_construction():
					errors.append("spatial: " + spatial.last_rejection)
				if VillageWarrenFabricSolver.terrain_contact_specs(spatial,spatial.compiled_fabric_cache()).size() != source.excavation.portals.size():
					errors.append("missing portal handoff")
			failures += int(not errors.is_empty())
			print("SETTLEMENT_CORPUS super=",sc," cell=",site.cell," scale=",profile.scale_id," ms=",Time.get_ticks_msec()-started," errors=",errors)
			if spatial != null:
				print("COMPOSITION_OPERATIONS cell=",site.cell,
					" support=",spatial.audit.get("structural_room_repair_count", 0),
					" shoulder=",spatial.audit.get("unroofable_shoulder_crown_repair_count", 0),
					" global_roof=",spatial.audit.get("global_roof_crown_repair_count", 0))
	print("SETTLEMENT_CORPUS count=",count," failures=",failures," area=",54*SettlementPlan.SUPER_WORLD*SettlementPlan.SUPER_WORLD)
	quit(1 if failures > 0 else 0)
