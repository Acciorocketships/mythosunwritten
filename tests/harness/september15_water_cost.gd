extends SceneTree

## Diagnostic decomposition of the production WaterFieldContext build. Same
## arrays/coverage/contours, with phase timings and output hashes. No scene or
## graphics work runs concurrently with this profile.
class ProfileFields extends WorldFieldBlockCache:
	var rows: Array = []
	var output: String
	func water(key: Vector2i) -> WaterFieldContext:
		if has_water(key): return super.water(key)
		var started := Time.get_ticks_usec()
		var block_region := region(key)
		var core := Rect2(Vector2(key) * BLOCK_WORLD, Vector2.ONE * BLOCK_WORLD)
		var query := core.grow(_query_margin)
		var raw_started := Time.get_ticks_usec()
		var raw := WaterField.ctx(_water_plan, key, block_region)
		var raw_finished := Time.get_ticks_usec()
		var result := WaterFieldContext.new()
		result._ctx = raw
		result._region = block_region
		result._coverage = query
		result._shore_limit = _shore_limit
		if not result.has_sources():
			result._shore_curves_ready = true
		elif _shore_limit > 0.0:
			result._shore_curves = WaterContour.curves(raw, query.grow(_shore_limit))
			result._shore_curves_ready = true
		var finished := Time.get_ticks_usec()
		var entry := _entry(key)
		entry.water = result
		_touch(key, entry)
		water_build_count += 1
		water_build_usec += finished - raw_started
		var row := {"chunk": str(key), "region_ms": (raw_started-started)/1000.0,
			"fill_ms": (raw_finished-raw_started)/1000.0,
			"contours_ms": (finished-raw_finished)/1000.0,
			"rivers": raw.rivers.size(), "ponds": raw.ponds.size(),
			"memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"fill_hash": var_to_bytes(raw.fill).hex_encode().sha256_text(),
			"coarse_level_hash": var_to_bytes(raw.fill.levels).hex_encode().sha256_text(),
			"fine_level_hash": var_to_bytes(raw.fill.sub_levels).hex_encode().sha256_text(),
			"contour_hash": var_to_bytes(result._shore_curves).hex_encode().sha256_text()}
		rows.append(row)
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
		print("WATER_COST ", JSON.stringify(row))
		return result

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	WaterField.profile_source_cost = true
	var water := TerrainWorldTuning.make_water(2697992464)
	var heights := TerrainWorldTuning.make_heightfield(2697992464, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var fields := ProfileFields.new(heights, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	fields.output = OS.get_cmdline_user_args()[0]
	var features := WorldFeaturePlan.new(2697992464, water, fields, program,
		SettlementPlan.new(2697992464, water))
	var started := Time.get_ticks_usec()
	for key: Vector2i in [Vector2i(-3,-1), Vector2i(-4,-2), Vector2i(-1,-1)]:
		print("PROFILE_FEATURE_BEGIN ",key)
		features.context_for(key)
		fields.water(key)
	print("FEATURE_COST ms=", (Time.get_ticks_usec()-started)/1000.0)
	quit()
