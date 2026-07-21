extends SceneTree

## Deterministic release corpus for canonical paths and feature blocks.
## Default is the small smoke set; `-- --full` uses all pinned seeds.
const SMOKE_SEEDS := [3046246887]
const FULL_SEEDS := [3046246887, 2697992464, 991177, 4242]
const THRESHOLDS := {
	"minimum_smoke_nodes": 1,
	"minimum_smoke_route_cells": 1,
	"minimum_full_nodes": 20,
	"minimum_full_route_cells": 50,
	"minimum_full_features": 1,
	"maximum_exact_failure_fraction": 0.5,
	"maximum_smoke_context_ms": 60000.0,
}

func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var path_program := PathProgram.compile(catalog)
	assert(path_program != null)
	var full := OS.get_cmdline_user_args().has("--full")
	var seeds := FULL_SEEDS if full else SMOKE_SEEDS
	var totals := {"nodes": 0, "route_cells": 0, "features": 0,
		"solves": 0, "exact_failures": 0}
	for seed_value: int in seeds:
		var metrics := _run_seed(seed_value, path_program)
		for field: String in totals:
			totals[field] += int(metrics[field])
		if not full:
			assert(int(metrics.nodes) >= int(THRESHOLDS.minimum_smoke_nodes))
			assert(int(metrics.route_cells) >= int(THRESHOLDS.minimum_smoke_route_cells))
			assert(float(metrics.context_ms) <= float(THRESHOLDS.maximum_smoke_context_ms))
	if full:
		assert(int(totals.nodes) >= int(THRESHOLDS.minimum_full_nodes))
		assert(int(totals.route_cells) >= int(THRESHOLDS.minimum_full_route_cells))
		assert(int(totals.features) >= int(THRESHOLDS.minimum_full_features))
	var failure_fraction := float(totals.exact_failures) \
		/ maxf(1.0, float(totals.solves))
	assert(failure_fraction <= float(THRESHOLDS.maximum_exact_failure_fraction))
	quit()

func _run_seed(seed_value: int, program: PathProgram) -> Dictionary:
	var water := WaterPlan.new(seed_value, 22.0, 8)
	var settlements := SettlementPlan.new(seed_value, water)
	var height_plan := HeightfieldPlan.new(seed_value, 22.0, 8, "mean", 3)
	height_plan.set_water_plan(water)
	var fields := WorldFieldBlockCache.new(height_plan, water,
		program.query_margin, program.shore_distance_limit, program.FIELD_CACHE_CAP)
	var paths := PathPlan.new(seed_value, water, fields, program,
		program.query_margin, settlements)
	var node_count := 0
	for z in range(-2, 3):
		for x in range(-2, 3):
			if not paths.node_for(Vector2i(x, z)).is_empty():
				node_count += 1
	var route_cells: Dictionary = {}
	var feature_ids: Dictionary = {}
	var feature_instances := 0
	var asset_counts: Dictionary = {}
	var started := Time.get_ticks_usec()
	for z in range(-1, 2):
		for x in range(-1, 2):
			var context := paths.context_for(Vector2i(x, z))
			for cell: Vector2i in context.connection_masks:
				route_cells[cell] = true
			var payload := context.placements()
			assert(payload.validate())
			feature_instances += payload.instance_count
			for asset_id: StringName in payload.asset_ids():
				asset_counts[asset_id] = int(asset_counts.get(asset_id, 0)) \
					+ int(payload.batches[asset_id].transforms.size())
				for stable_id: StringName in payload.batches[asset_id].ids:
					assert(not feature_ids.has(stable_id),
						"stable feature identity duplicated across half-open blocks")
					feature_ids[stable_id] = true
	var context_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var stats := paths.stats()
	var solves := int(stats.route_solves)
	var exact_failures := int(stats.route_exact_failures)
	print(("[path_corpus] seed=%d nodes=%d route_cells=%d features=%d assets=%s " \
		+ "context_ms=%.1f exact_failures=%d/%d fields=%s paths=%s") % [
		seed_value, node_count, route_cells.size(), feature_instances, asset_counts,
		context_ms, exact_failures, solves, fields.stats(), stats])
	return {"nodes": node_count, "route_cells": route_cells.size(),
		"features": feature_instances, "solves": solves,
		"exact_failures": exact_failures, "context_ms": context_ms}
