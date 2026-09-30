extends SceneTree
## Perimeter height profile of kit-built towns on flat ground.
##   Godot --headless --path . -s res://tests/harness/layout_judging/perimeter_profile.gd -- \
##     --cities 1260018864828801968:compact,3:standard [--seeds 1-12] [--scales compact,standard]
## For every exterior edge of the town footprint (a massif column facing open
## ground that reaches the far outside) it reports the wall height of the
## outermost column and of the column one ring inside. See
## `TownPerimeterProfile` for the metric.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const PROFILE := preload("res://tests/fixtures/town_perimeter_profile.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array = []
	var seeds: Array[int] = []
	var scales := PackedStringArray(["compact", "standard", "large"])
	for i in args.size():
		match args[i]:
			"--cities":
				for job in args[i + 1].split(","):
					var parts := job.split(":")
					jobs.append([int(parts[0]), StringName(parts[1])])
			"--seeds":
				var r := args[i + 1].split("-")
				for s in range(int(r[0]), int(r[r.size() - 1]) + 1):
					seeds.append(s)
			"--scales":
				scales = args[i + 1].split(",")
	for scale in scales:
		for s in seeds:
			jobs.append([s, StringName(scale)])
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var total := {}
	var failures: Array = []
	for job: Array in jobs:
		var started := Time.get_ticks_msec()
		var source := WarrenMazeSitePlanner.plan(int(job[0]), {},
			WarrenVillageScaleProfile.for_id(job[1]), &"", false)
		if source == null:
			failures.append([job, "plan: " + WarrenMazeSitePlanner.last_failure])
			print("FAIL ", job, " plan")
			continue
		var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
		if volume == null:
			failures.append([job, "volume"])
			print("FAIL ", job, " volume")
			continue
		var result := WarrenVolumetricSolver.from_volume(volume, -1, program, false, true)
		if result == null:
			failures.append([job, "solve: " + WarrenVolumetricSolver.last_failure])
			print("FAIL ", job, " solve ", WarrenVolumetricSolver.last_failure)
			continue
		var fabric := WarrenSpatialFabricCompiler.generate(result, program, true)
		if fabric == null:
			failures.append([job, "fabric: " + WarrenSpatialFabricCompiler.last_failure])
			print("FAIL ", job, " fabric ", WarrenSpatialFabricCompiler.last_failure)
			continue
		result.cache_compiled_fabric(fabric)
		var built := KitVillageBuildings.build(result, fabric, SuntailBuildingKit.create())
		var metric: Dictionary = PROFILE.measure(source, built.masses)
		metric.erase("offenders")
		print("TOWN ", job[0], " ", job[1], " ", metric, " ms=", Time.get_ticks_msec() - started)
		for key: String in ["edges", "rim_over", "inner_over", "rim_tall_house", "bridge_over", "rampart", "perimeter_lane_cells", "sheer", "rim_storeys_sum", "houses", "house_columns", "decks", "assets"]:
			total[key] = int(total.get(key, 0)) + int(metric[key])
		var hist: Dictionary = total.get("hist", {})
		for k: int in metric.hist:
			hist[k] = int(hist.get(k, 0)) + int(metric.hist[k])
		total["hist"] = hist
	var edges := maxi(1, int(total.get("edges", 0)))
	print("TOTAL towns=", jobs.size() - failures.size(), "/", jobs.size(), " ", total,
		" rim_over_share=", snappedf(float(total.get("rim_over", 0)) / edges, 0.001),
		" inner_over_share=", snappedf(float(total.get("inner_over", 0)) / edges, 0.001),
		" rim_tall_house_share=", snappedf(float(total.get("rim_tall_house", 0)) / edges, 0.001),
		" rampart_share=", snappedf(float(total.get("rampart", 0)) / edges, 0.001),
		" sheer_share=", snappedf(float(total.get("sheer", 0)) / edges, 0.001),
		" mean_rim_storeys=", snappedf(float(total.get("rim_storeys_sum", 0)) / edges, 0.01))
	for f: Array in failures:
		print("FAILURE ", f)
	quit()
