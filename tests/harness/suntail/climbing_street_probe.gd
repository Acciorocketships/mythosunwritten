extends SceneTree


## Inspect structural bridge refusals and downstream allocation beside climbing streets.
func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := "31:large,43:grand,101:large,103:grand"
	if args.has("--cities"):
		cities = args[args.find("--cities") + 1]
	var output := {}
	var program := (
		SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		if args.has("--finished")
		else null
	)
	for city: String in cities.split(","):
		var fields := city.split(":")
		var seed_value := int(fields[0])
		var profile := WarrenVillageScaleProfile.for_id(StringName(fields[1]))
		var source: WarrenMazeSourcePlan
		var spatial: WarrenSpatialPlan
		if args.has("--finished"):
			spatial = WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
			if spatial != null:
				source = spatial.source_volume.mass_context[&"maze_source_plan"]
		else:
			var massif := WarrenMassifBuilder.build(seed_value, {}, profile)
			source = WarrenMazeCarver.carve(seed_value, massif, profile)
		if source == null:
			output[city] = {"failure": WarrenMazeCarver.last_failure}
			continue
		var reasons := {}
		for record: Dictionary in source.excavation.bridge_span_audit.get("refused", []):
			var reason := String(record.get("reason", ""))
			reasons[reason] = int(reasons.get(reason, 0)) + 1
		var gates: Array = []
		for lane: Dictionary in source.excavation.lanes:
			if lane.get("feature_kind", &"") == &"citadel_gate":
				gates.append(lane)
		output[city] = {
			"gates": gates,
			"accepted": source.excavation.bridge_span_audit.get("seeded", []),
			"refusals": reasons
		}
		if spatial != null:
			output[city]["plot_bridges"] = WarrenPlotPlanner.outcomes(source).get("bridges", [])
			output[city]["compounds"] = spatial.source_volume.mass_context.get(
				&"maze_bridge_compounds", {}
			)
	if args.has("--output"):
		var file := FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE)
		file.store_string(JSON.stringify(output, "\t"))
	print(JSON.stringify(output))
	quit()
