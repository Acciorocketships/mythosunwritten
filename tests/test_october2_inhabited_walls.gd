extends GutTest

func test_wall_rooms_are_real_addressed_plots_inside_the_raised_district() -> void:
	var source := WarrenMazeSitePlanner.plan(13,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
	assert_not_null(source)
	if source == null: return
	var count := 0
	for plot: Dictionary in source.plots:
		if not bool(plot.get("wall_room",false)): continue
		count += 1
		assert_eq(plot.kind,WarrenMazeSourcePlan.PLOT_HOUSE)
		assert_true(source.passage_kinds.has(plot.door_walk))
		for column: Vector2i in plot.cells:
			assert_gte(int(plot.floor),source.massif.base_at(column))
			assert_eq(int(plot.top),source.massif.bearing_at(column))
			assert_lt(int(plot.floor),source.massif.bearing_at(column))
			for band in range(plot.floor,plot.top):
				assert_true(source.solid_at(Vector3i(column.x,band,column.y)),"room and structural cap keep the upper district borne")
	assert_gt(count,0,"a lower street should address houses built into this platform")
	var changed := false
	for plot: Dictionary in source.plots:
		if not bool(plot.get("wall_room",false)): continue
		var column: Vector2i = plot.cells[0]
		var invalid := plot.duplicate(true)
		invalid.floor = source.massif.base_at(column)-1
		assert_false(source.wall_room_support_ok(invalid,column),"wall rooms never excavate natural ground")
		invalid = plot.duplicate(true)
		invalid.top -= 1
		assert_false(source.wall_room_support_ok(invalid,column),"the cap must reach the district's bearing datum")
		changed = true
		break
	assert_true(changed)

func test_inhabited_wall_builds_without_floating_mass_or_blocked_public_air() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(13,{},program,WarrenVillageScaleProfile.for_id(&"large"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
	assert_true((built.payload as EnvironmentInstancePayload).validate())
	assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
	assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,SuntailBuildingKit.create()).intrusions),0)
	var rooms := 0
	for mass: BuildingMass in built.masses:
		if not String(mass.stable_id).contains("wall-room"): continue
		rooms += 1
		assert_eq(mass.roofs.size(),0,"an embedded room has a structural ceiling, never a roof intersecting the wall")
	assert_gt(rooms,0,"the room plots survive construction as inhabited kit buildings")
	var source := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
	var platform: BuildingMass = null
	for mass: BuildingMass in built.masses:
		if mass.stable_id==&"kit.platform-wall": platform = mass
	assert_not_null(platform)
	for plot: Dictionary in source.plots:
		if not bool(plot.get("wall_room",false)): continue
		var span := WarrenMazeBlockPartitioner.plot_roof_band_span(source,plot,spatial.source_volume)
		for column: Vector2i in plot.cells:
			for band in range(span.x,span.y):
				for dx in 2:
					for dz in 2:
						var cell := Vector3i(column.x*2+dx,band,column.y*2+dz)
						assert_eq(spatial.grid.use_at(cell),WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,
							"the embedded room retains its masonry ceiling and upper district support")
						if platform != null:
							assert_true(platform.cells_at_band(band).has(Vector2i(cell.x,cell.z)),
								"the native wall renders the complete cap, including its lower slab band")

func test_other_platform_towns_keep_their_rooms_and_caps_constructible() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for job: Array in [[58,&"large"],[2,&"grand"],[7,&"standard"]]:
		var spatial := WarrenVolumetricSolver.generate(job[0],{},program,WarrenVillageScaleProfile.for_id(job[1]))
		assert_not_null(spatial,"%s: %s" % [job,WarrenVolumetricSolver.last_failure])
		if spatial == null: continue
		var source := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
		assert_true((built.payload as EnvironmentInstancePayload).validate())
		assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0,str(job))
		assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,SuntailBuildingKit.create()).intrusions),0,str(job))
		for plot: Dictionary in source.plots:
			if bool(plot.get("wall_room",false)):
				assert_true(source.wall_room_support_ok(plot,plot.cells[0]))
				var column: Vector2i = plot.cells[0]
				_assert_room_carries_existing_ceiling(source,plot,column)
				if not source.massif.is_platform(column): continue
				if int(plot.floor)<=source.massif.base_at(column): continue
				var span := WarrenMazeBlockPartitioner.plot_roof_band_span(source,plot,spatial.source_volume)
				var platform: BuildingMass = null
				for mass: BuildingMass in built.masses:
					if mass.stable_id==&"kit.platform-wall": platform = mass
				assert_not_null(platform)
				for band in range(span.x,span.y):
					for dx in 2:
						for dz in 2:
							var cell := Vector3i(column.x*2+dx,band,column.y*2+dz)
							assert_eq(spatial.grid.use_at(cell),WarrenSpatialGrid.Use.STRUCTURAL_VOLUME)
							if platform != null:
								assert_true(platform.cells_at_band(band).has(Vector2i(cell.x,cell.z)),
									"upper wall rooms retain their whole rendered structural cap")

func test_upper_streets_address_rooms_inside_the_next_tier_wall() -> void:
	var elevated := 0
	for job: Array in [[58,&"large"],[2,&"grand"],[13,&"grand"]]:
		var source := WarrenMazeSitePlanner.plan(job[0],{},WarrenVillageScaleProfile.for_id(job[1]),&"",false)
		assert_not_null(source,str(job))
		if source==null: continue
		for plot: Dictionary in source.plots:
			if not bool(plot.get("wall_room",false)): continue
			var column: Vector2i = plot.cells[0]
			if int(plot.floor)<=source.massif.base_at(column): continue
			if source.massif.is_platform(column): elevated += 1
			assert_true(source.passage_kinds.has(plot.door_walk))
			assert_true(source.solid_at(Vector3i(column.x,int(plot.floor)-1,column.y)))
			_assert_room_carries_existing_ceiling(source,plot,column)
	assert_gt(elevated,0,"an upper street should be able to address a home embedded in the next retaining tier")

func _assert_room_carries_existing_ceiling(source: WarrenMazeSourcePlan, plot: Dictionary, column: Vector2i) -> void:
	if source.massif.is_platform(column):
		assert_eq(int(plot.top),source.massif.bearing_at(column),"A citadel room reaches the platform bearing datum.")
		return
	var carries_house := false
	for upper: Dictionary in source.plots:
		if upper.id!=plot.id and not upper.get("wall_room",false) and upper.cells.has(column) and int(upper.floor)==int(plot.top):
			carries_house = true
	var ceiling := Vector3i(column.x,int(plot.top),column.y)
	var carries_terrace := source.passage_kinds.has(ceiling) and not source.excavation.flight_cells().has(ceiling)
	assert_true(carries_house or carries_terrace,"An ordinary wall room must carry an existing house or a level public terrace.")
