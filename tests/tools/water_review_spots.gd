# Emit review_teleports.json entries for water review on a seed: the nearest
# river sources (mountain-top pools), a mid-reach, the steepest reach, and the
# terminal pond of the closest river.
# Run: Godot --headless --path . -s tests/tools/water_review_spots.gd -- <seed>
extends SceneTree

func _spot(name: String, plan: WaterPlan, at: Vector2, look: Vector2) -> Dictionary:
	var y: float = plan.noise_h(at) - plan.carve_at_cell(
		roundi(at.x / WaterPlan.TILE), roundi(at.y / WaterPlan.TILE))
	return {"name": name, "pos": [at.x, maxf(y, 0.0) + 7.0, at.y], "look": [look.x, look.y]}

func _init() -> void:
	var seed_arg: int = 991177
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		seed_arg = int(args[0])
	var plan: WaterPlan = WaterPlan.new(seed_arg, 22.0, 8)
	var sources: Array = []
	for sz in range(-5, 6):
		for sx in range(-5, 6):
			var sc: Vector2i = Vector2i(sx, sz)
			if plan.has_source(sc):
				sources.append(sc)
	sources.sort_custom(func(a, b):
		return plan.source_pos(a).length() < plan.source_pos(b).length())
	if sources.is_empty():
		print("[]")
		quit()
		return
	var spots: Array = []
	for k in mini(2, sources.size()):
		var sc: Vector2i = sources[k]
		var t: RiverTrace = plan.river_for(sc)
		var p: Vector2 = plan.source_pos(sc)
		var downstream: Vector2 = t.points[mini(6, t.points.size() - 1)]
		# stand back from the pool, looking across it and down the river
		var back: Vector2 = p + (p - downstream).normalized() * 40.0
		spots.append(_spot("WATER %d: mountain-top source pool" % k, plan, back, p))
		var mid: Vector2 = t.points[t.points.size() / 2]
		var mid2: Vector2 = t.points[t.points.size() / 2 + 2]
		spots.append(_spot("WATER %d: mid-river reach" % k, plan,
			mid + Vector2(18, 18), mid2))
		var steeps: PackedFloat32Array = WaterSurfaceBuilder.steepness_profile(t)
		var si: int = 0
		for i in steeps.size():
			if steeps[i] > steeps[si]:
				si = i
		spots.append(_spot("WATER %d: steepest reach (steep=%.2f)" % [k, steeps[si]], plan,
			t.points[si] + Vector2(20, 0), t.points[mini(si + 2, t.points.size() - 1)]))
		if t.pond != null:
			spots.append(_spot("WATER %d: terminal pond" % k, plan,
				t.pond.center + Vector2(t.pond.radius + 25.0, 0), t.pond.center))
	print(JSON.stringify(spots, " "))
	quit()
