extends SceneTree
## Growing-floor corpus: stepping faces, stepped storeys and withdrawals per cause.
## godot --headless --path . -s res://tests/harness/suntail/growth_corpus_audit.gd -- \
##   [--towns 53:grand,...] [--odds name=value ...] [--out /tmp/growth_audit.json]
const DEFAULT_TOWNS := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard"


func _init() -> void:
	call_deferred("_run")


## Faces (chains with any step), stepped storeys and withdrawals by cause.
static func counts(built: Dictionary) -> Dictionary:
	var chains := {}
	for lean: Dictionary in built.get("growth", []):
		chains[String(lean.get("chain", ""))] = true
	var causes := {}
	for rejection: Dictionary in built.get("growth_rejections", []):
		causes[String(rejection.cause)] = int(causes.get(String(rejection.cause), 0)) + 1
	return {"faces": chains.size(), "storeys": (built.get("growth", []) as Array).size(), "causes": causes}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var towns := DEFAULT_TOWNS
	var out_path := "/tmp/growth_audit.json"
	for i in args.size() - 1:
		if args[i] == "--towns": towns = args[i + 1]
		if args[i] == "--out": out_path = args[i + 1]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var overrides := TownOddsProgram.parse_overrides(args, program.town_odds)
	if overrides.has("error"):
		quit(2)
		return
	if not overrides.is_empty():
		program.town_odds = program.town_odds.with_overrides(overrides)
	var rows := []
	var bad := 0
	var total := {"faces": 0, "storeys": 0, "causes": {}}
	for town: String in towns.split(","):
		var parts := town.split(":")
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1]))
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, profile)
		if spatial == null:
			rows.append({"town": town, "error": "no town"})
			bad += 1
			print("GROWTH_AUDIT ", JSON.stringify(rows.back()))
			continue
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create())
		var row := counts(built)
		row["town"] = town
		row["valid_payload"] = built.payload.validate()
		if not bool(row.valid_payload):
			bad += 1
		total.faces += int(row.faces)
		total.storeys += int(row.storeys)
		for cause: String in row.causes:
			total.causes[cause] = int(total.causes.get(cause, 0)) + int(row.causes[cause])
		rows.append(row)
		print("GROWTH_AUDIT ", JSON.stringify(row))
	print("GROWTH_TOTAL ", JSON.stringify(total))
	FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("GROWTH_AUDIT_DONE bad=", bad)
	quit(0 if bad == 0 else 1)
