extends SceneTree

func _init() -> void:
	var start := Time.get_ticks_msec()
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	print("EVENING_PROFILE compile_ms=", Time.get_ticks_msec()-start)
	var water := TerrainWorldTuning.make_water(2697992464)
	var heightfield := TerrainWorldTuning.make_heightfield(2697992464, water)
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(2697992464, water, fields, program,
		SettlementPlan.new(2697992464, water))
	start = Time.get_ticks_msec()
	var frame := world.frame_for(Vector2i.ZERO)
	print("EVENING_PROFILE frame_ms=", Time.get_ticks_msec()-start)
	var vp := world.village_plan()
	var axis := vp._street_axis(frame)
	var urban := VillageWarrenFabricSolver.solve(VillageTerrainView.from_fields(fields), VillagePlan.warren_seed_for_cell(2697992464,frame.cell),frame.settlement_id,frame.centre,axis,program.villages,2697992464)
	print("FRAME axis=",axis," directions=",frame.incident_directions," transform=",urban.world_transform)
	print("FRAME entry=",urban.volumetric_spatial.source_volume.entry_cell," itinerary=",urban.volumetric_spatial.source_volume.primary_itinerary.slice(0,2))
	quit()
