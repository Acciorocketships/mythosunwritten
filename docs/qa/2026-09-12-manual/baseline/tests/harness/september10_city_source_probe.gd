extends SceneTree

func _init() -> void:
	for scale_id: StringName in WarrenVillageScaleProfile.IDS:
		for seed in range(1, 13):
			var profile := WarrenVillageScaleProfile.for_id(scale_id)
			var plan := WarrenMazeSitePlanner.plan(seed, {}, profile)
			if plan == null:
				print("CITY_SOURCE ", seed, "/", scale_id, " FAILED ",
					WarrenMazeSitePlanner.last_failure)
				continue
			var assets := 0
			for plot: Dictionary in plan.plots:
				if String(plot.get("kind", "")).contains("asset"):
					assets += 1
			print("CITY_SOURCE ", seed, "/", scale_id, " form=", plan.massif.form_id,
				" columns=", plan.massif.columns.size(), " core=", plan.massif.core_top_bands,
				" plots=", plan.plots.size(), " assets=", assets)
	quit()
