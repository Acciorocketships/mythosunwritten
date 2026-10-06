extends GutTest

func test_raised_district_has_a_real_connected_through_passage() -> void:
	var source := WarrenMazeSitePlanner.plan(13,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
	assert_not_null(source)
	if source == null: return
	var tunnels := 0
	for lane: Dictionary in source.excavation.lanes:
		if lane.get("feature_kind",&"")!=&"wall_tunnel": continue
		tunnels += 1
		assert_true(source.passage_kinds.has(lane.anchor))
		for cell: Vector3i in lane.cells:
			var column := Vector2i(cell.x,cell.z)
			assert_gte(cell.y,source.massif.base_at(column),"never dig through natural ground")
			assert_true(source.massif.is_platform(column))
			for band in range(cell.y,cell.y+WarrenExcavation.HEADROOM_BANDS):
				assert_false(source.solid_at(Vector3i(cell.x,band,cell.z)),"a tunnel is owned public air")
			assert_true(source.solid_at(cell+Vector3i.UP*WarrenExcavation.HEADROOM_BANDS),"retain the district's bearing ceiling")
		var joins := false
		for edge: Dictionary in source.excavation.loop_edges:
			if edge.from==lane.cells.back() and source.passage_kinds.has(edge.to): joins = true
		assert_true(joins,"the tunnel exits onto another connected street")
	assert_gt(tunnels,0,"this raised district should admit a through-route under its wall")

func test_through_routes_survive_construction_with_borne_ceilings_and_clear_roofs() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for case: Array in [[13,&"large"],[58,&"large"],[2,&"grand"],[7,&"standard"]]:
		var spatial := WarrenVolumetricSolver.generate(case[0],{},program,WarrenVillageScaleProfile.for_id(case[1]))
		assert_not_null(spatial,str(case)+": "+WarrenVolumetricSolver.last_failure)
		if spatial == null: continue
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial,fabric,SuntailBuildingKit.create())
		assert_true((built.payload as EnvironmentInstancePayload).validate())
		assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0,str(case))
		assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,SuntailBuildingKit.create()).intrusions),0,str(case))

func test_platform_boring_is_explicit_and_preserves_ground_ceiling_and_reservations() -> void:
	var massif := WarrenMassif.new(1)
	massif.columns[Vector2i.ZERO] = {"base":0,"top":10,"plinth":4,"terrace":10}
	var excavation := WarrenExcavation.new(1)
	assert_false(WarrenPassageLatticeRules.slot_is_borable(massif,excavation,Vector3i.ZERO,3),
		"ordinary alleys cannot eat the raised district")
	assert_true(WarrenPassageLatticeRules.slot_is_borable(massif,excavation,Vector3i.ZERO,3,false,false,true))
	assert_false(WarrenPassageLatticeRules.slot_is_borable(massif,excavation,Vector3i.DOWN,3,false,false,true))
	assert_false(WarrenPassageLatticeRules.slot_is_borable(massif,excavation,Vector3i.UP,3,false,false,true),
		"at least one whole bearing band must remain")
	excavation.construction_reservations[Vector3i.UP] = true
	assert_false(WarrenPassageLatticeRules.slot_is_borable(massif,excavation,Vector3i.ZERO,3,false,false,true))
	excavation.construction_reservations.clear()
	excavation.carved[Vector3i.UP*3] = true
	assert_false(WarrenPassageLatticeRules.slot_is_borable(massif,excavation,Vector3i.ZERO,3,false,false,true),
		"never join through an already removed ceiling")

func test_corner_route_keeps_its_unbored_supports_and_ceiling() -> void:
	var massif := WarrenMassif.new(1)
	for x in range(3):
		for z in range(3):
			massif.columns[Vector2i(x,z)] = {"base":0,"top":10,"plinth":4,"terrace":10}
	var excavation := WarrenExcavation.new(1)
	var start := Vector3i(-1,0,1)
	var finish := Vector3i(1,0,-1)
	excavation.route.append(start)
	excavation.transitions.append({"from":start,"to":finish,"kind":WarrenVolumeTransition.Kind.LEVEL})
	var occupied := {start:true,finish:true}
	assert_eq(WarrenPlatformStreets.carve_tunnel(1,massif,excavation,occupied),3,
		"adjacent street faces can join through a supported three-column corner bore")
	if excavation.lanes.is_empty(): return
	var lane: Dictionary = excavation.lanes.back()
	assert_true(lane.cells.has(Vector3i(1,0,1)),"turn inside the district")
	for cell: Vector3i in lane.cells:
		assert_false(excavation.carved.has(cell+Vector3i.UP*WarrenExcavation.HEADROOM_BANDS))
	var caps := WarrenMazeCarver._natural_tunnel_caps(1,massif,excavation,{}, {})
	for cell: Vector3i in lane.cells:
		assert_eq(int(caps[Vector2i(cell.x,cell.z)]),WarrenExcavation.HEADROOM_BANDS,
			"retention must not turn an adjacent leg back into solid wall")
	assert_eq(int(caps[Vector2i(2,1)]),0)
	assert_eq(int(caps[Vector2i(1,2)]),0)
	var refused := WarrenExcavation.new(1)
	refused.route.append(start)
	refused.transitions.append({"from":start,"to":finish,"kind":WarrenVolumeTransition.Kind.LEVEL})
	massif.columns.erase(Vector2i(2,1))
	assert_eq(WarrenPlatformStreets.carve_tunnel(1,massif,refused,{start:true,finish:true}),0,
		"a corner with a missing outside bearing is not a tunnel candidate")
	assert_true(refused.carved.is_empty(),"failed proof cannot leave partial excavation")

func test_direct_wall_tunnel_does_not_inherit_the_alley_turn_limit() -> void:
	var source := WarrenMazeSitePlanner.plan(11,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
	assert_not_null(source)
	if source == null: return
	assert_true(source.validate_construction(),source.last_rejection)
	var exercised := false
	for lane: Dictionary in source.excavation.lanes:
		if lane.get("feature_kind",&"") != &"wall_tunnel": continue
		var walk: Array[Vector3i] = [lane.anchor]
		walk.append_array(lane.cells)
		if WarrenMazeSourcePlan._max_straight_run(walk) <= WarrenMazeSourcePlan.MAX_ALLEY_STRAIGHT_RUN:
			continue
		exercised = true
		assert_lte(walk.size(),8,"the through-route retains its bounded bore budget")
		# An ordinary alley with these same cells must still fail its cadence
		# guard. Only the explicitly constructed wall-tunnel role is exempt.
		lane.feature_kind = &"alley"
		assert_gt(source._max_alley_straight_run(),WarrenMazeSourcePlan.MAX_ALLEY_STRAIGHT_RUN)
		lane.feature_kind = &"wall_tunnel"
	assert_true(exercised,"keep a real longer straight tunnel in this regression")
	assert_true(source.validate_construction(),source.last_rejection)
