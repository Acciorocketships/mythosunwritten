# tests/harness/profile_startup_pipeline.gd
# Production-faithful startup + streaming profiler. Mirrors
# FieldTerrainStreamer._ready() construction order exactly (TerrainWorldTuning
# factories, relief, programs, caches), then replays the startup gate work
# (4 support chunks + their feature-halo keys) and a steady-state ring sweep,
# attributing wall time to each phase. Everything runs on one thread, like the
# production worker.
#
#   Godot --headless --path . -s res://tests/harness/profile_startup_pipeline.gd \
#     [-- --seed=2697992464 --radius=2 --grass]
#
# Run with an overridden HOME to keep user://warren_solution_pins.json isolated
# from the real player cache.
extends SceneTree

const DEFAULT_SEED := 2697992464   # world.tscn SEED_OVERRIDE
const CHUNK_WORLD := 192.0

var _t0 := 0

func _ms(usec: int) -> String:
	return "%.1f" % (float(usec) / 1000.0)

func _mark(label: String, started_usec: int) -> int:
	var now := Time.get_ticks_usec()
	print("[profile] %s ms=%s total_ms=%s" % [
		label, _ms(now - started_usec), _ms(now - _t0)])
	return now

func _init() -> void:
	var seed_value := DEFAULT_SEED
	var radius := 2
	var do_grass := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--radius="):
			radius = int(arg.trim_prefix("--radius="))
		elif arg == "--grass":
			do_grass = true
	print("[profile] begin seed=%d radius=%d user_dir=%s" % [
		seed_value, radius, OS.get_user_data_dir()])
	_t0 = Time.get_ticks_usec()
	var t := _t0

	# --- _ready() equivalents, in production order -------------------------
	var water := TerrainWorldTuning.make_water(seed_value)
	t = _mark("ready.make_water", t)
	var settlements := SettlementPlan.new(seed_value, water)
	t = _mark("ready.settlement_plan", t)
	var relief = TerrainWorldTuning.make_relief(seed_value, water, settlements)
	t = _mark("ready.make_relief(active=%s)" % (relief != null), t)
	var plan := TerrainWorldTuning.make_heightfield(seed_value, water, relief)
	t = _mark("ready.make_heightfield", t)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(seed_value)
	var water_builder := WaterSurfaceBuilder.new()
	var catalog := EnvironmentCatalog.load_default()
	t = _mark("ready.environment_catalog", t)
	var render_cache := EnvironmentRenderCache.new(catalog)
	var dressing_index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var dressing_program := DressingCompiler.compile(dressing_index, catalog)
	t = _mark("ready.dressing_compile", t)
	var feature_program := FeatureProgram.compile(catalog)
	t = _mark("ready.feature_compile", t)
	var grass_program: GrassProgram = null
	var grass_settings := load("res://terrain/grass/settings.tres") as GrassSettings
	grass_program = GrassProgram.compile(grass_settings, catalog, render_cache)
	t = _mark("ready.grass_compile", t)
	var combined_query_margin := maxf(dressing_program.query_margin,
		feature_program.query_margin)
	var feature_context_margin := maxf(feature_program.query_margin,
		dressing_program.feature_query_margin)
	var combined_shore_limit := maxf(dressing_program.shore_distance_limit,
		feature_program.shore_distance_limit)
	if grass_program != null:
		combined_query_margin = maxf(combined_query_margin,
			grass_program.query_margin)
		combined_shore_limit = maxf(combined_shore_limit,
			grass_program.shore_distance_limit)
	var fields := WorldFieldBlockCache.new(plan, water, combined_query_margin,
		combined_shore_limit, feature_program.field_cache_cap)
	var features := WorldFeaturePlan.new(seed_value, water, fields,
		feature_program, settlements, feature_context_margin)
	t = _mark("ready.field_cache+feature_plan", t)
	var active_set: Dictionary = {}
	for asset_id: StringName in dressing_program.referenced_asset_ids:
		active_set[asset_id] = true
	if grass_program != null:
		for asset_id: StringName in grass_program.referenced_asset_ids:
			active_set[asset_id] = true
	for asset_id: StringName in CliffDressing.ASSETS.values():
		active_set[asset_id] = true
	var active_visuals: Array[StringName] = []
	active_visuals.assign(active_set.keys())
	active_visuals.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	assert(render_cache.prepare(active_visuals))
	t = _mark("ready.render_cache_prepare(%d assets)" % active_visuals.size(), t)
	CliffDressing.prepare(render_cache)
	CliffDressing.shared_material()
	WaterSurfaceBuilder.sheet_material()
	mesher.prepare_resources()
	t = _mark("ready.materials+mesher_resources", t)
	print("[profile] READY_TOTAL ms=%s" % _ms(Time.get_ticks_usec() - _t0))

	# --- startup gate replay ----------------------------------------------
	var supports := FieldTerrainStreamer.support_chunks_at(Vector3.ZERO)
	var halo := feature_program.geometry_halo
	var key_set: Dictionary = {}
	for chunk: Vector2i in supports:
		for dz in range(-halo, halo + 1):
			for dx in range(-halo, halo + 1):
				key_set[chunk + Vector2i(dx, dz)] = true
	var feature_keys: Array[Vector2i] = []
	feature_keys.assign(key_set.keys())
	feature_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	print("[profile] startup supports=%s feature_keys=%d halo=%d" % [
		str(supports), feature_keys.size(), halo])
	var startup_started := Time.get_ticks_usec()
	for key: Vector2i in feature_keys:
		var key_started := Time.get_ticks_usec()
		features.context_for(key)
		print("[profile] startup.context key=%d,%d ms=%s" % [
			key.x, key.y, _ms(Time.get_ticks_usec() - key_started)])
	t = _mark("startup.contexts_total", startup_started)
	for chunk: Vector2i in supports:
		var built := _build_chunk(chunk, plan, water, mesher, water_builder,
			dressing_program, features, fields, render_cache, seed_value, true)
		print("[profile] startup.support chunk=%d,%d %s" % [
			chunk.x, chunk.y, built])
	print("[profile] STARTUP_TOTAL ms=%s (contexts + 4 supports)" \
		% _ms(Time.get_ticks_usec() - startup_started))

	# --- steady-state sweep ------------------------------------------------
	var sweep_started := Time.get_ticks_usec()
	var sweep_count := 0
	var worst_usec := 0
	var worst_chunk := Vector2i.ZERO
	var phase_totals: Dictionary = {}
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var chunk := Vector2i(dx, dz)
			if supports.has(chunk):
				continue
			var chunk_started := Time.get_ticks_usec()
			var report := _build_chunk(chunk, plan, water, mesher, water_builder,
				dressing_program, features, fields, render_cache, seed_value, false)
			var chunk_usec := Time.get_ticks_usec() - chunk_started
			sweep_count += 1
			for phase: String in report_phases(report):
				phase_totals[phase] = int(phase_totals.get(phase, 0)) \
					+ int(report[phase])
			if chunk_usec > worst_usec:
				worst_usec = chunk_usec
				worst_chunk = chunk
			print("[profile] sweep.chunk chunk=%d,%d total_ms=%s %s" % [
				chunk.x, chunk.y, _ms(chunk_usec), report])
	var sweep_usec := Time.get_ticks_usec() - sweep_started
	print("[profile] SWEEP_TOTAL chunks=%d ms=%s avg_ms=%s worst_ms=%s at %s" % [
		sweep_count, _ms(sweep_usec), _ms(sweep_usec / maxi(sweep_count, 1)),
		_ms(worst_usec), worst_chunk])
	for phase: String in phase_totals:
		print("[profile] sweep.phase %s total_ms=%s avg_ms=%s" % [
			phase, _ms(phase_totals[phase]),
			_ms(int(phase_totals[phase]) / maxi(sweep_count, 1))])

	# --- grass tiles -------------------------------------------------------
	if do_grass and grass_program != null:
		var tiles := GrassStreamer.desired_tiles(Vector2.ZERO)
		var grass_started := Time.get_ticks_usec()
		var grass_worst := 0
		for tile: Vector2i in tiles:
			var parent := GrassField.parent_chunk(tile)
			var tile_started := Time.get_ticks_usec()
			GrassField.compute(grass_program, seed_value, tile,
				fields.region(parent), fields.water(parent),
				features.context_for(parent))
			grass_worst = maxi(grass_worst, Time.get_ticks_usec() - tile_started)
		var grass_usec := Time.get_ticks_usec() - grass_started
		print("[profile] GRASS_TOTAL tiles=%d ms=%s avg_ms=%s worst_ms=%s" % [
			tiles.size(), _ms(grass_usec),
			_ms(grass_usec / maxi(tiles.size(), 1)), _ms(grass_worst)])

	print("[profile] fields.stats=%s" % str(fields.stats()))
	print("[profile] features.stats=%s" % str(features.stats()))
	print("[profile] DONE total_ms=%s" % _ms(Time.get_ticks_usec() - _t0))
	quit()

