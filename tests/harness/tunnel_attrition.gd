extends SceneTree
## Tunnel attrition per town: eligible run -> bored -> pruned -> covered ->
## released. Prints one TUNNEL_ATTRITION JSON line per town.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var towns := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard,5:compact,21:standard,37:large,71:grand"
	for town: String in towns.split(","):
		var parts := town.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program,
			WarrenVillageScaleProfile.for_id(StringName(parts[1])))
		if spatial == null:
			print("TUNNEL_ATTRITION ", JSON.stringify({"town": town, "error": "no town"}))
			continue
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		var row: Dictionary = source.excavation.tunnel_attrition.duplicate()
		row["town"] = town
		row["final_tunnel_cells"] = source.excavation.tunnel_cells.size()
		row["tunnel_covers"] = int(source.audit.get("tunnel_covers", -1))
		var reasons := {}
		var covered := 0
		for record: Dictionary in WarrenPlotPlanner.outcomes(source).get("tunnel_roofs", []):
			if String(record.get("reason", "")) == "":
				covered += 1
			else:
				reasons[record.reason] = int(reasons.get(record.reason, 0)) + 1
		row["covered"] = covered
		row["cover_refusals"] = reasons
		row["released_crown_cells"] = int(spatial.audit.get("maze_released_unborne_crown_cells", -1))
		print("TUNNEL_ATTRITION ", JSON.stringify(row))
	quit(0)
