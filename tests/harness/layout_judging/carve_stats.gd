extends SceneTree
## Source-level intricacy over rolled seeds (fast; no composition):
##   -- COUNT [FIRST]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var count := int(a[0]) if not a.is_empty() else 200
	var first := int(a[1]) if a.size() > 1 else 1
	var sums := {}
	var ok := 0
	for i in range(first, first + count):
		var seed_value := Helper._mix64(i * 7919 + 17)
		var profile := WarrenVillageScaleProfile.select(seed_value)
		var plan := WarrenMazeSitePlanner.plan(seed_value, {}, profile, &"", false)
		if plan == null:
			continue
		ok += 1
		var ex := plan.excavation
		var covered := 0
		for c in ex.covered:
			covered += int(bool(ex.covered[c]))
		var levels := {}
		for c in ex.public_cells(): levels[c.y] = true
		for key in ["loops", "tunnels", "covered", "public", "lanes", "bridges", "levels"]:
			var v: float = {"loops": ex.loop_edges.size(), "tunnels": ex.tunnel_cells.size(),
				"covered": covered, "public": ex.public_cells().size(), "lanes": ex.lanes.size(),
				"bridges": ex.bridge_spans.size(), "levels": levels.size()}[key]
			sums[key] = float(sums.get(key, 0.0)) + v
	var line := "CARVE_STATS ok=%d/%d" % [ok, count]
	for key in sums:
		line += " %s=%.2f" % [key, float(sums[key]) / maxf(1.0, ok)]
	line += " covered_share=%.3f" % (float(sums.get("covered", 0)) / maxf(1.0, float(sums.get("public", 1))))
	print(line)
	quit()
