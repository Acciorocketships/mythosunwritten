extends GutTest

func test_accepted_crown_landing_remains_flat_with_an_open_guard_seam() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(43,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial==null:return
	var fabric := spatial.compiled_fabric_cache()
	var network := SettlementFabricAssembler.maze_exterior_network(fabric)
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial,fabric,kit)
	var landing := Vector3i(6,4,-4)
	assert_true(network.terrace_cells.has(landing),"Reported bridge lands on a construction crown")
	var deck_found := false
	for mass:BuildingMass in built.masses:
		for deck:Dictionary in mass.decks:
			if deck.band==landing.y and deck.cells.has(Vector2i(landing.x,landing.z)):deck_found=true
		for roof:Dictionary in mass.roofs:
			assert_false(roof.eave_band==landing.y and roof.rect.has_point(Vector2i(landing.x,landing.z)),"An accepted flat landing must never become a pitched roof")
	assert_true(deck_found,"The kit replacement must actually draw the landing floor")
	assert_true(built.payload.validate())
	assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
	assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)
	var surfaces := fabric.surface_plan
	var before := surfaces.mesh_payloads.duplicate(true)
	surfaces.finish_exterior_bridge_guards(network.spans)
	assert_eq(surfaces.mesh_payloads,before,"Re-sealing late bridge openings must not accumulate rail triangles or alter treads")
	var edges := SettlementFabricAssembler.maze_terrace_edges(fabric)
	var direction := SettlementFabricAssembler.FACE_DIRECTIONS.find(Vector3i.LEFT)
	assert_false(edges.has(Vector4i(landing.x,landing.y,landing.z,direction)),"No terrace railing across the accepted bridge mouth")
	assert_gt(edges.size(),0,"Unconnected terrace edges keep their fall protection")
