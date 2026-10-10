extends GutTest

func test_split_public_landing_does_not_grow_an_internal_parapet() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	mass.stable_id = &"split-landing"
	var storey := mass.add_storey(0,{Vector2i.ZERO:true},BuildingMass.MATERIAL_STONE)
	storey.fortified = true
	var assembler := BuildingKitAssembler.new(kit)
	var catalog := EnvironmentCatalog.load_default()
	var crossing := Vector3(2,3.6,1)
	var variants: Array[Array] = []
	for across in [false,true]:
		assembler.public_floor = func(cell: Vector2i, band: int) -> bool:
			return band==2 and (cell==Vector2i.ZERO or (across and cell==Vector2i.RIGHT))
		variants.append(assembler.assemble(mass))
	var closed := 0
	var open := 0
	var bearing_after := 0
	for part: Dictionary in variants[0]:
		closed += int(((part.transform as Transform3D)*catalog.descriptor(part.asset_id).measured_aabb).has_point(crossing))
	for part: Dictionary in variants[1]:
		open += int(((part.transform as Transform3D)*catalog.descriptor(part.asset_id).measured_aabb).has_point(crossing))
		bearing_after += int((part.transform as Transform3D).origin.y<3.0)
	assert_gt(closed,0,"an exposed edge retains its guard")
	assert_eq(open,0,"a public walk on both sides crosses the retained seam")
	assert_gt(bearing_after,0,"retain the grounded wall below the landing")
	assert_lt(variants[1].size(),variants[0].size())

func test_nested_rings_preserve_lower_district_space_and_reach_every_tier() -> void:
	var nested_examples := 0
	for seed_value in [2,13,58,67,78,95]:
		var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&"grand"),&"",false)
		assert_not_null(source,str(seed_value))
		if source == null: continue
		var massif := source.massif
		var levels := {}
		var reached := {}
		var housed := {}
		for column: Vector2i in massif.platform_columns(): levels[massif.plinth_at(column)] = true
		# Available crown area determines whether this seed has one or more
		# tiers; every generated tier must still be reached and inhabited.
		assert_gt(levels.size(),0,"exercise fortified examples")
		nested_examples += int(levels.size() >= 2)
		for cell: Vector3i in source.excavation.public_cells():
			var column := Vector2i(cell.x,cell.z)
			if cell.y == massif.bearing_at(column): reached[massif.plinth_at(column)] = true
		for plot: Dictionary in source.plots:
			if plot.kind not in [WarrenMazeSourcePlan.PLOT_HOUSE,WarrenMazeSourcePlan.PLOT_ASSET]: continue
			for column: Vector2i in plot.cells:
				if plot.floor == massif.bearing_at(column): housed[massif.plinth_at(column)] = true
		for level: int in levels:
			assert_true(reached.has(level),"%d tier %d has a gate-connected street" % [seed_value,level])
			assert_true(housed.has(level),"%d tier %d is an inhabited district" % [seed_value,level])

	assert_gte(nested_examples,2,"exercise multiple actual nested districts")

func test_nested_ring_sampling_is_optional_and_seeded() -> void:
	var one := 0
	var none := 0
	var nested := 0
	for seed_value in range(1,41):
		var a := WarrenMassifBuilder.build(seed_value,{},WarrenVillageScaleProfile.for_id(&"grand"))
		var b := WarrenMassifBuilder.build(seed_value,{},WarrenVillageScaleProfile.for_id(&"grand"))
		assert_eq(a.columns,b.columns)
		var levels := {}
		for column: Vector2i in a.platform_columns(): levels[a.plinth_at(column)] = true
		none += int(levels.is_empty())
		one += int(levels.size()==1)
		nested += int(levels.size()>1)
	assert_gt(none,0)
	assert_gt(one,0)
	assert_gt(nested,0)

func test_gate_frames_belong_only_to_their_own_wall_tier() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(13,{},program,WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial)
	if spatial == null: return
	var gates := KitVillageBuildings._platform_gate_edges(spatial)
	assert_eq(gates.size(),2,"outer and inner gates are both represented")
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
	var emitted := {}
	for mass: BuildingMass in built.masses:
		if mass.stable_id != &"kit.platform-wall": continue
		for storey: Dictionary in mass.storeys:
			var top := int(storey.floor_band)+int(storey.get("bands",2))
			for edge: Vector3i in storey.gate_frames:
				if not bool(storey.gate_frames[edge]): continue
				assert_true((gates.get(top,{}) as Dictionary).has(edge),"no copy of the lower gate at the upper height")
				var key := Vector4i(edge.x,edge.y,edge.z,top)
				assert_false(emitted.has(key),"one owner per gate edge")
				emitted[key] = true
	var expected := 0
	for band: int in gates:
		for edge: Vector3i in gates[band]: expected += int(bool(gates[band][edge]))
	assert_eq(emitted.size(),expected,"each whole gate frame has exactly one owner at its actual rim datum")
