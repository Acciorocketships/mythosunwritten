extends GutTest
const FIELD = preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")

func test_surrounding_districts_have_finished_streets_and_buildings() -> void:
	for seed_value in [17,24]:
		var profile := WarrenVillageScaleProfile.for_id(&"large")
		var field := FIELD.sample(seed_value,profile)
		assert_true(field.central_green)
		var source := WarrenMazeSitePlanner.plan(seed_value,{},profile,&"",false)
		assert_not_null(source,WarrenMazeSitePlanner.last_failure)
		if source == null: continue
		assert_true(source.validate_construction(),source.last_rejection)
		for id in field.lobes.size():
			var streets := 0
			var rooms := 0
			for column: Vector2i in source.massif.columns:
				if int(source.massif.columns[column].district_lobe) != id: continue
				for cell: Vector3i in source.passage_kinds:
					if Vector2i(cell.x,cell.z) == column: streets += 1
				for plot: Dictionary in source.plots:
					if plot.cells.has(column): rooms += 1
			assert_gt(streets,0,"every surrounding cluster needs connected access")
			assert_gt(rooms,0,"unbuilt masses do not enclose an inhabited green")
		for column: Vector2i in source.massif.columns:
			if not bool(source.massif.columns[column].get("planting_core",false)): continue
			for cell: Vector3i in source.passage_kinds:
				assert_ne(Vector2i(cell.x,cell.z),column,"district access must preserve planted cores")

func test_central_green_is_optional_and_repeatable() -> void:
	var selected := 0
	var ordinary := 0
	for seed_value in range(1,41):
		var profile := WarrenVillageScaleProfile.for_id(&"large")
		var field := FIELD.sample(seed_value,profile)
		if field.central_green:
			selected += 1
			assert_gte(field.lobes.size(),4)
			assert_gte(float(field.clearings[0].radius),float(profile.radius_cells)*0.55,
				"plan a grove-sized central clearing before fitting individual houses")
			assert_false(field.solid.has(Vector2i((field.green_centre as Vector2).round())))
		else: ordinary += 1
		assert_eq(field,FIELD.sample(seed_value,profile))
	assert_gt(selected,0)
	assert_gt(ordinary,selected,"ordinary town arrangements stay more common")

func test_central_green_has_reserved_walkable_ground_between_districts() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	var field := FIELD.sample(17,profile)
	var centre_ground := {}
	for space: Dictionary in field.open_spaces:
		if space.id==&"open.central_ground": centre_ground=space.cells
	assert_gt(centre_ground.size(),25,"The enclosed green is part of the town, not an absent route domain.")
	for column: Vector2i in centre_ground:
		assert_true(field.height_domain.has(column))
		assert_false(field.solid.has(column),"Access ground must never become building mass.")
	var source := WarrenMazeSitePlanner.plan(17,{},profile,&"",false)
	assert_not_null(source)
	if source==null: return
	assert_true(source.validate_construction(),source.last_rejection)
	var access_cells := 0
	var longest := 0
	var core := 0
	for column: Vector2i in centre_ground:
		assert_true(source.massif.is_reserved_ground(column))
		core += int(source.massif.columns[column].get("planting_core",false))
	assert_gte(core,4,"Direct access retains a protected planting island.")
	for lane: Dictionary in source.excavation.lanes:
		if lane.get("feature_kind",&"")!=&"district_access": continue
		access_cells += lane.cells.size()
		longest = maxi(longest,lane.cells.size())
	assert_lt(access_cells,50,"The old shoulder-only domain used 64 access cells.")
	assert_lte(longest,22,"The former 31-cell outer detour crosses legal open ground instead.")

func test_central_ground_routes_keep_complete_supported_town_construction() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := SuntailBuildingKit.create()
	for seed_value in [17,24]:
		var spatial := WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.for_id(&"large"))
		assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
		if spatial==null: continue
		var fabric := spatial.compiled_fabric_cache()
		assert_true(fabric.validate())
		var built := KitVillageBuildings.build(spatial,fabric,kit)
		assert_true(built.payload.validate())
		assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
		var roofs := preload("res://tests/fixtures/kit_roof_audit.gd").audit(built,kit)
		for key in ["gable_holes","open_exposed","air_unsupported"]:
			assert_eq(int(roofs[key]),0,str([seed_value,roofs.examples]))
		assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)

func test_added_central_ground_keeps_its_sampled_terrain_datum() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"large")
	var field := FIELD.sample(17,profile)
	var ground := {}
	for column: Vector2i in field.height_domain:
		ground[column] = floori(float(column.x)/5.0)
	var massif := WarrenMassifBuilder.build(17,ground,profile)
	assert_not_null(massif,WarrenMassifBuilder.last_failure)
	if massif==null: return
	var checked := 0
	for space: Dictionary in field.open_spaces:
		if space.id!=&"open.central_ground": continue
		for column: Vector2i in space.cells:
			assert_eq(massif.base_at(column),int(ground[column]),"Open ground must not invent a flat natural datum.")
			assert_true(massif.is_reserved_ground(column))
			checked += 1
	assert_gt(checked,25)
