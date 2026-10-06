extends GutTest

func test_streets_can_address_real_rooms_under_existing_massif_buildings() -> void:
	var found := 0
	for seed_value in [41,67]:
		var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
		assert_not_null(source)
		if source == null: continue
		for plot: Dictionary in source.plots:
			if not plot.get("wall_room",false) or source.massif.is_platform(plot.cells[0]): continue
			found += 1
			var column: Vector2i = plot.cells[0]
			assert_true(source.wall_room_support_ok(plot,column))
			assert_gte(int(plot.floor),source.massif.base_at(column))
			assert_true(source.passage_kinds.has(plot.door_walk))
			var carries := false
			for upper: Dictionary in source.plots:
				if upper.id!=plot.id and upper.cells.has(column) and int(upper.floor)==int(plot.top): carries=true
			carries = carries or source.passage_kinds.has(Vector3i(column.x,plot.top,column.y))
			assert_true(carries,"The room must bear an existing plot or walked terrace.")
			for band in range(plot.floor,plot.top):
				assert_true(source.solid_at(Vector3i(column.x,band,column.y)),"Room and cap preserve support.")
	assert_gt(found,0,"Ordinary massif supports need inhabited frontage too.")

func test_retained_rooms_survive_construction_with_clear_streets_and_bearing() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(41,{},program,WarrenVillageScaleProfile.for_id(&"large"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
	assert_true(built.payload.validate())
	assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
	assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,SuntailBuildingKit.create()).intrusions),0)
	var count := 0
	for mass: BuildingMass in built.masses:
		if not String(mass.stable_id).contains("wall-room"): continue
		count += 1
		assert_eq(mass.roofs.size(),0,"Embedded rooms cannot add roofs through the building above.")
	assert_gt(count,0)

func test_elevated_streets_can_have_inhabited_support_below() -> void:
	var source := WarrenMazeSitePlanner.plan(41,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
	var count := 0
	for plot: Dictionary in source.plots:
		if not plot.get("wall_room",false): continue
		var column: Vector2i = plot.cells[0]
		var upper := Vector3i(column.x,plot.top,column.y)
		if not source.passage_kinds.has(upper): continue
		count += 1
		assert_true(source.wall_room_support_ok(plot,column))
		assert_false(source.excavation.flight_cells().has(upper))
		assert_true(source.passage_kinds.has(plot.door_walk))
		assert_gte(int(plot.top)-int(plot.floor),3,"A full storey plus its structural slab must fit.")
	assert_gt(count,0,"Public terraces need inhabited frontage as well as building supports.")

func test_street_ceiling_rooms_are_planned_after_optional_lane_pruning() -> void:
	# These towns lost their proposed upper street after the first implementation
	# placed terrace rooms during partition. A room must never depend on that lane.
	for seed_value in [1,4,14,16]:
		var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.select(seed_value),&"",false)
		assert_not_null(source)
		if source == null: continue
		assert_true(source.validate_construction(),source.last_rejection)
		for plot: Dictionary in source.plots:
			if plot.get("wall_room",false):
				assert_true(source.wall_room_support_ok(plot,plot.cells[0]),"Its final construction must still carry the ceiling.")

func test_short_wall_rooms_keep_roof_clearance_below_setback_houses() -> void:
	# The old 2/grand route no longer contains a short terrace (also before
	# the interior-court candidate). 41/large retains a real three-band room
	# at (2,2), under a walked terrace: keep exercising that geometry.
	var source := WarrenMazeSitePlanner.plan(41,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
	var short_terraces := 0
	for plot: Dictionary in source.plots:
		if not plot.get("wall_room",false): continue
		if int(plot.top)-int(plot.floor)>=4: continue
		var column: Vector2i = plot.cells[0]
		var walk := Vector3i(column.x,plot.top,column.y)
		assert_true(source.passage_kinds.has(walk))
		assert_false(source.excavation.flight_cells().has(walk))
		short_terraces += 1
	assert_gt(short_terraces,0,"A genuine low terrace room still survives.")
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source,program)
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial==null: return
	var fabric := spatial.compiled_fabric_cache()
	assert_true(fabric.validate())
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial,fabric,kit)
	assert_true(built.payload.validate())
	assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
	assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)
