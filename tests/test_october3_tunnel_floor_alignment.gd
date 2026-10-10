extends GutTest

func test_host_accepts_either_storey_phase_without_growing_the_house() -> void:
	var plan := WarrenMazeSourcePlan.new(1,WarrenVillageScaleProfile.for_id(&"standard"),null,null)
	plan.plots=[{"kind":WarrenMazeSourcePlan.PLOT_HOUSE,"cells":[Vector2i(1,0)],"floor":0,"top":8}]
	plan._rebuild_plot_columns()
	assert_eq(WarrenPlotPlanner._tunnel_host(plan,Vector2i.ZERO,2),Vector2i(0,4))
	plan.plots[0].floor=1
	assert_eq(WarrenPlotPlanner._tunnel_host(plan,Vector2i.ZERO,2),Vector2i(0,3))
	plan.plots[0].top=6
	assert_eq(WarrenPlotPlanner._tunnel_host(plan,Vector2i.ZERO,2).x,-1,"The complete room and roof must fit the existing house")
	plan.plots[0].floor=5
	plan.plots[0].top=12
	assert_eq(WarrenPlotPlanner._tunnel_host(plan,Vector2i.ZERO,2).x,-1,"Do not admit a distant high floor")

func test_recovered_covers_have_whole_rooms_crowns_and_public_headroom() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var realized := 0
	for item: Array in [[13,&"large"],[31,&"large"],[7,&"large"]]:
		var spatial := WarrenVolumetricSolver.generate(item[0],{},program,WarrenVillageScaleProfile.for_id(item[1]))
		assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
		if spatial==null:continue
		var source: WarrenMazeSourcePlan=spatial.source_volume.mass_context[&"maze_source_plan"]
		var private_cells := WarrenVolumetricSolver.building_private_cells(spatial.buildings)
		for plot: Dictionary in source.plots:
			if plot.kind!=WarrenMazeSourcePlan.PLOT_OVER:continue
			var column: Vector2i=plot.cells[0]
			var rooms := 0
			var crowns := 0
			for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x,int(plot.floor),column.y)):
				rooms+=int(private_cells.has(cell))
			for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x,int(plot.crown),column.y)):
				crowns+=int(spatial.grid.use_at(cell)==WarrenSpatialGrid.Use.STRUCTURAL_VOLUME)
				assert_eq(spatial.grid.use_at(cell+Vector3i.DOWN),WarrenSpatialGrid.Use.PUBLIC_AIR)
			assert_true((rooms==4 and crowns==4) or (rooms==0 and crowns==0),"A cover is whole or absent: %s rooms=%d crowns=%d"%[column,rooms,crowns])
			for bearing_band in range(int(plot.crown)+1,int(plot.floor)):
				var course := 0
				for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x,bearing_band,column.y)):
					course+=int(spatial.grid.use_at(cell)==WarrenSpatialGrid.Use.STRUCTURAL_VOLUME)
				assert_eq(course,4 if rooms==4 else 0,"Every intermediate bearing course is whole or absent")
			realized+=int(rooms==4 and crowns==4)
	assert_gt(realized,0,"The alignment repair must reach finished inhabited tunnel covers")
