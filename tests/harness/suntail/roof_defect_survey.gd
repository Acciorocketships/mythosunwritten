extends SceneTree
## Corpus sweep of kit roof invariants (tests/fixtures/kit_roof_audit.gd):
## tiny one-module roofs, exposed open wing ends, holes in closed gables.
##   Godot --headless --path . -s res://tests/harness/suntail/roof_defect_survey.gd -- \
##     [--cities S:P,...] [--seeds 1-12] [--examples]
## Default corpus: seeds 1-12 x compact/standard/large/grand plus the two
## September 27 photo towns of world seed 2697992464.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const AUDIT := preload("res://tests/fixtures/kit_roof_audit.gd")
const PHOTO_TOWNS := ["1260018864828801968:compact", "85830433957479026:compact"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array = []
	var first := 1
	var last := 12
	if args.has("--seeds"):
		var range_parts := args[args.find("--seeds") + 1].split("-")
		first = int(range_parts[0])
		last = int(range_parts[1])
	if args.has("--cities"):
		jobs.assign(args[args.find("--cities") + 1].split(","))
	else:
		jobs.assign(PHOTO_TOWNS)
		for scale: String in ["compact", "standard", "large", "grand"]:
			for seed_value in range(first, last + 1): jobs.append("%d:%s" % [seed_value, scale])
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := SuntailBuildingKit.create()
	var totals := {"towns": 0, "roofs": 0, "tiny": 0, "tiny_beside": 0, "open_ends": 0, "open_exposed": 0,
		"gable_ends": 0, "gable_holes": 0, "air_roofs": 0, "air_unsupported": 0, "eaves_cut": 0}
	for job: String in jobs:
		var parts := job.split(":")
		var source := WarrenMazeSitePlanner.plan(int(parts[0]), {},
			WarrenVillageScaleProfile.for_id(StringName(parts[1])), &"", false)
		if source == null:
			print("PLAN_FAIL ", job)
			continue
		var spatial := FROZEN.spatial(source, program)
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
		var result := AUDIT.audit(built, kit)
		totals.towns += 1
		for key: String in totals:
			if key != "towns": totals[key] += int(result[key])
		print("TOWN %s roofs=%d tiny=%d beside=%d open=%d/%d gables=%d/%d air=%d/%d eaves_cut=%d" % [job,
			result.roofs, result.tiny, result.tiny_beside, result.open_exposed, result.open_ends,
			result.gable_holes, result.gable_ends, result.air_unsupported, result.air_roofs,
			result.eaves_cut])
		if args.has("--examples"):
			for line: String in result.examples: print("  ", line)
	print("TOTAL ", totals)
	quit()
