# tests/harness/water_block_cost.gd
# Times one chunk's planning (heightfield region, then water context) as the
# streamer's worker computes it, with the same native kernels and disk cache.
#   PROFILE_WATER_COST=1 Godot --headless --path . -s res://tests/harness/water_block_cost.gd -- \
#     [--seed=N] [--chunk=x,z] [--no-disk] [--serial]
# Prints a digest of the region's storeys/levels and the water fill so a
# change can be checked for identical output.
extends SceneTree

func _init() -> void:
	var seed := 2697992464
	var chunk := Vector2i(1, -5)
	var disk := true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--chunk="):
			var xz := arg.trim_prefix("--chunk=").split(",")
			chunk = Vector2i(int(xz[0]), int(xz[1]))
		elif arg == "--no-disk": disk = false
		elif arg == "--serial": HeightfieldPlan.prefetch_enabled = false
	if disk:
		preload("res://scripts/terrain/field/PlanningDiskCache.gd").configure(seed)
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	var water := TerrainWorldTuning.make_water(seed)
	var plan := TerrainWorldTuning.make_heightfield(seed, water)
	var catalog := EnvironmentCatalog.load_default()
	var index := load("res://terrain/dressing/index.tres") as DressingCatalogIndex
	var program := DressingCompiler.compile(index, catalog)
	var fields := WorldFieldBlockCache.new(plan, water, program.query_margin,
		program.shore_distance_limit, 64)
	var t := Time.get_ticks_usec()
	var region := fields.region(chunk)
	var region_ms := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	var context := fields.water(chunk)
	var water_ms := (Time.get_ticks_usec() - t) / 1000.0
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for j in range(chunk.y * 16 - 8, chunk.y * 16 + 24):
		for i in range(chunk.x * 16 - 8, chunk.x * 16 + 24):
			ctx.update(var_to_bytes([region.storey_at(i, j), region.level_at(i, j)]))
	for j in 96:
		for i in 96:
			var p := Vector2(chunk.x * 192.0 + i * 2.0, chunk.y * 192.0 + j * 2.0)
			ctx.update(var_to_bytes(context.signed_depth_at(p)))
	print("WATER_BLOCK_COST ", JSON.stringify({"chunk": str(chunk), "digest": ctx.finish().hex_encode().left(16), "region_ms": region_ms,
		"water_ms": water_ms, "height_samples": plan._samples.size(),
		"water_regions": water._region_cache.size(), "traces": water._trace_cache.size()}))
	quit()
