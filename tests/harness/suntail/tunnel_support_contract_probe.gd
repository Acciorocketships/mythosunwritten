extends SceneTree
## Compare admitted source tunnel compounds with their constructed bearing cells.
## This does not count a source-labelled tunnel as finished architecture.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := args[args.find("--cities")+1] if args.has("--cities") else "31:large,53:grand,63:grand,83:grand,103:grand,301:grand,101:large"
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var output := {}
	for city: String in cities.split(","):
		var fields := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(fields[0]),{},program,WarrenVillageScaleProfile.for_id(StringName(fields[1])))
		if spatial == null:
			output[city]={"failure":WarrenVolumetricSolver.last_failure}
			continue
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		var occupied := WarrenVolumetricSolver.building_private_cells(spatial.buildings)
		var covers := []
		for plot: Dictionary in source.plots:
			if plot.kind!=WarrenMazeSourcePlan.PLOT_OVER: continue
			var rooms := 0
			for column: Vector2i in plot.cells:
				for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x,plot.floor,column.y)):
					rooms+=int(occupied.has(cell))
			var missing := []
			for jamb: Vector2i in plot.get("jambs",[]):
				var candidates := []
				for index: int in source.plots_at(jamb):
					var support: Dictionary=source.plots[index]
					candidates.append({"id":support.id,"kind":support.kind,"floor":support.floor,"top":support.top,"roof_span":WarrenMazeBlockPartitioner.plot_roof_band_span(source,support,spatial.source_volume)})
				for band in [int(plot.crown)-1,int(plot.crown)]:
					for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(jamb.x,band,jamb.y)):
						var use := spatial.grid.use_at(cell)
						if use==WarrenSpatialGrid.Use.STRUCTURAL_VOLUME or (use==WarrenSpatialGrid.Use.PRIVATE_VOLUME and occupied.has(cell)): continue
						missing.append({"cell":cell,"use":WarrenSpatialGrid.Use.keys()[use],"source_support_plots":candidates})
			covers.append({"id":plot.id,"columns":plot.cells,"floor":plot.floor,"crown":plot.crown,"host":plot.get("host",&""),"finished_room_cells":rooms,"expected_room_cells":plot.cells.size()*4,"missing_bearings":missing})
		output[city]=covers
		print("SUPPORT_CONTRACT ",city," covers=",covers.size())
	var path := args[args.find("--output")+1] if args.has("--output") else "/tmp/tunnel-support-contract.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	quit()