func report_phases(report: Dictionary) -> Array:
	var out: Array = []
	for key in report:
		if String(key).ends_with("_usec"):
			out.append(key)
	return out

func _build_chunk(chunk: Vector2i, plan: HeightfieldPlan, water: WaterPlan,
		mesher: TerrainChunkMesher, water_builder: WaterSurfaceBuilder,
		dressing_program: DressingProgram, features: WorldFeaturePlan,
		fields: WorldFieldBlockCache, render_cache: EnvironmentRenderCache,
		seed_value: int, verbose: bool) -> Dictionary:
	var report: Dictionary = {}
	var t := Time.get_ticks_usec()
	var feature_context := features.context_for(chunk)
	report["context_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var region: HeightfieldRegion = fields.region(chunk)
	report["region_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var water_context := fields.water(chunk)
	report["water_ctx_usec"] = Time.get_ticks_usec() - t
	var core := Rect2(Vector2(chunk) * CHUNK_WORLD, Vector2.ONE * CHUNK_WORLD)
	t = Time.get_ticks_usec()
	var terrain_payload := mesher.compute_chunk(chunk, region, water_context,
		feature_context)
	report["mesh_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var water_payload := water_builder.compute_chunk(water, chunk, region,
		water_context)
	report["water_mesh_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var dressing_payload := DressingField.compute(dressing_program, seed_value,
		core, region, water_context, feature_context)
	report["dressing_usec"] = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var node := mesher.commit_chunk(terrain_payload)
	var water_node := water_builder.commit_chunk(water_payload)
	if water_node != null:
		node.add_child(water_node)
	EnvironmentCollisionBuilder.commit(node, dressing_payload, render_cache,
		&"DressingCollision")
	var queue := EnvironmentCommitQueue.new(render_cache, &"Dressing")
	queue.register_chunk(chunk, 1)
	queue.enqueue(chunk, 1, node, dressing_payload)
	queue.drain(1000000)
	report["commit_usec"] = Time.get_ticks_usec() - t
	node.free()
	return report
