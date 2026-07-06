# Headless report: river-source density + peak stats for a seed window.
# Run: Godot --headless --path . -s tests/tools/source_density_report.gd -- <seed>
extends SceneTree

func _init() -> void:
	var seed_arg: int = 991177
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		seed_arg = int(args[0])
	var plan: WaterPlan = WaterPlan.new(seed_arg, 22.0, 8)
	# Old (pre-summit) source rule, replicated for a density baseline:
	# jitter point on high sloped ground + the same density roll.
	var old_n: int = 0
	for sz in range(-6, 7):
		for sx in range(-6, 7):
			var sc: Vector2i = Vector2i(sx, sz)
			var p: Vector2 = plan._jitter_pos(sc)
			if p.length() < WaterPlan.SPAWN_WATER_RADIUS:
				continue
			if plan.smooth01(p) < 0.55 or plan.grad(p).length() < 0.035:
				continue
			if Helper._hash01(plan._hash_cell(sc, 103)) < WaterPlan.SOURCE_PROB:
				old_n += 1
	print("OLD-RULE sources in 13x13: %d" % old_n)
	var n: int = 0
	var joined: int = 0
	for sz in range(-6, 7):
		for sx in range(-6, 7):
			var sc: Vector2i = Vector2i(sx, sz)
			if not plan.has_source(sc):
				continue
			n += 1
			var p: Vector2 = plan.source_pos(sc)
			var t: RiverTrace = plan.river_for(sc)
			if t != null and t.joined:
				joined += 1
			print("source %s at %.0f,%.0f h01=%.2f grad=%.3f prom=%.3f len=%d" % [
				sc, p.x, p.y, plan.smooth01(p), plan.grad(p).length(),
				plan._ring_prominence(p), t.points.size() if t != null else -1])
	print("TOTAL sources in 13x13: %d (joined: %d)" % [n, joined])
	quit()
