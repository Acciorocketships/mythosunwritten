extends GutTest
const Candidate = preload("res://tests/harness/october9_support_node_sample.gd")


func test_exact_nodes_match_the_complete_evaluator_after_wetness_gate() -> void:
	var points := {}
	for z in range(-3, 12):
		for x in range(-3, 12):
			points[Vector2i(x, z)] = 0
	var region := HeightfieldRegion.new(points, points)
	var rng := RandomNumberGenerator.new()
	rng.seed = 261009
	var mismatches := []
	var checked := 0
	for trial in 30:
		var columns := 5
		var rows := 7
		var n := (columns - 1) * 2 + 1
		var fine_rows := (rows - 1) * 2 + 1
		var coarse := PackedFloat32Array()
		coarse.resize(columns * rows)
		var fine := PackedFloat32Array()
		fine.resize(n * fine_rows)
		var ground := fine.duplicate()
		for i in coarse.size():
			coarse[i] = -INF if rng.randf() < .3 else rng.randf_range(.01, 4)
		for i in fine.size():
			fine[i] = -INF if rng.randf() < .6 else rng.randf_range(.01, 4)
			ground[i] = INF if rng.randf() < .2 else 0.0
		var ctx := {
			"fill_base": Vector2(3, 3),
			"fill_size": columns,
			"region": region,
			"fill": {"levels": coarse, "sub_levels": fine, "sub_ground": ground}
		}
		for z in fine_rows:
			for x in n:
				var index := z * n + x
				var p: Vector2 = ctx.fill_base + Vector2(x, z) * 3
				var a := WaterField._fill_bilinear(ctx, p)
				var b := Candidate.sample(ctx, p, index)
				# The caller applies this same real-ground wetness gate.
				if not is_finite(a) or a <= WaterField.EPS:
					a = -INF
				if not is_finite(b) or b <= WaterField.EPS:
					b = -INF
				checked += 1
				if a != b:
					mismatches.append([trial, p, a, b])
	assert_eq(mismatches, [], "exact field values, including mixed shores and unknown ground")
	assert_eq(checked, 3510)
