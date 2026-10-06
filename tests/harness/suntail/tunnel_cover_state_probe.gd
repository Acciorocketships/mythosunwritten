extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[args.find("--seed")+1]) if args.has("--seed") else 7
	var profile := StringName(args[args.find("--profile")+1]) if args.has("--profile") else &"large"
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.for_id(profile))
	if spatial==null:
		push_error(WarrenVolumetricSolver.last_failure)
		quit(1)
		return
	var source: WarrenMazeSourcePlan=spatial.source_volume.mass_context[&"maze_source_plan"]
	var rooms := WarrenVolumetricSolver.building_private_cells(spatial.buildings)
	for plot: Dictionary in source.plots:
		if plot.kind!=WarrenMazeSourcePlan.PLOT_OVER:continue
		print("PLOT ",plot)
		var column: Vector2i=plot.cells[0]
		for band in range(int(plot.crown)-1,int(plot.floor)+3):
			var row := []
			for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x,band,column.y)):
				row.append({"cell":cell,"use":spatial.grid.use_at(cell),"owner":spatial.grid.owner_name_at(cell),"room":rooms.has(cell)})
			print("BAND ",row)
	quit()
