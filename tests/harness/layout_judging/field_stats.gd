extends SceneTree
## Massif-field statistics (before boring): old vs current WarrenTownField.
const SAMPLES := 150
const HASHED := true

func _init() -> void:
	var scripts := {"current": load("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")}
	if ResourceLoader.exists("res://tests/harness/layout_judging/_field_old.gd"):
		scripts["old"] = load("res://tests/harness/layout_judging/_field_old.gd")
	for name: String in scripts:
		for scale: StringName in WarrenVillageScaleProfile.IDS:
			var rows: Array[Dictionary] = []
			for i in range(1, SAMPLES + 1):
				var seed_value := Helper._mix64(i * 7919 + 17) if HASHED else i
				var profile := WarrenVillageScaleProfile.for_id(scale)
				var massif := WarrenMassifBuilder._terraced_massif(seed_value,
					scripts[name].sample(seed_value, profile).solid, {})
				massif.finish_construction()
				var row := stats(massif)
				row["carved"] = 1.0 if WarrenMazeCarver.carve(seed_value, massif, profile, false, false) != null else 0.0
				rows.append(row)
			var line := "FIELD %s %s" % [name, scale]
			for key in ["columns", "open_fraction", "interior_clearings", "largest_clearing", "high_massifs", "low_fraction", "enclosed_open", "largest_court", "carved"]:
				var values: Array = rows.map(func(r): return float(r[key]))
				var mean := 0.0
				for v in values: mean += v
				mean /= values.size()
				var variance := 0.0
				for v in values: variance += (v - mean) * (v - mean)
				line += " %s=%.3f±%.3f" % [key, mean, sqrt(variance / values.size())]
			print(line)
	quit()

static func stats(massif: WarrenMassif) -> Dictionary:
	var cols: Dictionary = massif.columns
	var bounds := Rect2i()
	var first := true
	for c: Vector2i in cols:
		bounds = Rect2i(c, Vector2i.ONE) if first else bounds.expand(c).expand(c + Vector2i.ONE)
		first = false
	var air := {}
	for x in range(bounds.position.x, bounds.end.x):
		for z in range(bounds.position.y, bounds.end.y):
			if not cols.has(Vector2i(x, z)): air[Vector2i(x, z)] = true
	var enclosed := {}
	for cell: Vector2i in air:
		var hits := 0
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var c := cell + d
			while bounds.has_point(c):
				if cols.has(c):
					hits += 1
					break
				c += d
		if hits >= 3: enclosed[cell] = true
	var courts: Array = preload("res://tests/harness/layout_judging/layout_corpus.gd")._components(enclosed, Rect2i(), false)
	var interior: Array = preload("res://tests/harness/layout_judging/layout_corpus.gd")._components(air, bounds, true)
	var max_layer := 0
	for c: Vector2i in cols: max_layer = maxi(max_layer, massif.layer_at(c))
	var tall := {}
	var low := 0
	for c: Vector2i in cols:
		if massif.layer_at(c) >= maxi(4, max_layer / 2): tall[c] = true
		if massif.layer_at(c) <= 2: low += 1
	var high: Array = preload("res://tests/harness/layout_judging/layout_corpus.gd")._components(tall, Rect2i(), false)
	return {"columns": cols.size(), "open_fraction": float(air.size()) / maxf(1.0, bounds.get_area()),
		"interior_clearings": interior.filter(func(a): return a.size() >= 2).size(),
		"largest_clearing": 0 if interior.is_empty() else interior.map(func(a): return a.size()).max(),
		"high_massifs": high.filter(func(a): return a.size() >= 3).size(),
		"low_fraction": float(low) / maxf(1.0, cols.size()),
		"enclosed_open": float(enclosed.size()) / maxf(1.0, cols.size()),
		"largest_court": 0 if courts.is_empty() else courts.map(func(a): return a.size()).max()}
