extends GutTest

func test_upper_square_reserves_a_supported_planting_island_inside_its_walk() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(13,{},program,
		WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial == null: return
	var source := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
	var fabric := spatial.compiled_fabric_cache()
	var square: Dictionary = {}
	for plot: Dictionary in source.plots:
		if plot.id != WarrenPlotReservations.PLAZA_PLOT_ID: continue
		for column: Vector2i in plot.cells:
			for dx in 2:
				for dz in 2:
					square[Vector3i(column.x*2+dx,plot.floor,column.y*2+dz)] = true
	assert_eq(square.size(),16,"exercise the upper 2 by 2 macro square")
	var planting := 0
	var walking := 0
	for cell: Vector3i in square:
		var interior := true
		for step: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			interior = interior and square.has(cell+step)
		if interior:
			planting += 1
			assert_true(spatial.grid.use_at(cell+Vector3i.DOWN) in [WarrenSpatialGrid.Use.STRUCTURAL_VOLUME,WarrenSpatialGrid.Use.PRIVATE_VOLUME],"planting stands on real retained or inhabited support")
			assert_false(fabric.surface_plan.has_cell(cell),"the planting island is not reserved walking air")
			assert_true(fabric.planned_plaza_cells.has(cell+Vector3i.DOWN),"the whole island retains turf support")
		else:
			walking += 1
			assert_true(fabric.surface_plan.has_cell(cell),"a continuous ring serves every court entrance")
	assert_eq(planting,4)
	assert_eq(walking,12)
	for segment: Dictionary in fabric.surface_plan.guard_segments:
		var key := String(segment.stable_key).split(":")
		var neighbour := Vector3i(int(key[0])+int(key[3]),int(key[1]),int(key[2])+int(key[4]))
		assert_false(fabric.planned_plaza_planting_cells.has(neighbour+Vector3i.DOWN),
			"level supported planting is not a fall requiring a rail")
	var bridge_cells := SettlementFabricAssembler.maze_skywalk_cells(
		SettlementFabricAssembler.maze_skywalk_spans(fabric))
	for support: Vector3i in fabric.planned_plaza_planting_cells:
		assert_false(bridge_cells.has(support+Vector3i.UP),
			"late skywalk assembly preserves the reserved planting island")
	var ground := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	var entries := SettlementFabricAssembler.maze_plaza_entries(fabric.planned_plaza_cells,ground.walked)
	var feature := SettlementFabricAssembler.maze_plaza_centre_feature(fabric.planned_plaza_cells,
		entries,ground.footprints,SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),ground.walked,true,1)
	assert_false(feature.is_empty(),"the reserved island receives a measured centre feature")
	if not feature.is_empty():
		assert_true(feature.asset in [&"lpfv.tree.01",&"lpfv.tree.02"],"new courtyard islands use leafy shade trees")
		var bounds: AABB = ground.footprints.asset_bounds[feature.asset]
		assert_almost_eq((feature.origin as Vector3).y+bounds.position.y*float(feature.get("scale",1.0)),12.005,0.001,
			"the measured root meets the upper court's actual supporting floor")
		var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
		var batch: Dictionary = payload.batches.get(StringName(feature.asset), {})
		assert_false(batch.is_empty(), "the selected leafy tree reaches the rendered payload")
		if not batch.is_empty():
			var found := false
			for index in batch.ids.size():
				if not String(batch.ids[index]).begins_with("maze-plaza-centre/"): continue
				found = true
				assert_eq(batch.colors[index], BiomeRegistry.blended_environment_tint({&"meadow":1.0}, &"tree"),
					"native canopy materials receive their vegetation tint")
				var transform: Transform3D = batch.transforms[index]
				assert_almost_eq(transform.basis.get_scale().x, float(feature.get("scale",1.0)), 0.0001)
			assert_true(found, "the court centre retains its stable placement identity")
		var kit_payload := preload("res://tests/harness/suntail/kit_town_review.gd").town_payload(spatial,fabric,false)
		var catalog := EnvironmentCatalog.load_default()
		var centre: Vector3 = feature.origin
		var root_box := AABB(centre-Vector3(0.5,0.1,0.5),Vector3(1,0.5,1))
		for asset: StringName in kit_payload.batches:
			var parts: Dictionary = kit_payload.batches[asset]
			for index in parts.ids.size():
				if String(parts.ids[index]).begins_with("kit.skywalk."):
					var bridge_box: AABB = parts.transforms[index]*catalog.descriptor(asset).measured_aabb
					var tree_box := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*float(feature.get("scale",1.0))),centre)*bounds
					assert_false(bridge_box.intersects(tree_box),
						"native bridge decks and rails cannot cross the reserved courtyard tree")
				if not String(parts.ids[index]).begins_with("kit.retained/"): continue
				var box: AABB = parts.transforms[index]*catalog.descriptor(asset).measured_aabb
				if box.intersects(root_box):
					assert_lte(box.end.y,12.005,"retaining frame stays below the supported garden, not through its tree roots")

func test_daylight_alone_cannot_retain_a_floating_crown() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO,Vector3i(3,4,3))
	var cell := Vector3i(1,2,1)
	var tx := grid.begin_transaction(&"garden")
	assert_true(tx.assign_use([cell] as Array[Vector3i],WarrenSpatialGrid.Use.DAYLIGHT_AIR,&"garden"))
	assert_true(tx.commit())
	assert_false(WarrenVolumetricSolver.bears_construction(grid,cell,{}),"ordinary empty sky bears nothing")
	var floor := grid.begin_transaction(&"garden")
	assert_true(floor.claim_face(cell,Vector3i.DOWN,WarrenSpatialGrid.FaceKind.GARDEN_FLOOR,&"garden"))
	assert_true(floor.commit())
	assert_true(WarrenVolumetricSolver.bears_construction(grid,cell,{}),"only a constructed garden floor carries the bed")

func test_planting_cannot_claim_the_court_entrance_edge() -> void:
	var fabric := SettlementFabricPlan.new(&"planting-contract")
	var square := {}
	for x in 4:
		for z in 4: square[Vector3i(x,0,z)] = true
	assert_false(fabric.set_planned_plaza(square,{Vector3i.ZERO:true}))
	assert_true(fabric.planned_plaza_cells.is_empty(),"a refused declaration is atomic")
	assert_true(fabric.set_planned_plaza(square,{Vector3i(1,0,1):true}))
