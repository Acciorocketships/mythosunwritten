extends SceneTree

## Top-down height map of the smooth natural field (large-scale review):
## elevation colour ramp with hillshade, sea-level green to highland tan/grey.
##   Godot --headless --path . -s res://tests/harness/terrain_height_map.gd -- \
##     --seed 2697992464 --center 0,0 --size 24000 --mpp 48 --output /tmp/height.png

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed := 2697992464
	var center := Vector2.ZERO
	var size := 24000.0
	var mpp := 48.0
	var output := "/tmp/terrain_height_map.png"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--seed": seed = int(next)
			"--center":
				var parts := next.split(",")
				center = Vector2(float(parts[0]), float(parts[1]))
			"--size": size = float(next)
			"--mpp": mpp = float(next)
			"--output": output = next
	var n := int(size / mpp)
	var origin := center - Vector2(size, size) * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for z in n:
		for x in n:
			var p := origin + Vector2(x + 0.5, z + 0.5) * mpp
			heights[z * n + x] = HeightfieldPlan.height01(Vector3(p.x, 0, p.y), seed, false) * TerrainField.REF_AMPLITUDE
	var stops := [[0.0, Color(0.16, 0.32, 0.12)], [40.0, Color(0.36, 0.48, 0.20)],
		[80.0, Color(0.62, 0.58, 0.30)], [120.0, Color(0.58, 0.44, 0.30)], [170.0, Color(0.85, 0.85, 0.85)]]
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	for z in n:
		for x in n:
			var h := heights[z * n + x]
			var c: Color = stops[0][1]
			for i in range(1, stops.size()):
				if h <= stops[i][0]:
					c = (stops[i - 1][1] as Color).lerp(stops[i][1], (h - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]))
					break
				c = stops[i][1]
			var hx := heights[z * n + mini(x + 1, n - 1)] - heights[z * n + maxi(x - 1, 0)]
			var hz := heights[mini(z + 1, n - 1) * n + x] - heights[maxi(z - 1, 0) * n + x]
			var shade := clampf(0.85 + (-hx - hz) / (2.0 * mpp) * 3.0, 0.5, 1.2)
			image.set_pixel(x, z, Color(clampf(c.r * shade, 0, 1), clampf(c.g * shade, 0, 1), clampf(c.b * shade, 0, 1)))
	image.save_png(output)
	var sorted := heights.duplicate()
	sorted.sort()
	print("HEIGHT_MAP %s %dx%d  p10 %.0f  p50 %.0f  p90 %.0f  max %.0f m" % [output, n, n,
		sorted[int(sorted.size() * 0.1)], sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.9)], sorted[-1]])
	quit()
