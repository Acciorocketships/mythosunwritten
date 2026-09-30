extends SceneTree
## September 27 mountain-water diagnosis (seed 2697992464, player
## (468.6,35.9,872.1), crosshair (472.1,34.3,878.4)). Dumps the rivers near
## the site, their source heads, hydraulic profile along the reach, the chunk
## water field against the heightfield ground, and the slope envelope.
## Usage: Godot --headless --path . -s res://tests/harness/mountain_water_probe.gd -- OUT.json
const SEED := 2697992464
const SITE := Vector2(472.1, 878.4)

func _init() -> void: _run.call_deferred()

func _run() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var water := TerrainWorldTuning.make_water(SEED)
	var plan := TerrainWorldTuning.make_heightfield(SEED, water)
	var fields := WorldFieldBlockCache.new(plan, water, 0, 0, 64)
	var chunk := WorldFieldBlockCache.key_of(SITE)
	var region := fields.region(chunk)
	var ctx := fields.water(chunk)
	var raw := ctx.raw_context()
	var result := {"chunk": str(chunk), "rivers": [], "grid": [], "steep": []}
	for tr: RiverTrace in raw.rivers:
		var prof := WaterField.profile(tr, region)
		var levels: PackedFloat32Array = prof.levels
		var near := []
		var closest := INF
		for i in tr.points.size():
			var p := tr.points[i]
			closest = minf(closest, p.distance_to(SITE))
			if p.distance_to(SITE) > 260.0: continue
			var g := TerrainSurfaceField.surface_y(region, p.x, p.y) if ctx.covers(p) else NAN
			near.append({"i": i, "p": str(p.round()), "bed": snappedf(tr.beds[i], .01),
				"level": snappedf(levels[i], .01), "ground": snappedf(g, .01),
				"natural": snappedf(water.noise_h(p), .01), "smooth": snappedf(water.smooth_h(p), .01),
				"field": snappedf(ctx.level_at(p), .01) if ctx.covers(p) else NAN})
		var src := tr.points[0]
		result.rivers.append({"cell": str(tr.source_cell), "source": str(src.round()),
			"source_smooth": water.smooth_h(src), "source_natural": water.noise_h(src),
			"pool_level": tr.source_pool.surface_y() if tr.source_pool != null else NAN,
			"pool_center": str(tr.source_pool.center.round()) if tr.source_pool != null else "",
			"n": tr.points.size(), "joined": tr.joined, "closest": closest,
			"descents": prof.descents.size(), "near": near})
	for x in range(-60, 61, 4):
		for z in range(-60, 61, 4):
			var p := SITE + Vector2(x, z)
			if not ctx.covers(p): continue
			var g := TerrainSurfaceField.surface_y(region, p.x, p.y)
			result.grid.append([p.x, p.y, snappedf(g, .01), snappedf(WaterField.level_at(raw, p), .01),
				ctx.is_wet(p), region.storey_at(roundi(p.x / 24.0), roundi(p.y / 24.0))])
	for s in WaterField.steep_spans(raw, Rect2(SITE - Vector2.ONE * 120, Vector2.ONE * 240)):
		result.steep.append(str(s))
	FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(result, " "))
	print("done ", out_path)
	quit()
