# tests/harness/profile_terrain.gd
# End-to-end terrain-generation profiler: replays the streamer's 49-chunk
# startup sweep and attributes the current field-driven worker and commit
# phases. Run:
#   godot --headless --path /Users/ryko/story -s res://tests/harness/profile_terrain.gd
# Add `-- --warm` to repeat the sweep against the same plan/water instances.
extends SceneTree

const SEED := 3046246887
const AMP := 22.0
const MAX_STOREYS := 8
const MAX_STEP := 3
const RADIUS := 3
const CHUNK_WORLD := 192.0

func _ms(usec: int) -> String:
	return "%.1f ms" % (float(usec) / 1000.0)

func _mib(bytes: int) -> String:
	return "%.1f MiB" % (float(bytes) / (1024.0 * 1024.0))

func _profile_pass(label: String, plan: HeightfieldPlan, water: WaterPlan,
		mesher: TerrainChunkMesher, water_builder: WaterSurfaceBuilder,
		dressing_program: DressingProgram, path_program: PathProgram,
		fields: WorldFieldBlockCache, paths: PathPlan,
		render_cache: EnvironmentRenderCache) -> void:
	var worker_total := 0
	var region_total := 0
	var context_total := 0
	var path_context_total := 0
	var terrain_total := 0
	var water_total := 0
	var dressing_total := 0
	var terrain_commit_total := 0
	var water_commit_total := 0
	var collision_commit_total := 0
	var dressing_commit_total := 0
	var dressing_batches := 0
	var dressing_instances := 0
	var feature_instances := 0
	var feature_commit_total := 0
	var feature_batches := 0
	var feature_collisions := 0
	var dressing_collisions := 0
	var worst_worker := 0
	var worst_chunk := Vector2i.ZERO
	var memory_before := OS.get_static_memory_usage()

	print("\n=== %s: 49 chunks (radius 3) ===" % label)
	for dz in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var chunk := Vector2i(dx, dz)
			var worker_started := Time.get_ticks_usec()

			var started := Time.get_ticks_usec()
			var path_context := paths.context_for(chunk)
			path_context_total += Time.get_ticks_usec() - started

			started = Time.get_ticks_usec()
			var region: HeightfieldRegion = fields.region(chunk)
			region_total += Time.get_ticks_usec() - started

			var core := Rect2(Vector2(chunk) * CHUNK_WORLD, Vector2.ONE * CHUNK_WORLD)
			started = Time.get_ticks_usec()
			var context := fields.water(chunk)
			context_total += Time.get_ticks_usec() - started

			started = Time.get_ticks_usec()
			var terrain_payload := mesher.compute_chunk(chunk, region, context, path_context)
			terrain_total += Time.get_ticks_usec() - started

			started = Time.get_ticks_usec()
			var water_payload := water_builder.compute_chunk(water, chunk, region, context)
			water_total += Time.get_ticks_usec() - started

			started = Time.get_ticks_usec()
			var dressing_payload := DressingField.compute(dressing_program, SEED,
				core, region, context, path_context)
			dressing_total += Time.get_ticks_usec() - started
			dressing_instances += dressing_payload.instance_count
			var feature_payload := path_context.placements()
			feature_instances += feature_payload.instance_count

			var worker_usec := Time.get_ticks_usec() - worker_started
			worker_total += worker_usec
			if worker_usec > worst_worker:
				worst_worker = worker_usec
				worst_chunk = chunk

			started = Time.get_ticks_usec()
			var terrain_node := mesher.commit_chunk(terrain_payload)
			terrain_commit_total += Time.get_ticks_usec() - started

			started = Time.get_ticks_usec()
			var water_node := water_builder.commit_chunk(water_payload)
			if water_node != null:
				terrain_node.add_child(water_node)
			water_commit_total += Time.get_ticks_usec() - started

			started = Time.get_ticks_usec()
			dressing_collisions += EnvironmentCollisionBuilder.commit(
				terrain_node, dressing_payload, render_cache, &"DressingCollision")
			collision_commit_total += Time.get_ticks_usec() - started

			var queue := EnvironmentCommitQueue.new(render_cache, &"Dressing")
			queue.register_chunk(chunk, 1)
			started = Time.get_ticks_usec()
			queue.enqueue(chunk, 1, terrain_node, dressing_payload)
			dressing_batches += queue.drain(1000000)
			dressing_commit_total += Time.get_ticks_usec() - started

			var feature_root := Node3D.new()
			started = Time.get_ticks_usec()
			feature_collisions += EnvironmentCollisionBuilder.commit(feature_root,
				feature_payload, render_cache, &"FeatureCollision")
			var feature_queue := EnvironmentCommitQueue.new(render_cache, &"Visuals")
			feature_queue.register_chunk(chunk, 1)
			feature_queue.enqueue(chunk, 1, feature_root, feature_payload)
			feature_batches += feature_queue.drain(1000000)
			feature_commit_total += Time.get_ticks_usec() - started
			feature_root.free()
			terrain_node.free()

	var commit_total := terrain_commit_total + water_commit_total \
		+ collision_commit_total + dressing_commit_total + feature_commit_total
	print("worker TOTAL: %s  avg: %s  worst: %s at %s" % [
		_ms(worker_total), _ms(worker_total / 49), _ms(worst_worker), worst_chunk])
	print("  heightfield region: %s" % _ms(region_total))
	print("  shared water context: %s" % _ms(context_total))
	print("  PathContext (planning/routes/features): %s" % _ms(path_context_total))
	print("  terrain mesh payload: %s" % _ms(terrain_total))
	print("  water skin payload: %s" % _ms(water_total))
	print("  DressingField: %s  (%d instances)" % [
		_ms(dressing_total), dressing_instances])
	print("commit TOTAL: %s" % _ms(commit_total))
	print("  terrain commit: %s" % _ms(terrain_commit_total))
	print("  water commit: %s" % _ms(water_commit_total))
	print("  dressing collision commit: %s  (%d shapes)" % [
		_ms(collision_commit_total), dressing_collisions])
	print("  dressing commit: %s  (%d MultiMesh batches)" % [
		_ms(dressing_commit_total), dressing_batches])
	print("  feature commit: %s  (%d instances, %d shapes, %d batches)" % [
		_ms(feature_commit_total), feature_instances, feature_collisions, feature_batches])
	print("  field cache: %s" % fields.stats())
	print("  path plan: %s" % paths.stats())
	print("static memory: %s -> %s  process peak: %s" % [
		_mib(memory_before), _mib(OS.get_static_memory_usage()),
		_mib(OS.get_static_memory_peak_usage())])

