extends SceneTree
## -- CITY:PROFILE,... : per bored walk cell, the plots on its neighbouring columns.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	for job in OS.get_cmdline_user_args()[0].split(","):
		var parts := job.split(":")
		var source := WarrenMazeSitePlanner.plan(int(parts[0]), {}, WarrenVillageScaleProfile.for_id(StringName(parts[1])), &"", false)
		var keys := source.excavation.tunnel_cells.keys()
		keys.sort()
		for walk: Vector3i in keys:
			var roof := source.passage_headroom_top(walk)
			var line := "%s walk=%s roof=%d top=%d" % [job, walk, roof, source.massif.top_at(Vector2i(walk.x, walk.z))]
			for d: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var c := Vector2i(walk.x, walk.z) + d
				var tag := "P" if source.passage_kinds.has(Vector3i(c.x, walk.y, c.y)) else ("T" if source.excavation.tunnel_cells.has(Vector3i(c.x, walk.y, c.y)) else "-")
				var solid := ""
				for y in range(walk.y, roof + 3):
					solid += "1" if source.solid_at(Vector3i(c.x, y, c.y)) else "0"
				var plots := []
				for plot: Dictionary in source.plots:
					if (plot.cells as Array).has(c):
						plots.append("%s:%s[%d,%d)" % [plot.building_id, String(plot.kind).left(1), int(plot.floor), int(plot.top)])
				line += " | %s%s %s %s" % [d, tag, solid, plots]
			print("JAMB ", line)
	quit()
