extends SceneTree
## Diagnose exact headroom and neighboring house-storey alignment on finished plans.
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := "13:large,31:large,43:grand,101:large,103:grand"
	if args.has("--cities"): cities=args[args.find("--cities")+1]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var results := {}
	for city: String in cities.split(","):
		var parts := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]),{},program,WarrenVillageScaleProfile.for_id(StringName(parts[1])))
		if spatial==null:
			results[city]={"failure":WarrenVolumetricSolver.last_failure}
			continue
		var source: WarrenMazeSourcePlan=spatial.source_volume.mass_context[&"maze_source_plan"]
		var rows := []
		for record: Dictionary in WarrenPlotPlanner.outcomes(source).get("tunnel_roofs",[]):
			if record.get("reason","")!="no adjacent house storey over the crown":continue
			var walk: Vector3i=record.walk
			var roof := source.passage_headroom_top(walk)
			var candidates := []
			var seen := {}
			for dir: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				for index: int in source.plots_at(Vector2i(walk.x,walk.z)+dir):
					if seen.has(index):continue
					seen[index]=true
					var plot: Dictionary=source.plots[index]
					if plot.kind!=WarrenMazeSourcePlan.PLOT_HOUSE:continue
					var floor_band := int(plot.floor)
					while floor_band<=roof:floor_band+=WarrenBuildingParcel.STOREY_BANDS
					candidates.append({"id":plot.id,"base":plot.floor,"top":plot.top,"floor_above_crown":floor_band,"lift":floor_band-roof,"whole_storey_fits":floor_band+WarrenBuildingParcel.STOREY_BANDS+WarrenBuildingParcel.ROOF_RESERVATION_BANDS<=int(plot.top)})
			rows.append({"walk":walk,"roof":roof,"candidates":candidates})
		results[city]=rows
		print("TUNNEL_HOST ",city," ",rows)
	if args.has("--output"):FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	quit()
