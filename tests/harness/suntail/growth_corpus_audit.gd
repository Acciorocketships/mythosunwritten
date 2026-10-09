extends SceneTree
## Growing-floor corpus: stepping faces, stepped storeys and withdrawals per cause.
## godot --headless --path . -s res://tests/harness/suntail/growth_corpus_audit.gd -- \
##   [--towns 53:grand,...] [--odds name=value ...] [--out /tmp/growth_audit.json]
const DEFAULT_TOWNS := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard"


func _init() -> void:
	call_deferred("_run")


## Faces (chains with any step), stepped storeys, wrapped storey-faces (lean
## records with a wrap closure), wrapped corners (one per corner and storey: the
## record whose right end wraps owns it), terrace-row joints (lean records with a
## joint closure; `row_joints` one per joint and storey), houses pulled into a row
## without rolling growth, buried storey-faces (lean records with a bury closure;
## `buried_own` / `buried_neighbour` count the walls run into by owner), and
## withdrawals by cause.
static func counts(built: Dictionary) -> Dictionary:
	var chains := {}
	var wraps := 0
	var corners := 0
	var joints := 0
	var row_joints := 0
	var pulled := {}
	var buried := 0
	var buried_own := 0
	var buried_neighbour := 0
	for lean: Dictionary in built.get("growth", []):
		if (lean.get("closures", []) as Array).has(&"bury"):
			buried += 1
			for owner: String in lean.get("buried_into", []):
				if owner == String(lean.get("host", "")):
					buried_own += 1
				else:
					buried_neighbour += 1
		chains[String(lean.get("chain", ""))] = true
		if (lean.get("closures", []) as Array).has(&"wrap"):
			wraps += 1
		if (lean.get("closures", []) as Array).size() == 2 and lean.closures[1] == &"wrap":
			corners += 1
		if (lean.get("closures", []) as Array).has(&"joint"):
			joints += 1
		if (lean.get("closures", []) as Array).size() == 2 and lean.closures[1] == &"joint":
			row_joints += 1
		if bool(lean.get("pulled", false)):
			pulled[String(lean.get("host", ""))] = true
	var causes := {}
	for rejection: Dictionary in built.get("growth_rejections", []):
		causes[String(rejection.cause)] = int(causes.get(String(rejection.cause), 0)) + 1
	return {"faces": chains.size(), "storeys": (built.get("growth", []) as Array).size(), "wraps": wraps,
		"corners": corners, "joints": joints, "row_joints": row_joints, "pulled": pulled.size(),
		"buried": buried, "buried_own": buried_own, "buried_neighbour": buried_neighbour,
		"causes": causes}


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
	var total := {"faces": 0, "storeys": 0, "wraps": 0, "corners": 0, "joints": 0, "row_joints": 0,
		"pulled": 0, "buried": 0, "buried_own": 0, "buried_neighbour": 0, "causes": {}}
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
		total.wraps += int(row.wraps)
		total.corners += int(row.corners)
		for key: String in ["joints", "row_joints", "pulled", "buried", "buried_own", "buried_neighbour"]:
			total[key] += int(row[key])
		for cause: String in row.causes:
			total.causes[cause] = int(total.causes.get(cause, 0)) + int(row.causes[cause])
		rows.append(row)
		print("GROWTH_AUDIT ", JSON.stringify(row))
	print("GROWTH_TOTAL ", JSON.stringify(total))
	FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("GROWTH_AUDIT_DONE bad=", bad)
	quit(0 if bad == 0 else 1)
