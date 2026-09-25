extends SceneTree

func _init() -> void:
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var original := frozen.read("res://tests/fixtures/september11-floating-source.txt")
	var results: Array[Dictionary] = []
	var seeds: Array[int] = [original.world_seed]
	var corpus := "--corpus" in OS.get_cmdline_user_args()
	if corpus: seeds.assign(range(1,13))
	for seed_value: int in seeds:
		for extra in [0,1]:
			var profile := WarrenVillageScaleProfile.for_id(original.scale_profile.scale_id)
			profile.landmark_range += Vector2i.ONE*extra
			var source := WarrenMazeSitePlanner.plan(seed_value,{},profile)
			assert(source != null,WarrenMazeSitePlanner.last_failure)
			var assets: Array[Dictionary] = []
			for plot: Dictionary in source.plots:
				if plot.kind == WarrenMazeSourcePlan.PLOT_ASSET: assets.append(plot)
			results.append({"seed":seed_value,"extra_requested":extra,"assets":assets,
				"outcomes":source.audit.get("plot_outcomes",{}),"plot_count":source.plots.size()})
	var name := "corpus-site-options.json" if corpus else "site-options.json"
	FileAccess.open("res://docs/qa/2026-09-11-manual/09-prefabs/"+name,
		FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit()
