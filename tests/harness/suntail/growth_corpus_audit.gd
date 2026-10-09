extends SceneTree
## Growing-floor corpus under step-in: stepping faces, stepped storeys and withdrawals per cause.
## godot --headless --path . -s res://tests/harness/suntail/growth_corpus_audit.gd -- \
##   [--towns 53:grand,...] [--odds name=value ...] [--out /tmp/growth_audit.json]
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const DEFAULT_TOWNS := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard"


func _init() -> void:
	call_deferred("_run")


## Faces (chains with any growth record), records (stepped storeys), stepped-in storeys,
## faces whose ground storey stepped in, the deepest offset, recessed ground doors,
## closures by kind (a corner/joint counts once per record end), houses pulled into a row
## without rolling growth, and withdrawals by cause: attempts (`causes`) and distinct
## faces (`faces_withdrawn`; Task 4 deferred minor).
static func counts(built: Dictionary) -> Dictionary:
	var by_id := {}
	for mass: BuildingMass in built.get("houses", []):
		by_id[mass.stable_id] = mass
	var faces := {}
	var ground_faces := {}
	var stepped_in := 0
	var deepest := 0.0
	var doors := 0
	var kinds := {"return": 0, "wrap": 0, "joint": 0, "bury": 0}
	var pulled := {}
	for lean: Dictionary in built.get("growth", []):
		faces[String(lean.chain)] = true
		var depth := float(lean.lean)
		if depth < 0.0:
			stepped_in += 1
			deepest = minf(deepest, depth)
		var mass: BuildingMass = by_id.get(lean.host)
		if mass != null and depth < 0.0 and int(lean.band) == mass.ground_band:
			ground_faces[String(lean.chain)] = true
			var ground: Dictionary = mass.storeys[GROWTH.ground_index(mass)]
			for edge: Vector3i in lean.edges:
				if StringName(ground.openings.get(edge, ground.default_opening)) == BuildingMass.OPENING_DOOR:
					doors += 1
		for kind: StringName in lean.get("closures", []):
			if kinds.has(String(kind)):
				kinds[String(kind)] += 1
		if bool(lean.get("pulled", false)):
			pulled[String(lean.host)] = true
	var causes := {}
	var withdrawn := {}
	for rejection: Dictionary in built.get("growth_rejections", []):
		var cause := String(rejection.cause)
		causes[cause] = int(causes.get(cause, 0)) + 1
		if not withdrawn.has(cause):
			withdrawn[cause] = {}
		withdrawn[cause][String(rejection.chain)] = true
	var faces_withdrawn := {}
	for cause: String in withdrawn:
		faces_withdrawn[cause] = (withdrawn[cause] as Dictionary).size()
	return {"faces": faces.size(), "storeys": (built.get("growth", []) as Array).size(),
		"stepped_in": stepped_in, "ground_faces": ground_faces.size(), "deepest": deepest,
		"recessed_doors": doors, "returns": kinds.return, "wraps": kinds.wrap, "joints": kinds.joint,
		"buried": kinds.bury, "pulled": pulled.size(), "causes": causes, "faces_withdrawn": faces_withdrawn}


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
	var total := {}
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
		_add(total, row)
		rows.append(row)
		print("GROWTH_AUDIT ", JSON.stringify(row))
	print("GROWTH_TOTAL ", JSON.stringify(total))
	FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("GROWTH_AUDIT_DONE bad=", bad)
	quit(0 if bad == 0 else 1)


## Totals: every int key summed, `deepest` the minimum, `causes` and `faces_withdrawn`
## merged by key.
static func _add(total: Dictionary, row: Dictionary) -> void:
	for key: String in row:
		var value: Variant = row[key]
		if key == "deepest":
			total[key] = minf(float(total.get(key, 0.0)), float(value))
		elif key in ["causes", "faces_withdrawn"]:
			var merged: Dictionary = total.get(key, {})
			for cause: String in value:
				merged[cause] = int(merged.get(cause, 0)) + int(value[cause])
			total[key] = merged
		elif value is int:
			total[key] = int(total.get(key, 0)) + int(value)
