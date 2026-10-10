extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := args[args.find("--cities")+1] if args.has("--cities") else "31:large,53:grand,63:grand,83:grand,103:grand,301:grand"
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var output := {}
	for city: String in cities.split(","):
		var fields := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(fields[0]),{},program,WarrenVillageScaleProfile.for_id(StringName(fields[1])))
		if spatial == null:
			output[city] = {"failure":WarrenVolumetricSolver.last_failure}
			continue
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		var options := []
		for record: Dictionary in WarrenPlotPlanner.outcomes(source).get("tunnel_roofs",[]):
			if not String(record.reason).begins_with("would overtop"): continue
			var walk: Vector3i = record.walk
			var column := Vector2i(walk.x,walk.z)
			var crown := source.passage_headroom_top(walk)
			var candidates := []
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				for index: int in source.plots_at(column+direction):
					var plot: Dictionary = source.plots[index]
					if plot.kind!=WarrenMazeSourcePlan.PLOT_HOUSE: continue
					var floor_band := int(plot.floor)
					while floor_band<=crown: floor_band+=WarrenBuildingParcel.STOREY_BANDS
					var fits := floor_band<=crown+WarrenPlotPlanner.TUNNEL_OVER_MAX_LIFT and floor_band+WarrenBuildingParcel.STOREY_BANDS+WarrenBuildingParcel.ROOF_RESERVATION_BANDS<=int(plot.top)
					var ceiling := mini(WarrenTownPlatform.huddle_top(source.massif,column),WarrenPlotPlanner._edge_limit(source,column,floor_band,WarrenBuildingParcel.ROOF_RESERVATION_BANDS))
					candidates.append({"id":plot.id,"floor":floor_band,"top":plot.top,"fits":fits,"ceiling":ceiling,"legal":fits and int(plot.top)<=ceiling})
			options.append({"walk":walk,"reason":record.reason,"candidates":candidates})
		output[city]=options
	var path := args[args.find("--output")+1] if args.has("--output") else "/tmp/tunnel-host-options.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	quit()
