extends SceneTree
## -- CITY:PROFILE,... : the plot planner's tunnel-roof outcomes.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	for job in OS.get_cmdline_user_args()[0].split(","):
		var parts := job.split(":")
		var source := WarrenMazeSitePlanner.plan(int(parts[0]), {}, WarrenVillageScaleProfile.for_id(StringName(parts[1])), &"", false)
		if source == null:
			print("ROOFS ", job, " FAILED ", WarrenMazeSitePlanner.last_failure)
			continue
		for record: Dictionary in source.audit.get("plot_outcomes", {}).get("tunnel_roofs", []):
			print("ROOFS ", job, " ", record)
		for plot: Dictionary in source.plots:
			if plot.kind == WarrenMazeSourcePlan.PLOT_OVER:
				print("ROOFS ", job, " PLOT ", plot)
	quit()
