extends SceneTree

## Top-down review map of the natural terrain field (spec 2026-10-02 §7).
## Hillshaded storey bands tinted by regime archetype, border bands darkened,
## set-piece footprints outlined. Also writes one F4 review spot per archetype.
##   Godot --headless --path . -s res://tests/harness/terrain_regime_map.gd -- \
##     --seed 2697992464 --center 0,0 --size 4096 --mpp 8 --output /tmp/map.png [--spots spots.json]

const TINT := {
	&"rolling_downs": Color(0.55, 0.75, 0.40), &"ridge_and_pass": Color(0.70, 0.55, 0.40),
	&"escarpment_country": Color(0.85, 0.70, 0.40), &"terraced_valleys": Color(0.45, 0.70, 0.55),
	&"karst_hollows": Color(0.55, 0.60, 0.75), &"tableland": Color(0.85, 0.50, 0.35),
	&"highland_massif": Color(0.65, 0.65, 0.70), &"low_flats": Color(0.40, 0.65, 0.70),
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed := 2697992464
	var center := Vector2.ZERO
	var size := 4096.0
	var mpp := 8.0
	var output := "/tmp/terrain_regime_map.png"
	var spots_path := ""
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
			"--spots": spots_path = next
	var n := int(size / mpp)
	var origin := center - Vector2(size, size) * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var started := Time.get_ticks_msec()
	for z in n:
		for x in n:
			var p := origin + Vector2(x + 0.5, z + 0.5) * mpp
			heights[z * n + x] = HeightfieldPlan.height01(Vector3(p.x, 0, p.y), seed) * TerrainField.REF_AMPLITUDE
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	var counts := {}
	var examples := {}
	for z in n:
		for x in n:
			var p := origin + Vector2(x + 0.5, z + 0.5) * mpp
			var s := TerrainRegimeField.sample(seed, p)
			var nearest: Dictionary = s[0][0]
			var a: StringName = nearest.archetype
			counts[a] = counts.get(a, 0) + 1
			if not examples.has(a) and s.size() == 1 and p.distance_to(nearest.site) < 120.0:
				examples[a] = p
			var h := heights[z * n + x]
			var hx := heights[z * n + mini(x + 1, n - 1)] - heights[z * n + maxi(x - 1, 0)]
			var hz := heights[mini(z + 1, n - 1) * n + x] - heights[maxi(z - 1, 0) * n + x]
			var shade := clampf(0.75 + (-hx - hz) / (4.0 * mpp), 0.35, 1.25)
			var band := 0.85 + 0.15 * float(int(floorf(h / 4.0)) % 2)
			var c: Color = TINT[a] * shade * band
			if float(s[0][1]) < 0.55:
				c = c.darkened(0.45)
			image.set_pixel(x, z, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
	var outlined := 0
	for piece in LandformSetpieces.setpieces_in_rect(seed, Rect2(origin, Vector2(size, size))):
		outlined += 1
		for k in 256:
			var e: Vector2 = piece.pos + Vector2.from_angle(k * TAU / 256.0) * piece.radius
			var px := Vector2i(((e - origin) / mpp).floor())
			if px.x >= 0 and px.y >= 0 and px.x < n and px.y < n:
				image.set_pixelv(px, Color(1, 1, 1))
	image.save_png(output)
	print("REGIME_MAP %s %dx%d in %d ms, %d set pieces" % [output, n, n, Time.get_ticks_msec() - started, outlined])
	var total := float(n * n)
	for a: StringName in TerrainRegimeCatalog.ARCHETYPES:
		print("  %-20s %5.1f%%  tint %s" % [a, 100.0 * counts.get(a, 0) / total, TINT[a].to_html(false)])
	if spots_path != "":
		var spots := []
		for a: StringName in examples:
			var p: Vector2 = examples[a]
			var y := HeightfieldPlan.height01(Vector3(p.x, 0, p.y), seed) * TerrainField.REF_AMPLITUDE
			spots.append({"name": "regime %s" % a, "pos": [p.x, y + 7.0, p.y], "look": [p.x + 40.0, p.y]})
		FileAccess.open(spots_path, FileAccess.WRITE).store_string(JSON.stringify(spots, " "))
		print("REGIME_SPOTS %s (%d)" % [spots_path, spots.size()])
	quit()
