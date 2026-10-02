extends SceneTree

## Tactical-structure metrics on the final storey lattice (spec 2026-10-02 §7).
## Uses only HeightfieldPlan/HeightfieldRegion/TerrainTileField APIs that also
## exist before the change, so the same file measures the baseline.
##   Godot --headless --path . -s res://tests/harness/terrain_structure_survey.gd -- \
##     --seed 2697992464 --center 0,0 --points 256 [--no-water] --output /tmp/survey.json

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed := 2697992464
	var center := Vector2i.ZERO
	var size := 256
	var water := true
	var output := "/tmp/terrain_structure_survey.json"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--seed": seed = int(next)
			"--center":
				var parts := next.split(",")
				center = Vector2i(int(parts[0]), int(parts[1]))
			"--points": size = int(next)
			"--no-water": water = false
			"--output": output = next
	var started := Time.get_ticks_msec()
	var plan := TerrainWorldTuning.make_heightfield(seed, TerrainWorldTuning.make_water(seed) if water else null)
	var lo := center - Vector2i(size / 2, size / 2)
	var region := plan.compute_rect_region(Rect2i(lo, Vector2i(size, size)))
	var build_ms := Time.get_ticks_msec() - started
	var walls := 0
	var slopes := 0
	var edges := 0
	var longest_run := 0
	var runs: Array[int] = []
	for axis in 2:
		var d := Vector2i(1, 0) if axis == 0 else Vector2i(0, 1)
		var side := Vector2i(0, 1) if axis == 0 else Vector2i(1, 0)
		for a in size - 1:
			var run := 0
			for b in size:
				var p := lo + d * a + side * b
				var cat := TerrainTileField.edge_category(region, p, d)
				edges += 1
				if cat == TerrainTileField.EdgeCategory.CLIFF:
					walls += 1
					run += 1
				else:
					if cat == TerrainTileField.EdgeCategory.SLOPE:
						slopes += 1
					if run > 0:
						runs.append(run)
					longest_run = maxi(longest_run, run)
					run = 0
			if run > 0:
				runs.append(run)
			longest_run = maxi(longest_run, run)
	var speckle := 0
	for j in range(1, size - 1):
		for i in range(1, size - 1):
			var p := lo + Vector2i(i, j)
			var s := region.storey_at(p.x, p.y)
			var higher := 0
			var lower := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o := region.storey_at(p.x + d.x, p.y + d.y)
				higher += int(o > s)
				lower += int(o < s)
			speckle += int(higher == 4 or lower == 4)
	var windows := 0
	var structured := 0
	var tactical := 0
	for wz in range(0, size - 4, 4):
		for wx in range(0, size - 4, 4):
			var has_wall := false
			var has_climb := false
			var smin := 9999
			var smax := -9999
			for j in 4:
				for i in 4:
					var p := lo + Vector2i(wx + i, wz + j)
					var s := region.storey_at(p.x, p.y)
					smin = mini(smin, s)
					smax = maxi(smax, s)
					for d in [Vector2i(1, 0), Vector2i(0, 1)]:
						var cat := TerrainTileField.edge_category(region, p, d)
						has_wall = has_wall or cat == TerrainTileField.EdgeCategory.CLIFF
						has_climb = has_climb or cat == TerrainTileField.EdgeCategory.SLOPE
			windows += 1
			structured += int(smax > smin)
			tactical += int(has_wall and has_climb)
	var seen := {}
	var small_area := 0
	for j in size:
		for i in size:
			var start := lo + Vector2i(i, j)
			if seen.has(start):
				continue
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			var component := 0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				component += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var o: Vector2i = p + d
					if o.x < lo.x or o.y < lo.y or o.x >= lo.x + size or o.y >= lo.y + size or seen.has(o):
						continue
					if TerrainTileField.is_walkable_edge(region, p, d):
						seen[o] = true
						stack.append(o)
			if component < 50:
				small_area += component
	runs.sort()
	var km2 := pow(size * 12.0 / 1000.0, 2.0)
	var result := {
		"seed": seed, "center": [center.x, center.y], "points": size, "water": water, "build_ms": build_ms,
		"structured": float(structured) / windows, "tactical": float(tactical) / windows,
		"speckle_per_km2": speckle / km2, "wall_edges_per_km2": walls / km2,
		"slope_edges_per_km2": slopes / km2,
		"wall_run_p50": runs[runs.size() / 2] if not runs.is_empty() else 0,
		"wall_run_p95": runs[int(runs.size() * 0.95)] if not runs.is_empty() else 0,
		"wall_run_max": longest_run, "trapped_area": float(small_area) / (size * size),
	}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("STRUCTURE_SURVEY ", JSON.stringify(result))
	quit()
