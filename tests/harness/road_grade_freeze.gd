extends SceneTree
## Freezes one real town grade with its natural terrain and nearby accepted
## country-road lattice as a compact fixture (September 27 dead-end road).
##   Godot --headless --path . -s res://tests/harness/road_grade_freeze.gd -- --seed S --only sx,sz --out res://tests/fixtures/X.var.gz
func _init() -> void:
	var seed_value := 2697992464
	var only := Vector2i(1, 0)
	var out_path := "res://tests/fixtures/september27-dead-end-grade.var.gz"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed": seed_value = int(args[i + 1])
		if args[i] == "--out": out_path = args[i + 1]
		if args[i] == "--only":
			var p := args[i + 1].split(",")
			only = Vector2i(int(p[0]), int(p[1]))
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program,
		SettlementPlan.new(seed_value, water))
	var frame := world.frame_for(only)
	var record := world.village_plan().record_for(frame)
	var grade := record.urban_fabric.terrain_grade
	var tile := TerrainSurfaceField.TILE
	var area := grade.bounds.grow(TerrainGradePatch.NATIVE_CONTROL_MARGIN + 3.0 * tile)
	var lo := Vector2i(floori(area.position.x / tile), floori(area.position.y / tile))
	var hi := Vector2i(ceili(area.end.x / tile), ceili(area.end.y / tile))
	var mid := (lo + hi) / 2
	var natural := heightfield.compute_region(mid.x, mid.y, maxi(hi.x - lo.x, hi.y - lo.y) / 2 + 3)
	var storeys := {}
	var levels := {}
	var carved := {}
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, z)
			storeys[c] = natural.storey_at(x, z)
			levels[c] = natural.level_at(x, z)
			if natural.is_carved(x, z): carved[c] = true
	var masks := {}
	var blocks := {}
	for z in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			blocks[WorldFieldBlockCache.key_of(Vector2(x, z) * tile)] = true
	for block: Vector2i in blocks:
		var ground := world.path_plan().context_for(block).ground_field()
		for cell: Vector2i in ground._connection_masks:
			if cell.x >= lo.x and cell.x <= hi.x and cell.y >= lo.y and cell.y <= hi.y:
				masks[cell] = ground._connection_masks[cell]
	var data := {"seed": seed_value, "settlement": String(frame.settlement_id),
		"cells": Rect2i(lo, hi - lo), "storeys": storeys, "levels": levels,
		"carved": carved, "road_masks": masks, "grade": _grade(grade)}
	var bytes := var_to_bytes(data).compress(FileAccess.COMPRESSION_GZIP)
	FileAccess.open(out_path, FileAccess.WRITE).store_buffer(bytes)
	print("FROZE ", out_path, " bytes=", bytes.size(), " cells=", Rect2i(lo, hi - lo), " roads=", masks.size())
	quit()

static func _grade(grade: TerrainGradePatch) -> Dictionary:
	if grade == null: return {}
	return {"id": String(grade.stable_id), "claims": grade._claims, "origin": grade._origin,
		"pitch": grade._targets.pitch, "continuous_cells": grade._continuous_cells,
		"continuous_datum": grade._continuous_datum, "source": _grade(grade._continuous_source)}
