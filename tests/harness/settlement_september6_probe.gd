extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var settlements := SettlementPlan.new(seed_value, water)
	var count := 0
	for z in range(-8, 1):
		for x in range(-1, 5):
			if not settlements.site_for(Vector2i(x, z)).is_empty():
				count += 1
	print("TOWN_PROBE sites=", count, "/54 area=", 54 * SettlementPlan.SUPER_WORLD * SettlementPlan.SUPER_WORLD)
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program, settlements)
	for sc: Vector2i in [Vector2i(2, -7), Vector2i(2, -6), Vector2i.ZERO]:
		print("TOWN_PROBE site ", sc, " ", settlements.site_for(sc))
		var frame := world.frame_for(sc)
		if frame == null:
			print("TOWN_PROBE no frame ", sc)
			continue
		print("TOWN_PROBE frame ", sc, " ", frame.cell, " dormant=", frame.is_dormant())
		var record := world.village_plan().record_for(frame)
		if record != null and record.urban_fabric.accepted:
			var urban := record.urban_fabric
			var fabric := urban.fabric_plan
			var source := urban.volumetric_spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
			print("TOWN_PROBE validation valid=", urban.validate(world.village_plan().get("_program") as VillageProgram, &"village"), " relief=", urban.terrain_relief_m, " signature=", urban._fabric_audit_matches_plan(), " scale=", urban._scale_feature_contract_matches(urban.fabric_audit))
			print("TOWN_PROBE portals=", source.excavation.portals, " contacts=", VillageWarrenFabricSolver.terrain_contact_specs(urban.volumetric_spatial, fabric))
			var streets := fabric.surface_plan.cells_for_kind(PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET)
			for portal in source.excavation.portals:
				var nearby: Array[Vector3i] = []
				for c: Vector3i in streets:
					if absi(c.x - portal.x * 2) < 3 and absi(c.z - portal.z * 2) < 3:
						nearby.append(c)
				print("TOWN_PROBE portal streets ", portal, ": ", nearby)
		print("TOWN_PROBE result ", sc, " ", "null" if record == null else str(record.urban_fabric.reason), " empty=", record == null or record.is_empty())
	quit()
