# tests/harness/planning_cache_check.gd
# PlanningDiskCache exactness: run twice in fresh processes with the same
# HOME. The first run solves the blocks' water fresh (and writes the cache),
# the second rebuilds them from disk; both print a digest of every query the
# game makes of a water context (wetness, level, signed depth, shore distance,
# wet intervals) plus the raw plain-data fields. The digests must match.
#   Godot --headless --path . -s res://tests/harness/planning_cache_check.gd -- \
#     [--seed=N] [--blocks="x,z;..."]
extends SceneTree

const DISK_CACHE := preload("res://scripts/terrain/field/PlanningDiskCache.gd")

func _init() -> void:
	var seed_value := 2697992464
	var blocks: Array[Vector2i] = [Vector2i(-1, 1), Vector2i(1, -2), Vector2i(0, 0)]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--blocks="):
			blocks.clear()
			for pair: String in arg.trim_prefix("--blocks=").split(";"):
				var xz := pair.split(",")
				blocks.append(Vector2i(int(xz[0]), int(xz[1])))
	DISK_CACHE.configure(seed_value)
	var water := TerrainWorldTuning.make_water(seed_value)
	var plan := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fields := WorldFieldBlockCache.new(plan, water, 16.0, 4.0, 64)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var t := Time.get_ticks_usec()
	var wet_points := 0
	for block: Vector2i in blocks:
		var context := fields.water(block)
		var raw := context.raw_context()
		for key: Variant in raw:
			if key in ["water", "ponds", "rivers", "region"]:
				continue
			ctx.update(str(key).to_utf8_buffer())
			ctx.update(var_to_bytes(raw[key]))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(block)
		var cover := context.coverage()
		for i in 3000:
			var p := cover.position + Vector2(rng.randf(), rng.randf()) * cover.size
			var wet := context.is_wet(p)
			if wet: wet_points += 1
			ctx.update(var_to_bytes([wet, context.level_at(p), context.signed_depth_at(p),
				context.shore_distance_at(p)]))
			if i % 10 == 0:
				var q := p + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
				if cover.has_point(q):
					ctx.update(var_to_bytes(context.wet_intervals(p, q)))
	print("CACHECHECK digest=%s ms=%.0f wet_points=%d hits=%d misses=%d writes=%d" % [
		ctx.finish().hex_encode().left(16), (Time.get_ticks_usec() - t) / 1000.0, wet_points,
		DISK_CACHE.hits, DISK_CACHE.misses, DISK_CACHE.writes])
	quit()
