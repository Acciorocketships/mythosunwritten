extends SceneTree
## Inspect source-plan admission for any native family; no seed-specific placement.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var family := args[args.find("--family") + 1] if args.has("--family") else ".street_jetties."
	var count := int(args[args.find("--count") + 1]) if args.has("--count") else 32
	var output := args[args.find("--output") + 1] if args.has("--output") else "/tmp/native-family-seeds.json"
	var rows: Array[Dictionary] = []
	for seed_value in count:
		var plan := WarrenMazeSitePlanner.plan(seed_value, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"reserve")
		var selected: Array[String] = []
		if plan != null:
			for asset: Dictionary in WarrenPlotPlanner.outcomes(plan).get("assets", []):
				if String(asset.get("kind_id", "")).contains(family):
					selected.append(String(asset.kind_id))
		var row := {"seed": seed_value, "selected": selected, "ok": plan != null}
		rows.append(row)
		print("NATIVE_FAMILY_SEED ", row)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit()