func _init() -> void:
	print("=== terrain profile, seed %d ===" % SEED)
	var water := WaterPlan.new(SEED, AMP, MAX_STOREYS)
	var settlements := SettlementPlan.new(SEED, water)
	var plan := HeightfieldPlan.new(SEED, AMP, MAX_STOREYS, "mean", MAX_STEP)
	plan.set_water_plan(water)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(SEED)
	var water_builder := WaterSurfaceBuilder.new()

	var memory_before := OS.get_static_memory_usage()
	var prepare_started := Time.get_ticks_usec()
	var catalog := EnvironmentCatalog.load_default()
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var dressing_program := DressingCompiler.compile(index, catalog)
	var path_program := PathProgram.compile(catalog)
	assert(dressing_program != null and path_program != null)
	var query_margin := maxf(dressing_program.query_margin, path_program.query_margin)
	var shore_limit := maxf(dressing_program.shore_distance_limit,
		path_program.shore_distance_limit)
	var fields := WorldFieldBlockCache.new(plan, water, query_margin, shore_limit,
		path_program.FIELD_CACHE_CAP)
	var paths := PathPlan.new(SEED, water, fields, path_program,
		query_margin, settlements)
	var render_cache := EnvironmentRenderCache.new(catalog)
	var active_set: Dictionary = {}
	for asset_id: StringName in dressing_program.referenced_asset_ids:
		active_set[asset_id] = true
	for asset_id: StringName in path_program.referenced_asset_ids:
		active_set[asset_id] = true
	for asset_id: StringName in CliffDressing.ASSETS.values():
		active_set[asset_id] = true
	var active_visuals: Array[StringName] = []
	active_visuals.assign(active_set.keys())
	assert(render_cache.prepare(active_visuals))
	CliffDressing.prepare(render_cache)
	CliffDressing.shared_material()
	WaterSurfaceBuilder.sheet_material()
	mesher.prepare_resources()
	var prepare_usec := Time.get_ticks_usec() - prepare_started
	var memory_after := OS.get_static_memory_usage()
	print("resource preparation: %s  memory: %s -> %s (+%s)" % [
		_ms(prepare_usec), _mib(memory_before), _mib(memory_after),
		_mib(memory_after - memory_before)])
	print("program: %d sets, %d active assets, margin %.1fm, estimated %d proposals/chunk" % [
		dressing_program.sets.size(), active_visuals.size(), query_margin,
		dressing_program.estimated_proposals_per_chunk])

	_profile_pass("cold sweep", plan, water, mesher, water_builder, dressing_program,
		path_program, fields, paths, render_cache)
	if OS.get_cmdline_user_args().has("--warm"):
		_profile_pass("warm sweep", plan, water, mesher, water_builder, dressing_program,
			path_program, fields, paths, render_cache)
	quit()
