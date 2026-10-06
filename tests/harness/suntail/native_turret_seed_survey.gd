extends SceneTree


func _init() -> void:
	var rows: Array[Dictionary] = []
	for seed_value in 64:
		if not WarrenPlotReservations._prefers_corner_turret(seed_value, {}):
			continue
		var plan := WarrenMazeSitePlanner.plan(
			seed_value, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"reserve"
		)
		var selected: Array[String] = []
		if plan != null:
			for asset: Dictionary in WarrenPlotPlanner.outcomes(plan).get("assets", []):
				if String(asset.get("kind_id", "")).contains(".turret."):
					selected.append(String(asset.kind_id))
		var row := {"seed": seed_value, "selected": selected, "ok": plan != null}
		rows.append(row)
		print("TURRET_SEED ", row)
	FileAccess.open("/tmp/turret-seed-survey.json", FileAccess.WRITE).store_string(
		JSON.stringify(rows, "  ")
	)
	quit()
