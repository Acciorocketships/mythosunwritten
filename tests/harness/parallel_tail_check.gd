# tests/harness/parallel_tail_check.gd
# Determinism / thread-safety check for parallel chunk tails. Plans regions
# and water for a set of chunks, then computes each chunk's tail (terrain
# mesh + cliff sheet, water skin, dressing, grass sampling, biome fx) twice:
# serially with one mesher, and on WorkerThreadPool with one mesher per task
# and a frozen 3x3 block view, while the main thread keeps planning other
# chunks through the shared caches (as the streamer's planning thread does).
# Every payload is hashed; any difference or crash fails the run.
#
#   Godot --headless --path . -s res://tests/harness/parallel_tail_check.gd -- \
#     [--seed=N] [--chunks="x,z;..."] [--busy="x,z;..."] [--rounds=N] [--tasks=N]
extends SceneTree

var _seed := 2697992464
var _chunks: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
var _busy: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(-2, 0), Vector2i(0, 2)]
var _rounds := 2
var _tasks := 4
var _no_busy := false

static func _parse(text: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pair: String in text.split(";"):
		var xz := pair.split(",")
		out.append(Vector2i(int(xz[0]), int(xz[1])))
	return out

static func _feed(ctx: HashingContext, value) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort_custom(func(a, b) -> bool: return str(a) < str(b))
			for key in keys:
				_feed(ctx, str(key))
				_feed(ctx, value[key])
		TYPE_ARRAY:
			ctx.update(var_to_bytes(value.size()))
			for item in value:
				_feed(ctx, item)
		TYPE_OBJECT:
			ctx.update(String(value.get_class() if value != null else "null").to_utf8_buffer())
		TYPE_CALLABLE:
			pass
		_:
			ctx.update(var_to_bytes(value))

static func _hash(value) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	_feed(ctx, value)
	return ctx.finish().hex_encode().left(16)

var plan: HeightfieldPlan
var water: WaterPlan
var fields: WorldFieldBlockCache
var dressing_program: DressingProgram
var _regions: Dictionary = {}
var _waters: Dictionary = {}

func _make_mesher() -> TerrainChunkMesher:
	var m := TerrainChunkMesher.new()
	m.set_seed(_seed)
	m.prepare_resources()
	return m

func _tail(chunk: Vector2i, mesher: TerrainChunkMesher, blocks: WorldFieldBlockCache) -> Dictionary:
	mesher.water_blocks = blocks
	var region: HeightfieldRegion = _regions[chunk]
	var water_ctx: WaterFieldContext = _waters[chunk]
	var terrain := mesher.compute_chunk(chunk, region, water_ctx, null)
	terrain.erase("profile")
	var skin := WaterSurfaceBuilder.new().compute_chunk(water, chunk, region, water_ctx)
	var core := Rect2(Vector2(chunk) * 192.0, Vector2.ONE * 192.0)
	var dressing := DressingField.compute(dressing_program, _seed, core, region, water_ctx,
		null, terrain.cliff_terraces.ground_reservations)
	var fx := BiomeAtmosphereField.compute(chunk, region, _seed, water_ctx)
	return {"terrain": _hash(terrain), "water": _hash(skin), "dressing": _hash(dressing),
		"fx": _hash(fx)}

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): _seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--chunks="): _chunks = _parse(arg.trim_prefix("--chunks="))
		elif arg.begins_with("--busy="): _busy = _parse(arg.trim_prefix("--busy="))
		elif arg.begins_with("--rounds="): _rounds = int(arg.trim_prefix("--rounds="))
		elif arg.begins_with("--tasks="): _tasks = int(arg.trim_prefix("--tasks="))
		elif arg == "--no-busy": _no_busy = true
	water = TerrainWorldTuning.make_water(_seed)
	plan = TerrainWorldTuning.make_heightfield(_seed, water)
	var catalog := EnvironmentCatalog.load_default()
	var render_cache := EnvironmentRenderCache.new(catalog)
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var visuals := DressingCompiler.authored_asset_ids(index)
	render_cache.prepare(visuals)
	dressing_program = DressingCompiler.compile(index, catalog)
	fields = WorldFieldBlockCache.new(plan, water, dressing_program.query_margin,
		dressing_program.shore_distance_limit, 64)
	CliffDressing.prepare(render_cache)
	CliffDressing.shared_material()
	BiomeRegistry.profile(&"meadow")
	var t := Time.get_ticks_usec()
	var views: Dictionary = {}
	for chunk: Vector2i in _chunks:
		_regions[chunk] = fields.region(chunk)
		_waters[chunk] = fields.water(chunk)
		var keys: Array[Vector2i] = []
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				keys.append(chunk + Vector2i(dx, dz))
		views[chunk] = keys
	print("[tailcheck] planned %d chunks ms=%.0f" % [_chunks.size(), (Time.get_ticks_usec() - t) / 1000.0])
	# Plan every view first so the timings below are tails only.
	var serial_views: Dictionary = {}
	for chunk: Vector2i in _chunks:
		serial_views[chunk] = fields.frozen_view(views[chunk])
	print("[tailcheck] planned views ms=%.0f" % ((Time.get_ticks_usec() - t) / 1000.0))
	var serial_mesher := _make_mesher()
	var reference: Dictionary = {}
	t = Time.get_ticks_usec()
	for chunk: Vector2i in _chunks:
		reference[chunk] = _tail(chunk, serial_mesher, serial_views[chunk])
	var serial_ms := (Time.get_ticks_usec() - t) / 1000.0
	print("[tailcheck] serial tails ms=%.0f" % serial_ms)
	var meshers: Array[TerrainChunkMesher] = []
	for i in _chunks.size():
		meshers.append(_make_mesher())
	var failures := 0
	for round_index in _rounds:
		var results: Dictionary = {}
		var lock := Mutex.new()
		var frozen: Array[WorldFieldBlockCache] = []
		for chunk: Vector2i in _chunks:
			frozen.append(fields.frozen_view(views[chunk]))
		t = Time.get_ticks_usec()
		var group := WorkerThreadPool.add_group_task(func(i: int) -> void:
			var r := _tail(_chunks[i], meshers[i], frozen[i])
			lock.lock()
			results[_chunks[i]] = r
			lock.unlock(), _chunks.size(), _tasks, true)
		# Meanwhile the "planning thread" keeps using the shared caches.
		for chunk: Vector2i in ([] if _no_busy else _busy):
			var c := chunk + Vector2i(round_index * 7, 0)
			fields.region(c)
			fields.water(c)
		WorkerThreadPool.wait_for_group_task_completion(group)
		var parallel_ms := (Time.get_ticks_usec() - t) / 1000.0
		for chunk: Vector2i in _chunks:
			if results.get(chunk) != reference[chunk]:
				failures += 1
				print("[tailcheck] MISMATCH round=%d chunk=%s serial=%s parallel=%s" % [
					round_index, chunk, reference[chunk], results.get(chunk)])
		print("[tailcheck] round=%d parallel tails+busy planning ms=%.0f" % [round_index, parallel_ms])
	print("[tailcheck] %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
