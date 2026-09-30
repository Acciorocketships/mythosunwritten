extends SceneTree
## Corpus sweep of roofline variety (tests/fixtures/roofline_variety.gd) and
## the kit roof invariants (tests/fixtures/kit_roof_audit.gd) side by side.
##   Godot --headless --path . -s res://tests/harness/suntail/roofline_variety_survey.gd -- \
##     [--cities S:P,...] [--seeds 1-6] [--footprints]
## Default corpus: the two September 29 photo towns plus seeds 1-6 compact and
## standard and 1-3 large.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const AUDIT := preload("res://tests/fixtures/kit_roof_audit.gd")
const VARIETY := preload("res://tests/fixtures/roofline_variety.gd")
const PHOTO_TOWNS := ["1260018864828801968:compact", "1998423929946073270:compact"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array = []
	if args.has("--cities"):
		jobs.assign(args[args.find("--cities") + 1].split(","))
	else:
		jobs.assign(PHOTO_TOWNS)
		for seed_value in range(1, 7):
			jobs.append("%d:compact" % seed_value)
			jobs.append("%d:standard" % seed_value)
		for seed_value in range(1, 4):
			jobs.append("%d:large" % seed_value)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var kit := SuntailBuildingKit.create()
	var totals := {}
	for job: String in jobs:
		var parts := job.split(":")
		var source := WarrenMazeSitePlanner.plan(int(parts[0]), {},
			WarrenVillageScaleProfile.for_id(StringName(parts[1])), &"", false)
		if source == null:
			print("PLAN_FAIL ", job)
			continue
		var spatial := FROZEN.spatial(source, program)
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
		var v := VARIETY.measure(built, kit)
		var a := AUDIT.audit(built, kit)
		for key: String in v:
			if key == "examples":
				if args.has("--examples"):
					for line: String in v.examples: print("  ", line)
				continue
			totals[key] = float(totals.get(key, 0.0)) + float(v[key])
		for key: String in ["roofs", "tiny", "open_exposed", "gable_holes", "air_unsupported", "eaves_cut"]:
			totals["audit_" + key] = int(totals.get("audit_" + key, 0)) + int(a[key])
		totals.towns = int(totals.get("towns", 0)) + 1
		print("TOWN %s houses=%d gable_front=%d/%d minority=%.2f pairs=%d twins=%d run=%d same_ridge=%d levels=%d compound=%d | tiny=%d open=%d holes=%d air=%d eaves=%d" % [
			job, v.houses, v.gable_front, v.fronted, v.axis_minority, v.pairs, v.twins, v.twin_run,
			v.same_ridge, v.ridge_levels, v.compound,
			a.tiny, a.open_exposed, a.gable_holes, a.air_unsupported, a.eaves_cut])
		if args.has("--footprints"):
			for mass: BuildingMass in built.houses:
				var line := "  %s" % mass.stable_id
				for storey: Dictionary in mass.storeys:
					line += " [b%d %s]" % [storey.floor_band, BuildingDesigner._bounds(storey.cells)]
				for roof: Dictionary in mass.roofs:
					line += " roof(%s ax%d e%d)" % [roof.rect, roof.axis, roof.eave_band]
				print(line)
	var towns := float(totals.get("towns", 1))
	var houses := float(totals.get("houses", 1))
	print("TOTAL ", totals)
	print("SUMMARY gable_front=%.2f twin_share=%.2f same_ridge_share=%.2f compound=%.2f mean_twin_run=%.2f minority=%.2f" % [
		float(totals.get("gable_front", 0)) / maxf(1.0, float(totals.get("fronted", 0))),
		float(totals.get("twins", 0)) / maxf(1.0, float(totals.get("pairs", 0))),
		float(totals.get("same_ridge", 0)) / maxf(1.0, float(totals.get("pairs", 0))),
		float(totals.get("compound", 0)) / houses,
		float(totals.get("twin_run", 0)) / towns, float(totals.get("axis_minority", 0)) / towns])
	quit()
