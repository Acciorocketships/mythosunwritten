extends SceneTree
const Exhaustive = preload("res://tests/fixtures/September10ExhaustivePathContext.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := WorldFieldBlockCache.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var frozen := Exhaustive.new(seed_value, water, fields, program.paths,
		program.query_margin, settlements, program.surface_priorities)
	var candidate := PathPlan.new(seed_value, water, fields, program.paths,
		program.query_margin, settlements, program.surface_priorities)
	var rows: Array = []
	var ok := true
	var started := Time.get_ticks_msec()
	for key: Vector2i in [Vector2i(1,-2), Vector2i(9,-2), Vector2i(10,-6),
			Vector2i(5,-11), Vector2i(2,-11), Vector2i(8,-3), Vector2i(-8,-21)]:
		var before := frozen.context_for(key)
		var after := candidate.context_for(key)
		var node_masks_match := true
		for node: Vector2i in before.node_cells:
			var super_cell := SettlementPlan.super_of(node)
			node_masks_match = node_masks_match and frozen.accepted_mask_for_node(super_cell) == candidate.accepted_mask_for_node(super_cell)
		var row := {"chunk":str(key), "masks_identical":before.connection_masks == after.connection_masks,
			"nodes_identical":before.node_cells == after.node_cells,
			"bridges_identical":before.bridge_cells == after.bridge_cells,
			"placements_identical":before.placements().batches == after.placements().batches,
			"settlement_masks_identical":node_masks_match,
			"mask_cells":after.connection_masks.size(), "elapsed_msec":Time.get_ticks_msec()-started}
		ok = ok and row.masks_identical and row.nodes_identical and row.bridges_identical and row.placements_identical and node_masks_match
		rows.append(row)
		FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE).store_string(JSON.stringify({
			"identical":ok,"sites":rows,"before_stats":frozen.stats(),"after_stats":candidate.stats(),
			"note":"Shared canonical fields; elapsed times are not a speed comparison."},"  "))
		print("PATH_CONTEXT_COMPARISON ",JSON.stringify(row))
	quit(0 if ok else 1)
